import type {Firestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import type {
  AiAccess,
  ChatRequest,
  EvidenceItem,
  GenerateRequest,
  GroundedContext,
} from "./types";

const MAX_NOTE_LENGTH = 1_600;
const MAX_ACTIVE_MEMBERS = 40;
const MAX_ACTIVE_MOMENTS = 60;
const MAX_CHAT_OCCURRENCES = 24;
const MAX_CHAT_RHYTHMS = 16;
const MAX_CHAT_MEMORIES = 8;
const MAX_CHAT_REMINDERS = 16;

interface ActiveMember {
  id: string;
  ageGroup: string;
  data: Record<string, unknown>;
}

interface ActiveMoment {
  id: string;
  data: Record<string, unknown>;
}

export async function buildGenerateContext(
  db: Firestore,
  access: AiAccess,
  request: GenerateRequest,
  allowYoungChildData: boolean,
): Promise<GroundedContext> {
  const [members, hasYoungChild] = await Promise.all([
    activeMembers(db, access.familyId),
    familyHasYoungChild(db, access.familyId),
  ]);
  requireYoungChildDataProtection(hasYoungChild, allowYoungChildData);
  const allowedMemberIds = new Set(members.map((member) => member.id));
  const moments = await (request.feature === "simulationParse"
    ? recurringMoments(db, access.familyId)
    : activeMoments(db, access.familyId));
  const allowedMomentIds = new Set(moments.map((moment) => moment.id));
  const evidence: EvidenceItem[] = [];

  switch (request.feature) {
    case "memoryReflection": {
      if (!request.targetId) {
        throw new HttpsError(
          "invalid-argument",
          "Choose a Memory to reflect on.",
        );
      }
      const memoryRef = db.doc(
        `families/${access.familyId}/memories/${request.targetId}`,
      );
      const memorySnapshot = await memoryRef.get();
      if (!memorySnapshot.exists) {
        throw new HttpsError("not-found", "This Memory could not be found.");
      }
      const memory = memorySnapshot.data() ?? {};
      if (!stringValue(memory.note)) {
        throw new HttpsError(
          "failed-precondition",
          "Add a family note before creating a reflection.",
        );
      }
      const sourceVersion = memorySourceVersion(memory);
      const momentId = stringValue(memory.momentId);
      const instanceId = stringValue(memory.instanceId);
      const [momentSnapshot, instanceSnapshot] = await Promise.all([
        momentId
          ? db.doc(`families/${access.familyId}/moments/${momentId}`).get()
          : Promise.resolve(null),
        instanceId
          ? db
              .doc(
                `families/${access.familyId}/momentInstances/${instanceId}`,
              )
              .get()
          : Promise.resolve(null),
      ]);
      evidence.push({
        id: "memory.note",
        text: JSON.stringify({
          familyNote: truncate(stringValue(memory.note), MAX_NOTE_LENGTH),
          title: truncate(stringValue(memory.title), 120),
          occurredAt: timestampValue(memory.occurredAt),
          isLegacyOccurrence: !instanceId,
        }),
      });
      if (momentSnapshot?.exists) {
        evidence.push({
          id: "memory.moment",
          text: JSON.stringify(momentFacts(momentSnapshot.data() ?? {})),
        });
      }
      if (instanceSnapshot?.exists) {
        evidence.push({
          id: "memory.occurrence",
          text: JSON.stringify(
            instanceFacts(instanceSnapshot.data() ?? {}),
          ),
        });
      }
      return {
        evidence,
        allowedMomentIds,
        allowedMemberIds,
        hasYoungChild,
        sourceVersion,
      };
    }

    case "simulationParse": {
      const recurringMoments = moments.filter(
        (moment) => moment.data.type === "recurring",
      );
      allowedMomentIds.clear();
      recurringMoments.forEach((moment) => allowedMomentIds.add(moment.id));
      evidence.push({
        id: "simulation.availableMoments",
        text: JSON.stringify(
          recurringMoments.map((moment) => ({
            momentId: moment.id,
            title: truncate(stringValue(moment.data.title), 100),
            type: stringValue(moment.data.type),
            category: stringValue(moment.data.category),
            expectedIntervalDays: numberValue(
              moment.data.expectedIntervalDays,
            ),
            preferredStartMinutes: numberValue(
              moment.data.preferredStartMinutes,
            ),
            preferredWeekday: numberValue(moment.data.preferredWeekday),
            preferredDayOfMonth: numberValue(
              moment.data.preferredDayOfMonth,
            ),
            preferredMonth: numberValue(moment.data.preferredMonth),
            participantIds: stringList(moment.data.expectedParticipantIds),
          })),
        ),
      });
      evidence.push({
        id: "simulation.availableMembers",
        text: JSON.stringify(
          members.map((member, index) => {
            const mayExposeName =
              member.ageGroup !== "child" || allowYoungChildData;
            return {
              memberId: member.id,
              label: `${member.ageGroup} member ${index + 1}`,
              ...(mayExposeName
                ? {
                    displayName: truncate(
                      stringValue(member.data.displayName),
                      80,
                    ),
                  }
                : {}),
              ageGroup: member.ageGroup,
              relationship: stringValue(member.data.relationship),
            };
          }),
        ),
      });
      evidence.push({
        id: "simulation.request",
        text: request.prompt ?? "",
      });
      evidence.push({
        id: "simulation.currentDateUtc",
        text: new Date().toISOString(),
      });
      break;
    }

    case "homeInsight": {
      evidence.push({
        id: "insight.deterministicDecision",
        text: JSON.stringify(request.grounding),
      });
      evidence.push(
        ...(await loadHomeInsightEvidence(
          db,
          access,
          request.grounding,
        )),
      );
      break;
    }

    case "weeklyReport":
      evidence.push({
        id: "weekly.deterministicReport",
        text: JSON.stringify(request.grounding),
      });
      break;

    case "digitalTwinReflection":
      evidence.push({
        id: "twin.deterministicPatterns",
        text: JSON.stringify(request.grounding),
      });
      break;

    case "simulationExplain":
      evidence.push({
        id: "simulation.deterministicProjection",
        text: JSON.stringify(request.grounding),
      });
      break;
  }

  return {
    evidence,
    allowedMomentIds,
    allowedMemberIds,
    hasYoungChild,
  };
}

export function memorySourceVersion(
  data: Record<string, unknown>,
): string {
  return JSON.stringify({
    note: stringValue(data.note),
    title: stringValue(data.title),
    occurredAt: timestampValue(data.occurredAt),
    momentId: stringValue(data.momentId),
    instanceId: stringValue(data.instanceId),
  });
}

export async function buildChatContext(
  db: Firestore,
  access: AiAccess,
  request: ChatRequest,
  allowYoungChildData: boolean,
): Promise<GroundedContext> {
  const currentTime = new Date();
  const viewerLocalTime = new Date(
    currentTime.getTime() + request.timezoneOffsetMinutes * 60_000,
  );
  const [members, hasYoungChild] = await Promise.all([
    activeMembers(db, access.familyId),
    familyHasYoungChild(db, access.familyId),
  ]);
  requireYoungChildDataProtection(hasYoungChild, allowYoungChildData);
  const [
    moments,
    upcomingInstanceSnapshot,
    recentInstanceSnapshot,
    rhythmSnapshot,
    memorySnapshot,
    reminderSnapshot,
  ] = await Promise.all([
    activeMoments(db, access.familyId),
    db
      .collection(`families/${access.familyId}/momentInstances`)
      .where("scheduledStartAt", ">=", currentTime)
      .orderBy("scheduledStartAt", "asc")
      .limit(MAX_CHAT_OCCURRENCES / 2)
      .get(),
    db
      .collection(`families/${access.familyId}/momentInstances`)
      .where("scheduledStartAt", "<", currentTime)
      .orderBy("scheduledStartAt", "desc")
      .limit(MAX_CHAT_OCCURRENCES / 2)
      .get(),
    db
      .collection(`families/${access.familyId}/rhythms`)
      .orderBy("updatedAt", "desc")
      .limit(MAX_CHAT_RHYTHMS)
      .get(),
    db
      .collection(`families/${access.familyId}/memories`)
      .orderBy("occurredAt", "desc")
      .limit(MAX_CHAT_MEMORIES)
      .select("momentId", "instanceId", "title", "occurredAt")
      .get(),
    db
      .collection(`families/${access.familyId}/careActions`)
      .where("assignedMemberId", "==", access.uid)
      .orderBy("assignedMemberId", "asc")
      .limit(MAX_CHAT_REMINDERS)
      .select(
        "momentId",
        "instanceId",
        "title",
        "reason",
        "dueAt",
        "status",
        "source",
        "updatedAt",
      )
      .get(),
  ]);
  const upcomingInstances = upcomingInstanceSnapshot.docs.map((document) => ({
    occurrenceId: document.id,
    ...instanceFacts(document.data()),
  }));
  const recentInstances = recentInstanceSnapshot.docs.map((document) => ({
    occurrenceId: document.id,
    ...instanceFacts(document.data()),
  }));
  const rhythms = rhythmSnapshot.docs.map((document) => ({
    momentId: stringValue(document.data().momentId),
    status: stringValue(document.data().status),
    confidence: stringValue(document.data().confidence),
    currentGapDays: numberValue(document.data().currentGapDays),
    expectedIntervalDays: numberValue(
      document.data().expectedIntervalDays,
    ),
    occurrenceCount: numberValue(document.data().occurrenceCount),
  }));
  const memories = memorySnapshot.docs.map((document) => {
    const data = document.data();
    return {
      memoryId: document.id,
      momentId: stringValue(data.momentId),
      occurrenceId: stringValue(data.instanceId),
      title: truncate(stringValue(data.title), 120),
      occurredAt: timestampValue(data.occurredAt),
    };
  });
  const reminders = [...reminderSnapshot.docs]
    .sort(
      (left, right) =>
        timestampMillis(left.data().dueAt) -
        timestampMillis(right.data().dueAt),
    )
    .map((document) => reminderFacts(document.data()));

  return {
    evidence: [
      {
        id: "context.currentTime",
        text: JSON.stringify({
          currentTimeUtc: currentTime.toISOString(),
          viewerLocalDateTime: viewerLocalTime
            .toISOString()
            .replace(/Z$/, ""),
          timezoneOffsetMinutes: request.timezoneOffsetMinutes,
        }),
      },
      {
        id: "family.members",
        text: JSON.stringify({
          activeMemberCount: members.length,
          ageGroups: members.map((member) => member.ageGroup),
        }),
      },
      {
        id: "family.moments",
        text: JSON.stringify(
          moments.map((moment) => ({
            momentId: moment.id,
            title: truncate(stringValue(moment.data.title), 100),
            type: stringValue(moment.data.type),
            category: stringValue(moment.data.category),
            importanceLevel: numberValue(moment.data.importanceLevel),
            expectedIntervalDays: numberValue(
              moment.data.expectedIntervalDays,
            ),
          })),
        ),
      },
      {
        id: "family.upcomingOccurrences",
        text: JSON.stringify(upcomingInstances),
      },
      {
        id: "family.recentOccurrences",
        text: JSON.stringify(recentInstances),
      },
      {id: "family.rhythms", text: JSON.stringify(rhythms)},
      {
        id: "family.memories",
        text: JSON.stringify(memories),
      },
      {
        id: "viewer.reminders",
        text: JSON.stringify(reminders),
      },
      {
        id: "family.dataLimit",
        text: JSON.stringify({
          recordsAreBounded: true,
          memoryNotesIncluded: false,
        }),
      },
      {id: "chat.question", text: request.message},
    ],
    allowedMomentIds: new Set(moments.map((moment) => moment.id)),
    allowedMemberIds: new Set(members.map((member) => member.id)),
    hasYoungChild,
  };
}

function requireYoungChildDataProtection(
  hasYoungChild: boolean,
  allowYoungChildData: boolean,
): void {
  if (hasYoungChild && !allowYoungChildData) {
    throw new HttpsError(
      "failed-precondition",
      "Sakan AI is unavailable for this family until protected young-child data processing is enabled.",
    );
  }
}

async function loadHomeInsightEvidence(
  db: Firestore,
  access: AiAccess,
  grounding: Record<string, unknown>,
): Promise<EvidenceItem[]> {
  const momentId = stringValue(grounding.relatedMomentId);
  const instanceId = stringValue(grounding.relatedInstanceId);
  const reminderId = stringValue(grounding.relatedReminderId);
  const [moment, instance, reminder, viewerSnapshot] = await Promise.all([
    loadRelatedDocument(db, access.familyId, "moments", momentId, "Moment"),
    loadRelatedDocument(
      db,
      access.familyId,
      "momentInstances",
      instanceId,
      "Moment occurrence",
    ),
    loadRelatedDocument(
      db,
      access.familyId,
      "careActions",
      reminderId,
      "Reminder",
    ),
    db.doc(`families/${access.familyId}/members/${access.uid}`).get(),
  ]);

  if (reminder && stringValue(reminder.assignedMemberId) !== access.uid) {
    throw new HttpsError(
      "permission-denied",
      "This reminder belongs to another family member.",
    );
  }

  assertMatchingLink(momentId, stringValue(instance?.momentId));
  assertMatchingLink(momentId, stringValue(reminder?.momentId));
  assertMatchingLink(instanceId, stringValue(reminder?.instanceId));

  const viewer = viewerSnapshot.data() ?? {};
  const participantSource = instance ?? moment;
  const expectedParticipantIds = participantSource
    ? stringList(participantSource.expectedParticipantIds)
    : null;
  const evidence: EvidenceItem[] = [
    {
      id: "viewer.context",
      text: JSON.stringify({
        displayName: truncate(access.displayName, 80),
        role: access.role,
        ageGroup: access.ageGroup,
        relationship: stringValue(viewer.relationship),
        isExpectedParticipant: expectedParticipantIds
          ? expectedParticipantIds.includes(access.uid)
          : null,
        isReminderAssignee: reminder ? true : null,
      }),
    },
  ];

  if (moment) {
    evidence.push({
      id: "target.moment",
      text: JSON.stringify(momentFacts(moment)),
    });
  }
  if (instance) {
    evidence.push({
      id: "target.occurrence",
      text: JSON.stringify(instanceFacts(instance)),
    });
  }
  if (reminder) {
    evidence.push({
      id: "target.reminder",
      text: JSON.stringify(reminderFacts(reminder)),
    });
  }
  return evidence;
}

async function loadRelatedDocument(
  db: Firestore,
  familyId: string,
  collection: "moments" | "momentInstances" | "careActions",
  id: string | null,
  label: string,
): Promise<Record<string, unknown> | null> {
  if (!id) return null;
  const snapshot = await db.doc(`families/${familyId}/${collection}/${id}`).get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", `${label} could not be found.`);
  }
  return snapshot.data() as Record<string, unknown>;
}

