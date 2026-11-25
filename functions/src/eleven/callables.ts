/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {getDatabase} from "firebase-admin/database";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {assertControllerSession} from "../room/controller-session.js";
import {assertStartGameSnapshot, startGameFingerprint} from "../common/start-game-transaction.js";
import {leaveSessionRequest} from "../game-interruption/leave-request.js";
import {replayGameCommand, runGameCommandTransaction} from "../game-interruption/game-command-transaction.js";
import {
  canRestartElevenGame, completeElevenPhase, createElevenGame, finishElevenGame,
  normalizeElevenGame, pickElevenTile, submitElevenTile, timeoutElevenTurn,
} from "./game.js";
import {ELEVEN_DRAW_TILES} from "./rules.js";
import {ElevenGameState, ElevenRoom} from "./types.js";

const REGION = "asia-northeast3";
type Data = Record<string, unknown>;

export const game_eleven_start_game = onCall<Data>({region: REGION}, async (request) => {
  const uid = requireUid(request.auth?.uid);
  if (request.data?.role !== "controller") throw new HttpsError("permission-denied", "태블릿에서만 시작할 수 있습니다.");
  const roomCode = parseRoomCode(request.data?.roomCode);
  const ref = getDatabase().ref(`rooms/${roomCode}`);
  const replay = await replayGameCommand(ref, request, "game_eleven_start_game");
  if (replay) return replay;
  const snapshot = (await ref.get()).val() as ElevenRoom | null;
  if (!snapshot) throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
  const fingerprint = startGameFingerprint(snapshot);
  assertControllerSession(snapshot, uid, request.data?.controllerSessionId);
  if (snapshot.selectedGame !== "eleven") throw new HttpsError("failed-precondition", "선택한 게임과 일치하지 않습니다.");
  const restart = request.data?.restart === true;
  if (!restart && snapshot.status !== "seating") throw new HttpsError("failed-precondition", "자리 배치를 먼저 완료해주세요.");
  if (restart && !canRestartElevenGame(snapshot.game)) throw new HttpsError("failed-precondition", "다시 시작할 게임이 없습니다.");
  const result = await runGameCommandTransaction(ref, request, "game_eleven_start_game", (raw, now) => {
    if (!raw) return raw;
    const room = raw as ElevenRoom;
    assertControllerSession(room, uid, request.data?.controllerSessionId);
    assertStartGameSnapshot(fingerprint, room);
    if (room.selectedGame !== "eleven" || (restart ? !canRestartElevenGame(room.game) : room.status !== "seating")) {
      throw new HttpsError("failed-precondition", "게임 시작 상태가 바뀌었습니다.");
    }
    const players = Object.entries(room.players ?? {}).filter(([, player]) => player.status === "active").map(([playerUid, player]) => ({
      uid: playerUid,
      nickname: String(player.nickname ?? "Player"),
      characterId: String(player.characterId ?? ""),
      seatIndex: Number(player.seatIndex),
    }));
    if (players.length !== 2 || players.some((p) => !Number.isInteger(p.seatIndex))) {
      throw new HttpsError("failed-precondition", "두 참가자의 좌석이 필요합니다.");
    }
    room.game = createElevenGame(players, now);
    return room;
  }, () => ({success: true, roomCode}));
  if (!result.committed) throw new HttpsError("aborted", "게임을 시작하지 못했습니다.");
  return result.operationResult ?? {success: true};
});

export const game_eleven_pick_draw_tile = onCall<Data>({region: REGION}, (request) =>
  mutate(request, "game_eleven_pick_draw_tile", true, (game, data, _uid, now) => {
    pickElevenTile(game, parseUid(data.pickerUid), parseIntInRange(data.slotIndex, 0, ELEVEN_DRAW_TILES.length - 1), now);
    return {success: true, revision: game.public.revision};
  }));

export const game_eleven_submit_tile = onCall<Data>({region: REGION}, (request) =>
  mutate(request, "game_eleven_submit_tile", false, (game, data, uid, now) => {
    submitElevenTile(game, uid, parseIntInRange(data.round, 1, 11), parseIntInRange(data.value, 0, 11), now);
    return {success: true, revision: game.public.revision};
  }));

