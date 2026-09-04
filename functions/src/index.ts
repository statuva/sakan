import {createHash, randomUUID} from "node:crypto";
import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {defineBoolean, defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {requireAiAdult} from "./auth";
import {
  buildChatContext,
  buildGenerateContext,
} from "./context";
import {
  createStructuredResponse,
  moderateText,
} from "./openai";
import {chatInstructions, generationInstructions} from "./prompts";
import {consumeDailyAllowance} from "./rate_limit";
import type {
  AiStructuredOutput,
  GenerateFeature,
  OpenAiResult,
} from "./types";
import {parseChatRequest, parseGenerateRequest} from "./validation";

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();
const openAiKey = defineSecret("OPENAI_API_KEY");
const enableYoungChildDataAi = defineBoolean(
  "ENABLE_YOUNG_CHILD_DATA_AI",
  {default: false},
);
const GENERATION_LOCK_LEASE_MS = 130_000;

const callableOptions = {
  region: "me-central1",
  secrets: [openAiKey],
  enforceAppCheck: false,
  minInstances: 0,
  maxInstances: 2,
  timeoutSeconds: 120,
  memory: "512MiB" as const,
};

export const sakanGenerate = onCall(
  callableOptions,
  async (call): Promise<Record<string, unknown>> => {
    const request = parseGenerateRequest(call.data);
    const access = await requireAiAdult(
      db,
      call.auth?.uid,
      request.familyId,
    );
    const grounded = await buildGenerateContext(
      db,
      access,
      request,
      enableYoungChildDataAi.value(),
    );

    const inputHash = stableHash({
      version: request.version,
      familyId: request.familyId,
      audience:
        request.feature === "weeklyReport" ||
        request.feature === "memoryReflection"
          ? "family-adults"
          : access.uid,
      feature: request.feature,
      targetId: request.targetId,
      prompt: request.prompt,
      locale: request.locale,
      grounding: request.grounding,
      evidence: grounded.evidence,
      sourceVersion: grounded.sourceVersion,
      promptVersion: 2,
    });

    const cached = await readCachedArtifact(
      request.familyId,
      inputHash,
      request.feature,
    );
    if (cached) {
      return responseEnvelope({
        feature: request.feature,
        output: cached,
        inputHash,
        cached: true,
      });
    }

    const audience =
      request.feature === "weeklyReport" ||
      request.feature === "memoryReflection"
        ? "family-adults"
        : access.uid;
    const artifactRef = db.doc(
      `families/${request.familyId}/aiArtifacts/${inputHash}`,
    );
    const lockId = randomUUID();
    const acquired = await acquireGenerationLock(
      artifactRef.path,
      request.feature,
      audience,
      lockId,
    );
    if (!acquired) {
      const completed = await readCachedArtifact(
        request.familyId,
        inputHash,
        request.feature,
      );
      if (completed) {
        return responseEnvelope({
          feature: request.feature,
          output: completed,
          inputHash,
          cached: true,
        });
      }
      throw new HttpsError("aborted", "Sakan is already preparing this.");
    }

    try {
      await consumeDailyAllowance(
        db,
        request.familyId,
        access.uid,
        request.feature,
      );
      const instructions = generationInstructions(
        request,
        grounded.evidence,
      );
      await moderateText(
        openAiKey.value(),
        `${request.prompt ?? ""}\n${instructions.user}`,
      );
      const generated = await createStructuredResponse({
        apiKey: openAiKey.value(),
        feature: request.feature,
        system: instructions.system,
        user: instructions.user,
        grounded,
      });

      normalizeFeatureOutput(
        generated.output,
        request.feature,
        request.grounding,
      );
      await moderateOutput(openAiKey.value(), generated.output);

      await finalizeGeneration({
        artifactPath: artifactRef.path,
        lockId,
        artifact: {
          familyId: request.familyId,
          feature: request.feature,
          targetId: request.targetId ?? null,
          audience,
          status: "ready",
          response: generated.output,
          inputHash,
          promptVersion: 2,
          model: generated.model,
          usage: generated.usage,
          estimatedCostUsd: estimateCost(generated),
          generatedAt: FieldValue.serverTimestamp(),
          expiresAt: expiryFor(request.feature),
        },
      });
      await logUsage({
        familyId: request.familyId,
        uid: access.uid,
        feature: request.feature,
        inputHash,
        result: generated,
      }).catch(() => undefined);

      return responseEnvelope({
        feature: request.feature,
        output: generated.output,
        inputHash,
        cached: false,
      });
    } catch (error) {
      await releaseGenerationLock(artifactRef.path, lockId).catch(
        () => undefined,
      );
      if (error instanceof HttpsError) throw error;
      throw new HttpsError(
        "unavailable",
        "Sakan AI is temporarily unavailable.",
      );
    }
  },
);

export const sakanChat = onCall(
  callableOptions,
  async (call): Promise<Record<string, unknown>> => {
    const request = parseChatRequest(call.data);
    const access = await requireAiAdult(
      db,
      call.auth?.uid,
      request.familyId,
    );
    const grounded = await buildChatContext(
      db,
      access,
      request,
      enableYoungChildDataAi.value(),
    );
    await consumeDailyAllowance(db, request.familyId, access.uid, "chat");
    const instructions = chatInstructions(request, grounded.evidence);
    await moderateText(
      openAiKey.value(),
      [
        request.message,
        ...request.recentMessages.map((turn) => turn.text),
      ].join("\n"),
    );
    const generated = await createStructuredResponse({
      apiKey: openAiKey.value(),
      feature: "chat",
      system: instructions.system,
      user: instructions.user,
      grounded,
    });
    normalizeFeatureOutput(generated.output, "chat", {});
    await moderateOutput(openAiKey.value(), generated.output);

    const inputHash = stableHash({
      familyId: request.familyId,
      uid: access.uid,
      message: request.message,
      turns: request.recentMessages,
      evidence: grounded.evidence,
      promptVersion: 2,
    });
    await logUsage({
      familyId: request.familyId,
      uid: access.uid,
      feature: "chat",
      inputHash,
      result: generated,
    }).catch(() => undefined);
    return responseEnvelope({
      feature: "chat",
      output: generated.output,
      inputHash,
      cached: false,
    });
  },
);

async function readCachedArtifact(
  familyId: string,
  inputHash: string,
  feature: GenerateFeature,
): Promise<AiStructuredOutput | null> {
  const snapshot = await db
    .doc(`families/${familyId}/aiArtifacts/${inputHash}`)
    .get();
  const data = snapshot.data();
  if (
    !snapshot.exists ||
    data?.status !== "ready" ||
    data.feature !== feature ||
    !data.response
  ) {
    return null;
  }
  const expiresAt = data.expiresAt;
  if (
    expiresAt &&
    typeof expiresAt.toMillis === "function" &&
    expiresAt.toMillis() <= Date.now()
  ) {
    return null;
  }
  return data.response as AiStructuredOutput;
}

async function acquireGenerationLock(
  artifactPath: string,
  feature: GenerateFeature,
  audience: string,
  lockId: string,
): Promise<boolean> {
  const ref = db.doc(artifactPath);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data();
    const now = Date.now();
    if (data?.status === "ready" && !isExpired(data.expiresAt, now)) {
      return false;
    }
    if (
      data?.status === "generating" &&
      data.lockedAt &&
      typeof data.lockedAt.toMillis === "function" &&
      data.lockedAt.toMillis() > now - GENERATION_LOCK_LEASE_MS
    ) {
      throw new HttpsError(
        "aborted",
        "Sakan is already preparing this explanation.",
      );
    }
    transaction.set(ref, {
      feature,
      status: "generating",
      audience,
      lockId,
      lockedAt: FieldValue.serverTimestamp(),
      expiresAt: new Date(now + GENERATION_LOCK_LEASE_MS),
    });
    return true;
  });
}

