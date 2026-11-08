import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
const database = require('firebase-admin/database');
const {logger} = require('firebase-functions');
const {HttpsError} = require('firebase-functions/v2/https');
const {traceRecoveryReport} = require('../lib/game-interruption/recovery-report-diagnostics.js');
const onboarding = require('../lib/auth/require-complete-onboarding.js');
const {game_liars_poker_start_game: start} = require('../lib/liars-poker/start-game.js');
const {game_final_call_start_game: startFinalCall} = require('../lib/final-call/start-game.js');
const {game_final_call_complete_dealing: completeFinalCall} = require('../lib/final-call/complete-dealing.js');
const {hasStalledStartup, recoverStalledStartup} = require('../lib/game-interruption/startup-recovery.js');
const {cleanupExpiredGameInterruptions: scanRecoveries} = require('../lib/game-interruption/expire-scheduler.js');
const {game_liars_poker_complete_dealing: completeDealing} = require('../lib/liars-poker/complete-dealing.js');
const {game_liars_poker_ready_turn: readyTurn} = require('../lib/liars-poker/ready-turn.js');
const {game_liars_poker_force_timeout: forceTimeout} = require('../lib/liars-poker/force-timeout.js');
const {syncRealtimeRoomConnection: syncConnection} = require('../lib/room/session-functions.js');
const {restartRound} = require('../lib/liars-poker/restart-round.js');
const {excludeLiarsPokerPlayer} = require('../lib/liars-poker/exclude-player.js');
const {previewRecoveryExclusion, decorateRecoveryCauses} = require('../lib/game-interruption/game-adapters.js');
const {registerRecoveryFailure} = require('../lib/game-interruption/recovery-state.js');
const {leaveSessionRequest} = require('../lib/game-interruption/leave-request.js');
const {resumeRealtimeControllerRoom: resume} = require('../lib/room/realtime-room-lifecycle.js');
const {joinRealtimeRoom: join} = require('../lib/room/realtime-room-functions.js');
const {game_common_recovery_report: report, game_common_interruption_expire: expire,
  game_common_interruption_on_connection_changed: presence} =
  require('../lib/game-interruption/functions.js');

// RTDB does not preserve nulls or empty maps. Every committed write/read uses
// this representation; JSON serialization alone would retain the missing map.
function stored(value) {
  if (value == null) return null;
  if (typeof value !== 'object') return value;
  const entries = Object.entries(value).map(([k, v]) => [k, stored(v)]).filter(([, v]) => v !== null);
  return entries.length ? Object.fromEntries(entries) : null;
}

class RoomRef {
  constructor(count) {
    this.value = {roomInstanceId: 'room-current', status: 'seating', selectedGame: 'liars_poker',
      controllerUid: 'tablet', controllerSessionId: '11111111-1111-4111-8111-111111111111',
      controllerCurrentConnectionId: 'connection-tablet', controllerConnectionSeq: 1,
      connections: {tablet: {'connection-tablet': {roomInstanceId: 'room-current',
        connectionSeq: 1, connected: true, lastSeen: 1}}}, players: {}};
    for (let i = 0; i < count; i++) {
      const uid = `player${i}`;
      this.value.players[uid] = {uid, role: 'player', status: 'active', seatIndex: i,
        membershipId: `membership-${uid}`, nickname: uid, characterId: ['frog', 'bear', 'cat'][i % 3],
        currentConnectionId: `connection-${uid}`, connectionSeq: 1, isConnected: true, lastSeen: 1};
      this.value.connections[uid] = {[`connection-${uid}`]: {roomInstanceId: 'room-current',
        membershipId: `membership-${uid}`, connectionSeq: 1, connected: true, lastSeen: 1}};
    }
  }
  snapshot() { return {val: () => structuredClone(this.value), exists: () => this.value !== null}; }
  async get() { return this.snapshot(); }
  on(_event, listener) { listener(this.snapshot()); }
  off() {}
  async transaction(update) {
    const next = update(structuredClone(this.value));
    if (next === undefined) return {committed: false, snapshot: this.snapshot()};
    this.value = stored(next);
    return {committed: true, snapshot: this.snapshot()};
  }
  request(id, uid = 'tablet', extra = {}) {
    const player = this.value.players?.[uid];
    const pub = this.value.game?.public ?? {};
    return {auth: {uid}, data: {roomCode: 'ABCDE', roomInstanceId: this.value.roomInstanceId,
      ...(this.value.presenceProtocol ? {presenceProtocol: this.value.presenceProtocol} : {}),
      role: player ? 'player' : 'controller', controllerSessionId: this.value.controllerSessionId,
      membershipId: player?.membershipId,
      connectionId: player?.currentConnectionId ?? this.value.controllerCurrentConnectionId,
      connectionSeq: player?.connectionSeq ?? this.value.controllerConnectionSeq,
      ...Object.fromEntries(['gameInstanceId', 'phaseSeq', 'turnSeq', 'dataSeq', 'resumeEpoch']
        .filter(k => pub[k] !== undefined).map(k => [k, pub[k]])),
      commandId: id, operationId: id, ...extra}};
  }
}

