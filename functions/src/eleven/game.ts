/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {HttpsError} from "firebase-functions/v2/https";
import {
  ELEVEN_TILES, ELEVEN_TURN_MS, createElevenDraw, decideElevenAfterRound,
  elevenTileColor, isElevenTile, nextElevenDrawPicker, pickElevenDrawSlot,
  pickElevenTimeoutTile, randomElevenDrawOrder, judgeElevenRound,
} from "./rules.js";
import {ElevenGameState, ElevenPlayer} from "./types.js";

type StartPlayer = Pick<ElevenPlayer, "uid" | "nickname" | "characterId" | "seatIndex">;

/** RTDB는 빈 객체·배열을 저장하지 않으므로 명령 전에 슬롯을 복원합니다. */
export function normalizeElevenGame(game: ElevenGameState): ElevenGameState {
  game.server ??= {submissions: {}};
  game.server.submissions ??= {};
  game.controller ??= {history: []};
  game.controller.history ??= [];
  game.private ??= {};
  game.public.currentRound ??= {round: game.public.round, autoSubmitted: {}};
  game.public.currentRound.autoSubmitted ??= {};
  return game;
}

export function createElevenGame(players: StartPlayer[], now: number): ElevenGameState {
  if (players.length !== 2 || new Set(players.map((p) => p.uid)).size !== 2 ||
      new Set(players.map((p) => p.seatIndex)).size !== 2) {
    throw new HttpsError("failed-precondition", "일레븐은 좌석이 정해진 두 명이 필요합니다.");
  }
  const ordered = [...players].sort((a, b) => a.seatIndex - b.seatIndex);
  const order = randomElevenDrawOrder([ordered[0].uid, ordered[1].uid]);
  const draw = createElevenDraw("firstPlayer", order);
  return {
    public: {
      gameType: "eleven", status: "playing", phase: "drawPick", revision: 0, round: 1,
      players: Object.fromEntries(ordered.map((p) => [p.uid, {...p, status: "alive" as const}])),
      scores: Object.fromEntries(ordered.map((p) => [p.uid, 0])),
      firstUid: null, secondUid: null, turnUid: null, turnDeadlineAt: null,
      currentRound: {round: 1, autoSubmitted: {}},
      draw: {purpose: draw.purpose, order, picks: {}, nextPickerUid: order[0]},
      winnerUid: null, startedAt: now, updatedAt: now,
    },
    controller: {history: []},
    private: Object.fromEntries(ordered.map((p) => [p.uid, {tiles: [...ELEVEN_TILES]}])),
    server: {draw: {purpose: draw.purpose, slots: draw.slots}, submissions: {}},
  };
}

export function canRestartElevenGame(game: ElevenGameState | undefined): boolean {
  return game?.public.gameType === "eleven" && ["playing", "finished"].includes(game.public.status);
}

export function pickElevenTile(game: ElevenGameState, pickerUid: string, slotIndex: number, now: number): void {
  const pub = game.public;
  if (pub.status !== "playing" || pub.phase !== "drawPick" || !pub.draw || !game.server.draw) {
    throw new HttpsError("failed-precondition", "지금은 공용 타일을 뽑을 수 없습니다.");
  }
  let picked;
  try {
    picked = pickElevenDrawSlot({...game.server.draw, order: pub.draw.order, picks: pub.draw.picks}, pickerUid, slotIndex);
  } catch {
    throw new HttpsError("failed-precondition", "뽑기 순서 또는 타일 위치가 올바르지 않습니다.");
  }
  pub.draw.picks = picked.picks;
  pub.draw.nextPickerUid = nextElevenDrawPicker(picked);
  if (!pub.draw.nextPickerUid) {
    const first = pub.draw.order[0];
    const second = pub.draw.order[1];
    const firstValue = picked.slots[picked.picks[first]];
    const secondValue = picked.slots[picked.picks[second]];
    const winnerUid = firstValue > secondValue ? first : second;
    pub.draw.revealed = {[first]: firstValue, [second]: secondValue};
    pub.draw.winnerUid = winnerUid;
    pub.phase = "drawReveal";
    delete game.server.draw;
  }
  touch(game, now);
}

