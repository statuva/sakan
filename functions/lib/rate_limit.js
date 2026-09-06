"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.consumeDailyAllowance = consumeDailyAllowance;
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const DAILY_LIMITS = {
    chat: 20,
    homeInsight: 24,
    memoryReflection: 4,
    weeklyReport: 3,
    digitalTwinReflection: 12,
    simulationParse: 6,
    simulationExplain: 6,
};
const GLOBAL_UID_DAILY_REQUEST_LIMIT = 40;
const PROJECT_DAILY_REQUEST_LIMIT = 120;
const RATE_LIMIT_RETENTION_MS = 35 * 24 * 60 * 60 * 1000;
async function consumeDailyAllowance(db, familyId, uid, feature) {
    const dateKey = new Date().toISOString().slice(0, 10);
    const familyRef = db.doc(`families/${familyId}/aiRateLimits/${uid}_${dateKey}`);
    const uidRef = db.doc(`aiGlobalRateLimits/${uid}_${dateKey}`);
    const projectRef = db.doc(`aiProjectRateLimits/${dateKey}`);
    await db.runTransaction(async (transaction) => {
        const familySnapshot = await transaction.get(familyRef);
        const uidSnapshot = await transaction.get(uidRef);
        const projectSnapshot = await transaction.get(projectRef);
        const familyData = familySnapshot.data() ?? {};
        const counts = asRecord(familyData.counts);
        const familyFeatureUsed = typeof counts[feature] === "number" ? counts[feature] : 0;
        if (familyFeatureUsed >= DAILY_LIMITS[feature]) {
            throw new https_1.HttpsError("resource-exhausted", "This family AI limit has been reached for today.");
        }
        const uidUsed = requestCount(uidSnapshot.data());
        if (uidUsed >= GLOBAL_UID_DAILY_REQUEST_LIMIT) {
            throw new https_1.HttpsError("resource-exhausted", "Your AI request limit has been reached for today.");
        }
        const projectUsed = requestCount(projectSnapshot.data());
        if (projectUsed >= PROJECT_DAILY_REQUEST_LIMIT) {
            throw new https_1.HttpsError("resource-exhausted", "Sakan AI has reached its daily safety limit. Try again tomorrow.");
        }
        const expiresAt = new Date(Date.now() + RATE_LIMIT_RETENTION_MS);
        transaction.set(familyRef, {
            familyId,
            uid,
            dateKey,
            counts: {
                [feature]: firestore_1.FieldValue.increment(1),
            },
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
            expiresAt,
        }, { merge: true });
        transaction.set(uidRef, {
            uid,
            dateKey,
            requestCount: firestore_1.FieldValue.increment(1),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
            expiresAt,
        }, { merge: true });
        transaction.set(projectRef, {
            dateKey,
            requestCount: firestore_1.FieldValue.increment(1),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
            expiresAt,
        }, { merge: true });
    });
}
function requestCount(value) {
    const data = asRecord(value);
    const count = data.requestCount;
    return typeof count === "number" && Number.isFinite(count) && count >= 0
        ? count
        : 0;
}
function asRecord(value) {
    return value != null && typeof value === "object" && !Array.isArray(value)
        ? value
        : {};
}
//# sourceMappingURL=rate_limit.js.map