async function setup(t, count = 3, independent = false, gameType = 'liars_poker') {
  t.mock.method(logger, 'info', () => {});
  const ref = new RoomRef(count);
  ref.value.selectedGame = gameType;
  if (independent) ref.value.presenceProtocol = 2;
  t.mock.method(database, 'getDatabase', () => ({ref: path => {
    assert.equal(path, 'rooms/ABCDE'); return ref;
  }}));
  t.mock.method(onboarding, 'assertOnboardingComplete', async () => {});
  await (gameType === 'final_call' ? startFinalCall : start).run(ref.request('start-operation'));
  assert.equal(ref.value.game.public.phase, 'dealing');
  assert.equal(ref.value.game.private, undefined, 'real start empty private is absent after read-back');
  if (!independent) registerRecoveryFailure(ref.value, 'player0', 'player', Date.now(), 'disconnected');
  ref.value = stored(ref.value);
  return ref;
}

async function independentGame(t, count = 3) {
  const ref = await setup(t, count, true);
  assert.equal(ref.value.game.server.playerRecoveryPolicy, 'independent-v1');
  const ready = await report.run(ref.request('controller-ready', 'tablet', {
    state: 'ready', reportSeq: 1, screenUsable: true, assetsReady: true,
  }));
  assert.equal(ready.status, 'accepted');
  assert.equal(ready.paused, false, 'phones need not all be ready for controller progress');
  assert.equal(ref.value.game.public.phase, 'dealing', 'readiness must not invent animation completion');
  assert.equal(ref.value.game.private, undefined);
  await completeDealing.run(ref.request('complete-dealing'));
  ref.value.status = 'playing'; // The existing game/status trigger projection.
  return ref;
}

function readyRequest(ref, uid, id, reportSeq = 1) {
  return ref.request(id, uid, {state: 'ready', reportSeq, screenUsable: true, assetsReady: true});
}

function refreshHeartbeats(ref, now) {
  for (const connections of Object.values(ref.value.connections)) {
    for (const connection of Object.values(connections)) connection.lastSeen = now;
  }
}

test('LP completion/end diagnostics use the committed snapshot and expose an old completion replay', async t => {
  const ref = await setup(t, 3, true);
  await report.run(readyRequest(ref, 'tablet', 'diagnostic-ready'));
  const logs = [];
  t.mock.method(logger, 'info', (event, fields) => {
    if (event === 'liars_poker_transition_result') logs.push(fields);
  });
  const completion = ref.request('diagnostic-complete');
  const completed = await completeDealing.run(completion);
  assert.equal(logs[0].status, 'playing');
  assert.equal(logs[0].phase, 'playing');
  assert.equal(logs[0].matchingPrivatePlayers, 3);
  assert.equal(logs[0].pendingHands, false);
  const {game_liars_poker_end_game: end} = require('../lib/liars-poker/end-game.js');
  await end.run(ref.request('diagnostic-end'));
  assert.equal(logs[1].status, 'finished');
  assert.equal(logs[1].privatePlayers, 0);
  await start.run(ref.request('diagnostic-restart', 'tablet', {restart: true}));
  const restarted = structuredClone(ref.value.game);
  assert.deepEqual(await completeDealing.run(completion), completed);
  assert.equal(logs[2].responseType, 'dealingCompleted');
  assert.equal(logs[2].requestGameCurrent, false);
  assert.equal(logs[2].phase, 'dealing');
  assert.equal(logs[2].pendingHands, true);
  assert.deepEqual(ref.value.game, restarted, 'logging/replay cannot advance the new game');
});

