/* eslint-disable max-len */
import {gameRandomInt} from "../common/transaction-random.js";

/**
 * ELEVEN(일레븐) 순수 규칙입니다.
 *
 * Firebase에 의존하지 않으며 상태를 직접 바꾸지 않고 새 값을 돌려줍니다.
 * 계약 원본: docs/engineering/ELEVEN_GAME_CONTRACT.md 2절.
 * 판정 유형(`reason`)은 서버 전용 값입니다. public·응답·로그에 쓰지 않습니다.
 */

/** 개인 손패의 타일 값입니다. 10은 없습니다. */
export const ELEVEN_TILES: readonly number[] = Object.freeze([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11]);
/** 공용 뽑기 묶음(첫 선공·최종 동점)의 카드 값입니다. 2026-11-25 계약 변경으로 1–9 9장입니다. */
export const ELEVEN_DRAW_TILES: readonly number[] = Object.freeze([1, 2, 3, 4, 5, 6, 7, 8, 9]);
export const ELEVEN_MAX_ROUNDS = 11;
export const ELEVEN_TURN_MS = 60000;
export const ELEVEN_PLAYER_COUNT = 2;

export type ElevenColor = "black" | "white";
export type ElevenOutcome = "first" | "second" | "tie";
export type ElevenJudgeReason = "sameNumber" | "sum20" | "under10" | "atLeast10";
export type ElevenDrawPurpose = "firstPlayer" | "finalTie";

/** 최대값을 받아 [0, max) 정수를 돌려주는 무작위 함수입니다. 테스트에서 주입합니다. */
export type ElevenRandomInt = (maxExclusive: number) => number;

/** 규칙 위반을 나타냅니다. callable 계층이 code를 HttpsError로 바꿉니다. */
export class ElevenRuleError extends Error {
  readonly code: string;

  /**
   * @param {string} code 기계가 읽는 오류 코드
   * @param {string} message 개발자용 설명
   */
  constructor(code: string, message: string) {
    super(message);
    this.name = "ElevenRuleError";
    this.code = code;
  }
}

/**
 * 유효한 타일 값인지 확인합니다.
 * @param {unknown} value 검사할 값
 * @return {boolean} 0–9 또는 11인 정수면 true
 */
export function isElevenTile(value: unknown): value is number {
  return typeof value === "number" && ELEVEN_TILES.includes(value);
}

/**
 * 타일 색을 돌려줍니다. 흑 = 0, 2, 4, 6, 8, 11 / 백 = 1, 3, 5, 7, 9.
 * @param {number} value 타일 값
 * @return {ElevenColor} 타일 색
 */
export function elevenTileColor(value: number): ElevenColor {
  if (!isElevenTile(value)) {
    throw new ElevenRuleError("invalidTile", `Not an ELEVEN tile: ${value}`);
  }
  return value === 11 || value % 2 === 0 ? "black" : "white";
}

export interface ElevenJudgement {
  outcome: ElevenOutcome;
  /** 서버 전용 판정 근거입니다. */
  reason: ElevenJudgeReason;
}

/**
 * 한 라운드의 승패를 판정합니다.
 *
 * 1. 같은 숫자면 동점
 * 2. 합이 20이면 11을 낸 사람 승리(9와 11뿐)
 * 3. 합이 10 미만이면 큰 숫자 승리
 * 4. 합이 10 이상이면 작은 숫자 승리
 *
 * @param {number} firstValue 선공이 낸 값
 * @param {number} secondValue 후공이 낸 값
 * @return {ElevenJudgement} 결과와 서버 전용 근거
 */
