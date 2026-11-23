import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import {withTransactionRandom} from '../lib/common/transaction-random.js';
import {runGameCommandTransaction} from '../lib/game-interruption/game-command-transaction.js';
import {excludeRecoveryPlayer} from '../lib/game-interruption/game-adapters.js';
import {supportsInsufficientPlayerFinish} from '../lib/game-interruption/finish-now-resolution.js';
import {resolveRoomPlayerRange} from '../lib/room/room-seating-policy.js';
import {createElevenGame, pickElevenTile, completeElevenPhase, submitElevenTile,
  timeoutElevenTurn, finishElevenGame} from '../lib/eleven/game.js';

const players = [
  {uid: 'a', nickname: 'A', characterId: 'bear', seatIndex: 0},
  {uid: 'b', nickname: 'B', characterId: 'bee', seatIndex: 1},
];
const game = () => withTransactionRandom(Buffer.alloc(32, 3), () => createElevenGame(players, 1000));
function startFirstRound(state, now = 2000) {
  const [first, second] = state.public.draw.order;
  pickElevenTile(state, first, 0, now);
  assert.equal(state.public.phase, 'drawPick');
  assert.equal(state.public.draw.revealed, undefined);
  assert.equal(state.server.draw.slots.length, 11);
  assert.throws(() => pickElevenTile(state, second, 0, now + 1));
  pickElevenTile(state, second, 1, now + 2);
  assert.equal(state.public.phase, 'drawReveal');
  assert.equal(Object.keys(state.public.draw.revealed).length, 2);
  assert.equal(state.server.draw, undefined);
  assert.equal(completeElevenPhase(state, state.public.revision, now + 3), true);
  assert.equal(state.public.phase, 'firstSubmit');
}

test('two player draw reveals both numbers together without using either hand', () => {
  const state = game();
  assert.deepEqual(resolveRoomPlayerRange('eleven', 1, 12), {minPlayers: 2, maxPlayers: 2});
  assert.equal(state.private.a.tiles.length, 11);
  startFirstRound(state);
  assert.equal(state.private.a.tiles.length, 11);
  assert.equal(state.private.b.tiles.length, 11);
  assert.equal(state.public.turnDeadlineAt, 62003);
});

test('early second submission, duplicate tile and expired manual turn are rejected', () => {
  const state = game(); startFirstRound(state);
  const first = state.public.firstUid, second = state.public.secondUid;
  assert.throws(() => submitElevenTile(state, second, 1, 4, 2005));
  assert.throws(() => submitElevenTile(state, first, 2, 4, 2005));
  assert.throws(() => submitElevenTile(state, first, 1, 4, 62003));
  submitElevenTile(state, first, 1, 4, 2005);
  assert.equal(state.public.phase, 'secondSubmit');
  assert.equal(state.public.turnDeadlineAt, 62005);
  assert.equal(state.public.currentRound.firstColor, 'black');
  assert.equal(state.private[first].tiles.includes(4), false);
  assert.throws(() => submitElevenTile(state, first, 1, 5, 2006));
  assert.throws(() => submitElevenTile(state, second, 1, 10, 2006));
});

test('timeout picks remaining tile once, result hides numbers and advances on exact revision', () => {
  const state = game(); startFirstRound(state);
  const first = state.public.firstUid, second = state.public.secondUid;
  state.private[first].tiles = [4];
  assert.equal(timeoutElevenTurn(state, 1, 'firstSubmit', 62002), false);
  assert.equal(timeoutElevenTurn(state, 1, 'firstSubmit', 62003), true);
  assert.equal(timeoutElevenTurn(state, 1, 'firstSubmit', 62003), false);
  assert.equal(state.private[first].submission.value, 4);
  assert.equal(state.private[first].submission.auto, true);
  state.private[second].tiles = [8];
  assert.equal(timeoutElevenTurn(state, 1, 'secondSubmit', state.public.turnDeadlineAt), true);
  assert.equal(state.public.phase, 'roundResult');
  assert.equal(state.controller.history.length, 1);
  assert.equal(state.controller.history[0].colors[first], 'black');
  assert.equal(state.controller.history[0].colors[second], 'black');
  assert.equal(JSON.stringify(state.public).includes('"value"'), false);
  assert.equal(JSON.stringify(state.controller).includes('"value"'), false);
  assert.equal(state.public.history, undefined);
  assert.equal(completeElevenPhase(state, state.public.revision - 1, 123000), false);
  assert.equal(completeElevenPhase(state, state.public.revision, 123000), true);
  assert.equal(state.public.phase, 'firstSubmit');
  assert.equal(state.public.round, 2);
  assert.equal(state.private[first].submission, undefined);
});

