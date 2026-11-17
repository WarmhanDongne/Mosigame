import assert from "node:assert/strict";
import test from "node:test";

import {
  canRestartRussianRouletteGame,
  completeRussianRoulettePhase,
  createRussianRouletteGame,
  excludeRussianRoulettePlayer,
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
  assert.equal(first.public.turnDeadlineAt, 31000);
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
  timeoutRussianRouletteTurn(state, 31000);
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
