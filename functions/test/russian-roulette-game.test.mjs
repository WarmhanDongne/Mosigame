import assert from "node:assert/strict";
import test from "node:test";

import {
  canRestartRussianRouletteGame,
  completeRussianRouletteIntro,
  completeRussianRoulettePhase,
  createRussianRouletteGame,
  excludeRussianRoulettePlayer,
  russianRouletteIntroMs,
  submitRussianRouletteAction,
  timeoutRussianRouletteTurn,
} from "../lib/russian-roulette/game.js";
import {withTransactionRandom} from "../lib/common/transaction-random.js";
import {excludeRecoveryPlayer} from "../lib/game-interruption/game-adapters.js";
import {supportsInsufficientPlayerFinish} from "../lib/game-interruption/finish-now-resolution.js";
import {resolveRoomPlayerRange} from "../lib/room/room-seating-policy.js";

const players = ["a", "b", "c", "d"].map((uid, seatIndex) => ({
  uid, nickname: uid.toUpperCase(), characterId: `face-${uid}`, seatIndex,
}));

function game() {
  return withTransactionRandom(Buffer.alloc(32, 7), () =>
    createRussianRouletteGame(players, 1000));
}

function submit(gameState, actions, now = 2000) {
  for (const [uid, action] of Object.entries(actions)) {
    submitRussianRouletteAction(gameState, uid, action, now);
  }
}

test("starts 2-6 players with a deterministic random target and 30 second timer", () => {
  const first = game();
  const second = game();
  assert.equal(first.public.targetUid, second.public.targetUid);
  // 첫 턴은 시작 연출(4명 5.34초) + 준비 여유 10초 뒤까지 30초를 둡니다.
  // 태블릿이 연출을 끝내면 그때부터 30초로 당겨집니다.
  assert.equal(first.public.turnDeadlineAt, 1000 + 5340 + 10000 + 30000);
  assert.equal(first.public.phaseStartedAt, 1000);
  assert.doesNotThrow(() => createRussianRouletteGame(players.slice(0, 2), 0));
  assert.throws(() => createRussianRouletteGame(players.slice(0, 1), 0), {code: "failed-precondition"});
  const sevenPlayers = Array.from({length: 7}, (_, seatIndex) => ({
    uid: `extra-${seatIndex}`,
    nickname: `Extra ${seatIndex}`,
    characterId: `face-extra-${seatIndex}`,
    seatIndex,
  }));
  assert.throws(() => createRussianRouletteGame(sevenPlayers, 0), {code: "failed-precondition"});
});
test("restart accepts both an active and a finished Russian Roulette game", () => {
  const state = game();
  assert.equal(canRestartRussianRouletteGame(state), true);
  state.public.status = "finished";
  state.public.phase = "finished";
  assert.equal(canRestartRussianRouletteGame(state), true);
  assert.equal(canRestartRussianRouletteGame(undefined), false);
});

test("room seating pins Russian Roulette to two through six players", () => {
  assert.deepEqual(resolveRoomPlayerRange("russian_roulette", 3, 8), {
    minPlayers: 2,
    maxPlayers: 6,
  });
});

test("all hidden actions reveal together and spin rotates clockwise", () => {
  const state = game();
  state.public.targetUid = "a";
  submit(state, {a: "none", b: "spin", c: "spin", d: "shield"});
  assert.equal(state.public.phase, "revealing");
  assert.equal(state.public.spinCount, 2);
  completeRussianRoulettePhase(state, 2100);
  assert.equal(state.public.targetUid, "c");
  assert.equal(state.public.phase, "rotating");
});

test("timeout assigns none and an unshielded target is eliminated", () => {
  const state = game();
  state.public.targetUid = "b";
  submitRussianRouletteAction(state, "a", "spin", 2000);
  assert.throws(() => timeoutRussianRouletteTurn(state, 31000), {code: "failed-precondition"});
  timeoutRussianRouletteTurn(state, state.public.turnDeadlineAt);
  assert.equal(state.public.revealedActions.b, "none");
  completeRussianRoulettePhase(state, 32000);
  completeRussianRoulettePhase(state, 33000);
  completeRussianRoulettePhase(state, 34000);
  assert.equal(state.public.players.c.status, "eliminated");
  assert.equal(state.public.phase, "outcome");
  completeRussianRoulettePhase(state, 35000);
  assert.equal(state.public.phase, "selecting");
});

test("shield blocks the shot and is unavailable on the next turn", () => {
  const state = game();
  state.public.targetUid = "a";
  submit(state, {a: "shield", b: "none", c: "none", d: "none"});
  completeRussianRoulettePhase(state, 2100);
  completeRussianRoulettePhase(state, 2200);
  completeRussianRoulettePhase(state, 2300);
  assert.equal(state.public.players.a.status, "alive");
  assert.equal(state.public.phase, "outcome");
  completeRussianRoulettePhase(state, 2350);
  assert.equal(state.public.players.a.shieldLocked, true);
  assert.throws(() => submitRussianRouletteAction(state, "a", "shield", 2400), {
    code: "failed-precondition",
  });
});

