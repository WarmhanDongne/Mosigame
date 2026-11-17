/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {HttpsError} from "firebase-functions/v2/https";
import {gameRandomInt} from "../common/transaction-random.js";
import {
  RussianRouletteAction,
  RussianRouletteGameState,
  RussianRoulettePlayer,
} from "./types.js";

export const RUSSIAN_ROULETTE_TURN_MS = 30000;
export const RUSSIAN_ROULETTE_MIN_PLAYERS = 2;
export const RUSSIAN_ROULETTE_MAX_PLAYERS = 6;

export interface RussianRouletteStartPlayer {
  uid: string;
  nickname: string;
  characterId: string;
  seatIndex: number;
}
export function createRussianRouletteGame(
  players: RussianRouletteStartPlayer[],
  now: number,
): RussianRouletteGameState {
  if (players.length < RUSSIAN_ROULETTE_MIN_PLAYERS || players.length > RUSSIAN_ROULETTE_MAX_PLAYERS) {
    throw new HttpsError("failed-precondition", "러시안 룰렛은 2~6명이 필요합니다.");
  }
  const ordered = [...players].sort((a, b) => a.seatIndex - b.seatIndex);
  if (new Set(ordered.map((player) => player.uid)).size !== ordered.length ||
      new Set(ordered.map((player) => player.seatIndex)).size !== ordered.length) {
    throw new HttpsError("failed-precondition", "참가자와 좌석을 다시 확인해주세요.");
  }
  const publicPlayers = Object.fromEntries(ordered.map((player) => [player.uid, {
    ...player,
    status: "alive" as const,
    shieldLocked: false,
  } satisfies RussianRoulettePlayer]));
  return {
    public: {
      gameType: "russian_roulette",
      status: "playing",
      phase: "selecting",
      round: 1,
      revision: 0,
      targetUid: ordered[gameRandomInt(ordered.length)].uid,
      turnDeadlineAt: now + RUSSIAN_ROULETTE_TURN_MS,
      choiceCount: 0,
      revealedActions: {},
      spinCount: 0,
      shotBlocked: null,
      eliminatedUid: null,
      players: publicPlayers,
      winnerUid: null,
      startedAt: now,
      updatedAt: now,
    },
    private: Object.fromEntries(ordered.map(({uid}) => [uid, {choiceSubmitted: false}])),
    server: {},
  };
}

export function normalizeRussianRouletteGame(game: RussianRouletteGameState): RussianRouletteGameState {
  game.public.players = game.public.players ?? {};
  game.public.revealedActions = game.public.revealedActions ?? {};
  game.private = game.private ?? {};
  game.server = game.server ?? {};
  return game;
}

export function canRestartRussianRouletteGame(
  game: RussianRouletteGameState | null | undefined,
): boolean {
  return game?.public.gameType === "russian_roulette" &&
    (game.public.status === "playing" || game.public.status === "finished");
}

export function submitRussianRouletteAction(
  game: RussianRouletteGameState,
  uid: string,
  action: RussianRouletteAction,
  now: number,
): void {
  normalizeRussianRouletteGame(game);
  const pub = game.public;
  const player = pub.players[uid];
  const privatePlayer = game.private[uid];
  if (pub.status !== "playing" || pub.phase !== "selecting") {
    throw new HttpsError("failed-precondition", "지금은 행동을 선택할 수 없습니다.");
  }
  if (!player || player.status !== "alive" || !privatePlayer) {
    throw new HttpsError("permission-denied", "이번 차례 참가자가 아닙니다.");
  }
  if (privatePlayer.choiceSubmitted) {
    throw new HttpsError("already-exists", "이번 차례 행동을 이미 선택했습니다.");
  }
  if (action === "shield" && player.shieldLocked) {
    throw new HttpsError("failed-precondition", "방패는 연속으로 사용할 수 없습니다.");
  }
  privatePlayer.action = action;
  privatePlayer.choiceSubmitted = true;
  pub.choiceCount = alivePlayers(game).filter((entry) => game.private[entry.uid]?.choiceSubmitted).length;
  if (pub.choiceCount === alivePlayers(game).length) revealActions(game, now);
  else touch(game, now);
}

export function timeoutRussianRouletteTurn(game: RussianRouletteGameState, now: number): void {
  const pub = game.public;
  if (pub.status !== "playing" || pub.phase !== "selecting") return;
  if ((pub.turnDeadlineAt ?? Number.MAX_SAFE_INTEGER) > now) {
    throw new HttpsError("failed-precondition", "아직 선택 시간이 남아 있습니다.");
  }
  for (const player of alivePlayers(game)) {
    const entry = game.private[player.uid] ??= {choiceSubmitted: false};
    if (!entry.choiceSubmitted) {
      entry.choiceSubmitted = true;
      entry.action = "none";
    }
  }
  revealActions(game, now);
}

function revealActions(game: RussianRouletteGameState, now: number): void {
  const pub = game.public;
  const actions: Record<string, RussianRouletteAction> = {};
  for (const player of alivePlayers(game)) {
    actions[player.uid] = game.private[player.uid]?.action ?? "none";
  }
  pub.revealedActions = actions;
  pub.choiceCount = Object.keys(actions).length;
  pub.spinCount = Object.values(actions).filter((action) => action === "spin").length;
  pub.phase = "revealing";
  pub.turnDeadlineAt = null;
  touch(game, now);
}