for (const gameType of ['liars_poker', 'final_call']) {
  test(`${gameType}: missing failed report still recovers only unready live devices once`, async t => {
    let now = 100000;
    t.mock.method(Date, 'now', () => now);
    const ref = await setup(t, gameType === 'final_call' ? 4 : 3, true, gameType);
    ref.value.status = 'playing';
    await report.run(readyRequest(ref, 'player0', 'healthy-ready'));
    if (gameType === 'final_call') await report.run(readyRequest(ref, 'player3', 'healthy-ready3'));
    ref.value.connections.player2['connection-player2'].connected = false;
    const pending = structuredClone(ref.value.game.server.pendingHands);
    const instance = ref.value.game.public.gameInstanceId;
    now += 89999; refreshHeartbeats(ref, now);
    assert.equal(hasStalledStartup(ref.value, now), false);
    now++; refreshHeartbeats(ref, now);
    assert.equal(hasStalledStartup(ref.value, now), true);
    await ref.transaction(room => {
      assert.equal(recoverStalledStartup(room, 'room-current', instance, now), 2);
      return room;
    });
    assert.equal(ref.value.connections.player0['connection-player0'].connected, true);
    assert.equal(ref.value.connections.player1['connection-player1'].connected, false);
    assert.equal(ref.value.controllerPresence.connected, false);
    assert.equal(ref.value.game.server.preparationReconnects['player:player2'], undefined);
    assert.equal(ref.value.game.public.phase, 'dealing');
    assert.equal(ref.value.game.public.recovery.paused, true);
    assert.equal(ref.value.game.private, undefined);
    assert.deepEqual(ref.value.game.server.pendingHands, pending);
    await resume.run(ref.request('watchdog-tablet-resume', 'tablet', {expectedConnectionSeq: 1}));
    assert.equal((await report.run(readyRequest(ref, 'tablet', 'watchdog-tablet-ready'))).paused, false);
    await (gameType === 'final_call' ? completeFinalCall : completeDealing).run(ref.request('actual-animation-complete'));
    assert.notEqual(ref.value.game.public.phase, 'dealing');
    await join.run(ref.request('watchdog-phone-rejoin', 'player1', {
      expectedConnectionSeq: 1, nickname: 'player1', characterId: 'bear', reconnectOnly: true,
    }));
    assert.equal((await report.run(readyRequest(ref, 'player1', 'watchdog-phone-ready'))).status, 'accepted');
    const stable = structuredClone(ref.value);
    assert.equal(recoverStalledStartup(ref.value, 'room-current', instance, now), 0);
    assert.deepEqual(ref.value, stable);
    const again = await report.run(ref.request('watchdog-failed-again', 'player1', {state: 'failed', reportSeq: 2}));
    assert.equal(again.reconnectRequested, false, 'watchdog and failed reports share the same one-shot allowance');
  });
}

test('healthy startup is permanently removed from the watchdog without changing gameplay', async t => {
  t.mock.method(Date, 'now', () => 100000);
  const ref = await independentGame(t);
  for (const uid of Object.keys(ref.value.players)) await report.run(readyRequest(ref, uid, `healthy-${uid}`));
  assert.equal(ref.value.game.server.startupRecovery, undefined);
  refreshHeartbeats(ref, 190000);
  const before = structuredClone(ref.value);
  assert.equal(recoverStalledStartup(ref.value, 'room-current', ref.value.game.public.gameInstanceId, 190000), 0);
  assert.deepEqual(ref.value, before);
});

test('phone-only startup recovery leaves current hands, deadline and controller untouched', async t => {
  t.mock.method(Date, 'now', () => 100000);
  const ref = await independentGame(t);
  await report.run(readyRequest(ref, 'player0', 'healthy-phone0'));
  await report.run(readyRequest(ref, 'player2', 'healthy-phone2'));
  const before = structuredClone(ref.value.game);
  refreshHeartbeats(ref, 190000);
  assert.equal(recoverStalledStartup(ref.value, 'room-current', before.public.gameInstanceId, 190000), 1);
  assert.deepEqual(ref.value.game.public, before.public);
  assert.deepEqual(ref.value.game.private, before.private);
  assert.equal(ref.value.connections.tablet['connection-tablet'].connected, true);
});

const invalidStartupCases = {
  'old game without opt-in': room => {delete room.game.server.startupRecovery;},
  'unsupported game': room => {room.game.public.gameType = 'mafia';},
  'legacy protocol': room => {delete room.presenceProtocol;},
  'finished game': room => {room.game.public.status = 'finished';},
  'terminal room': room => {room.status = 'terminal';},
  'different game instance': room => {room.game.public.gameInstanceId = 'new-game';},
  'different room instance': room => {room.roomInstanceId = 'new-room';},
  'expired observation window': room => {room.game.server.startupRecovery.startedAt = -200000;},
  'backgrounded connection': room => {room.connections.player1['connection-player1'].connected = false;},
  'stale heartbeat': room => {room.connections.player1['connection-player1'].lastSeen = 169999;},
  'future heartbeat': room => {room.connections.player1['connection-player1'].lastSeen = 190001;},
  'new membership': room => {room.players.player1.membershipId = 'replacement-member';},
  'new connection': room => {room.players.player1.currentConnectionId = 'replacement-connection';},
  'eliminated player': room => {room.game.public.players.player1.status = 'eliminated';},
};
for (const [label, change] of Object.entries(invalidStartupCases)) {
  test(`startup watchdog makes no change for ${label}`, async t => {
    t.mock.method(Date, 'now', () => 100000);
    const ref = await independentGame(t);
    await report.run(readyRequest(ref, 'player0', 'ready-zero'));
    await report.run(readyRequest(ref, 'player2', 'ready-two'));
    const instance = ref.value.game.public.gameInstanceId;
    refreshHeartbeats(ref, 190000); change(ref.value);
    const before = structuredClone(ref.value);
    assert.equal(recoverStalledStartup(ref.value, 'room-current', instance, 190000), 0);
    assert.deepEqual(ref.value, before);
  });
}

