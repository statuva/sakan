import type {Firestore} from "firebase-admin/firestore";

export const GENERATE_FEATURES = [
  "homeInsight",
  "memoryReflection",
  "weeklyReport",
  "digitalTwinReflection",
  "simulationParse",
  "simulationExplain",
] as const;

export type GenerateFeature = (typeof GENERATE_FEATURES)[number];

export interface GenerateRequest {
  version: 1;
  familyId: string;
  feature: GenerateFeature;
  targetId?: string;
  prompt?: string;
  grounding: Record<string, unknown>;
  locale: string;
}
export interface ChatTurn {
  role: "user" | "assistant";
  text: string;
}

export interface ChatRequest {
  version: 1;
  familyId: string;
  message: string;
  conversationId?: string;
  recentMessages: ChatTurn[];
  timezoneOffsetMinutes: number;
  locale: string;
}

export interface AiAccess {
  uid: string;
  familyId: string;
  role: "admin" | "adult";
  ageGroup: "adult" | "senior";
  displayName: string;
}

export interface EvidenceItem {
  id: string;
  text: string;
}

export interface GroundedContext {
  evidence: EvidenceItem[];
  allowedMomentIds: Set<string>;
  allowedMemberIds: Set<string>;
  hasYoungChild: boolean;
  sourceVersion?: string;
}

export interface AiScenario {
  type: string;
  targetMomentId: string | null;
  participantIds: string[];
  newTitle: string | null;
  newCategory: string | null;
  newIntervalDays: number | null;
  newStartMinutes: number | null;
  newWeekday: number | null;
  newDayOfMonth: number | null;
  newMonth: number | null;
  newIsDayFlexible: boolean;
  scope: string;
  assumedDurationMinutes: number | null;
}

export interface AiStructuredOutput {
  title: string | null;
  text: string;
  reasons: string[];
  suggestedActions: string[];
  evidenceRefs: string[];
  quickReplies: string[];
  reminderTitle: string | null;
  reminderReason: string | null;
  scenario: AiScenario | null;
}

export interface OpenAiUsage {
  inputTokens: number;
  cachedInputTokens: number;
  outputTokens: number;
}

export interface OpenAiResult {
  output: AiStructuredOutput;
  usage: OpenAiUsage;
  model: string;
}

export interface RequestContext {
  db: Firestore;
  access: AiAccess;
  grounded: GroundedContext;
}