export function completeRussianRoulettePhase(game: RussianRouletteGameState, now: number): void {
  const pub = game.public;
  if (pub.status !== "playing") return;
  if (pub.phase === "revealing") {
    pub.targetUid = rotateTarget(game, pub.targetUid, pub.spinCount);
    pub.phase = "rotating";
  } else if (pub.phase === "rotating") {
    pub.phase = "firing";
  } else if (pub.phase === "firing") {
    resolveShot(game, now);
    return;
  } else if (pub.phase === "outcome") {
    pub.targetUid = pub.shotBlocked === true ? pub.targetUid : nextAliveUid(game, pub.targetUid);
    beginNextTurn(game, now);
    return;
  } else {
    throw new HttpsError("failed-precondition", "완료할 연출 단계가 아닙니다.");
  }
  touch(game, now);
}

function resolveShot(game: RussianRouletteGameState, now: number): void {
  const pub = game.public;
  const targetUid = pub.targetUid;
  const target = targetUid == null ? null : pub.players[targetUid];
  if (!target || target.status !== "alive") {
    pub.targetUid = nextAliveUid(game, targetUid);
    beginNextTurn(game, now);
    return;
  }
  const blocked = pub.revealedActions[target.uid] === "shield";
  pub.shotBlocked = blocked;
  pub.eliminatedUid = blocked ? null : targetUid;
  if (!blocked) {
    target.status = "eliminated";
    target.eliminatedTurn = pub.round;
    target.rank = alivePlayers(game).length + 1;
  }
  const alive = alivePlayers(game);
  if (alive.length <= 1) {
    finishRussianRouletteGame(game, now, "winner", alive[0]?.uid ?? null);
    return;
  }
  pub.phase = "outcome";
  pub.turnDeadlineAt = null;
  touch(game, now);
}

function beginNextTurn(game: RussianRouletteGameState, now: number): void {
  const pub = game.public;
  for (const player of Object.values(pub.players)) {
    if (player.status === "alive") player.shieldLocked = pub.revealedActions[player.uid] === "shield";
  }
  pub.phase = "selecting";
  pub.round += 1;
  pub.choiceCount = 0;
  pub.revealedActions = {};
  pub.spinCount = 0;
  pub.shotBlocked = null;
  pub.eliminatedUid = null;
  pub.turnDeadlineAt = now + RUSSIAN_ROULETTE_TURN_MS;
  for (const player of alivePlayers(game)) game.private[player.uid] = {choiceSubmitted: false};
  touch(game, now);
}

export function excludeRussianRoulettePlayer(game: RussianRouletteGameState, uid: string, now: number): void {
  const player = game.public.players[uid];
  if (!player || player.status === "eliminated") return;
  player.status = "eliminated";
  player.eliminatedTurn = game.public.round;
  delete game.private[uid];
  delete game.public.revealedActions[uid];
  if (game.public.targetUid === uid) game.public.targetUid = nextAliveUid(game, uid);
  const alive = alivePlayers(game);
  if (alive.length < RUSSIAN_ROULETTE_MIN_PLAYERS) {
    finishRussianRouletteGame(game, now, "insufficientPlayers", alive.length === 1 ? alive[0].uid : null);
    return;
  }
  if (game.public.phase === "selecting") {
    game.public.choiceCount = alive.filter((entry) => game.private[entry.uid]?.choiceSubmitted).length;
    if (game.public.choiceCount === alive.length) revealActions(game, now);
  }
  touch(game, now);
}

export function finishRussianRouletteForInsufficientPlayers(game: RussianRouletteGameState, now: number): void {
  const alive = alivePlayers(game);
  finishRussianRouletteGame(game, now, "insufficientPlayers", alive.length === 1 ? alive[0].uid : null);
}

export function finishRussianRouletteGame(
  game: RussianRouletteGameState,
  now: number,
  reason: "winner" | "manual" | "insufficientPlayers" = "manual",
  winnerUid: string | null = null,
): void {
  const pub = game.public;
  pub.status = "finished";
  pub.phase = "finished";
  pub.finishReason = reason;
  pub.winnerUid = winnerUid;
  pub.turnDeadlineAt = null;
  pub.finishedAt = now;
  touch(game, now);
}

export function alivePlayers(game: RussianRouletteGameState): RussianRoulettePlayer[] {
  return Object.values(game.public.players)
    .filter((player) => player.status === "alive")
    .sort((a, b) => a.seatIndex - b.seatIndex);
}

export function rotateTarget(game: RussianRouletteGameState, targetUid: string | null, steps: number): string | null {
  const alive = alivePlayers(game);
  if (alive.length === 0) return null;
  const current = alive.findIndex((player) => player.uid === targetUid);
  const start = current < 0 ? 0 : current;
  return alive[(start + Math.max(0, steps)) % alive.length].uid;
}

function nextAliveUid(game: RussianRouletteGameState, fromUid: string | null): string | null {
  const all = Object.values(game.public.players).sort((a, b) => a.seatIndex - b.seatIndex);
  if (all.length === 0) return null;
  const start = Math.max(0, all.findIndex((player) => player.uid === fromUid));
  for (let offset = 1; offset <= all.length; offset++) {
    const candidate = all[(start + offset) % all.length];
    if (candidate.status === "alive") return candidate.uid;
  }
  return null;
}

function touch(game: RussianRouletteGameState, now: number): void {
  game.public.revision += 1;
  game.public.updatedAt = now;
}
