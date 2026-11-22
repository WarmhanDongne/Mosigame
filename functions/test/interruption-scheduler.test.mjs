import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import test from 'node:test';
import {CleanupDatabase} from './fake-cleanup-database.mjs';

const require = createRequire(import.meta.url);
const admin = require('firebase-admin/database');
const {logger} = require('firebase-functions');
const {cleanupExpiredGameInterruptions} = require('../lib/game-interruption/expire-scheduler.js');
const NOW = 10_000_000;

function setup(t) {
  const database = new CleanupDatabase();
  const logs = [];
  t.mock.method(admin, 'getDatabase', () => database);
  t.mock.method(logger, 'info', (message, counters) => logs.push({message, counters}));
  t.mock.method(Date, 'now', () => NOW);
  return {database, logs};
}

function recoveryRoom() {
  return {status: 'playing', controllerUid: 'private-controller', players: {},
    game: {public: {status: 'playing', revision: 1, updatedAt: 1, players: {},
      recovery: {paused: true, pauseId: 'private-incident', causes: {
        'player:private-player': {incidentId: 'private-incident', uid: 'private-player',
          role: 'player', reason: 'disconnected', deadlineAt: NOW - 1,
          startedAt: NOW - 60_000, extended: false, awaitingDecision: false},
      }}}, private: {'private-player': {hand: ['private-card']}}, server: {}}};
}

const causePath = '/game/public/recovery/causes/player:private-player';

for (const scenario of ['empty', 'not-due']) {
  test('recovery deadline scan stays quiet without due work: ' + scenario, async t => {
    const {database, logs} = setup(t);
    if (scenario === 'not-due') {
      database.put('rooms/FUTUR', recoveryRoom());
      database.put('rooms/FUTUR' + causePath + '/deadlineAt', NOW + 1);
      database.put('rooms/READY', recoveryRoom());
      database.put('rooms/READY' + causePath + '/awaitingDecision', true);
    }

    await cleanupExpiredGameInterruptions.run({});

    assert.deepEqual(logs, []);
    assert.equal(database.maxActive, 0);
  });
}

test('recovery deadline work has at most ten concurrent transactions and skips non-due rooms', async t => {
  const {database, logs} = setup(t);
  for (let n = 0; n < 25; n++) database.put('rooms/A' + String(n).padStart(4, '0'), recoveryRoom());
  database.put('rooms/FUTUR', recoveryRoom());
  database.put('rooms/FUTUR' + causePath + '/deadlineAt', NOW + 1);
  database.put('rooms/READY', recoveryRoom());
  database.put('rooms/READY' + causePath + '/awaitingDecision', true);
  database.put('rooms/ENDED', recoveryRoom());
  database.put('rooms/ENDED/status', 'finished');

  await cleanupExpiredGameInterruptions.run({});

  assert.equal(database.maxActive, 10);
  assert.equal(logs.at(-1).message, 'Game recovery deadline scan');
  assert.deepEqual(logs.at(-1).counters, {scanned: 27, candidates: 25,
    checked: 25, expiredRooms: 25, expiredCauses: 25, failed: 0, durationMs: 0});
  assert.equal(database.value('rooms/FUTUR' + causePath + '/awaitingDecision'), false);
  assert.equal(database.value('rooms/ENDED' + causePath + '/awaitingDecision'), false);
});

test('one failed room does not reject the scan or starve later work and retries next minute', async t => {
  const {database, logs} = setup(t);
  for (let n = 0; n < 12; n++) database.put('rooms/A' + String(n).padStart(4, '0'), recoveryRoom());
  database.failures.add('rooms/A0000');

  await cleanupExpiredGameInterruptions.run({});

  assert.equal(logs.at(-1).counters.failed, 1);
  assert.equal(logs.at(-1).counters.checked, 11);
  assert.equal(logs.at(-1).counters.expiredRooms, 11);
  assert.equal(database.value('rooms/A0000' + causePath + '/awaitingDecision'), false);
  assert.equal(database.value('rooms/A0011' + causePath + '/awaitingDecision'), true);

  await cleanupExpiredGameInterruptions.run({});

  assert.equal(logs.at(-1).counters.candidates, 1);
  assert.equal(logs.at(-1).counters.expiredRooms, 1);
  assert.equal(logs.at(-1).counters.failed, 0);
  assert.equal(database.value('rooms/A0000' + causePath + '/awaitingDecision'), true);
});

for (const transition of ['resolved', 'extended', 'finished', 'deleted']) {
  test('deadline transaction rechecks latest room after it is ' + transition, async t => {
    const {database, logs} = setup(t);
    database.put('rooms/ABCDE', recoveryRoom());
    database.beforeTransaction = path => {
      if (path !== 'rooms/ABCDE') return;
      database.beforeTransaction = null;
      if (transition === 'resolved') database.put(path + '/game/public/recovery', null);
      else if (transition === 'extended') database.put(path + causePath + '/deadlineAt', NOW + 30_000);
      else if (transition === 'finished') {
        database.put(path + '/status', 'finished');
        database.put(path + '/game/public/status', 'finished');
      } else database.put(path, null);
    };

    await cleanupExpiredGameInterruptions.run({});

    assert.equal(logs.at(-1).counters.candidates, 1);
    assert.equal(logs.at(-1).counters.checked, 1);
    assert.equal(logs.at(-1).counters.expiredRooms, 0);
    assert.equal(logs.at(-1).counters.expiredCauses, 0);
    assert.notEqual(database.value('rooms/ABCDE' + causePath + '/awaitingDecision'), true);
  });
}

test('transaction callback retry counts committed causes once and logs aggregates only', async t => {
  const {database, logs} = setup(t);
  const room = recoveryRoom();
  room.game.public.recovery.causes['controller:private-controller'] = {
    ...room.game.public.recovery.causes['player:private-player'], uid: 'private-controller', role: 'controller'};
  database.put('rooms/ABCDE', room);
  database.rerunTransaction = () => {};

  await cleanupExpiredGameInterruptions.run({});

  assert.equal(database.value('rooms/ABCDE/game/public/revision'), 2);
  assert.equal(logs.at(-1).counters.expiredRooms, 1);
  assert.equal(logs.at(-1).counters.expiredCauses, 2);
  assert.deepEqual(database.value('rooms/ABCDE/game/private'), room.game.private);
  assert.deepEqual(Object.keys(logs.at(-1).counters).sort(),
    ['candidates', 'checked', 'durationMs', 'expiredCauses', 'expiredRooms', 'failed', 'scanned']);
  assert.ok(!JSON.stringify(logs).includes('ABCDE'));
  assert.ok(!JSON.stringify(logs).includes('private-'));
});