test('ready arriving after scan selection prevents reconnect in the transaction', async t => {
  t.mock.method(Date, 'now', () => 100000);
  const ref = await independentGame(t);
  for (const uid of ['player0', 'player2']) await report.run(readyRequest(ref, uid, `early-${uid}`));
  refreshHeartbeats(ref, 190000);
  assert.equal(hasStalledStartup(ref.value, 190000), true);
  await report.run(readyRequest(ref, 'player1', 'just-in-time-ready'));
  const before = structuredClone(ref.value);
  assert.equal(recoverStalledStartup(ref.value, 'room-current', ref.value.game.public.gameInstanceId, 190000), 0);
  assert.deepEqual(ref.value, before);
});

test('unaccepted ready cannot suppress startup recovery, and a replaced live connection is never revoked', async t => {
  t.mock.method(Date, 'now', () => 100000);
  const ref = await independentGame(t);
  for (const uid of ['player0', 'player2']) await report.run(readyRequest(ref, uid, `valid-${uid}`));
  delete ref.value.game.private.player1._context;
  assert.equal((await report.run(readyRequest(ref, 'player1', 'invalid-private'))).status, 'dataMissing');
  assert.ok(ref.value.game.server.startupRecovery.waiting['player:player1']);
  refreshHeartbeats(ref, 190000);
  assert.equal(hasStalledStartup(ref.value, 190000), true);
  const player = ref.value.players.player1;
  player.currentConnectionId = 'new-live-connection'; player.connectionSeq = 2;
  ref.value.connections.player1[player.currentConnectionId] = {
    roomInstanceId: 'room-current', membershipId: player.membershipId,
    connectionSeq: 2, connected: true, lastSeen: 190000,
  };
  const before = structuredClone(ref.value);
  assert.equal(recoverStalledStartup(ref.value, 'room-current', ref.value.game.public.gameInstanceId, 190000), 0);
  assert.deepEqual(ref.value, before);
});

for (const failedRoom of [false, true]) test(`scheduler limits concurrency and preserves other rooms (one failure=${failedRoom})`, async t => {
  t.mock.method(Date, 'now', () => 100000);
  const ref = await independentGame(t);
  const records = [];
  t.mock.method(logger, 'info', (event, fields) => records.push({event, fields}));
  await report.run(readyRequest(ref, 'player0', 'scheduler-ready0'));
  await report.run(readyRequest(ref, 'player2', 'scheduler-ready2'));
  refreshHeartbeats(ref, 190000);
  t.mock.method(Date, 'now', () => 190000);
  let queries = 0, active = 0, maxActive = 0, writes = 0, healthyWrites = 0;
  const children = Array.from({length: 12}, (_, index) => {
    const child = new RoomRef(3); child.value = structuredClone(ref.value);
    const transaction = child.transaction.bind(child);
    child.transaction = async update => {
      active++; maxActive = Math.max(maxActive, active);
      await new Promise(resolve => setImmediate(resolve));
      try {
        writes++;
        if (failedRoom && index === 0) throw new Error('synthetic transaction failure');
        return await transaction(update);
      } finally {active--;}
    };
    return {val: () => structuredClone(child.value), ref: child};
  });
  const healthy = structuredClone(ref.value); delete healthy.game.server.startupRecovery;
  children.push({val: () => healthy, ref: {on() {healthyWrites++;}}});
  const query = {
    orderByChild(key) {assert.equal(key, 'status'); return this;},
    equalTo(value) {assert.equal(value, 'playing'); return this;},
    async get() {queries++; return {forEach: fn => children.forEach(fn)};},
  };
  t.mock.method(database, 'getDatabase', () => ({ref: path => {assert.equal(path, 'rooms'); return query;}}));
  if (failedRoom) await assert.rejects(scanRecoveries.run({}), /Game recovery transactions failed: 1/);
  else await scanRecoveries.run({});
  assert.equal(queries, 1); assert.equal(writes, 12); assert.equal(maxActive, 10); assert.equal(healthyWrites, 0);
  assert.deepEqual(records.filter(r => r.event === 'game_startup_recovery_scan'), [{
    event: 'game_startup_recovery_scan', fields: {reconnectedDevices: failedRoom ? 11 : 12, failedRooms: failedRoom ? 1 : 0},
  }], 'scheduler logs only committed counts, without room identities or game payloads');
  for (const child of children.slice(failedRoom ? 1 : 0, 12)) assert.equal(child.ref.value.players.player1.isConnected, false);
});

