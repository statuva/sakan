import {HttpsError} from "firebase-functions/v2/https";
import type {
  AiStructuredOutput,
  GenerateFeature,
  GroundedContext,
  OpenAiResult,
} from "./types";

const OPENAI_URL = "https://api.openai.com/v1";
const LUNA_MODEL = "gpt-5.6-luna";
const TERRA_MODEL = "gpt-5.6-terra";
const MODERATION_TIMEOUT_MS = 10_000;
const RESPONSE_TIMEOUT_MS = 75_000;

export async function moderateText(
  apiKey: string,
  text: string,
): Promise<void> {
  const response = await fetch(`${OPENAI_URL}/moderations`, {
    method: "POST",
    headers: headers(apiKey),
    body: JSON.stringify({
      model: "omni-moderation-latest",
      input: text.slice(0, 12_000),
    }),
    signal: AbortSignal.timeout(MODERATION_TIMEOUT_MS),
  });
  if (!response.ok) {
    throw openAiFailure(response.status);
  }
  const body = (await response.json()) as {
    results?: Array<{flagged?: boolean}>;
  };
  if (body.results?.some((result) => result.flagged === true)) {
    throw new HttpsError(
      "invalid-argument",
      "Sakan cannot use AI for that request.",
    );
  }
}

export async function createStructuredResponse(args: {
  apiKey: string;
  feature: GenerateFeature | "chat";
  system: string;
  user: string;
  grounded: GroundedContext;
}): Promise<OpenAiResult> {
  const model = modelFor(args.feature);
  const response = await fetch(`${OPENAI_URL}/responses`, {
    method: "POST",
    headers: headers(args.apiKey),
    body: JSON.stringify({
      model,
      store: false,
      reasoning: {effort: "low"},
      input: [
        {
          role: "system",
          content: [{type: "input_text", text: args.system}],
        },
        {
          role: "user",
          content: [{type: "input_text", text: args.user}],
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "sakan_ai_response",
          strict: true,
          schema: responseSchema(
            args.feature,
            args.grounded.evidence.map((item) => item.id),
          ),
        },
      },
      max_output_tokens: outputLimit(args.feature),
    }),
    signal: AbortSignal.timeout(RESPONSE_TIMEOUT_MS),
  });

  if (!response.ok) {
    throw openAiFailure(response.status);
  }
  const body = (await response.json()) as Record<string, unknown>;
  if (body.status !== "completed") {
    throw new HttpsError(
      "unavailable",
      "Sakan AI could not finish this response. Please try again.",
    );
  }
  const text = extractOutputText(body);
  let decoded: unknown;
  try {
    decoded = JSON.parse(text);
  } catch {
    throw new HttpsError("internal", "Sakan received an invalid AI response.");
  }

  const output = validateOutput(decoded, args.feature, args.grounded);
  const usage = recordValue(body.usage);
  const inputDetails = recordValue(usage.input_tokens_details);

  return {
    output,
    model:
      typeof body.model === "string" && body.model ? body.model : model,
    usage: {
      inputTokens: integerValue(usage.input_tokens),
      cachedInputTokens: integerValue(inputDetails.cached_tokens),
      outputTokens: integerValue(usage.output_tokens),
    },
  };
}

function responseSchema(
  feature: GenerateFeature | "chat",
  evidenceIds: string[],
): Record<string, unknown> {
  const isChat = feature === "chat";
  const isHomeInsight = feature === "homeInsight";
  const isTwinReflection = feature === "digitalTwinReflection";
  const nullableText = {
    anyOf: [
      {type: "string"},
      {type: "null"},
    ],
  };
  const nullOnly = {type: "null"};
  return {
    type: "object",
    additionalProperties: false,
    properties: {
      title: {
        ...(isChat || isTwinReflection
          ? nullOnly
          : isHomeInsight
            ? {type: "string"}
            : nullableText),
      },
      text: {type: "string"},
      reasons: {
        type: "array",
        ...(isChat || isHomeInsight || isTwinReflection
          ? {minItems: 1, maxItems: 1}
          : {maxItems: 3}),
        items: {type: "string"},
      },
      suggestedActions: {
        type: "array",
        ...(isChat
          ? {minItems: 1, maxItems: 1}
          : isHomeInsight
            ? {maxItems: 1}
            : isTwinReflection
              ? {maxItems: 0}
          : {maxItems: 3}),
        items: {type: "string"},
      },
      evidenceRefs: {
        type: "array",
        minItems: 1,
        maxItems: isChat || isHomeInsight || isTwinReflection ? 4 : 12,
        items: {
          type: "string",
          enum: evidenceIds,
        },
      },
      quickReplies: {
        type: "array",
        maxItems: isChat ? 2 : 0,
        items: {type: "string"},
      },
      reminderTitle: isHomeInsight ? nullableText : nullOnly,
      reminderReason: isHomeInsight ? nullableText : nullOnly,
      scenario: feature === "simulationParse"
        ? {
            anyOf: [
              {type: "null"},
              scenarioSchema(),
            ],
          }
        : nullOnly,
    },
    required: [
      "title",
      "text",
      "reasons",
      "suggestedActions",
      "evidenceRefs",
      "quickReplies",
      "reminderTitle",
      "reminderReason",
      "scenario",
    ],
  };
}

