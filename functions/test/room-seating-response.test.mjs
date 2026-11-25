import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
const database = require('firebase-admin/database');
const catalog = require('../lib/room/game-catalog.js');
const {beginRealtimeRoomSeating} = require('../lib/room/realtime-room-lifecycle.js');

const controllerSessionId = '11111111-1111-4111-8111-111111111111';
const player = (seatIndex) => ({role: 'player', status: 'active', seatIndex,
  nickname: `Player ${seatIndex}`, characterId: 'bear'});

test('seating returns the roster committed after a concurrent join', async (t) => {
  const before = {roomInstanceId: 'room-current', status: 'waiting',
    controllerUid: 'tablet', controllerSessionId, selectedGame: 'yut',
    players: {first: player(0), second: player(1)},
    seatingPreference: {playerUids: ['first', 'second'], mode: 'sides'}};
  const current = structuredClone(before);
  current.players.third = player(2);
  const snapshot = (value) => ({exists: () => value !== null,
    val: () => structuredClone(value)});
  const ref = {
    get: async () => snapshot(before),
    on: (_event, listener) => listener(snapshot(current)),
    off: () => {},
    transaction: async (update) => {
      const next = update(structuredClone(current));
      assert.equal(next.status, 'seating');
      return {committed: true, snapshot: snapshot(next)};
    },
  };
  t.mock.method(database, 'getDatabase', () => ({ref: (path) => {
    assert.equal(path, 'rooms/ABCDE');
    return ref;
  }}));
  t.mock.method(catalog, 'getGameCatalog', async () => ({exists: true,
    data: () => ({enabled: true, minPlayers: 2, maxPlayers: 4})}));

  const result = await beginRealtimeRoomSeating.run({auth: {uid: 'tablet'},
    data: {roomCode: 'ABCDE', roomInstanceId: 'room-current', controllerSessionId}});
  assert.deepEqual(Object.keys(result.players), ['first', 'second', 'third']);
  assert.deepEqual(result.playerUids, ['first', 'second', 'third']);
  assert.deepEqual(result.seatingPreference,
    {playerUids: ['first', 'second'], mode: 'sides'});
  assert.equal(result.status, 'seating');
});