test('independent phones disconnect/rejoin without pausing or changing hands/deadline', async t => {
  const ref = await independentGame(t);
  const beforeGame = structuredClone(ref.value.game);
  const oldId = ref.value.players.player1.currentConnectionId;
  ref.value.connections.player1[oldId].connected = false;
  await syncConnection.run({params: {roomCode: 'ABCDE', uid: 'player1', connectionId: oldId},
    data: {after: {val: () => false}}});
  assert.equal(ref.value.players.player1.isConnected, false);
  assert.deepEqual(ref.value.game, beforeGame);
  const joined = await join.run(ref.request('independent-rejoin', 'player1', {
    expectedConnectionSeq: 1, nickname: 'player1', characterId: 'bear', reconnectOnly: true,
  }));
  assert.equal(joined.connectionSeq, 2);
  assert.deepEqual(ref.value.game, beforeGame, 'rejoining cannot pause peers or redeal cards');
  assert.equal((await report.run(readyRequest(ref, 'player1', 'returned-ready'))).status, 'accepted');
  assert.equal(ref.value.game.public.recovery.paused, false);
  assert.deepEqual(ref.value.game.private, beforeGame.private);
  await syncConnection.run({params: {roomCode: 'ABCDE', uid: 'player1', connectionId: oldId},
    data: {after: {val: () => false}}});
  assert.equal(ref.value.players.player1.isConnected, true, 'late old onDisconnect cannot undo rejoin');
});

for (const gameType of ['liars_poker', 'final_call']) {
  test(`${gameType}: first player can retry preparation on the same connection`, async t => {
    const ref = await setup(t, gameType === 'final_call' ? 4 : 3, true, gameType);
    await report.run(readyRequest(ref, 'tablet', 'tablet-ready'));
    await (gameType === 'final_call' ? completeFinalCall : completeDealing).run(ref.request('complete-dealing'));
    ref.value.status = 'playing';
    const uid = ref.value.game.public.turnUid;
    const beforePublic = structuredClone(ref.value.game.public);
    const beforePrivate = structuredClone(ref.value.game.private);
    const beforeConnections = structuredClone(ref.value.connections);
    const beforePlayers = structuredClone(ref.value.players);
    for (let seq = 1; seq <= 3; seq++) {
      const failed = await report.run(ref.request(`first-failure-${seq}`, uid, {
        state: 'failed', reportSeq: seq, dataSeq: 1,
      }));
      assert.equal(failed.reconnectRequested, false);
      assert.deepEqual(ref.value.connections, beforeConnections);
      assert.deepEqual(ref.value.players, beforePlayers);
    }
    assert.equal((await report.run(readyRequest(ref, uid, 'first-retry-ready', 4))).status, 'accepted');
    assert.deepEqual(ref.value.game.public, beforePublic);
    assert.deepEqual(ref.value.game.private, beforePrivate);
    assert.equal(ref.value.game.server.preparationReconnects, undefined);
  });
}

test('phone preparation failures preserve the connection across retries and explicit rejoin', async t => {
  const ref = await independentGame(t);
  const beforePublic = structuredClone(ref.value.game.public);
  const beforePrivate = structuredClone(ref.value.game.private);
  const failed = ref.request('phone-preparation-failed', 'player1', {state: 'failed', reportSeq: 1});
  const response = await report.run(failed);
  assert.equal(response.status, 'accepted');
  assert.equal(response.outcome, 'localOnly');
  assert.equal(response.reconnectRequested, false);
  assert.equal(ref.value.players.player1.isConnected, true);
  assert.equal(ref.value.connections.player1[failed.data.connectionId].connected, true);
  assert.equal(ref.value.connections.player0['connection-player0'].connected, true);
  assert.equal(ref.value.controllerConnected, undefined, 'other device summaries are untouched');
  assert.deepEqual(ref.value.game.public, beforePublic);
  assert.deepEqual(ref.value.game.private, beforePrivate);
  assert.equal(ref.value.game.server.preparationReconnects, undefined);
  assert.equal((await report.run(readyRequest(ref, 'player1', 'same-connection-ready', 2))).status, 'accepted');
  await join.run(ref.request('automatic-rejoin', 'player1', {
    expectedConnectionSeq: 1, nickname: 'player1', characterId: 'bear', reconnectOnly: true,
  }));
  assert.deepEqual(await report.run(failed), response, 'response-loss replay is idempotent');
  const newId = ref.value.players.player1.currentConnectionId;
  assert.equal(ref.value.connections.player1[newId].connected, true);
  assert.equal((await report.run(readyRequest(ref, 'player1', 'automatic-ready', 2))).status, 'accepted');
  const again = await report.run(ref.request('failed-again', 'player1', {state: 'failed', reportSeq: 3}));
  assert.equal(again.reconnectRequested, false);
  assert.equal(ref.value.connections.player1[newId].connected, true);
  assert.deepEqual(ref.value.game.public, beforePublic);
});