export const game_eleven_timeout_turn = onCall<Data>({region: REGION}, (request) =>
  mutate(request, "game_eleven_timeout_turn", null, (game, data, _uid, now) => {
    const sameTurn = game.public.status === "playing" && game.public.round === data.round && game.public.phase === data.phase;
    const applied = timeoutElevenTurn(game, parseIntInRange(data.round, 1, 11), String(data.phase ?? ""), now);
    if (!applied && sameTurn) return {success: false, revision: game.public.revision};
    return {success: true, ignored: !applied, revision: game.public.revision};
  }));

export const game_eleven_complete_phase = onCall<Data>({region: REGION}, (request) =>
  mutate(request, "game_eleven_complete_phase", true, (game, data, _uid, now) => {
    const applied = completeElevenPhase(game, parseIntInRange(data.revision, 0, Number.MAX_SAFE_INTEGER), now);
    return {success: true, ignored: !applied, revision: game.public.revision};
  }));

export const game_eleven_end_game = onCall<Data>({region: REGION}, (request) =>
  mutate(request, "game_eleven_end_game", true, (game, _data, _uid, now) => {
    finishElevenGame(game, now);
    return {success: true, revision: game.public.revision};
  }));

export const game_eleven_leave_game = onCall({region: REGION}, leaveSessionRequest);

async function mutate(request: CallableRequest<Data>, kind: string, controllerOnly: boolean | null,
  action: (game: ElevenGameState, data: Data, uid: string, now: number) => Record<string, unknown>): Promise<Record<string, unknown>> {
  const uid = requireUid(request.auth?.uid);
  if (controllerOnly === true && request.data?.role !== "controller") {
    throw new HttpsError("permission-denied", "태블릿에서만 진행할 수 있습니다.");
  }
  if (controllerOnly === false && request.data?.role !== "player") {
    throw new HttpsError("permission-denied", "휴대폰 참가자만 제출할 수 있습니다.");
  }
  if (controllerOnly === null && request.data?.role !== "controller" && request.data?.role !== "player") {
    throw new HttpsError("invalid-argument", "기기 역할이 필요합니다.");
  }
  const roomCode = parseRoomCode(request.data?.roomCode);
  const ref = getDatabase().ref(`rooms/${roomCode}`);
  const replay = await replayGameCommand(ref, request, kind);
  if (replay) return replay;
  let response: Record<string, unknown> | null = null;
  let result;
  try {
    result = await runGameCommandTransaction(ref, request, kind, (raw, now) => {
      if (!raw) throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
      const room = raw as ElevenRoom;
      if (room.selectedGame !== "eleven" || !room.game || room.game.public.gameType !== "eleven") {
        throw new HttpsError("failed-precondition", "진행 중인 일레븐 게임이 없습니다.");
      }
      if (controllerOnly === true || (controllerOnly === null && request.data?.role === "controller")) {
        assertControllerSession(room, uid, request.data?.controllerSessionId);
      } else if (!room.players?.[uid] || room.players[uid].status !== "active" || !room.game.private[uid]) {
        throw new HttpsError("permission-denied", "방 참가자만 조작할 수 있습니다.");
      }
      response = action(normalizeElevenGame(room.game), request.data ?? {}, uid, now);
      return room;
    }, () => response ?? {success: true});
  } catch (error) {
    if ((kind === "game_eleven_timeout_turn" || kind === "game_eleven_complete_phase") &&
        error instanceof HttpsError && error.code === "failed-precondition" &&
        (error.details as {reason?: string} | undefined)?.reason === "staleContext") {
      return {success: true, ignored: true};
    }
    throw error;
  }
  if (!result.committed) throw new HttpsError("aborted", "명령을 처리하지 못했습니다.");
  return result.operationResult ?? response ?? {success: true};
}

function requireUid(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  return uid;
}
function parseUid(value: unknown): string {
  if (typeof value !== "string" || !value) throw new HttpsError("invalid-argument", "참가자가 필요합니다.");
  return value;
}
function parseRoomCode(value: unknown): string {
  const code = typeof value === "string" ? value.trim().toUpperCase() : "";
  if (!/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/.test(code)) throw new HttpsError("invalid-argument", "방 코드가 올바르지 않습니다.");
  return code;
}
function parseIntInRange(value: unknown, min: number, max: number): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < min || value > max) {
    throw new HttpsError("invalid-argument", "명령 값이 올바르지 않습니다.");
  }
  return value;
}
