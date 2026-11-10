import assert from "node:assert/strict";
import test from "node:test";

import {
  isValidRoomNickname,
  roomProfileConflict,
} from "../lib/room/realtime-room-functions.js";

test("room nickname reserves the current-player label", () => {
  assert.equal(isValidRoomNickname("나"), false);
  assert.equal(isValidRoomNickname(" 나 ".trim()), false);
  assert.equal(isValidRoomNickname("나나"), true);
  assert.equal(isValidRoomNickname("player"), true);
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