test('initial phone failure preserves transport without blocking controller readiness', async t => {
  const ref = await setup(t, 3, true);
  const failed = await report.run(ref.request('initial-phone-failed', 'player1', {state: 'failed', reportSeq: 1}));
  assert.equal(failed.reconnectRequested, false);
  assert.equal(ref.value.connections.player1['connection-player1'].connected, true);
  assert.equal(ref.value.game.public.recovery.purpose, 'initialReadiness');
  assert.equal((await report.run(readyRequest(ref, 'tablet', 'initial-controller-ready'))).paused, false);
  assert.equal(ref.value.game.private, undefined, 'hands still wait for tablet animation completion');
});

test('independent readiness retains private validation and stale-connection checks', async t => {
  const ref = await independentGame(t);
  const request = readyRequest(ref, 'player1', 'missing-private-ready');
  delete ref.value.game.private.player1._context;
  assert.equal((await report.run(request)).status, 'dataMissing');
  const before = structuredClone(ref.value);
  await assert.rejects(report.run(ref.request('old-connection-failed', 'player1', {
    state: 'failed', reportSeq: 2, connectionId: 'old-connection',
  })), e => e.code === 'permission-denied' && e.details.reason === 'staleConnection');
  assert.deepEqual(ref.value, before, 'an old connection cannot request anyone to reconnect');
  await assert.rejects(report.run(ref.request('old-membership-failed', 'player1', {
    state: 'failed', reportSeq: 2, membershipId: 'old-membership',
  })), e => e.code === 'permission-denied');
  assert.deepEqual(ref.value, before);
});

test('old game, old report and eliminated player cannot request a fresh disconnect', async t => {
  const ref = await independentGame(t);
  const oldGame = await report.run(ref.request('old-game-failed', 'player1', {
    state: 'failed', reportSeq: 1, gameInstanceId: 'previous-game',
  }));
  assert.equal(oldGame.status, 'staleContext');
  assert.equal(ref.value.players.player1.isConnected, true);
  await report.run(readyRequest(ref, 'player1', 'newer-ready-report', 10));
  const oldReport = await report.run(ref.request('older-failed-report', 'player1', {state: 'failed', reportSeq: 9}));
  assert.equal(oldReport.status, 'ignored');
  ref.value.game.public.players.player1.status = 'eliminated';
  const eliminated = await report.run(ref.request('eliminated-failed', 'player1', {state: 'failed', reportSeq: 11}));
  assert.equal(eliminated.reconnectRequested, false);
  assert.equal(ref.value.players.player1.isConnected, true);
  assert.equal(ref.value.game.server.preparationReconnects, undefined);
});

test('controller failure still pauses; its fresh readiness resumes without waiting for phones', async t => {
  t.mock.method(Date, 'now', () => 100000);
  const ref = await independentGame(t);
  const beforeHands = structuredClone(ref.value.game.private);
  const failed = await report.run(ref.request('tablet-preparation-failed', 'tablet', {state: 'failed', reportSeq: 2}));
  assert.equal(failed.reconnectRequested, false);
  assert.equal(ref.value.connections.tablet['connection-tablet'].connected, true);
  assert.equal(ref.value.game.public.recovery.paused, true);
  assert.equal(ref.value.game.public.turnDeadlineAt, undefined);
  const restored = await resume.run(ref.request('automatic-tablet-resume', 'tablet', {expectedConnectionSeq: 1}));
  assert.equal(restored.connectionSeq, 2);
  assert.equal((await report.run(readyRequest(ref, 'tablet', 'restored-tablet-ready', 3))).paused, false);
  assert.equal(ref.value.game.public.turnDeadlineAt, 130000);
  assert.deepEqual(ref.value.game.private, beforeHands);
});

test('first player absence cannot leave the LP turn without a deadline; late ready cannot extend it', async t => {
  t.mock.method(Date, 'now', () => 100000);
  const ref = await independentGame(t);
  const uid = ref.value.game.public.turnUid;
  assert.equal(ref.value.game.public.isFirstTurnReady, true);
  assert.equal(ref.value.game.public.turnDeadlineAt, 130000);
  assert.equal((await readyTurn.run(ref.request('late-first-turn-ready', uid))).ignored, true);
  assert.equal(ref.value.game.public.turnDeadlineAt, 130000);
  const id = ref.value.players[uid].currentConnectionId;
  ref.value.connections[uid][id].connected = false;
  await syncConnection.run({params: {roomCode: 'ABCDE', uid, connectionId: id}, data: {after: {val: () => false}}});
  t.mock.method(Date, 'now', () => 130001);
  const result = await forceTimeout.run(ref.request('tablet-forced-timeout'));
  assert.equal(result.success, true);
  assert.notEqual(ref.value.game.public.turnUid, uid);
  assert.equal(ref.value.game.public.players[uid].status, 'alive', 'temporary absence does not eliminate the player');
});