export function submitElevenTile(game: ElevenGameState, uid: string, round: number, value: number, now: number): void {
  const pub = game.public;
  if (pub.status !== "playing" || !["firstSubmit", "secondSubmit"].includes(pub.phase) ||
      pub.round !== round || pub.turnUid !== uid) {
    throw new HttpsError("failed-precondition", "현재 제출 차례가 아닙니다.");
  }
  if (pub.turnDeadlineAt === null || now >= pub.turnDeadlineAt) {
    throw new HttpsError("deadline-exceeded", "제출 시간이 지났습니다.");
  }
  applySubmission(game, uid, value, false, now);
}

export function timeoutElevenTurn(game: ElevenGameState, round: number, phase: string, now: number): boolean {
  const pub = game.public;
  if (pub.status !== "playing" || pub.round !== round || pub.phase !== phase ||
      !["firstSubmit", "secondSubmit"].includes(pub.phase)) return false;
  if (pub.turnDeadlineAt === null || now < pub.turnDeadlineAt) return false;
  const uid = pub.turnUid;
  if (!uid || !game.private[uid]) throw new HttpsError("data-loss", "차례 참가자의 손패가 없습니다.");
  applySubmission(game, uid, pickElevenTimeoutTile(game.private[uid].tiles), true, now);
  return true;
}

function applySubmission(game: ElevenGameState, uid: string, value: number, auto: boolean, now: number): void {
  const pub = game.public;
  const privatePlayer = game.private[uid];
  if (!privatePlayer || !isElevenTile(value) || !privatePlayer.tiles.includes(value) ||
      game.server.submissions[uid] !== undefined) {
    throw new HttpsError("failed-precondition", "제출할 수 없는 타일입니다.");
  }
  privatePlayer.tiles = privatePlayer.tiles.filter((tile) => tile !== value);
  privatePlayer.submission = {round: pub.round, value, auto};
  game.server.submissions[uid] = value;
  if (auto) pub.currentRound.autoSubmitted[uid] = true;
  if (pub.phase === "firstSubmit") {
    pub.currentRound.firstColor = elevenTileColor(value);
    pub.phase = "secondSubmit";
    pub.turnUid = pub.secondUid;
    pub.turnDeadlineAt = now + ELEVEN_TURN_MS;
    touch(game, now);
    return;
  }
  pub.currentRound.secondColor = elevenTileColor(value);
  resolveRound(game, now);
}

function resolveRound(game: ElevenGameState, now: number): void {
  const pub = game.public;
  const first = pub.firstUid;
  const second = pub.secondUid;
  if (!first || !second) throw new HttpsError("data-loss", "선후공 정보가 없습니다.");
  const {outcome, reason} = judgeElevenRound(game.server.submissions[first], game.server.submissions[second]);
  const winnerUid = outcome === "tie" ? null : outcome === "first" ? first : second;
  if (winnerUid) pub.scores[winnerUid] += 1;
  game.controller.history.push({
    round: pub.round, firstUid: first,
    colors: {[first]: pub.currentRound.firstColor!, [second]: pub.currentRound.secondColor!},
    winnerUid,
    ...(Object.keys(pub.currentRound.autoSubmitted).length ? {autoSubmitted: {...pub.currentRound.autoSubmitted}} : {}),
  });
  game.server.lastJudgeReason = reason;
  game.server.nextFirstUid = winnerUid ?? first;
  game.server.submissions = {};
  pub.phase = "roundResult";
  pub.turnUid = null;
  pub.turnDeadlineAt = null;
  touch(game, now);
}