function assertMatchingLink(
  expectedId: string | null,
  linkedId: string | null,
): void {
  if (expectedId && linkedId && expectedId !== linkedId) {
    throw new HttpsError(
      "failed-precondition",
      "The related Moment records no longer match.",
    );
  }
}

async function activeMembers(
  db: Firestore,
  familyId: string,
): Promise<ActiveMember[]> {
  const snapshot = await db
    .collection(`families/${familyId}/members`)
    .where("isActive", "==", true)
    .orderBy("isActive", "asc")
    .limit(MAX_ACTIVE_MEMBERS)
    .get();
  return snapshot.docs
    .map((document) => {
      const data = document.data() as Record<string, unknown>;
      return {
        id: document.id,
        ageGroup: stringValue(data.ageGroup) ?? "unknown",
        data,
      };
    })
    .sort((left, right) => left.id.localeCompare(right.id));
}

async function activeMoments(
  db: Firestore,
  familyId: string,
): Promise<ActiveMoment[]> {
  const snapshot = await db
    .collection(`families/${familyId}/moments`)
    .orderBy("updatedAt", "desc")
    .limit(MAX_ACTIVE_MOMENTS)
    .get();
  return snapshot.docs
    .filter((document) => document.data().isArchived !== true)
    .map((document) => ({
      id: document.id,
      data: document.data() as Record<string, unknown>,
    }));
}

