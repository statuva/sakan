import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import type {GenerateFeature} from "./types";

const DAILY_LIMITS: Record<GenerateFeature | "chat", number> = {
  chat: 75,
  homeInsight: 60,
  memoryReflection: 20,
  weeklyReport: 10,
  digitalTwinReflection: 30,
  simulationParse: 30,
  simulationExplain: 30,
};
const GLOBAL_UID_DAILY_REQUEST_LIMIT = 200;
const PROJECT_DAILY_REQUEST_LIMIT = 600;
const RATE_LIMIT_RETENTION_MS = 35 * 24 * 60 * 60 * 1000;

export async function consumeDailyAllowance(
  db: Firestore,
  familyId: string,
  uid: string,
  feature: GenerateFeature | "chat",
): Promise<void> {
  const dateKey = new Date().toISOString().slice(0, 10);
  const familyRef = db.doc(
    `families/${familyId}/aiRateLimits/${uid}_${dateKey}`,
  );
  const uidRef = db.doc(`aiGlobalRateLimits/${uid}_${dateKey}`);
  const projectRef = db.doc(`aiProjectRateLimits/${dateKey}`);

  await db.runTransaction(async (transaction) => {
    const familySnapshot = await transaction.get(familyRef);
    const uidSnapshot = await transaction.get(uidRef);
    const projectSnapshot = await transaction.get(projectRef);

    const familyData = familySnapshot.data() ?? {};
    const counts = asRecord(familyData.counts);
    const familyFeatureUsed =
      typeof counts[feature] === "number" ? (counts[feature] as number) : 0;
    if (familyFeatureUsed >= DAILY_LIMITS[feature]) {
      throw new HttpsError(
        "resource-exhausted",
        "This family AI limit has been reached for today.",
      );
    }

    const uidUsed = requestCount(uidSnapshot.data());
    if (uidUsed >= GLOBAL_UID_DAILY_REQUEST_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "Your AI request limit has been reached for today.",
      );
    }

    const projectUsed = requestCount(projectSnapshot.data());
    if (projectUsed >= PROJECT_DAILY_REQUEST_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "Sakan AI has reached its daily safety limit. Try again tomorrow.",
      );
    }

    const expiresAt = new Date(Date.now() + RATE_LIMIT_RETENTION_MS);
    transaction.set(
      familyRef,
      {
        familyId,
        uid,
        dateKey,
        counts: {
          [feature]: FieldValue.increment(1),
        },
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt,
      },
      {merge: true},
    );
    transaction.set(
      uidRef,
      {
        uid,
        dateKey,
        requestCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt,
      },
      {merge: true},
    );
    transaction.set(
      projectRef,
      {
        dateKey,
        requestCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt,
      },
      {merge: true},
    );
  });
}

function requestCount(value: unknown): number {
  const data = asRecord(value);
  const count = data.requestCount;
  return typeof count === "number" && Number.isFinite(count) && count >= 0
    ? count
    : 0;
}

function asRecord(value: unknown): Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}
