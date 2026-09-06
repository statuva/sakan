import {HttpsError} from "firebase-functions/v2/https";
import {
  GENERATE_FEATURES,
  type ChatRequest,
  type ChatTurn,
  type GenerateFeature,
  type GenerateRequest,
} from "./types";

const ID_PATTERN = /^[A-Za-z0-9_-]{1,160}$/;
const LOCALE_PATTERN = /^[A-Za-z]{2,3}(?:[-_][A-Za-z0-9]{2,8})?$/;
const HOME_INSIGHT_SURFACES = new Set(["home", "calendar"]);
const HOME_INSIGHT_ACTION_TYPES = new Set([
  "joinActiveMoment",
  "reviewToday",
  "openReminders",
  "addReminder",
  "startMomentNow",
  "scheduleMoment",
  "manageMoments",
  "none",
]);

export function parseGenerateRequest(value: unknown): GenerateRequest {
  const data = objectValue(value, "request");
  rejectUnknownKeys(data, [
    "version",
    "familyId",
    "feature",
    "targetId",
    "prompt",
    "grounding",
    "locale",
  ]);

  if (data.version !== 1) {
    invalid("Unsupported AI request version.");
  }
  const feature = requiredString(data.feature, "feature", 40);
  if (!GENERATE_FEATURES.includes(feature as GenerateFeature)) {
    invalid("Unknown AI feature.");
  }

  const grounding =
    data.grounding == null ? {} : objectValue(data.grounding, "grounding");
  const serialized = JSON.stringify(grounding);
  if (serialized.length > 18_000) {
    invalid("The AI grounding payload is too large.");
  }
  assertSafeJson(grounding, 0);

  const prompt = optionalString(data.prompt, "prompt", 2_400);
  if (feature === "simulationParse" && !prompt) {
    invalid("Describe the change you want to simulate.");
  }
  if (feature === "homeInsight") {
    validateHomeInsightIds(grounding);
  }

  return {
    version: 1,
    familyId: requiredId(data.familyId, "familyId"),
    feature: feature as GenerateFeature,
    targetId: optionalId(data.targetId, "targetId"),
    prompt,
    grounding,
    locale: parseLocale(data.locale),
  };
}

function validateHomeInsightIds(grounding: Record<string, unknown>): void {
  for (const key of [
    "relatedMomentId",
    "relatedInstanceId",
    "relatedReminderId",
  ]) {
    optionalId(grounding[key], key);
  }

  const surface = grounding.surface;
  if (surface != null && !HOME_INSIGHT_SURFACES.has(surface as string)) {
    invalid("Unknown family insight surface.");
  }

  const actionType = requiredString(
    grounding.actionType,
    "family insight action type",
    40,
  );
  if (!HOME_INSIGHT_ACTION_TYPES.has(actionType)) {
    invalid("Unknown family insight action type.");
  }
}

export function parseChatRequest(value: unknown): ChatRequest {
  const data = objectValue(value, "request");
  rejectUnknownKeys(data, [
    "version",
    "familyId",
    "message",
    "conversationId",
    "recentMessages",
    "timezoneOffsetMinutes",
    "locale",
  ]);
  if (data.version !== 1) {
    invalid("Unsupported AI request version.");
  }

  const rawTurns = data.recentMessages ?? [];
  if (!Array.isArray(rawTurns) || rawTurns.length > 8) {
    invalid("Chat history must contain at most eight messages.");
  }
  const recentMessages = rawTurns.map(parseChatTurn);

  return {
    version: 1,
    familyId: requiredId(data.familyId, "familyId"),
    message: requiredString(data.message, "message", 1_200),
    conversationId: optionalId(data.conversationId, "conversationId"),
    recentMessages,
    timezoneOffsetMinutes: boundedInteger(
      data.timezoneOffsetMinutes,
      "timezone offset",
      -840,
      840,
    ),
    locale: parseLocale(data.locale),
  };
}

function boundedInteger(
  value: unknown,
  name: string,
  minimum: number,
  maximum: number,
): number {
  if (
    typeof value !== "number" ||
    !Number.isInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    invalid(`Invalid ${name}.`);
  }
  return value;
}

function parseChatTurn(value: unknown): ChatTurn {
  const data = objectValue(value, "chat message");
  rejectUnknownKeys(data, ["role", "text"]);
  if (data.role !== "user" && data.role !== "assistant") {
    invalid("Unknown chat message role.");
  }
  return {
    role: data.role,
    text: requiredString(data.text, "chat message", 1_200),
  };
}

function parseLocale(value: unknown): string {
  const locale = optionalString(value, "locale", 20) ?? "en";
  if (!LOCALE_PATTERN.test(locale)) {
    invalid("Invalid locale.");
  }
  return locale.replace("_", "-");
}

function objectValue(
  value: unknown,
  name: string,
): Record<string, unknown> {
  if (
    value == null ||
    typeof value !== "object" ||
    Array.isArray(value)
  ) {
    invalid(`${name} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function rejectUnknownKeys(
  data: Record<string, unknown>,
  allowed: string[],
): void {
  const allowedSet = new Set(allowed);
  if (Object.keys(data).some((key) => !allowedSet.has(key))) {
    invalid("The request contains unsupported fields.");
  }
}

function requiredId(value: unknown, name: string): string {
  const id = requiredString(value, name, 160);
  if (!ID_PATTERN.test(id)) {
    invalid(`Invalid ${name}.`);
  }
  return id;
}

function optionalId(value: unknown, name: string): string | undefined {
  if (value == null) return undefined;
  return requiredId(value, name);
}

function requiredString(
  value: unknown,
  name: string,
  maxLength: number,
): string {
  if (typeof value !== "string") {
    invalid(`${name} must be text.`);
  }
  const clean = value.trim();
  if (!clean || clean.length > maxLength) {
    invalid(`${name} has an invalid length.`);
  }
  return clean;
}

function optionalString(
  value: unknown,
  name: string,
  maxLength: number,
): string | undefined {
  if (value == null) return undefined;
  return requiredString(value, name, maxLength);
}

function assertSafeJson(value: unknown, depth: number): void {
  if (depth > 7) invalid("The grounding payload is too deeply nested.");
  if (
    value == null ||
    typeof value === "string" ||
    typeof value === "boolean" ||
    (typeof value === "number" && Number.isFinite(value))
  ) {
    return;
  }
  if (Array.isArray(value)) {
    if (value.length > 80) invalid("A grounding list is too long.");
    value.forEach((item) => assertSafeJson(item, depth + 1));
    return;
  }
  if (typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>);
    if (entries.length > 80) invalid("A grounding object is too large.");
    for (const [key, item] of entries) {
      if (key.length > 80) invalid("A grounding field name is too long.");
      assertSafeJson(item, depth + 1);
    }
    return;
  }
  invalid("The grounding payload contains an unsupported value.");
}

function invalid(message: string): never {
  throw new HttpsError("invalid-argument", message);
}
