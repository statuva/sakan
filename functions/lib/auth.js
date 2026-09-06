"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requireAiAdult = requireAiAdult;
const https_1 = require("firebase-functions/v2/https");
async function requireAiAdult(db, uid, familyId) {
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Sign in to use Sakan AI.");
    }
    const memberRef = db.doc(`families/${familyId}/members/${uid}`);
    const memberSnapshot = await memberRef.get();
    if (!memberSnapshot.exists) {
        throw new https_1.HttpsError("permission-denied", "You are not a member of this family.");
    }
    const member = memberSnapshot.data() ?? {};
    if (member.isActive !== true) {
        throw new https_1.HttpsError("permission-denied", "This family membership is not active.");
    }
    if (member.role !== "admin" && member.role !== "adult") {
        throw new https_1.HttpsError("permission-denied", "Sakan AI is currently available to confirmed adults only.");
    }
    if (member.ageGroup !== "adult" && member.ageGroup !== "senior") {
        throw new https_1.HttpsError("permission-denied", "This AI version is not available to minors.");
    }
    const privacy = asRecord(member.privacyConsent);
    if (privacy.aiConsent !== true) {
        throw new https_1.HttpsError("failed-precondition", "Turn on AI assistance in Privacy Settings first.");
    }
    return {
        uid,
        familyId,
        role: member.role,
        ageGroup: member.ageGroup,
        displayName: typeof member.displayName === "string" ? member.displayName : "Adult",
    };
}
function asRecord(value) {
    return value != null && typeof value === "object" && !Array.isArray(value)
        ? value
        : {};
}
//# sourceMappingURL=auth.js.map