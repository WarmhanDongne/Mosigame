/* eslint-disable require-jsdoc, valid-jsdoc */
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getMessaging, Message} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  LocalizedCopy,
  parseLocalizedCopy,
  requireOperationsAdmin,
} from "./announcements.js";

const REGION = "asia-northeast3";
const TEST_PROJECT_ID = "ban-pick-simulator";
const DISPATCH_COLLECTION = "operationsPushDispatches";
const DEVICE_COLLECTION = "pushDevices";
const ACTIVE_DEVICE_AGE_MS = 60 * 24 * 60 * 60 * 1000;
const COMMAND_ID = /^[A-Za-z0-9_-]{16,80}$/;

const DEVICE_LOCALE_TO_COPY = {
  korean: "ko",
  english: "en",
  simplifiedChinese: "zh-Hans",
  traditionalChinese: "zh-Hant",
} as const;

type DeviceLocale = keyof typeof DEVICE_LOCALE_TO_COPY;
type SendOperationsPushData = {
  commandId?: unknown;
  localized?: unknown;
};

type PushDevice = {
  token?: unknown;
  locale?: unknown;
  updatedAt?: unknown;
};

export function assertOperationsTestProject(
  projectId: string | undefined,
): void {
  if (projectId !== TEST_PROJECT_ID) {
    throw new HttpsError(
      "failed-precondition",
      "운영 알림은 TEST Firebase에서만 발송할 수 있습니다.",
    );
  }
}

export function parseOperationsPushRequest(
  data: SendOperationsPushData | undefined,
): {commandId: string; localized: LocalizedCopy} {
  if (typeof data?.commandId !== "string" ||
      !COMMAND_ID.test(data.commandId)) {
    throw new HttpsError(
      "invalid-argument",
      "알림 발송 요청 ID가 올바르지 않습니다.",
    );
  }
  return {
    commandId: data.commandId,
    localized: parseLocalizedCopy(data.localized),
  };
}

export function localizedPushCopy(
  localized: LocalizedCopy,
  deviceLocale: string,
): {title: string; body: string} {
  const locale = DEVICE_LOCALE_TO_COPY[deviceLocale as DeviceLocale] ?? "ko";
  return localized[locale];
}

function activeDevices(
  docs: Array<{id: string; data(): PushDevice}>,
  now: number,
): Array<{id: string; token: string; locale: string}> {
  const cutoff = now - ACTIVE_DEVICE_AGE_MS;
  return docs.flatMap((doc) => {
    const data = doc.data();
    if (typeof data.token !== "string" ||
        typeof data.updatedAt !== "number" ||
        data.updatedAt <= cutoff) {
      return [];
    }
    return [{
      id: doc.id,
      token: data.token,
      locale: typeof data.locale === "string" ? data.locale : "korean",
    }];
  });
}

/** Sends an operator-confirmed push to recently registered phones. */
export const sendOperationsPushNotification = onCall<SendOperationsPushData>(
  {region: REGION, timeoutSeconds: 120},
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    requireOperationsAdmin(request);
    assertOperationsTestProject(
      process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT,
    );
    const {commandId, localized} = parseOperationsPushRequest(request.data);
    const db = getFirestore();
    const dispatchRef = db.collection(DISPATCH_COLLECTION).doc(commandId);
    let claimed = false;
    const previous = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(dispatchRef);
      if (snapshot.exists) return snapshot.data();
      claimed = true;
      transaction.create(dispatchRef, {
        commandId,
        status: "sending",
        localized,
        createdAt: FieldValue.serverTimestamp(),
        createdBy: request.auth?.uid,
      });
      return null;
    });
    if (!claimed) {
      if (previous?.status === "completed") {
        return {
          commandId,
          status: previous.status,
          total: previous.total ?? 0,
          success: previous.success ?? 0,
          failure: previous.failure ?? 0,
        };
      }
      throw new HttpsError(
        "already-exists",
        "같은 알림 발송 요청이 이미 처리 중입니다.",
      );
    }

    try {
      const deviceSnapshot = await db.collection(DEVICE_COLLECTION).get();
      const devices = activeDevices(deviceSnapshot.docs, Date.now());
      let success = 0;
      let failure = 0;
      const invalidDeviceIds: string[] = [];
      for (let offset = 0; offset < devices.length; offset += 500) {
        const batch = devices.slice(offset, offset + 500);
        const messages: Message[] = batch.map((device) => ({
          token: device.token,
          notification: localizedPushCopy(localized, device.locale),
          android: {priority: "high"},
          apns: {payload: {aps: {sound: "default"}}},
          data: {kind: "operationsNotice", dispatchId: commandId},
        }));
        const result = await getMessaging().sendEach(messages);
        success += result.successCount;
        failure += result.failureCount;
        result.responses.forEach((response, index) => {
          const code = response.error?.code;
          if (!response.success &&
              (code === "messaging/registration-token-not-registered" ||
               code === "messaging/invalid-registration-token")) {
            invalidDeviceIds.push(batch[index].id);
          }
        });
      }
      await Promise.all(invalidDeviceIds.map((id) =>
        db.collection(DEVICE_COLLECTION).doc(id).delete()));
      await dispatchRef.update({
        status: "completed",
        total: devices.length,
        success,
        failure,
        invalidTokensRemoved: invalidDeviceIds.length,
        completedAt: FieldValue.serverTimestamp(),
      });
      logger.info("operations_push_completed", {
        commandId,
        total: devices.length,
        success,
        failure,
      });
      return {
        commandId,
        status: "completed",
        total: devices.length,
        success,
        failure,
      };
    } catch (error) {
      await dispatchRef.update({
        status: "failed",
        completedAt: FieldValue.serverTimestamp(),
      });
      logger.error("operations_push_failed", {
        commandId,
        errorType: error instanceof Error ? error.name : typeof error,
      });
      throw new HttpsError("internal", "알림을 발송하지 못했습니다.");
    }
  },
);