async function finalizeGeneration(args: {
  artifactPath: string;
  lockId: string;
  artifact: Record<string, unknown>;
}): Promise<void> {
  const artifactRef = db.doc(args.artifactPath);

  await db.runTransaction(async (transaction) => {
    const artifactSnapshot = await transaction.get(artifactRef);
    const artifactData = artifactSnapshot.data();
    if (
      artifactData?.status !== "generating" ||
      artifactData.lockId !== args.lockId
    ) {
      throw new HttpsError(
        "aborted",
        "This Sakan generation was replaced by a newer request.",
      );
    }

    transaction.set(artifactRef, args.artifact);
  });
}

async function releaseGenerationLock(
  artifactPath: string,
  lockId: string,
): Promise<void> {
  const ref = db.doc(artifactPath);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data();
    if (data?.status === "generating" && data.lockId === lockId) {
      transaction.delete(ref);
    }
  });
}

function isExpired(value: unknown, now: number): boolean {
  const candidate = value as {toMillis?: () => number} | undefined;
  return (
    typeof candidate?.toMillis === "function" && candidate.toMillis() <= now
  );
}

function normalizeFeatureOutput(
  output: AiStructuredOutput,
  feature: GenerateFeature | "chat",
  grounding: Record<string, unknown>,
): void {
  if (feature !== "homeInsight" || grounding.actionType !== "addReminder") {
    output.reminderTitle = null;
    output.reminderReason = null;
  }
  if (feature !== "simulationParse") output.scenario = null;
  if (feature !== "chat") output.quickReplies = [];
}

