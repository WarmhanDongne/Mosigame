/* eslint-disable valid-jsdoc */

import {
  gameRandomInt as randomInt,
  gameRandomUUID as randomUUID,
} from "../../common/transaction-random.js";

import {CardRank, GameCard} from "./types.js";

/**
 * 플레이어 수에 맞는 진실·거짓 덱을 생성하고 안전하게 섞습니다.
 *
 * 각 생존 플레이어는 5장을 받습니다. 전체 덱은 2·3인 15장,
 * 4인부터 인원 × 5장이며, 진실 카드는 인원 × 2.1장을 반올림합니다.
 * 나머지는 모두 거짓 카드입니다.
 */
export function createDeck(playerCount: number): GameCard[] {
  const counts = deckCounts(playerCount);
  const deck: GameCard[] = [];

  for (const [rank, count] of Object.entries(counts)) {
    for (let index = 0; index < count; index += 1) {
      deck.push({id: randomUUID(), rank: rank as CardRank});
    }
  }

  for (let index = deck.length - 1; index > 0; index -= 1) {
    const swapIndex = randomInt(index + 1);
    [deck[index], deck[swapIndex]] = [deck[swapIndex], deck[index]];
  }
  return deck;
}

/** 인원 1명당 진실 카드 비율입니다. */
export const TRUTH_CARDS_PER_PLAYER = 2.1;

/** 플레이어 수가 라이어스 포커의 지원 범위인지 확인합니다. */
function assertSupportedPlayerCount(playerCount: number): void {
  if (!Number.isInteger(playerCount) || playerCount < 2 || playerCount > 6) {
    throw new Error("지원하지 않는 플레이어 수입니다.");
  }
}

/** 플레이어 수에 따른 전체 덱 장수입니다. */
export function totalCardCountForPlayerCount(playerCount: number): number {
  assertSupportedPlayerCount(playerCount);
  return Math.max(15, playerCount * 5);
}

/** 이번 라운드의 진실 카드 수를 고정 비율로 계산합니다. */
export function truthCardCountForPlayerCount(playerCount: number): number {
  assertSupportedPlayerCount(playerCount);
  return Math.round(playerCount * TRUTH_CARDS_PER_PLAYER);
}

/** 모든 플레이어에게 5장씩 나눠 준 뒤 중앙 덱에 남는 장수입니다. */
export function unrevealedCardCountForPlayerCount(
  playerCount: number,
): number {
  return totalCardCountForPlayerCount(playerCount) - playerCount * 5;
}

/** 플레이어 수별 덱 구성을 반환합니다. */
function deckCounts(playerCount: number): Record<CardRank, number> {
  const totalCards = totalCardCountForPlayerCount(playerCount);
  const truthCount = truthCardCountForPlayerCount(playerCount);
  return {TRUTH: truthCount, LIE: totalCards - truthCount};
}