export function completeElevenPhase(game: ElevenGameState, revision: number, now: number): boolean {
  const pub = game.public;
  if (pub.status !== "playing" || pub.revision !== revision) return false;
  if (pub.phase === "drawReveal" && pub.draw) {
    if (pub.draw.purpose === "finalTie") {
      finishElevenGame(game, now, "winner", pub.draw.winnerUid ?? null, "tieDraw");
      return true;
    }
    const first = pub.draw.winnerUid;
    if (!first) throw new HttpsError("data-loss", "뽑기 승자가 없습니다.");
    const second = pub.draw.order.find((uid) => uid !== first)!;
    pub.firstUid = first;
    pub.secondUid = second;
    pub.phase = "firstSubmit";
    pub.turnUid = first;
    pub.turnDeadlineAt = now + ELEVEN_TURN_MS;
    delete pub.draw;
    touch(game, now);
    return true;
  }
  if (pub.phase !== "roundResult" || !pub.firstUid || !pub.secondUid) {
    throw new HttpsError("failed-precondition", "완료할 단계가 아닙니다.");
  }
  const decision = decideElevenAfterRound(pub.scores, pub.round, pub.firstUid, pub.secondUid);
  if (decision.kind === "finish") {
    if (decision.detail === "earlyEnd") {
      pub.earlyEnd = {remainingRounds: decision.remainingRounds, leaderUid: decision.winnerUid, gap: decision.gap};
    }
    finishElevenGame(game, now, "winner", decision.winnerUid, decision.detail);
  } else if (decision.kind === "finalTie") {
    const draw = createElevenDraw("finalTie", decision.order);
    pub.phase = "drawPick";
    pub.draw = {purpose: "finalTie", order: draw.order, picks: {}, nextPickerUid: draw.order[0]};
    game.server.draw = {purpose: "finalTie", slots: draw.slots};
    touch(game, now);
  } else {
    const first = game.server.nextFirstUid;
    if (!first) throw new HttpsError("data-loss", "다음 선공이 없습니다.");
    const second = Object.keys(pub.players).find((uid) => uid !== first)!;
    pub.round = decision.nextRound;
    pub.firstUid = first;
    pub.secondUid = second;
    pub.turnUid = first;
    pub.turnDeadlineAt = now + ELEVEN_TURN_MS;
    pub.currentRound = {round: pub.round, autoSubmitted: {}};
    pub.phase = "firstSubmit";
    for (const entry of Object.values(game.private)) delete entry.submission;
    delete game.server.nextFirstUid;
    delete game.server.lastJudgeReason;
    touch(game, now);
  }
  return true;
}

export function excludeElevenPlayer(game: ElevenGameState, uid: string, now: number): void {
  normalizeElevenGame(game);
  if (game.public.status !== "playing" || !game.public.players[uid] ||
      game.public.players[uid].status === "eliminated") return;
  game.public.players[uid].status = "eliminated";
  delete game.private[uid];
  finishElevenGame(game, now, "insufficientPlayers");
}

export function finishElevenForInsufficientPlayers(game: ElevenGameState, now: number): void {
  normalizeElevenGame(game);
  if (game.public.status === "playing") finishElevenGame(game, now, "insufficientPlayers");
}

export function finishElevenGame(game: ElevenGameState, now: number,
  reason: "winner" | "manual" | "insufficientPlayers" = "manual",
  winnerUid: string | null = null,
  detail?: "earlyEnd" | "allRounds" | "tieDraw"): void {
  normalizeElevenGame(game);
  const pub = game.public;
  if (pub.status === "finished") return;
  pub.status = "finished";
  pub.phase = "finished";
  pub.finishReason = reason;
  pub.winnerUid = winnerUid;
  if (detail) pub.finishDetail = detail;
  pub.turnUid = null;
  pub.turnDeadlineAt = null;
  pub.finishedAt = now;
  game.server.submissions = {};
  delete game.server.draw;
  delete game.server.lastJudgeReason;
  touch(game, now);
}

function touch(game: ElevenGameState, now: number): void {
  game.public.revision += 1;
  game.public.updatedAt = now;
}
