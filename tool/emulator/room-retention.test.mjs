import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import test from 'node:test';
import {accounts, assertLocalEnvironment, password, project, seedLocalFixtures} from './local-fixtures.mjs';

// This suite directly invokes scheduler handlers against real local RTDB CAS.
// Refuse all remote projects/hosts before initializing any Firebase SDK.
assertLocalEnvironment();
assert.ok(!process.env.GOOGLE_APPLICATION_CREDENTIALS, 'Production credentials are not needed');
assert.ok(!process.env.FIREBASE_TOKEN, 'Production tokens are not needed');
const require = createRequire(new URL('../../functions/package.json', import.meta.url));
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getDatabase} = require('firebase-admin/database');
const {cleanupStaleRealtimeRooms} = require('./lib/room/room-cleanup.js');

const hub = 'http://127.0.0.1:4400/functions/';
async function dispatchBackground(enabled) {
  const response = await fetch(`${hub}${enabled ? 'enable' : 'disable'}BackgroundTriggers`, {
    method: 'PUT', signal: AbortSignal.timeout(10000),
  });
  assert.equal(response.ok, true, 'Local trigger dispatch toggle failed');
}

test('room retention uses canonical heartbeats and safely compacts expired allocations', {timeout: 120000}, async t => {
  await seedLocalFixtures();
  const app = initializeApp({projectId: project,
    databaseURL: `https://${project}-default-rtdb.firebaseio.com`,
    credential: {getAccessToken: async () => ({access_token: 'owner', expires_in: 3600})},
  });
  const db = getDatabase(app);
  const codes = ['RTA2A', 'RTA2B', 'RTA2C', 'RTA2D', 'RTA2E'];
  const uid = 'local-tablet';
  const operationId = 'local-retention-create-operation';
  const reservationPath = `roomCreateRequests/${uid}/${operationId}`;
  const slotPath = `roomCreateSlots/${uid}`;
  const mappingPath = `controllerRooms/${uid}`;
  // Preserve the smoke fixture's locator/slot and any pre-existing scan cursor.
  const restorePaths = ['roomCleanupScan/cursor', reservationPath, slotPath, mappingPath];
  const previous = await Promise.all(restorePaths.map(async path => [path, (await db.ref(path).get()).val()]));
  const now = Date.now();
  const grace = 15 * 60000;
  const instance = code => `local-retention-${code}`;
  const room = (code, lastSeen, extra = {}) => ({
    roomCode: code, roomInstanceId: instance(code), allocationGeneration: 1,
    presenceProtocol: 2, status: 'finished', controllerUid: uid,
    controllerCurrentConnectionId: 'local-retention-controller', controllerConnectionSeq: 1,
    controllerPresence: {connected: false, lastSeen: 1},
    finishedAt: now - 2 * grace, retainUntil: now - grace, cleanupAt: now - grace,
    connections: {[uid]: {'local-retention-controller': {
      roomInstanceId: instance(code), connectionSeq: 1, connected: true, lastSeen,
    }}},
    game: {public: {status: 'finished', gameType: 'liars_poker'},
      private: {synthetic: {hand: ['local-test-card']}}, server: {syntheticHistory: 'x'.repeat(65536)}},
    ...extra,
  });
  const queue = (code, generation = 1, id = instance(code)) => ({
    roomInstanceId: id, allocationGeneration: generation,
    nextCheckAt: now - grace, failures: 0,
  });
  const read = async path => (await db.ref(path).get()).val();
  const assertCompact = async code => {
    const value = await read(`rooms/${code}`);
    assert.deepEqual(Object.keys(value).sort(), [
      'roomInstanceId', 'allocationGeneration', 'status', 'terminalAt', 'cleanupPending',
    ].sort());
    assert.equal(value.roomInstanceId, instance(code));
    assert.equal(value.allocationGeneration, 1);
    assert.equal(value.status, 'terminal');
    assert.equal(value.cleanupPending, false);
    assert.equal(await read(`roomCleanupQueue/${code}`), null);
  };

  let dispatchDisabled = false;
  let ownsFixtures = false;
  try {
    // Status/cleanup triggers are tested elsewhere. Suppress only their local
    // fixture side effects while exercising the real scheduler and Admin SDK.
    await dispatchBackground(false);
    dispatchDisabled = true;
    for (const code of codes) assert.equal(await read(`rooms/${code}`), null,
      'Synthetic fixture code unexpectedly already exists');
    ownsFixtures = true;
    await db.ref('roomCleanupScan/cursor').remove();

    await t.test('fresh canonical heartbeat protects a result room beyond its first 15 minutes', async () => {
      const code = codes[0];
      const original = room(code, now);
      await db.ref(`rooms/${code}`).set(original);
      await db.ref(`roomCleanupQueue/${code}`).set(queue(code));
      await cleanupStaleRealtimeRooms.run({});
      const current = await read(`rooms/${code}`);
      assert.equal(current.status, 'finished');
      assert.deepEqual(current.game, original.game);
      assert.equal(await read(`roomCleanupQueue/${code}/nextCheckAt`), now + grace);
    });

    await t.test('expired real canonical leaf removes large payload and compacts the generation fence', async () => {
      const code = codes[1];
      await db.ref(`rooms/${code}`).set(room(code, now - grace - 60000));
      await db.ref(`roomCleanupQueue/${code}`).set(queue(code));
      await cleanupStaleRealtimeRooms.run({});
      await assertCompact(code);
    });

    await t.test('explicit close expires despite a fresh canonical controller heartbeat', async () => {
      const code = codes[2];
      await db.ref(`rooms/${code}`).set(room(code, now, {status: 'closed', cleanupAt: now - 1000}));
      await db.ref(`roomCleanupQueue/${code}`).set(queue(code));
      await cleanupStaleRealtimeRooms.run({});
      await assertCompact(code);
    });

    await t.test('old allocation queue cannot terminalize its replacement room', async () => {
      const code = codes[3];
      const replacement = room(code, now, {roomInstanceId: `replacement-${code}`, allocationGeneration: 2});
      replacement.connections[uid]['local-retention-controller'].roomInstanceId = replacement.roomInstanceId;
      await db.ref(`rooms/${code}`).set(replacement);
      await db.ref(`roomCleanupQueue/${code}`).set(queue(code));
      // Exclude this code from the scan so the old due queue actually reaches
      // the worker's generation check instead of being refreshed by enqueue.
      await db.ref('roomCleanupScan/cursor').set(code);
      await cleanupStaleRealtimeRooms.run({});
      const current = await read(`rooms/${code}`);
      assert.equal(current.roomInstanceId, replacement.roomInstanceId);
      assert.equal(current.allocationGeneration, 2);
      assert.equal(current.status, 'finished');
      assert.deepEqual(current.game, replacement.game);
      assert.equal(await read(`roomCleanupQueue/${code}`), null);
    });

    await t.test('terminal creation request is compact and replays terminal without a new room', async () => {
      const code = codes[4];
      const original = room(code, now - grace - 60000, {creationOperationId: operationId});
      await db.ref(`rooms/${code}`).set(original);
      await db.ref(reservationPath).set({roomCode: code, roomInstanceId: instance(code),
        allocationGeneration: 1, expectedAllocationGeneration: 0, status: 'created',
        createdAt: now - 3 * grace, controllerSessionId: 'local-synthetic-only',
        connectionId: 'local-retention-controller'});
      await db.ref(slotPath).set({operationId, roomInstanceId: instance(code), allocationGeneration: 1, status: 'created'});
      await db.ref(mappingPath).set({roomCode: code, roomInstanceId: instance(code), allocationGeneration: 1});
      await db.ref(`roomCleanupQueue/${code}`).set(queue(code));
      await cleanupStaleRealtimeRooms.run({});
      await assertCompact(code);
      assert.deepEqual(await read(reservationPath), {roomCode: code, roomInstanceId: instance(code),
        allocationGeneration: 1, status: 'terminal', createdAt: now - 3 * grace});
      assert.equal(await read(mappingPath), null);
      // The actual Functions emulator owns its Firestore credentials. Exercise
      // onboarding and replay through HTTP instead of borrowing our RTDB-only
      // owner credential for a direct callable invocation.
      const account = accounts.find(value => value.uid === uid);
      assert.ok(account, 'Synthetic fixture controller must exist');
      const loginResponse = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=local-emulator-only', {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({email: account.email, password, returnSecureToken: true}),
        signal: AbortSignal.timeout(15000),
      });
      assert.equal(loginResponse.ok, true, 'Local synthetic controller login failed');
      const login = await loginResponse.json();
      assert.equal(login.localId, uid);
      const response = await fetch(`http://127.0.0.1:5001/${project}/asia-northeast3/createRealtimeRoom`, {
        method: 'POST', headers: {'Content-Type': 'application/json', Authorization: `Bearer ${login.idToken}`},
        body: JSON.stringify({data: {operationId, presenceProtocol: 2}}),
        signal: AbortSignal.timeout(20000),
      });
      assert.equal(response.ok, true, 'Local creation replay callable failed');
      const replay = await response.json();
      assert.deepEqual(replay.result, {status: 'terminal'});
      await assertCompact(code);
    });
  } finally {
    try {
      // Delete only this suite's synthetic paths, never a parent collection.
      for (const code of ownsFixtures ? codes : []) {
        await db.ref(`rooms/${code}`).remove();
        await db.ref(`roomCleanupQueue/${code}`).remove();
      }
      for (const [path, value] of previous) await db.ref(path).set(value);
    } finally {
      try { if (dispatchDisabled) await dispatchBackground(true); }
      finally { await deleteApp(app); }
    }
  }
});
