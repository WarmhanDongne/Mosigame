/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {createHash} from "node:crypto";
import {getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

export interface PushDevice {uid: string; token: string; locale: string; updatedAt: number}

const collection = () => getFirestore().collection("pushDevices");

export function parsePushToken(value: unknown): string {
  if (typeof value !== "string" || value.length < 16 || value.length > 4096 || !/^[\x21-\x7e]+$/.test(value)) {
    throw new HttpsError("invalid-argument", "올바른 알림 기기 정보가 필요합니다.");
  }
  return value;
}

export function pushDeviceId(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export const registerPushDevice = onCall({region: "asia-northeast3"}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const token = parsePushToken(request.data?.token);
  const locale = request.data?.locale;
  if (!["korean", "english", "simplifiedChinese", "traditionalChinese"].includes(locale)) {
    throw new HttpsError("invalid-argument", "올바른 언어 정보가 필요합니다.");
  }
  await collection().doc(pushDeviceId(token)).set({uid, token, locale, updatedAt: Date.now()});
  return {success: true};
});

export const unregisterPushDevice = onCall({region: "asia-northeast3"}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const token = parsePushToken(request.data?.token);
  const ref = collection().doc(pushDeviceId(token));
  await getFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (snapshot.exists && snapshot.data()?.uid === uid) transaction.delete(ref);
  });
  return {success: true};
});

export async function devicesForUids(uids: string[]): Promise<PushDevice[]> {
  const results = await Promise.all(uids.map((uid) => collection().where("uid", "==", uid).get()));
  const cutoff = Date.now() - 60 * 24 * 60 * 60 * 1000;
  return results.flatMap((snapshot) => snapshot.docs.map((doc) => doc.data() as PushDevice))
    .filter((device) => typeof device.token === "string" && typeof device.updatedAt === "number" && device.updatedAt > cutoff);
}

export async function removeInvalidPushToken(token: string): Promise<void> {
  await collection().doc(pushDeviceId(token)).delete();
}
