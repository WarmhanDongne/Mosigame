import assert from "node:assert/strict";
import test from "node:test";

import {
  TEST_PROJECT_ID,
  grantOperationsAdmin,
} from "../scripts/grant-operations-admin.mjs";

test("operations-admin script is pinned to the test Firebase project", () => {
  assert.equal(TEST_PROJECT_ID, "ban-pick-simulator");
});

test("operations-admin claim keeps the user's existing claims", async () => {
  const calls = [];
  const auth = {
    async getUser(uid) {
      assert.equal(uid, "1X5ZpesNaMPD0PgqNCjhLm3Yi4T2");
      return {customClaims: {betaTester: true}};
    },
    async setCustomUserClaims(uid, claims) {
      calls.push({uid, claims});
    },
  };

  const result = await grantOperationsAdmin(
    auth,
    "1X5ZpesNaMPD0PgqNCjhLm3Yi4T2",
  );

  assert.deepEqual(result, {
    uid: "1X5ZpesNaMPD0PgqNCjhLm3Yi4T2",
    operationsAdmin: true,
  });
  assert.deepEqual(calls, [{
    uid: "1X5ZpesNaMPD0PgqNCjhLm3Yi4T2",
    claims: {betaTester: true, operationsAdmin: true},
  }]);
});

test("operations-admin script rejects an invalid UID before contacting Auth", async () => {
  await assert.rejects(
    () => grantOperationsAdmin({}, "not a Firebase uid"),
    /Invalid Firebase Auth UID/,
  );
});
