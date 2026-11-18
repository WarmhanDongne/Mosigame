/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {getDatabase} from "firebase-admin/database";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {assertControllerSession} from "../room/controller-session.js";
import {assertStartGameSnapshot, startGameFingerprint} from "../common/start-game-transaction.js";
import {leaveSessionRequest} from "../game-interruption/leave-request.js";
import {replayGameCommandFromRoom, runGameCommandTransaction} from "../game-interruption/game-command-transaction.js";
import {
  canRestartRussianRouletteGame,
  completeRussianRoulettePhase,
  createRussianRouletteGame,
  finishRussianRouletteGame,
  normalizeRussianRouletteGame,
  submitRussianRouletteAction,
  timeoutRussianRouletteTurn,
} from "./game.js";
import {RussianRouletteAction, RussianRouletteGameState, RussianRouletteRoom} from "./types.js";

const REGION = "asia-northeast3";
type Data = {roomCode?: unknown; restart?: unknown; commandId?: unknown; action?: unknown; controllerSessionId?: unknown};

export const game_russian_roulette_start_game = onCall<Data>({region: REGION}, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const roomCode = parseRoomCode(request.data?.roomCode);
  const ref = getDatabase().ref(`rooms/${roomCode}`);
  const snapshot = (await ref.get()).val() as RussianRouletteRoom | null;
  const replay = replayGameCommandFromRoom(snapshot, request, "game_russian_roulette_start_game");
  if (replay) return replay;
  if (!snapshot) throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
  const fingerprint = startGameFingerprint(snapshot);
  assertControllerSession(snapshot, uid, request.data?.controllerSessionId);
  if (snapshot.selectedGame !== "russian_roulette") throw new HttpsError("failed-precondition", "선택한 게임과 일치하지 않습니다.");
  const restart = request.data?.restart === true;
  if (!restart && snapshot.status !== "seating") throw new HttpsError("failed-precondition", "자리 배치를 먼저 완료해주세요.");
  if (restart && !canRestartRussianRouletteGame(snapshot.game)) {
    throw new HttpsError("failed-precondition", "다시 시작할 러시안 룰렛 게임을 찾을 수 없습니다.");
  }
  let targetUid: string | null = null;
  const transaction = await runGameCommandTransaction(ref, request, "game_russian_roulette_start_game", (raw, now) => {
    if (!raw) return raw;
    const room = raw as RussianRouletteRoom;
    assertControllerSession(room, uid, request.data?.controllerSessionId);
    assertStartGameSnapshot(fingerprint, room);
    if (restart && !canRestartRussianRouletteGame(room.game)) {
      throw new HttpsError("failed-precondition", "다시 시작할 러시안 룰렛 게임을 찾을 수 없습니다.");
    }
    const players = Object.entries(room.players ?? {}).map(([playerUid, player]) => ({
      uid: playerUid,
      nickname: String(player.nickname ?? "Player"),
      characterId: String(player.characterId ?? ""),
      seatIndex: Number(player.seatIndex),
    })).filter((player) => Number.isInteger(player.seatIndex)).sort((a, b) => a.seatIndex - b.seatIndex);
    room.game = createRussianRouletteGame(players, now);
    targetUid = room.game.public.targetUid;
    return room;
  }, () => ({success: true, roomCode, targetUid}));
  if (!transaction.committed) throw new HttpsError("aborted", "게임을 시작하지 못했습니다.");
  return transaction.operationResult ?? {success: true};
});

export const game_russian_roulette_submit_action = onCall<Data>({region: REGION}, (request) =>
  playerMutation(request, "game_russian_roulette_submit_action", (game, uid, now) => {
    const action = parseAction(request.data?.action);
    submitRussianRouletteAction(game, uid, action, now);
    return {success: true, submitted: true};
  }));

export const game_russian_roulette_timeout_turn = onCall<Data>({region: REGION}, (request) =>
  controllerMutation(request, "game_russian_roulette_timeout_turn", (game, now) => {
    timeoutRussianRouletteTurn(game, now);
    return {success: true};
  }));

export const game_russian_roulette_complete_phase = onCall<Data>({region: REGION}, (request) =>
  controllerMutation(request, "game_russian_roulette_complete_phase", (game, now) => {
    completeRussianRoulettePhase(game, now);
    return {success: true, phase: game.public.phase};
  }));

export const game_russian_roulette_end_game = onCall<Data>({region: REGION}, (request) =>
  controllerMutation(request, "game_russian_roulette_end_game", (game, now) => {
    finishRussianRouletteGame(game, now);
    return {success: true};
  }));

export const game_russian_roulette_leave_game = onCall({region: REGION}, leaveSessionRequest);

function playerMutation(request: CallableRequest<Data>, kind: string, action: (game: RussianRouletteGameState, uid: string, now: number) => Record<string, unknown>) {
  return mutate(request, kind, (room, uid, now) => {
    if (!room.players?.[uid]) throw new HttpsError("permission-denied", "방 참가자만 조작할 수 있습니다.");
    return action(requireGame(room), uid, now);
  });
}
function controllerMutation(request: CallableRequest<Data>, kind: string, action: (game: RussianRouletteGameState, now: number) => Record<string, unknown>) {
  return mutate(request, kind, (room, uid, now, data) => {
    assertControllerSession(room, uid, data.controllerSessionId);
    return action(requireGame(room), now);
  });
}

async function mutate(request: CallableRequest<Data>, kind: string, action: (room: RussianRouletteRoom, uid: string, now: number, data: Data) => Record<string, unknown>) {
  const uid = requireUid(request.auth?.uid);
  const roomCode = parseRoomCode(request.data?.roomCode);
  const ref = getDatabase().ref(`rooms/${roomCode}`);
  let response: Record<string, unknown> | null = null;
  const result = await runGameCommandTransaction(ref, request, kind, (raw, now) => {
    if (!raw) throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
    response = action(raw as RussianRouletteRoom, uid, now, request.data ?? {});
    return raw;
  }, () => response ?? {success: true});
  return result.operationResult ?? response ?? {success: true};
}

function requireGame(room: RussianRouletteRoom): RussianRouletteGameState {
  if (!room.game?.public || room.game.public.gameType !== "russian_roulette") {
    throw new HttpsError("failed-precondition", "게임이 시작되지 않았습니다.");
  }
  return normalizeRussianRouletteGame(room.game);
}

function parseAction(value: unknown): RussianRouletteAction {
  if (value !== "spin" && value !== "shield" && value !== "none") {
    throw new HttpsError("invalid-argument", "행동을 다시 선택해주세요.");
  }
  return value;
}

function parseRoomCode(value: unknown): string {
  const code = typeof value === "string" ? value.trim().toUpperCase() : "";
  if (!/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/.test(code)) throw new HttpsError("invalid-argument", "방 코드가 올바르지 않습니다.");
  return code;
}

function requireUid(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  return uid;
}