async function recurringMoments(
  db: Firestore,
  familyId: string,
): Promise<ActiveMoment[]> {
  const snapshot = await db
    .collection(`families/${familyId}/moments`)
    .where("type", "==", "recurring")
    .orderBy("type", "asc")
    .limit(MAX_ACTIVE_MOMENTS)
    .get();
  return snapshot.docs
    .filter((document) => document.data().isArchived !== true)
    .map((document) => ({
      id: document.id,
      data: document.data() as Record<string, unknown>,
    }))
    .sort((left, right) => left.id.localeCompare(right.id));
}

async function familyHasYoungChild(
  db: Firestore,
  familyId: string,
): Promise<boolean> {
  const snapshot = await db
    .collection(`families/${familyId}/members`)
    .where("isActive", "==", true)
    .where("ageGroup", "==", "child")
    .limit(1)
    .get();
  return !snapshot.empty;
}

function momentFacts(data: Record<string, unknown>): Record<string, unknown> {
  return {
    title: truncate(stringValue(data.title), 100),
    type: stringValue(data.type),
    category: stringValue(data.category),
    importanceLevel: numberValue(data.importanceLevel),
    expectedParticipantCount: stringList(data.expectedParticipantIds).length,
    expectedIntervalDays: numberValue(data.expectedIntervalDays),
  };
}

