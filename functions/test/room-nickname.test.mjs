import assert from "node:assert/strict";
import test from "node:test";

import {
  isValidRoomNickname,
  roomProfileConflict,
} from "../lib/room/realtime-room-functions.js";
import {
  ROOM_PROFILE_RECONNECT_GRACE_MS,
  buildRoomJoinPreview,
} from "../lib/room/room-join-preview.js";

test("room nickname reserves the current-player label", () => {
  assert.equal(isValidRoomNickname("나"), false);
  assert.equal(isValidRoomNickname(" 나 ".trim()), false);
  assert.equal(isValidRoomNickname("나나"), true);
  assert.equal(isValidRoomNickname("player"), true);
});

test("disconnected profile is released after the 90 second reconnect grace", () => {
  const now = 10_000_000;
  const players = {
    gone: {nickname: "팝콘", characterId: "cat", isConnected: false,
      lastSeen: now - ROOM_PROFILE_RECONNECT_GRACE_MS - 1},
  };
  assert.equal(roomProfileConflict(players, "new-user", "팝콘", "cat", now), null);
  assert.deepEqual(buildRoomJoinPreview(players, now).participants, []);
});

test("disconnected profile remains visible and reserved during the grace", () => {
  const now = 10_000_000;
  const lastSeen = now - 1;
  const players = {
    reconnecting: {nickname: "팝콘", characterId: "cat", isConnected: false,
      lastSeen},
  };
  assert.equal(roomProfileConflict(players, "new-user", "팝콘", "cat", now), "character");
  assert.deepEqual(buildRoomJoinPreview(players, now).participants, [{
    nickname: "팝콘", characterId: "cat",
    reservationExpiresAt: lastSeen + ROOM_PROFILE_RECONNECT_GRACE_MS,
  }]);
});

test("character conflict is reported before its generated guest nickname", () => {
  const players = {
    existing: {nickname: "팝콘", characterId: "cat"},
  };

  assert.equal(
    roomProfileConflict(players, "new-user", "팝콘", "cat"),
    "character",
  );
  assert.equal(
    roomProfileConflict(players, "new-user", "다른이름", "cat"),
    "character",
  );
  assert.equal(
    roomProfileConflict(players, "new-user", "팝콘", "frog"),
    "nickname",
  );
  assert.equal(
    roomProfileConflict(players, "existing", "팝콘", "cat"),
    null,
  );
});