test('eleven tied rounds reach separate final draw and finish with no round numbers published', () => {
  const state = game(); startFirstRound(state);
  for (let round = 1; round <= 11; round++) {
    assert.equal(state.public.round, round);
    const first = state.public.firstUid, second = state.public.secondUid;
    const value = state.private[first].tiles[0];
    assert.equal(state.private[second].tiles[0], value);
    submitElevenTile(state, first, round, value, 10000 + round * 1000);
    submitElevenTile(state, second, round, value, 10001 + round * 1000);
    assert.equal(state.public.phase, 'roundResult');
    assert.equal(state.controller.history.at(-1).winnerUid, null);
    assert.equal(completeElevenPhase(state, state.public.revision, 10002 + round * 1000), true);
  }
  assert.equal(state.public.phase, 'drawPick');
  assert.deepEqual(state.public.draw.order, [state.public.firstUid, state.public.secondUid]);
  assert.equal(state.private.a.tiles.length, 0);
  assert.equal(state.private.b.tiles.length, 0);
  const [first, second] = state.public.draw.order;
  pickElevenTile(state, first, 0, 30000);
  pickElevenTile(state, second, 1, 30001);
  const winner = state.public.draw.winnerUid;
  assert.equal(completeElevenPhase(state, state.public.revision, 30002), true);
  assert.equal(state.public.status, 'finished');
  assert.equal(state.public.finishReason, 'winner');
  assert.equal(state.public.finishDetail, 'tieDraw');
  assert.equal(state.public.winnerUid, winner);
  assert.equal(state.controller.history.length, 11);
  assert.equal(state.public.history, undefined);
  assert.equal(state.server.submissions && Object.keys(state.server.submissions).length, 0);
});

test('finish and common exclusion never assign a winner to a departing player', () => {
  const state = game();
  const room = {selectedGame: 'eleven', game: state};
  assert.equal(supportsInsufficientPlayerFinish('eleven'), true);
  excludeRecoveryPlayer(room, 'a', 3000);
  assert.equal(state.public.status, 'finished');
  assert.equal(state.public.finishReason, 'insufficientPlayers');
  assert.equal(state.public.winnerUid, null);
  assert.equal(state.private.a, undefined);
  finishElevenGame(state, 4000);
  assert.equal(state.public.finishReason, 'insufficientPlayers');
});

test('controller history rule denies phones, outsiders, unauthenticated users and game parent reads', () => {
  const rules = JSON.parse(readFileSync(new URL('../../database.rules.json', import.meta.url), 'utf8')).rules;
  const root = {child: (key) => ({child: (code) => ({child: (field) => ({val: () =>
    key === 'rooms' && code === 'ABCDE' && field === 'controllerUid' ? 'tablet' : null})})})};
  const rule = rules.rooms.$roomCode.game.controller['.read'];
  const allowed = (uid) => vm.runInNewContext(rule, {auth: uid ? {uid} : null, root, $roomCode: 'ABCDE'});
  assert.equal(allowed('tablet'), true);
  for (const uid of ['a', 'b', 'outsider', null]) assert.equal(allowed(uid), false);
  assert.equal(rules.rooms.$roomCode.game['.read'], false);
  assert.equal(rules.rooms.$roomCode.game['.write'], false);
  assert.equal(rules.rooms.$roomCode.game.server['.read'], false);
  assert.equal(rules.rooms.$roomCode.game.private.$playerUid['.read'], 'auth != null && auth.uid == $playerUid');
});

test('same command ID replays a committed draw without consuming a second tile', async () => {
  const session = '11111111-1111-4111-8111-111111111111';
  const state = game();
  const room = {roomInstanceId: 'room-one', controllerUid: 'tablet', controllerSessionId: session,
    controllerCurrentConnectionId: 'ct', controllerConnectionSeq: 1, status: 'playing', selectedGame: 'eleven',
    connections: {tablet: {ct: {roomInstanceId: 'room-one', connectionSeq: 1, connected: true}}},
    players: {}, game: state};
  state.public.gameInstanceId = 'game-one'; state.public.phaseSeq = 1; state.public.turnSeq = 1;
  const ref = {value: room, on(_event, cb) {cb({val: () => this.value});}, off() {},
    async transaction(update) {this.value = update(structuredClone(this.value)); return {committed: true, snapshot: {val: () => this.value}};}};
  const request = {auth: {uid: 'tablet'}, data: {roomCode: 'ABCDE', roomInstanceId: 'room-one',
    role: 'controller', controllerSessionId: session, connectionId: 'ct', connectionSeq: 1,
    commandId: 'pick-one', gameInstanceId: 'game-one', phaseSeq: 1, turnSeq: 1,
    pickerUid: state.public.draw.order[0], slotIndex: 0}};
  const kind = 'game_eleven_pick_draw_tile';
  const apply = (raw, now) => {pickElevenTile(raw.game, request.data.pickerUid, 0, now); return raw;};
  const first = await runGameCommandTransaction(ref, request, kind, apply, () => ({success: true}));
  const replay = await runGameCommandTransaction(ref, request, kind, () => {throw Error('duplicate mutation');});
  assert.equal(first.committed, true);
  assert.deepEqual(replay.operationResult, first.operationResult);
  assert.equal(Object.keys(ref.value.game.public.draw.picks).length, 1);
});
