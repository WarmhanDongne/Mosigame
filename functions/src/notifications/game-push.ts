/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {getDatabase} from "firebase-admin/database";
import {getMessaging, Message} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {onValueWritten} from "firebase-functions/v2/database";
import {devicesForUids, removeInvalidPushToken} from "./push-devices.js";
import {eventRecipients, notificationText, PushKind} from "./push-policy.js";

type GameRoom = Parameters<typeof eventRecipients>[1] & {game?: {public?: {
  gameInstanceId?: string; turnSeq?: number; turnUid?: string | null;
  turnDeadlineAt?: number | null; status?: string; recovery?: {paused?: boolean};
}}};

async function sendToParticipants(kind: PushKind, uids: string[]): Promise<void> {
  if (uids.length === 0) return;
  const devices = await devicesForUids(uids);
  for (let offset = 0; offset < devices.length; offset += 500) {
    const batch = devices.slice(offset, offset + 500);
    const messages: Message[] = batch.map((device) => ({
      token: device.token,
      notification: notificationText(kind, device.locale),
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
      data: {kind},
    }));
    const result = await getMessaging().sendEach(messages);
    await Promise.all(result.responses.map(async (response, index) => {
      if (response.success) return;
      const code = response.error?.code;
      if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token") {
        await removeInvalidPushToken(batch[index].token);
      } else {
        logger.warn("game_push_send_failed", {kind, code});
      }
    }));
  }
}

async function currentRoom(roomCode: string): Promise<GameRoom | null> {
  return (await getDatabase().ref(`rooms/${roomCode}`).get()).val() as GameRoom | null;
}

async function dispatchStatus(roomCode: string, kind: "gameStarted" | "gameFinished"): Promise<void> {
  const room = await currentRoom(roomCode);
  const gameInstanceId = room?.game?.public?.gameInstanceId;
  if (!room || !gameInstanceId) return;
  const recipients = eventRecipients(kind, room, Date.now());
  if (recipients.length === 0) return;
  const marker = getDatabase().ref(`rooms/${roomCode}/pushDispatch/${kind}`);
  const claimed = await marker.transaction((previous) => previous === gameInstanceId ? undefined : gameInstanceId);
  if (claimed.committed) await sendToParticipants(kind, recipients);
}

export const pushGameStatus = onValueWritten({
  ref: "/rooms/{roomCode}/game/public/status", region: "asia-southeast1",
}, async (event) => {
  const before = event.data.before.val();
  const after = event.data.after.val();
  if (before === after) return;
  if (after === "playing") await dispatchStatus(event.params.roomCode, "gameStarted");
  if (after === "finished") await dispatchStatus(event.params.roomCode, "gameFinished");
});

export const pushGameTurn = onValueWritten({
  ref: "/rooms/{roomCode}/game/public/turnDeadlineAt", region: "asia-southeast1",
}, async (event) => {
  const before = event.data.before.val();
  const after = event.data.after.val();
  if (before === after || typeof after !== "number" || after <= Date.now()) return;
  const roomCode = event.params.roomCode;
  const room = await currentRoom(roomCode);
  if (!room) return;
  const recipients = eventRecipients("yourTurn", room, Date.now());
  const pub = room.game?.public;
  if (recipients.length !== 1 || !pub?.gameInstanceId || !pub.turnSeq || !pub.turnUid) return;
  // A phase can restart the timer without handing the turn to someone else.
  const marker = getDatabase().ref(`rooms/${roomCode}/pushDispatch/turn`);
  const claimed = await marker.transaction((previous) => {
    if (previous?.gameInstanceId === pub.gameInstanceId && previous?.turnUid === pub.turnUid) return;
    return {gameInstanceId: pub.gameInstanceId, turnUid: pub.turnUid, turnSeq: pub.turnSeq};
  });
  if (claimed.committed) await sendToParticipants("yourTurn", recipients);
});