test("common disconnect adapter shifts the target and finishes below two players", () => {
  const state = game();
  state.public.targetUid = "a";
  const room = {selectedGame: "russian_roulette", game: state};
  excludeRecoveryPlayer(room, "a", 2000);
  assert.equal(state.public.status, "playing");
  assert.equal(state.public.targetUid, "b");
  excludeRecoveryPlayer(room, "b", 3000);
  assert.equal(state.public.status, "playing");
  excludeRecoveryPlayer(room, "c", 4000);
  assert.equal(state.public.status, "finished");
  assert.equal(state.public.finishReason, "insufficientPlayers");
  assert.equal(supportsInsufficientPlayerFinish("russian_roulette"), true);
});

test("direct exclusion ignores an already eliminated player", () => {
  const state = game();
  excludeRussianRoulettePlayer(state, "d", 2000);
  const revision = state.public.revision;
  excludeRussianRoulettePlayer(state, "d", 3000);
  assert.equal(state.public.revision, revision);
});

test("intro length matches the tablet start animation", () => {
  assert.equal(russianRouletteIntroMs(2), 4380);
  assert.equal(russianRouletteIntroMs(4), 5340);
  assert.equal(russianRouletteIntroMs(6), 6300);
});

test("every phase change records the server start time for synced animations", () => {
  const state = game();
  state.public.targetUid = "a";
  submit(state, {a: "shield", b: "spin", c: "none", d: "none"}, 2000);
  assert.equal(state.public.phase, "revealing");
  assert.equal(state.public.phaseStartedAt, 2000);
  completeRussianRoulettePhase(state, 7000);
  assert.equal(state.public.phase, "rotating");
  assert.equal(state.public.phaseStartedAt, 7000);
  completeRussianRoulettePhase(state, 9000);
  assert.equal(state.public.phase, "firing");
  assert.equal(state.public.phaseStartedAt, 9000);
  completeRussianRoulettePhase(state, 10500);
  assert.equal(state.public.phase, "outcome");
  assert.equal(state.public.phaseStartedAt, 10500);
  completeRussianRoulettePhase(state, 14000);
  assert.equal(state.public.phase, "selecting");
  assert.equal(state.public.phaseStartedAt, 14000);
  // 두 번째 턴부터는 시작 연출이 없어 30초 그대로입니다.
  assert.equal(state.public.turnDeadlineAt, 44000);
});

test("timeout is accepted within the grace window just before the deadline", () => {
  const state = game();
  const deadline = state.public.turnDeadlineAt;
  assert.throws(() => timeoutRussianRouletteTurn(state, deadline - 1500), {code: "failed-precondition"});
  timeoutRussianRouletteTurn(state, deadline - 800);
  assert.equal(state.public.phase, "revealing");
});

test("a target who leaves after the gun stopped on them is not replaced by an innocent player", () => {
  for (const phase of ["rotating", "firing"]) {
    const state = game();
    state.public.targetUid = "a";
    submit(state, {a: "none", b: "spin", c: "none", d: "none"});
    completeRussianRoulettePhase(state, 3000);
    assert.equal(state.public.targetUid, "b");
    if (phase === "firing") completeRussianRoulettePhase(state, 4000);
    assert.equal(state.public.phase, phase);
    excludeRussianRoulettePlayer(state, "b", 5000);
    assert.equal(state.public.phase, "selecting", phase);
    assert.equal(state.public.round, 2, phase);
    assert.equal(state.public.targetUid, "c", phase);
    for (const uid of ["a", "c", "d"]) assert.equal(state.public.players[uid].status, "alive", phase);
    assert.equal(state.public.players.b.rank, 4, phase);
  }
});

test("a player who leaves during the reveal does not move the gun with their spin", () => {
  const state = game();
  state.public.targetUid = "a";
  submit(state, {a: "none", b: "spin", c: "spin", d: "none"});
  assert.equal(state.public.spinCount, 2);
  excludeRussianRoulettePlayer(state, "c", 2500);
  assert.equal(state.public.spinCount, 1);
  assert.equal(state.public.choiceCount, 3);
  completeRussianRoulettePhase(state, 3000);
  assert.equal(state.public.targetUid, "b");
});

test("tablet intro completion starts the first 30 second turn from that moment", () => {
  const state = game();
  const revision = state.public.revision;
  // 태블릿이 연출을 7초 늦게 끝내도 그 순간부터 30초가 온전히 남습니다.
  assert.equal(completeRussianRouletteIntro(state, 1000 + 5340 + 7000), true);
  assert.equal(state.public.turnDeadlineAt, 1000 + 5340 + 7000 + 30000);
  assert.equal(state.public.revision, revision + 1);
  // 두 번 알려도 마감을 다시 늘리거나 당기지 않습니다.
  assert.equal(completeRussianRouletteIntro(state, 1000 + 5340 + 9000), false);
  assert.equal(state.public.turnDeadlineAt, 1000 + 5340 + 7000 + 30000);
});

test("intro completion is ignored after the first turn or while paused", () => {
  const paused = game();
  paused.public.turnDeadlineAt = null;
  assert.equal(completeRussianRouletteIntro(paused, 3000), false);
  assert.equal(paused.public.turnDeadlineAt, null);

  const later = game();
  later.public.targetUid = "a";
  submit(later, {a: "none", b: "none", c: "none", d: "none"}, 2000);
  assert.equal(completeRussianRouletteIntro(later, 3000), false);
  assert.equal(later.public.phase, "revealing");
});
