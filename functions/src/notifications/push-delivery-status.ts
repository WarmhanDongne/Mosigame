/* eslint-disable require-jsdoc, valid-jsdoc */
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {PushKind} from "./push-policy.js";

/** FCM API outcomes only; this does not prove delivery to a device. */
export async function recordPushDeliveryStatus(
  kind: PushKind,
  accepted: number,
  rejected: number,
): Promise<void> {
  try {
    await getFirestore().collection("pushDeliveryStatus").doc("current").set({
      [kind]: {
        accepted: FieldValue.increment(accepted),
        rejected: FieldValue.increment(rejected),
        lastAttemptAt: FieldValue.serverTimestamp(),
      },
    }, {merge: true});
  } catch (error) {
    // A status write must never change the game push result or cause a resend.
    logger.error("game_push_status_write_failed", {
      kind,
      errorType: error instanceof Error ? error.name : typeof error,
    });
  }
}
