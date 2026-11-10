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
 * 진실 카드는 플레이어당 3장이고 나머지는 모두 거짓 카드입니다.
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

/** 플레이어 수별 덱 구성을 반환합니다. */
function deckCounts(playerCount: number): Record<CardRank, number> {
  if (!Number.isInteger(playerCount) || playerCount < 2 || playerCount > 6) {
    throw new Error("지원하지 않는 플레이어 수입니다.");
  }
  const totalCards = playerCount * 5 + 3;
  const truthCount = playerCount * 3;
  return {TRUTH: truthCount, LIE: totalCards - truthCount};
}