export function judgeElevenRound(firstValue: number, secondValue: number): ElevenJudgement {
  if (!isElevenTile(firstValue) || !isElevenTile(secondValue)) {
    throw new ElevenRuleError("invalidTile", "Both values must be ELEVEN tiles");
  }
  if (firstValue === secondValue) return {outcome: "tie", reason: "sameNumber"};
  const sum = firstValue + secondValue;
  if (sum === 20) {
    return {outcome: firstValue === 11 ? "first" : "second", reason: "sum20"};
  }
  if (sum < 10) {
    return {outcome: firstValue > secondValue ? "first" : "second", reason: "under10"};
  }
  return {outcome: firstValue < secondValue ? "first" : "second", reason: "atLeast10"};
}

export interface ElevenRoundInput {
  round: number;
  firstUid: string;
  secondUid: string;
  values: Record<string, number>;
  scores: Record<string, number>;
  tiles: Record<string, readonly number[]>;
}

export interface ElevenRoundResolution {
  round: number;
  outcome: ElevenOutcome;
  /** 서버 전용 판정 근거입니다. */
  reason: ElevenJudgeReason;
  winnerUid: string | null;
  colors: Record<string, ElevenColor>;
  scores: Record<string, number>;
  tiles: Record<string, number[]>;
  /** 다음 라운드 선공. 승자, 동점이면 이번 선공을 유지합니다. */
  nextFirstUid: string;
}

/**
 * 두 사람의 제출을 판정하고 점수·남은 타일·다음 선공을 계산합니다.
 * 동점이어도 두 타일을 모두 소모합니다.
 * @param {ElevenRoundInput} input 라운드 입력
 * @return {ElevenRoundResolution} 새 점수와 남은 타일을 담은 결과
 */
export function resolveElevenRound(input: ElevenRoundInput): ElevenRoundResolution {
  const {round, firstUid, secondUid, values, scores, tiles} = input;
  if (firstUid === secondUid) {
    throw new ElevenRuleError("invalidPlayers", "First and second must differ");
  }
  if (!Number.isInteger(round) || round < 1 || round > ELEVEN_MAX_ROUNDS) {
    throw new ElevenRuleError("invalidRound", `Round out of range: ${round}`);
  }
  const firstValue = values[firstUid];
  const secondValue = values[secondUid];
  const nextTiles: Record<string, number[]> = {};
  for (const [uid, value] of [[firstUid, firstValue], [secondUid, secondValue]] as const) {
    nextTiles[uid] = removeElevenTile(tiles[uid] ?? [], value);
  }
  const judgement = judgeElevenRound(firstValue, secondValue);
  const winnerUid = judgement.outcome === "first" ? firstUid :
    judgement.outcome === "second" ? secondUid : null;
  const nextScores: Record<string, number> = {
    [firstUid]: scores[firstUid] ?? 0,
    [secondUid]: scores[secondUid] ?? 0,
  };
  if (winnerUid) nextScores[winnerUid] += 1;
  return {
    round,
    outcome: judgement.outcome,
    reason: judgement.reason,
    winnerUid,
    colors: {
      [firstUid]: elevenTileColor(firstValue),
      [secondUid]: elevenTileColor(secondValue),
    },
    scores: nextScores,
    tiles: nextTiles,
    nextFirstUid: winnerUid ?? firstUid,
  };
}

/**
 * 남은 타일에서 한 장을 뺀 새 배열을 돌려줍니다.
 * @param {number[]} remaining 남은 타일
 * @param {number} value 낼 타일
 * @return {number[]} 남은 타일(오름차순)
 */
export function removeElevenTile(remaining: readonly number[], value: number): number[] {
  if (!isElevenTile(value)) {
    throw new ElevenRuleError("invalidTile", `Not an ELEVEN tile: ${value}`);
  }
  const index = remaining.indexOf(value);
  if (index < 0) {
    throw new ElevenRuleError("tileNotOwned", `Tile already used or not owned: ${value}`);
  }
  return remaining.filter((_, i) => i !== index).sort((a, b) => a - b);
}

export type ElevenAfterRound =
  | {kind: "continue"; nextRound: number}
  | {kind: "finish"; winnerUid: string; detail: "earlyEnd" | "allRounds"; remainingRounds: number; gap: number}
  | {kind: "finalTie"; order: [string, string]};