function scenarioSchema(): Record<string, unknown> {
  const nullableInteger = {
    anyOf: [{type: "integer"}, {type: "null"}],
  };
  const nullableString = {
    anyOf: [{type: "string"}, {type: "null"}],
  };
  return {
    type: "object",
    additionalProperties: false,
    properties: {
      type: {
        type: "string",
        enum: [
          "addParticipant",
          "removeParticipant",
          "changeTime",
          "changeWeekday",
          "changeDayOfMonth",
          "changeFrequency",
          "assumeNextCompleted",
          "assumeNextMissed",
          "assumeParticipantJoins",
          "createMoment",
        ],
      },
      targetMomentId: nullableString,
      participantIds: {
        type: "array",
        maxItems: 12,
        items: {type: "string"},
      },
      newTitle: nullableString,
      newCategory: {
        anyOf: [
          {type: "string", enum: ["tradition", "milestone", "care", "familyTime"]},
          {type: "null"},
        ],
      },
      newIntervalDays: nullableInteger,
      newStartMinutes: nullableInteger,
      newWeekday: nullableInteger,
      newDayOfMonth: nullableInteger,
      newMonth: nullableInteger,
      newIsDayFlexible: {type: "boolean"},
      scope: {
        type: "string",
        enum: ["nextOccurrence", "futureOccurrences"],
      },
      assumedDurationMinutes: nullableInteger,
    },
    required: [
      "type",
      "targetMomentId",
      "participantIds",
      "newTitle",
      "newCategory",
      "newIntervalDays",
      "newStartMinutes",
      "newWeekday",
      "newDayOfMonth",
      "newMonth",
      "newIsDayFlexible",
      "scope",
      "assumedDurationMinutes",
    ],
  };
}

