import assert from "node:assert/strict";
import test from "node:test";

import {eventRecipients, notificationText} from "../lib/notifications/push-policy.js";
import {parsePushToken, pushDeviceId} from "../lib/notifications/push-devices.js";

const now = 1_800_000_000_000;
const room = (publicState) => ({
  status: "playing",
  players: {
    first: {role: "player", status: "active"},
    second: {role: "player", status: "active"},
    left: {role: "player", status: "left"},
    tablet: {role: "controller", status: "active"},
  },
  game: {public: publicState},
});

test("game lifecycle push targets active phone participants only", () => {
  assert.deepEqual(eventRecipients("gameStarted", room({status: "playing"}), now), ["first", "second"]);
  assert.deepEqual(eventRecipients("gameFinished", room({status: "finished"}), now), ["first", "second"]);
  assert.deepEqual(eventRecipients("gameFinished", room({status: "playing"}), now), []);
});

test("turn push needs a live turn, future deadline and no recovery pause", () => {
  const live = {status: "playing", turnUid: "second", turnDeadlineAt: now + 30_000};
  assert.deepEqual(eventRecipients("yourTurn", room(live), now), ["second"]);
  assert.deepEqual(eventRecipients("yourTurn", room({...live, turnDeadlineAt: now - 1}), now), []);
  assert.deepEqual(eventRecipients("yourTurn", room({...live, recovery: {paused: true}}), now), []);
  assert.deepEqual(eventRecipients("yourTurn", room({...live, turnUid: "left"}), now), []);
  assert.deepEqual(eventRecipients("yourTurn", room({...live, turnUid: null}), now), []);
});

test("push payload stays generic and token IDs never expose raw tokens", () => {
  const token = "a-valid-registration-token-123";
  assert.equal(parsePushToken(token), token);
  assert.notEqual(pushDeviceId(token), token);
  assert.throws(() => parsePushToken("bad token"), {code: "invalid-argument"});
  for (const kind of ["gameStarted", "yourTurn", "gameFinished"]) {
    const message = notificationText(kind, "korean");
    assert.ok(message.title && message.body);
    assert.equal(JSON.stringify(message).includes("roomCode"), false);
  }
});
