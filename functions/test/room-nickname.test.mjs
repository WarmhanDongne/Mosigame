import assert from "node:assert/strict";
import test from "node:test";

import {isValidRoomNickname} from "../lib/room/realtime-room-functions.js";

test("room nickname reserves the current-player label", () => {
  assert.equal(isValidRoomNickname("나"), false);
  assert.equal(isValidRoomNickname(" 나 ".trim()), false);
  assert.equal(isValidRoomNickname("나나"), true);
  assert.equal(isValidRoomNickname("player"), true);
});
