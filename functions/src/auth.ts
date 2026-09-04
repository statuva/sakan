import type {Firestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import type {AiAccess} from "./types";

export async function requireAiAdult(
  db: Firestore,
  uid: string | undefined,
  familyId: string,
): Promise<AiAccess> {
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to use Sakan AI.");
  }

  const memberRef = db.doc(`families/${familyId}/members/${uid}`);
  const memberSnapshot = await memberRef.get();
  if (!memberSnapshot.exists) {
    throw new HttpsError(
      "permission-denied",
      "You are not a member of this family.",
    );
  }

  const member = memberSnapshot.data() ?? {};
  if (member.isActive !== true) {
    throw new HttpsError(
      "permission-denied",
      "This family membership is not active.",
    );
  }
  if (member.role !== "admin" && member.role !== "adult") {
    throw new HttpsError(
      "permission-denied",
      "Sakan AI is currently available to confirmed adults only.",
    );
  }
  if (member.ageGroup !== "adult" && member.ageGroup !== "senior") {
    throw new HttpsError(
      "permission-denied",
      "This AI version is not available to minors.",
    );
  }

  const privacy = asRecord(member.privacyConsent);
  if (privacy.aiConsent !== true) {
    throw new HttpsError(
      "failed-precondition",
      "Turn on AI assistance in Privacy Settings first.",
    );
  }

  return {
    uid,
    familyId,
    role: member.role,
    ageGroup: member.ageGroup,
    displayName:
      typeof member.displayName === "string" ? member.displayName : "Adult",
  };
}

function asRecord(value: unknown): Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}