async function moderateOutput(
  apiKey: string,
  output: AiStructuredOutput,
): Promise<void> {
  await moderateText(
    apiKey,
    [
      output.title,
      output.text,
      ...output.reasons,
      ...output.suggestedActions,
      ...output.quickReplies,
      output.reminderTitle,
      output.reminderReason,
    ]
      .filter((item): item is string => typeof item === "string")
      .join("\n"),
  );
}

function responseEnvelope(args: {
  feature: GenerateFeature | "chat";
  output: AiStructuredOutput;
  inputHash: string;
  cached: boolean;
}): Record<string, unknown> {
  return {
    requestId: randomUUID(),
    feature: args.feature,
    ...args.output,
    source: "ai",
    generatedAt: new Date().toISOString(),
    inputHash: args.inputHash,
    cached: args.cached,
  };
}

function expiryFor(feature: GenerateFeature): Date {
  const durationMs = {
    homeInsight: 6 * 60 * 60 * 1000,
    memoryReflection: 365 * 24 * 60 * 60 * 1000,
    weeklyReport: 365 * 24 * 60 * 60 * 1000,
    digitalTwinReflection: 6 * 60 * 60 * 1000,
    simulationParse: 24 * 60 * 60 * 1000,
    simulationExplain: 7 * 24 * 60 * 60 * 1000,
  }[feature];
  return new Date(Date.now() + durationMs);
}

async function logUsage(args: {
  familyId: string;
  uid: string;
  feature: GenerateFeature | "chat";
  inputHash: string;
  result: OpenAiResult;
}): Promise<void> {
  await db.collection("aiUsageEvents").add({
    familyIdHash: stableHash(args.familyId),
    uidHash: stableHash(args.uid),
    feature: args.feature,
    inputHash: args.inputHash,
    model: args.result.model,
    usage: args.result.usage,
    estimatedCostUsd: estimateCost(args.result),
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000),
  });
}

function estimateCost(result: OpenAiResult): number {
  const isLuna = result.model.includes("luna");
  const inputRate = isLuna ? 0.2 : 2;
  const cachedRate = isLuna ? 0.02 : 0.2;
  const outputRate = isLuna ? 1.2 : 12;
  const uncached = Math.max(
    0,
    result.usage.inputTokens - result.usage.cachedInputTokens,
  );
  return (
    (uncached * inputRate +
      result.usage.cachedInputTokens * cachedRate +
      result.usage.outputTokens * outputRate) /
    1_000_000
  );
}

function stableHash(value: unknown): string {
  return createHash("sha256").update(stableStringify(value)).digest("hex");
}

function stableStringify(value: unknown): string {
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }
  if (value != null && typeof value === "object") {
    return `{${Object.entries(value as Record<string, unknown>)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(
        ([key, item]) =>
          `${JSON.stringify(key)}:${stableStringify(item)}`,
      )
      .join(",")}}`;
  }
  return JSON.stringify(value) ?? "null";
}