/**
 * 라운드 결과를 반영한 뒤 다음 진행을 정합니다.
 *
 * 점수 차가 남은 라운드 수보다 클 때만 조기 종료합니다. 같으면 동점 가능성이
 * 남아 계속합니다. 11라운드 뒤 동점이면 직전 선공 → 후공 순서로 최종 뽑기를 합니다.
 *
 * @param {Record<string, number>} scores 반영 후 점수(정확히 2명)
 * @param {number} completedRounds 끝난 라운드 수
 * @param {string} lastFirstUid 방금 끝난 라운드의 선공
 * @param {string} lastSecondUid 방금 끝난 라운드의 후공
 * @return {ElevenAfterRound} 다음 진행
 */
export function decideElevenAfterRound(
  scores: Record<string, number>,
  completedRounds: number,
  lastFirstUid: string,
  lastSecondUid: string,
): ElevenAfterRound {
  if (!Number.isInteger(completedRounds) || completedRounds < 1 || completedRounds > ELEVEN_MAX_ROUNDS) {
    throw new ElevenRuleError("invalidRound", `Completed rounds out of range: ${completedRounds}`);
  }
  const firstScore = scores[lastFirstUid] ?? 0;
  const secondScore = scores[lastSecondUid] ?? 0;
  const remainingRounds = ELEVEN_MAX_ROUNDS - completedRounds;
  const gap = Math.abs(firstScore - secondScore);
  const leaderUid = firstScore > secondScore ? lastFirstUid : lastSecondUid;
  if (gap > remainingRounds) {
    return {
      kind: "finish",
      winnerUid: leaderUid,
      detail: remainingRounds > 0 ? "earlyEnd" : "allRounds",
      remainingRounds,
      gap,
    };
  }
  if (remainingRounds > 0) return {kind: "continue", nextRound: completedRounds + 1};
  // 11라운드가 끝났고 gap(0)이 remainingRounds(0)보다 크지 않으므로 동점이다.
  return {kind: "finalTie", order: [lastFirstUid, lastSecondUid]};
}

/**
 * 남은 타일 중 하나를 무작위로 고릅니다(시간 초과 자동 제출).
 * 미리 고른 타일은 고려하지 않습니다.
 * @param {number[]} remaining 남은 타일
 * @param {ElevenRandomInt} randomInt 무작위 함수
 * @return {number} 제출할 타일
 */
export function pickElevenTimeoutTile(
  remaining: readonly number[],
  randomInt: ElevenRandomInt = gameRandomInt,
): number {
  if (remaining.length === 0) {
    throw new ElevenRuleError("noTilesLeft", "No tiles left to submit");
  }
  return remaining[randomInt(remaining.length)];
}

/**
 * 배열을 섞은 새 배열을 돌려줍니다(Fisher–Yates).
 * @param {T[]} values 원본
 * @param {ElevenRandomInt} randomInt 무작위 함수
 * @return {T[]} 섞인 사본
 */
export function shuffleEleven<T>(values: readonly T[], randomInt: ElevenRandomInt = gameRandomInt): T[] {
  const result = [...values];
  for (let index = result.length - 1; index > 0; index -= 1) {
    const swapIndex = randomInt(index + 1);
    [result[index], result[swapIndex]] = [result[swapIndex], result[index]];
  }
  return result;
}

export interface ElevenDraw {
  purpose: ElevenDrawPurpose;
  /** 뽑는 순서. 첫 선공은 무작위, 최종 동점은 직전 선공 → 후공. */
  order: [string, string];
  /** 서버 전용. 위치별 숫자입니다. */
  slots: number[];
  /** 공개 가능. uid → 고른 위치 */
  picks: Record<string, number>;
}

/**
 * 공용 뽑기를 만듭니다.
 * @param {ElevenDrawPurpose} purpose 첫 선공 또는 최종 동점
 * @param {[string, string]} order 뽑는 순서
 * @param {ElevenRandomInt} randomInt 무작위 함수
 * @return {ElevenDraw} 새 뽑기
 */
