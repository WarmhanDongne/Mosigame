import assert from "node:assert/strict";
import test from "node:test";

import {
  registerCommand,
  registerRussianRouletteCatalog,
  RUSSIAN_ROULETTE_ID,
  russianRouletteCatalogEntry,
} from "../scripts/register-russian-roulette.mjs";

test("Russian Roulette catalog is playable from the lobby but hidden from store", async () => {
  const result = await registerRussianRouletteCatalog({
    firestore: null,
  });
  assert.equal(result.status, "dry-run");
  assert.equal(result.document.id, RUSSIAN_ROULETTE_ID);
  assert.equal(result.document.enabled, true);
  assert.equal(result.document.storeVisible, false);
  assert.equal(result.document.accessType, "free");
  assert.deepEqual(result.document, {
    id: RUSSIAN_ROULETTE_ID,
    ...russianRouletteCatalogEntry,
  });
});

test("registration writes only games/russian_roulette as a merge", async () => {
  const writes = [];
  const reference = {path: "games/russian_roulette"};
  const firestore = {
    collection: (name) => ({
      doc: (id) => {
        assert.equal(name, "games");
        assert.equal(id, RUSSIAN_ROULETTE_ID);
        return reference;
      },
    }),
    runTransaction: async (callback) => callback({
      get: async (target) => {
        assert.equal(target, reference);
        return {exists: false};
      },
      set: (target, data, options) => writes.push({target, data, options}),
    }),
  };

  const result = await registerRussianRouletteCatalog({firestore, apply: true});

  assert.equal(result.status, "registered");
  assert.equal(writes.length, 1);
  assert.equal(writes[0].target, reference);
  assert.deepEqual(writes[0].options, {merge: true});
  assert.equal(writes[0].data.enabled, true);
  assert.equal(writes[0].data.storeVisible, false);
  assert.ok(writes[0].data.createdAt);
  assert.ok(writes[0].data.updatedAt);
});

test("Russian Roulette registration requires an explicit matching target", () => {
  assert.deepEqual(registerCommand(["--project=ban-pick-simulator"]), {
    apply: false,
    projectId: "ban-pick-simulator",
  });
  assert.deepEqual(registerCommand([
    "--apply",
    "--project=project0000-ec01e",
    "--confirm-project=project0000-ec01e",
  ]), {
    apply: true,
    projectId: "project0000-ec01e",
  });
  assert.throws(
    () => registerCommand(["--apply", "--project=ban-pick-simulator"]),
    /Apply requires --confirm-project=ban-pick-simulator/,
  );
});
