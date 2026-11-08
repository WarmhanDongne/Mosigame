import assert from 'node:assert/strict';
import test from 'node:test';
import {createRequire} from 'node:module';
const require = createRequire(import.meta.url);
const {logger} = require('firebase-functions');
const {recordLiarsPokerTransition: record} = require('../lib/game-interruption/transition-diagnostics.js');

function room() {
  const context = {gameInstanceId: 'private-game', phaseSeq: 2, turnSeq: 2, dataSeq: 2};
  return {roomCode: 'private-room', players: {'private-uid': {nickname: 'private-name'}}, game: {
    public: {...context, status: 'playing', phase: 'playing'},
    private: {'private-uid': {_context: context, hand: {'private-card': {value: 'private-value'}}}},
    server: {secret: 'private-secret'},
  }};
}

test('transition diagnostics reports committed state and context match without payloads or mutation', t => {
  const logs = [];
  t.mock.method(logger, 'info', (...args) => logs.push(args));
  const value = room(), before = structuredClone(value);
  record('completeDealing', {gameInstanceId: 'private-game', token: 'private-token'},
    {type: 'dealingCompleted', uid: 'private-uid'}, () => value);
  assert.deepEqual(logs, [['liars_poker_transition_result', {
    action: 'completeDealing', responseType: 'dealingCompleted', requestGameCurrent: true,
    status: 'playing', phase: 'playing', paused: false, contextValid: true,
    privatePlayers: 1, matchingPrivatePlayers: 1, pendingHands: false,
  }]]);
  assert.equal(JSON.stringify(logs).includes('private-'), false);
  assert.deepEqual(value, before);
});

test('old replay and missing/mismatched private data remain distinguishable from current completion', t => {
  const logs = [];
  t.mock.method(logger, 'info', (_event, fields) => logs.push(fields));
  const value = room();
  value.game.public.gameInstanceId = 'new-private-game';
  value.game.public.phase = 'dealing';
  value.game.public.recovery = {paused: true};
  value.game.server.pendingHands = {'private-uid': {hand: {secret: true}}};
  record('completeDealing', {gameInstanceId: 'private-game'}, {type: 'dealingCompleted'}, () => value);
  assert.equal(logs[0].requestGameCurrent, false);
  assert.equal(logs[0].phase, 'dealing');
  assert.equal(logs[0].paused, true);
  assert.equal(logs[0].pendingHands, true);
  assert.equal(logs[0].matchingPrivatePlayers, 0);
  value.game.public.status = 'finished';
  value.game.public.phase = 'finished';
  delete value.game.private;
  delete value.game.server.pendingHands;
  record('endGame', {gameInstanceId: 'new-private-game'}, {type: 'gameEnded'}, () => value);
  assert.equal(logs[1].requestGameCurrent, true);
  assert.equal(logs[1].status, 'finished');
  assert.equal(logs[1].privatePlayers, 0);
});

test('unrecognized labels and missing contexts never leak values or count as matching', t => {
  const logs = [];
  t.mock.method(logger, 'info', (_event, fields) => logs.push(fields));
  record('endGame', {}, {type: 'private-response'}, () => ({game: {
    public: {phase: 'private-phase', status: 'private-status'}, private: {uid: {}},
  }}));
  assert.equal(logs[0].contextValid, false);
  assert.equal(logs[0].matchingPrivatePlayers, 0);
  assert.equal(logs[0].requestGameCurrent, false);
  assert.equal(JSON.stringify(logs).includes('private-'), false);
});

test('snapshot and logging failures cannot replace an applied response', t => {
  assert.doesNotThrow(() => record('endGame', {}, {}, () => {throw Error('decode failure');}));
  t.mock.method(logger, 'info', () => {throw Error('sink failure');});
  assert.doesNotThrow(() => record('endGame', {}, {}, room));
});