export function createElevenDraw(
  purpose: ElevenDrawPurpose,
  order: [string, string],
  randomInt: ElevenRandomInt = gameRandomInt,
): ElevenDraw {
  if (order[0] === order[1]) {
    throw new ElevenRuleError("invalidPlayers", "Draw order needs two players");
  }
  return {purpose, order: [order[0], order[1]], slots: shuffleEleven(ELEVEN_DRAW_TILES, randomInt), picks: {}};
}

/**
 * 첫 선공 뽑기 순서를 무작위로 정합니다.
 * @param {[string, string]} uids 두 참가자
 * @param {ElevenRandomInt} randomInt 무작위 함수
 * @return {[string, string]} 뽑는 순서
 */
export function randomElevenDrawOrder(
  uids: [string, string],
  randomInt: ElevenRandomInt = gameRandomInt,
): [string, string] {
  if (uids[0] === uids[1]) {
    throw new ElevenRuleError("invalidPlayers", "Draw order needs two players");
  }
  return randomInt(2) === 0 ? [uids[0], uids[1]] : [uids[1], uids[0]];
}

/**
 * 다음에 뽑을 사람을 돌려줍니다. 둘 다 뽑았으면 null입니다.
 * @param {ElevenDraw} draw 진행 중인 뽑기
 * @return {string | null} 다음 차례 uid
 */
export function nextElevenDrawPicker(draw: ElevenDraw): string | null {
  return draw.order.find((uid) => draw.picks[uid] === undefined) ?? null;
}

/**
 * 공용 뽑기에서 한 위치를 고릅니다. 태블릿은 누가 눌렀는지 확인할 수 없으므로
 * 순서와 중복 위치만 검증합니다.
 * @param {ElevenDraw} draw 진행 중인 뽑기
 * @param {string} pickerUid 화면이 안내한 차례
 * @param {number} slotIndex 고른 위치(0–8)
 * @return {ElevenDraw} 선택이 반영된 새 뽑기
 */
export function pickElevenDrawSlot(draw: ElevenDraw, pickerUid: string, slotIndex: number): ElevenDraw {
  const expected = nextElevenDrawPicker(draw);
  if (expected === null) {
    throw new ElevenRuleError("drawComplete", "Both players already picked");
  }
  if (pickerUid !== expected) {
    throw new ElevenRuleError("notYourPick", "Not this player's pick");
  }
  if (!Number.isInteger(slotIndex) || slotIndex < 0 || slotIndex >= draw.slots.length) {
    throw new ElevenRuleError("invalidSlot", `Slot out of range: ${slotIndex}`);
  }
  if (Object.values(draw.picks).includes(slotIndex)) {
    throw new ElevenRuleError("slotTaken", "Slot already picked");
  }
  return {...draw, order: [draw.order[0], draw.order[1]], slots: [...draw.slots], picks: {...draw.picks, [pickerUid]: slotIndex}};
}

export interface ElevenDrawReveal {
  values: Record<string, number>;
  /** 더 큰 숫자를 뽑은 사람. 값이 모두 달라 동점은 없습니다. */
  winnerUid: string;
}

/**
 * 두 사람이 모두 뽑은 뒤 숫자를 함께 공개합니다.
 * @param {ElevenDraw} draw 두 사람이 모두 고른 뽑기
 * @return {ElevenDrawReveal} 공개할 숫자와 승자
 */
export function revealElevenDraw(draw: ElevenDraw): ElevenDrawReveal {
  if (nextElevenDrawPicker(draw) !== null) {
    throw new ElevenRuleError("drawIncomplete", "Both players must pick before reveal");
  }
  const [a, b] = draw.order;
  const values = {[a]: draw.slots[draw.picks[a]], [b]: draw.slots[draw.picks[b]]};
  return {values, winnerUid: values[a] > values[b] ? a : b};
}