for (const count of [2, 3]) {
  test(`explicit leave still uses game rules with ${count} players`, async t => {
    const ref = await independentGame(t, count);
    await leaveSessionRequest(ref.request('explicit-player-leave', 'player1'));
    assert.equal(ref.value.players.player1, undefined);
    assert.equal(ref.value.game.public.status, count === 2 ? 'finished' : 'playing');
    assert.notEqual(ref.value.game.public.recovery?.paused, true);
  });
}

test('readiness callable distinguishes HTTP-success outcomes without logging private context', async t => {
  const ref = await setup(t);
  const logs = [];
  t.mock.method(logger, 'info', (...args) => logs.push(args));
  const ready = {state: 'ready', reportSeq: 1, screenUsable: true, assetsReady: true};
  const accepted = await report.run(ref.request('diagnostic-ready', 'player1', ready));
  const ignored = await report.run(ref.request('diagnostic-duplicate', 'player1', ready));
  const stale = await report.run(ref.request('diagnostic-stale', 'player1', {
    ...ready, reportSeq: 2, dataSeq: 999,
  }));
  assert.deepEqual([accepted.status, ignored.status, stale.status], ['accepted', 'ignored', 'staleContext']);
  assert.deepEqual(logs.map(([, fields]) => fields.status), ['accepted', 'ignored', 'staleContext']);
  assert.ok(logs.every(([event]) => event === 'game_recovery_report_result'));
  const serialized = JSON.stringify(logs);
  for (const value of ['ABCDE', 'player1', 'room-current', 'membership-', 'connection-', 'gameInstanceId', 'reportSeq']) {
    assert.equal(serialized.includes(value), false, value);
  }
});

test('readiness diagnostics preserve errors and redact arbitrary messages and details', async t => {
  const logs = [];
  t.mock.method(logger, 'info', (...args) => logs.push(args));
  const error = new HttpsError('permission-denied', 'private-message', {
    reason: 'staleConnection', token: 'private-token', uid: 'private-user',
  });
  await assert.rejects(traceRecoveryReport({state: 'ready', role: 'player', roomCode: 'private-room'}, async () => {
    throw error;
  }), value => value === error);
  assert.equal(logs[0][1].errorCode, 'permission-denied');
  assert.equal(logs[0][1].reason, 'staleConnection');
  const result = {status: 'private-result', paused: 'private-value', context: {uid: 'private-user'}};
  assert.equal(await traceRecoveryReport({state: 'private-state', role: 'private-role'}, async () => result), result);
  assert.equal(logs[1][1].status, 'other');
  assert.equal(JSON.stringify(logs).includes('private-'), false);
});

test('readiness logging failure never replaces the server result or error', async t => {
  t.mock.method(logger, 'info', () => { throw new Error('logging unavailable'); });
  const result = {status: 'accepted', paused: true};
  assert.equal(await traceRecoveryReport({}, async () => result), result);
  const error = new Error('original failure');
  await assert.rejects(traceRecoveryReport(null, async () => { throw error; }), value => value === error);
});

for (const nextRound of [false, true]) {
  test(`LP ${nextRound ? 'next round' : 'first deal'} read-back supports exclusion and a non-mutating preview`, async t => {
    const ref = await setup(t);
    if (nextRound) {
      restartRound(ref.value.game, 'player1', Date.now());
      ref.value = stored(ref.value);
    }
    const before = structuredClone(ref.value);
    const preview = previewRecoveryExclusion(ref.value, 'player0', Date.now());
    assert.equal(preview.canContinue, true);
    assert.deepEqual(ref.value, before);
    decorateRecoveryCauses(ref.value, Date.now());
    assert.equal(ref.value.game.public.recovery.causes['player:player0'].canContinue, true);
    excludeLiarsPokerPlayer(ref.value.game, 'player0', Date.now());
    assert.equal(ref.value.game.public.players.player0.status, 'eliminated');
    assert.equal(ref.value.game.server.pendingHands.player0, undefined);
    assert.equal(Object.keys(ref.value.game.server.pendingHands).length, 2);
    assert.equal(ref.value.game.public.phase, 'dealing');
  });
}

test('dealing self-leave removes membership once and ends when only one survivor remains', async t => {
  const ref = await setup(t, 2);
  const request = ref.request('leave-operation', 'player0');
  const first = await leaveSessionRequest(request);
  assert.equal(first.status, 'applied');
  assert.equal(ref.value.players.player0, undefined);
  assert.equal(ref.value.game.public.status, 'finished');
  assert.equal(ref.value.game.public.finishReason, 'insufficientPlayers');
  const saved = structuredClone(ref.value);
  assert.deepEqual(await leaveSessionRequest(request), first);
  assert.deepEqual(ref.value, saved, 'replayed leave does not mutate again');
});

