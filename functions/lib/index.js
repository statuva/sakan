"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sakanChat = exports.sakanGenerate = void 0;
const node_crypto_1 = require("node:crypto");
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const params_1 = require("firebase-functions/params");
const https_1 = require("firebase-functions/v2/https");
const auth_1 = require("./auth");
const context_1 = require("./context");
const openai_1 = require("./openai");
const prompts_1 = require("./prompts");
const rate_limit_1 = require("./rate_limit");
const validation_1 = require("./validation");
if ((0, app_1.getApps)().length === 0) {
    (0, app_1.initializeApp)();
}
const db = (0, firestore_1.getFirestore)();
const openAiKey = (0, params_1.defineSecret)("OPENAI_API_KEY");
const enableYoungChildDataAi = (0, params_1.defineBoolean)("ENABLE_YOUNG_CHILD_DATA_AI", { default: false });
const GENERATION_LOCK_LEASE_MS = 130_000;
const callableOptions = {
    region: "me-central1",
    secrets: [openAiKey],
    enforceAppCheck: false,
    minInstances: 0,
    maxInstances: 2,
    timeoutSeconds: 120,
    memory: "512MiB",
};
exports.sakanGenerate = (0, https_1.onCall)(callableOptions, async (call) => {
    const request = (0, validation_1.parseGenerateRequest)(call.data);
    const access = await (0, auth_1.requireAiAdult)(db, call.auth?.uid, request.familyId);
    const grounded = await (0, context_1.buildGenerateContext)(db, access, request, enableYoungChildDataAi.value());
    const inputHash = stableHash({
        version: request.version,
        familyId: request.familyId,
        audience: request.feature === "weeklyReport" ||
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
    const cached = await readCachedArtifact(request.familyId, inputHash, request.feature);
    if (cached) {
        return responseEnvelope({
            feature: request.feature,
            output: cached,
            inputHash,
            cached: true,
        });
    }
    const audience = request.feature === "weeklyReport" ||
        request.feature === "memoryReflection"
        ? "family-adults"
        : access.uid;
    const artifactRef = db.doc(`families/${request.familyId}/aiArtifacts/${inputHash}`);
    const lockId = (0, node_crypto_1.randomUUID)();
    const acquired = await acquireGenerationLock(artifactRef.path, request.feature, audience, lockId);
    if (!acquired) {
        const completed = await readCachedArtifact(request.familyId, inputHash, request.feature);
        if (completed) {
            return responseEnvelope({
                feature: request.feature,
                output: completed,
                inputHash,
                cached: true,
            });
        }
        throw new https_1.HttpsError("aborted", "Sakan is already preparing this.");
    }
    try {
        await (0, rate_limit_1.consumeDailyAllowance)(db, request.familyId, access.uid, request.feature);
        const instructions = (0, prompts_1.generationInstructions)(request, grounded.evidence);
        await (0, openai_1.moderateText)(openAiKey.value(), `${request.prompt ?? ""}\n${instructions.user}`);
        const generated = await (0, openai_1.createStructuredResponse)({
            apiKey: openAiKey.value(),
            feature: request.feature,
            system: instructions.system,
            user: instructions.user,
            grounded,
        });
        normalizeFeatureOutput(generated.output, request.feature, request.grounding);
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
                generatedAt: firestore_1.FieldValue.serverTimestamp(),
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
    }
    catch (error) {
        await releaseGenerationLock(artifactRef.path, lockId).catch(() => undefined);
        if (error instanceof https_1.HttpsError)
            throw error;
        throw new https_1.HttpsError("unavailable", "Sakan AI is temporarily unavailable.");
    }
});
exports.sakanChat = (0, https_1.onCall)(callableOptions, async (call) => {
    const request = (0, validation_1.parseChatRequest)(call.data);
    const access = await (0, auth_1.requireAiAdult)(db, call.auth?.uid, request.familyId);
    const grounded = await (0, context_1.buildChatContext)(db, access, request, enableYoungChildDataAi.value());
    await (0, rate_limit_1.consumeDailyAllowance)(db, request.familyId, access.uid, "chat");
    const instructions = (0, prompts_1.chatInstructions)(request, grounded.evidence);
    await (0, openai_1.moderateText)(openAiKey.value(), [
        request.message,
        ...request.recentMessages.map((turn) => turn.text),
    ].join("\n"));
    const generated = await (0, openai_1.createStructuredResponse)({
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
});
async function readCachedArtifact(familyId, inputHash, feature) {
    const snapshot = await db
        .doc(`families/${familyId}/aiArtifacts/${inputHash}`)
        .get();
    const data = snapshot.data();
    if (!snapshot.exists ||
        data?.status !== "ready" ||
        data.feature !== feature ||
        !data.response) {
        return null;
    }
    const expiresAt = data.expiresAt;
    if (expiresAt &&
        typeof expiresAt.toMillis === "function" &&
        expiresAt.toMillis() <= Date.now()) {
        return null;
    }
    return data.response;
}
async function acquireGenerationLock(artifactPath, feature, audience, lockId) {
    const ref = db.doc(artifactPath);
    return db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const data = snapshot.data();
        const now = Date.now();
        if (data?.status === "ready" && !isExpired(data.expiresAt, now)) {
            return false;
        }
        if (data?.status === "generating" &&
            data.lockedAt &&
            typeof data.lockedAt.toMillis === "function" &&
            data.lockedAt.toMillis() > now - GENERATION_LOCK_LEASE_MS) {
            throw new https_1.HttpsError("aborted", "Sakan is already preparing this explanation.");
        }
        transaction.set(ref, {
            feature,
            status: "generating",
            audience,
            lockId,
            lockedAt: firestore_1.FieldValue.serverTimestamp(),
            expiresAt: new Date(now + GENERATION_LOCK_LEASE_MS),
        });
        return true;
    });
}
async function finalizeGeneration(args) {
    const artifactRef = db.doc(args.artifactPath);
    await db.runTransaction(async (transaction) => {
        const artifactSnapshot = await transaction.get(artifactRef);
        const artifactData = artifactSnapshot.data();
        if (artifactData?.status !== "generating" ||
            artifactData.lockId !== args.lockId) {
            throw new https_1.HttpsError("aborted", "This Sakan generation was replaced by a newer request.");
        }
        transaction.set(artifactRef, args.artifact);
    });
}
async function releaseGenerationLock(artifactPath, lockId) {
    const ref = db.doc(artifactPath);
    await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const data = snapshot.data();
        if (data?.status === "generating" && data.lockId === lockId) {
            transaction.delete(ref);
        }
    });
}
function isExpired(value, now) {
    const candidate = value;
    return (typeof candidate?.toMillis === "function" && candidate.toMillis() <= now);
}
function normalizeFeatureOutput(output, feature, grounding) {
    if (feature !== "homeInsight" || grounding.actionType !== "addReminder") {
        output.reminderTitle = null;
        output.reminderReason = null;
    }
    if (feature !== "simulationParse")
        output.scenario = null;
    if (feature !== "chat")
        output.quickReplies = [];
}
async function moderateOutput(apiKey, output) {
    await (0, openai_1.moderateText)(apiKey, [
        output.title,
        output.text,
        ...output.reasons,
        ...output.suggestedActions,
        ...output.quickReplies,
        output.reminderTitle,
        output.reminderReason,
    ]
        .filter((item) => typeof item === "string")
        .join("\n"));
}
function responseEnvelope(args) {
    return {
        requestId: (0, node_crypto_1.randomUUID)(),
        feature: args.feature,
        ...args.output,
        source: "ai",
        generatedAt: new Date().toISOString(),
        inputHash: args.inputHash,
        cached: args.cached,
    };
}
function expiryFor(feature) {
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
async function logUsage(args) {
    await db.collection("aiUsageEvents").add({
        familyIdHash: stableHash(args.familyId),
        uidHash: stableHash(args.uid),
        feature: args.feature,
        inputHash: args.inputHash,
        model: args.result.model,
        usage: args.result.usage,
        estimatedCostUsd: estimateCost(args.result),
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        expiresAt: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000),
    });
}
function estimateCost(result) {
    const isLuna = result.model.includes("luna");
    const inputRate = isLuna ? 0.2 : 2;
    const cachedRate = isLuna ? 0.02 : 0.2;
    const outputRate = isLuna ? 1.2 : 12;
    const uncached = Math.max(0, result.usage.inputTokens - result.usage.cachedInputTokens);
    return ((uncached * inputRate +
        result.usage.cachedInputTokens * cachedRate +
        result.usage.outputTokens * outputRate) /
        1_000_000);
}
function stableHash(value) {
    return (0, node_crypto_1.createHash)("sha256").update(stableStringify(value)).digest("hex");
}
function stableStringify(value) {
    if (Array.isArray(value)) {
        return `[${value.map(stableStringify).join(",")}]`;
    }
    if (value != null && typeof value === "object") {
        return `{${Object.entries(value)
            .sort(([left], [right]) => left.localeCompare(right))
            .map(([key, item]) => `${JSON.stringify(key)}:${stableStringify(item)}`)
            .join(",")}}`;
    }
    return JSON.stringify(value) ?? "null";
}
//# sourceMappingURL=index.js.map