function validateOutput(
  value: unknown,
  feature: GenerateFeature | "chat",
  grounded: GroundedContext,
): AiStructuredOutput {
  const data = recordValue(value);
  const isChat = feature === "chat";
  const isHomeInsight = feature === "homeInsight";
  const isTwinReflection = feature === "digitalTwinReflection";
  const output: AiStructuredOutput = {
    title: optionalBoundedText(data.title, isHomeInsight ? 60 : 100),
    text: requiredBoundedText(
      data.text,
      isChat ? 600 : isHomeInsight ? 180 : isTwinReflection ? 300 : 1_400,
    ),
    reasons: textList(
      data.reasons,
      isChat || isHomeInsight || isTwinReflection ? 1 : 3,
      isHomeInsight ? 110 : isTwinReflection ? 80 : 220,
    ),
    suggestedActions: textList(
      data.suggestedActions,
      isChat ? 1 : isHomeInsight ? 1 : isTwinReflection ? 0 : 3,
      isHomeInsight ? 90 : 180,
    ),
    evidenceRefs: textList(
      data.evidenceRefs,
      isChat || isHomeInsight || isTwinReflection ? 4 : 12,
      100,
    ),
    quickReplies: textList(data.quickReplies, isChat ? 2 : 3, 90),
    reminderTitle: optionalBoundedText(
      data.reminderTitle,
      isHomeInsight ? 60 : 100,
    ),
    reminderReason: optionalBoundedText(
      data.reminderReason,
      isHomeInsight ? 140 : 600,
    ),
    scenario: data.scenario == null ? null : scenarioValue(data.scenario),
  };

  if (
    isChat &&
    (output.reasons.length !== 1 || output.suggestedActions.length !== 1)
  ) {
    throw new HttpsError(
      "internal",
      "Sakan received an incomplete chat response.",
    );
  }
  if (isHomeInsight && (!output.title || output.reasons.length !== 1)) {
    throw new HttpsError(
      "internal",
      "Sakan received an incomplete insight response.",
    );
  }
  if (
    isTwinReflection &&
    (output.title != null ||
      output.reasons.length !== 1 ||
      output.suggestedActions.length !== 0)
  ) {
    throw new HttpsError(
      "internal",
      "Sakan received an invalid family reflection.",
    );
  }

  const allowedEvidence = new Set(
    grounded.evidence.map((item) => item.id),
  );
  if (output.evidenceRefs.some((id) => !allowedEvidence.has(id))) {
    throw new HttpsError("internal", "AI cited an unknown family fact.");
  }
  if (output.evidenceRefs.length === 0) {
    throw new HttpsError("internal", "AI did not cite supporting evidence.");
  }
  if (feature !== "simulationParse" && output.scenario != null) {
    throw new HttpsError("internal", "AI returned an unexpected simulation.");
  }
  if (feature === "simulationParse" && output.scenario != null) {
    const target = output.scenario.targetMomentId;
    if (target && !grounded.allowedMomentIds.has(target)) {
      throw new HttpsError("internal", "AI selected an unknown Moment.");
    }
    if (
      output.scenario.participantIds.some(
        (memberId) => !grounded.allowedMemberIds.has(memberId),
      )
    ) {
      throw new HttpsError("internal", "AI selected an unknown family member.");
    }
    validateScenario(output.scenario);
  }
  if (feature !== "homeInsight") {
    output.reminderTitle = null;
    output.reminderReason = null;
  }
  if (feature !== "chat") {
    output.quickReplies = [];
  }
  return output;
}

function validateScenario(
  scenario: NonNullable<AiStructuredOutput["scenario"]>,
): void {
  const invalid = (): never => {
    throw new HttpsError(
      "internal",
      "AI returned a simulation that could not be validated.",
    );
  };
  const inRange = (
    value: number | null,
    minimum: number,
    maximum: number,
  ): boolean =>
    value == null ||
    (Number.isInteger(value) && value >= minimum && value <= maximum);

  if (
    !inRange(scenario.newIntervalDays, 1, 365) ||
    !inRange(scenario.newStartMinutes, 0, 1439) ||
    !inRange(scenario.newWeekday, 1, 7) ||
    !inRange(scenario.newDayOfMonth, 1, 31) ||
    !inRange(scenario.newMonth, 1, 12) ||
    !inRange(scenario.assumedDurationMinutes, 1, 1440)
  ) {
    invalid();
  }

  if (scenario.type === "createMoment") {
    if (
      scenario.targetMomentId != null ||
      !scenario.newTitle ||
      !scenario.newCategory ||
      scenario.newIntervalDays == null ||
      scenario.newStartMinutes == null ||
      scenario.participantIds.length === 0
    ) {
      invalid();
    }
    if (!scenario.newIsDayFlexible) {
      if (
        (scenario.newIntervalDays === 7 || scenario.newIntervalDays === 14) &&
        scenario.newWeekday == null
      ) {
        invalid();
      }
      if (
        (scenario.newIntervalDays === 30 || scenario.newIntervalDays === 90) &&
        scenario.newDayOfMonth == null
      ) {
        invalid();
      }
      if (
        scenario.newIntervalDays === 365 &&
        (scenario.newMonth == null || scenario.newDayOfMonth == null)
      ) {
        invalid();
      }
    }
    return;
  }

  if (!scenario.targetMomentId) invalid();
  if (
    (scenario.type === "addParticipant" ||
      scenario.type === "removeParticipant" ||
      scenario.type === "assumeParticipantJoins") &&
    scenario.participantIds.length === 0
  ) {
    invalid();
  }
  if (scenario.type === "changeTime" && scenario.newStartMinutes == null) {
    invalid();
  }
  if (scenario.type === "changeWeekday" && scenario.newWeekday == null) {
    invalid();
  }
  if (
    scenario.type === "changeDayOfMonth" &&
    scenario.newDayOfMonth == null
  ) {
    invalid();
  }
  if (
    scenario.type === "changeFrequency" &&
    scenario.newIntervalDays == null
  ) {
    invalid();
  }
}