for (const operation of ['resume', 'join', 'report', 'ready', 'expire', 'presence']) {
  test(`LP dealing ${operation} commits despite absent private and existing player recovery cause`, async t => {
    const ref = await setup(t);
    let response;
    if (operation === 'resume') {
      response = await resume.run(ref.request('resume-operation', 'tablet', {expectedConnectionSeq: 1}));
      assert.equal(response.connectionSeq, 2);
      assert.equal(ref.value.controllerCurrentConnectionId, response.connectionId);
    } else if (operation === 'join') {
      response = await join.run(ref.request('join-operation', 'player1', {
        expectedConnectionSeq: 1, nickname: 'player1', characterId: 'bear', reconnectOnly: true,
      }));
      assert.equal(response.connectionSeq, 2);
      assert.equal(ref.value.players.player1.currentConnectionId, response.connectionId);
    } else if (operation === 'report' || operation === 'ready') {
      response = await report.run(ref.request('report-operation', 'player1', {
        state: operation === 'ready' ? 'ready' : 'failed', reportSeq: 1,
        screenUsable: operation === 'ready', assetsReady: operation === 'ready',
      }));
      assert.ok(response.status);
    } else if (operation === 'presence') {
      ref.value.players.player1.isConnected = false;
      await presence.run({params: {roomCode: 'ABCDE', uid: 'player1'},
        data: {after: {val: () => false}}});
      assert.ok(ref.value.game.public.recovery.causes['player:player1']);
    } else {
      const cause = ref.value.game.public.recovery.causes['player:player0'];
      cause.deadlineAt = Date.now() - 1;
      response = await expire.run(ref.request('expire-operation', 'tablet', {incidentId: cause.incidentId}));
      assert.equal(response.status, 'awaitingDecision');
    }
    assert.equal(ref.value.game.public.recovery.paused, true, 'transport success never replaces ready barrier');
    assert.equal(ref.value.game.public.recovery.causes['player:player0'].canContinue, true);
    assert.equal(ref.value.game.private, undefined);
  });
}

test('a pending phone join replays only a usable connection after connection loss', async t => {
  const ref = await independentGame(t);
  const request = ref.request('pending-phone-reconnect', 'player1', {
    expectedConnectionSeq: 1, nickname: 'player1', characterId: 'bear', preserveProfile: true,
  });
  const joined = await join.run(request);
  assert.deepEqual(await join.run(request), joined, 'live response-loss replay is idempotent');
  const oldId = joined.connectionId;
  ref.value.connections.player1[oldId].connected = false;
  await syncConnection.run({params: {roomCode: 'ABCDE', uid: 'player1', connectionId: oldId},
    data: {after: {val: () => false}}});
  const before = structuredClone(ref.value);
  await assert.rejects(join.run(request),
    error => error.code === 'aborted' && error.details?.reason === 'staleConnection');
  assert.deepEqual(ref.value, before, 'failed replay cannot allocate or resurrect an old connection');
  const replacement = await join.run(ref.request('fresh-phone-reconnect', 'player1', {
    expectedConnectionSeq: 2, nickname: 'player1', characterId: 'bear', preserveProfile: true,
  }));
  assert.equal(replacement.connectionSeq, 3);
  assert.notEqual(replacement.connectionId, oldId);
  assert.equal(replacement.membershipId, joined.membershipId);
  assert.deepEqual(ref.value.game, before.game);
  assert.equal((await report.run(readyRequest(ref, 'player1', 'cold-restart-ready'))).status, 'accepted');
  const after = structuredClone(ref.value);
  assert.deepEqual(await join.run(request), joined, 'a later live connection preserves ordinary replay semantics');
  assert.deepEqual(ref.value, after);
  await syncConnection.run({params: {roomCode: 'ABCDE', uid: 'player1', connectionId: oldId},
    data: {after: {val: () => false}}});
  assert.equal(ref.value.players.player1.isConnected, true);
});


for (const boundary of ['closed', 'terminal', 'removed', 'replaced-membership']) {
  test(`pending join replay preserves the existing ${boundary} boundary`, async t => {
    const ref = await independentGame(t);
    const request = ref.request('boundary-reconnect', 'player1', {
      expectedConnectionSeq: 1, nickname: 'player1', characterId: 'bear', preserveProfile: true,
    });
    const joined = await join.run(request);
    ref.value.connections.player1[joined.connectionId].connected = false;
    if (boundary === 'closed' || boundary === 'terminal') ref.value.status = boundary;
    if (boundary === 'removed') ref.value.players.player1.status = 'removed';
    if (boundary === 'replaced-membership') {
      ref.value.players.player1.membershipId = 'replacement-member';
      ref.value.connections.player1[joined.connectionId].membershipId = 'replacement-member';
    }
    const before = structuredClone(ref.value);
    assert.deepEqual(await join.run(request), joined);
    assert.deepEqual(ref.value, before, 'replay must not restore membership or reopen the room');
  });
}
