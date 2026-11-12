/* eslint-disable valid-jsdoc */

import {
  gameRandomInt as randomInt,
  gameRandomUUID as randomUUID,
} from "../../common/transaction-random.js";

import {CardRank, GameCard} from "./types.js";

/**
 * 플레이어 수에 맞는 진실·거짓 덱을 생성하고 안전하게 섞습니다.
 *
 * 각 생존 플레이어는 5장을 받고, 정확히 3장은 서버에만 남습니다.
 * 진실 카드는 매 라운드 인원 × 1.6~1.9 장 범위에서 무작위로 정하고,
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

/** 인원 1명당 진실 카드 비율의 이번 라운드 하한·상한입니다. */
export const MIN_TRUTH_CARDS_PER_PLAYER = 1.6;
export const MAX_TRUTH_CARDS_PER_PLAYER = 1.9;

/** 이번 라운드의 진실 카드 수를 인원 비율 범위 안에서 고릅니다. */
export function truthCardCountForPlayerCount(
  playerCount: number,
  draw: (maxExclusive: number) => number = randomInt,
): number {
  if (!Number.isInteger(playerCount) || playerCount < 2 || playerCount > 6) {
    throw new Error("지원하지 않는 플레이어 수입니다.");
  }
  // 카드 수는 정수여야 하므로 양 끝 비율을 반올림한 모든 정수를 같은 확률로
  // 고릅니다. 예: 4명은 6·7·8장 중 하나가 되어, 라운드마다 심리전 밀도가 달라집니다.
  const minimum = Math.round(playerCount * MIN_TRUTH_CARDS_PER_PLAYER);
  const maximum = Math.round(playerCount * MAX_TRUTH_CARDS_PER_PLAYER);
  return minimum + draw(maximum - minimum + 1);
}

/** 플레이어 수별 덱 구성을 반환합니다. */
function deckCounts(playerCount: number): Record<CardRank, number> {
  if (!Number.isInteger(playerCount) || playerCount < 2 || playerCount > 6) {
    throw new Error("지원하지 않는 플레이어 수입니다.");
  }
  const totalCards = playerCount * 5 + 3;
  const truthCount = truthCardCountForPlayerCount(playerCount);
  return {TRUTH: truthCount, LIE: totalCards - truthCount};
}