function instanceFacts(
  data: Record<string, unknown>,
): Record<string, unknown> {
  return {
    momentId: stringValue(data.momentId),
    title: truncate(stringValue(data.titleSnapshot), 100),
    status: stringValue(data.status),
    source: stringValue(data.source),
    scheduledStartAt: timestampValue(data.scheduledStartAt),
    actualStartAt: timestampValue(data.actualStartAt),
    actualDurationMinutes: numberValue(data.actualDurationMinutes),
    expectedParticipantCount: stringList(data.expectedParticipantIds).length,
    recordedParticipantCount: new Set([
      ...stringList(data.confirmedParticipantIds),
      ...stringList(data.reportedParticipantIds),
    ]).size,
    confirmationLevel: stringValue(data.confirmationLevel),
  };
}

function reminderFacts(
  data: Record<string, unknown>,
): Record<string, unknown> {
  return {
    momentId: stringValue(data.momentId),
    occurrenceId: stringValue(data.instanceId),
    title: truncate(stringValue(data.title), 100),
    reason: truncate(stringValue(data.reason), 500),
    dueAt: timestampValue(data.dueAt),
    status: stringValue(data.status),
    source: stringValue(data.source),
    evidenceType: stringValue(data.evidenceType),
    completedAt: timestampValue(data.completedAt),
    updatedAt: timestampValue(data.updatedAt),
  };
}

function timestampMillis(value: unknown): number {
  const candidate = value as Partial<Timestamp> | undefined;
  return typeof candidate?.toMillis === "function" ? candidate.toMillis() : 0;
}

function timestampValue(value: unknown): string | null {
  const candidate = value as Partial<Timestamp> | undefined;
  if (typeof candidate?.toDate !== "function") return null;
  return candidate.toDate().toISOString();
}

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function numberValue(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function stringList(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

function truncate(value: string | null, length: number): string | null {
  if (!value) return null;
  return value.length <= length ? value : `${value.slice(0, length)}…`;
}
