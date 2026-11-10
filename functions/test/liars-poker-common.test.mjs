import assert from "node:assert/strict";
import test from "node:test";

import {createDeck} from "../lib/liars-poker/common/deck.js";
import {dealCards} from "../lib/liars-poker/common/deal-card.js";
import {recordCommand} from "../lib/liars-poker/common/commands.js";
import {
  findNextAlivePlayer,
} from "../lib/liars-poker/common/next-turn.js";
import {finishGame} from "../lib/liars-poker/finish-game.js";
import {drawPenaltyResult} from "../lib/liars-poker/finish-penalty.js";
import {restartRound} from "../lib/liars-poker/restart-round.js";

function players(count) {
  return Object.fromEntries(
    Array.from({length: count}, (_, index) => {
      const uid = `uid${index + 1}`;
      return [uid, {
        uid,
        nickname: uid,
        seatIndex: index,
        status: "alive",
        penaltyCount: 0,
        remainingCardCount: 5,
      }];
    }),
  );
}

function gameState(count = 3) {
  return {
    public: {
      status: "playing",
      phase: "penalty",
      round: 1,
      revision: 1,
      table: "TRUTH",
      truthCardCount: 9,
      lieCardCount: 9,
      unrevealedCardCount: 3,
      turnUid: null,
      turnDeadlineAt: null,
      lastPlay: null,
      penaltyTargetUid: "uid1",
      winnerUid: null,
      players: players(count),
      startedAt: 1,
      updatedAt: 1,
    },
    private: {},
    server: {
      lastPlayCards: null,
      processedCommands: {},
      roundStarterUid: "uid1",
    },
  };
}

test("2~6인 덱은 진실 3N장과 거짓 2N+3장으로 구성된다", () => {
  for (let count = 2; count <= 6; count += 1) {
    const deck = createDeck(count);
    assert.equal(deck.length, count * 5 + 3);
    const truthCount = deck.filter((card) => card.rank === "TRUTH").length;
    const lieCount = deck.filter((card) => card.rank === "LIE").length;
    assert.equal(truthCount, count * 3);
    assert.equal(lieCount, count * 2 + 3);
    assert.equal(new Set(deck.map((card) => card.id)).size, deck.length);
  }
});

test("카드는 5장씩 분배되고 정확히 3장이 중앙 덱에 남는다", () => {
  for (let count = 2; count <= 6; count += 1) {
    const gamePlayers = players(count);
    const deck = createDeck(count);
    const hands = dealCards(deck, gamePlayers, 5);
    assert.equal(Object.keys(hands).length, count);
    for (const hand of Object.values(hands)) {
      assert.equal(Object.keys(hand).length, 5);
    }
    const remaining = deck.slice(count * 5);
    assert.equal(remaining.length, 3);
    const dealtIds = new Set(
      Object.values(hands).flatMap((hand) => Object.keys(hand)),
    );
    assert.equal(remaining.some((card) => dealtIds.has(card.id)), false);
  }
});

test("다음 턴은 탈락자를 건너뛴다", () => {
  const gamePlayers = players(3);
  gamePlayers.uid2.status = "eliminated";
  assert.equal(findNextAlivePlayer(gamePlayers, "uid1"), "uid3");
});

test("새 라운드는 생존자에게만 손패를 재분배한다", () => {
  const game = gameState();
  game.public.players.uid2.status = "eliminated";
  restartRound(game, "uid3", 100);

  assert.equal(game.public.round, 2);
  assert.equal(game.public.phase, "dealing");
  assert.equal(game.public.turnUid, "uid3");
  assert.deepEqual(game.private, {});
  assert.equal(Object.keys(game.server.pendingHands.uid1.hand).length, 5);
  assert.equal(Object.keys(game.server.pendingHands.uid3.hand).length, 5);
  assert.equal(game.server.pendingHands.uid2, undefined);
  assert.equal(game.server.unrevealedCards.length, 3);
  assert.equal(game.public.unrevealedCardCount, 3);
});

test("게임 종료 시 승자와 종료 상태가 기록된다", () => {
  const game = gameState(2);
  finishGame(game, "uid2", 200);
  assert.equal(game.public.status, "finished");
  assert.equal(game.public.phase, "finished");
  assert.equal(game.public.winnerUid, "uid2");
  assert.equal(game.public.finishedAt, 200);
});

test("명령 결과의 undefined 값은 RTDB 저장 전에 제거된다", () => {
  const game = gameState();
  recordCommand(game, "roulette_1", {
    uid: "uid1",
    type: "penaltyResolved",
    createdAt: 300,
    result: {
      success: true,
      winnerUid: undefined,
      nested: {turnUid: undefined, round: 2},
    },
  });

  assert.deepEqual(game.server.processedCommands.roulette_1.result, {
    success: true,
    nested: {round: 2},
  });
});

test("벌칙 결과는 서버 추첨 확률의 경계값으로 결정된다", () => {
  assert.equal(drawPenaltyResult(0, () => 3), "eliminated");
  assert.equal(drawPenaltyResult(0, () => 4), "safe");
  assert.equal(drawPenaltyResult(1, () => 4), "eliminated");
  assert.equal(drawPenaltyResult(1, () => 5), "safe");
  assert.equal(drawPenaltyResult(2, () => 10), "eliminated");
  assert.equal(drawPenaltyResult(2, () => 11), "safe");
});