function scenarioValue(value: unknown): AiStructuredOutput["scenario"] {
  const data = recordValue(value);
  return {
    type: requiredBoundedText(data.type, 40),
    targetMomentId: optionalBoundedText(data.targetMomentId, 160),
    participantIds: textList(data.participantIds, 12, 160),
    newTitle: optionalBoundedText(data.newTitle, 100),
    newCategory: optionalBoundedText(data.newCategory, 30),
    newIntervalDays: nullableIntegerValue(data.newIntervalDays),
    newStartMinutes: nullableIntegerValue(data.newStartMinutes),
    newWeekday: nullableIntegerValue(data.newWeekday),
    newDayOfMonth: nullableIntegerValue(data.newDayOfMonth),
    newMonth: nullableIntegerValue(data.newMonth),
    newIsDayFlexible: data.newIsDayFlexible === true,
    scope: requiredBoundedText(data.scope, 30),
    assumedDurationMinutes: nullableIntegerValue(
      data.assumedDurationMinutes,
    ),
  };
}

function extractOutputText(body: Record<string, unknown>): string {
  const output = Array.isArray(body.output) ? body.output : [];
  for (const item of output) {
    const itemData = recordValue(item);
    const content = Array.isArray(itemData.content) ? itemData.content : [];
    for (const part of content) {
      const partData = recordValue(part);
      if (partData.type === "refusal") {
        throw new HttpsError(
          "failed-precondition",
          "Sakan AI cannot answer that request.",
        );
      }
      if (
        partData.type === "output_text" &&
        typeof partData.text === "string"
      ) {
        return partData.text;
      }
    }
  }
  throw new HttpsError("internal", "Sakan received an empty AI response.");
}

function modelFor(feature: GenerateFeature | "chat"): string {
  return feature === "chat" ||
    feature === "homeInsight" ||
    feature === "digitalTwinReflection"
    ? LUNA_MODEL
    : TERRA_MODEL;
}

function outputLimit(feature: GenerateFeature | "chat"): number {
  return {
    chat: 800,
    homeInsight: 700,
    memoryReflection: 800,
    weeklyReport: 1_800,
    digitalTwinReflection: 900,
    simulationParse: 1_100,
    simulationExplain: 1_200,
  }[feature];
}

function headers(apiKey: string): Record<string, string> {
  return {
    "Authorization": `Bearer ${apiKey}`,
    "Content-Type": "application/json",
  };
}

function openAiFailure(status: number): HttpsError {
  if (status === 429) {
    return new HttpsError(
      "resource-exhausted",
      "Sakan AI is at its current usage limit.",
    );
  }
  if (status === 400) {
    return new HttpsError(
      "internal",
      "Sakan AI could not process the server request.",
    );
  }
  return new HttpsError("unavailable", "Sakan AI is temporarily unavailable.");
}

function recordValue(value: unknown): Record<string, unknown> {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function requiredBoundedText(value: unknown, maxLength: number): string {
  const text = optionalBoundedText(value, maxLength);
  if (!text) {
    throw new HttpsError("internal", "AI returned missing text.");
  }
  return text;
}

function optionalBoundedText(
  value: unknown,
  maxLength: number,
): string | null {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new HttpsError("internal", "AI returned invalid text.");
  }
  const text = value.trim();
  if (!text || text.length > maxLength) {
    throw new HttpsError("internal", "AI returned text outside safe limits.");
  }
  return text;
}

function textList(
  value: unknown,
  maxItems: number,
  maxLength: number,
): string[] {
  if (!Array.isArray(value) || value.length > maxItems) {
    throw new HttpsError("internal", "AI returned an invalid list.");
  }
  return value.map((item) => requiredBoundedText(item, maxLength));
}

function integerValue(value: unknown): number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0
    ? value
    : 0;
}

function nullableIntegerValue(value: unknown): number | null {
  if (value == null) return null;
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw new HttpsError("internal", "AI returned an invalid number.");
  }
  return value;
}
