import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';
import {withTransactionRandom} from '../lib/common/transaction-random.js';
import {runGameCommandTransaction} from '../lib/game-interruption/game-command-transaction.js';
import {excludeElevenPlayer, finishElevenForInsufficientPlayers, finishElevenGame,
  createElevenGame, pickElevenTile, submitElevenTile, timeoutElevenTurn,
  completeElevenPhase} from '../lib/eleven/game.js';

const players = [
  {uid: 'a', nickname: 'A', characterId: 'bear', seatIndex: 0},
  {uid: 'b', nickname: 'B', characterId: 'bee', seatIndex: 1},
];
const makeGame = () => withTransactionRandom(Buffer.alloc(32, 7), () => createElevenGame(players, 1000));
const forbiddenKeys = new Set(['value', 'values', 'slots', 'submissions', 'sum', 'reason', 'lastJudgeReason']);
const forbiddenReasons = new Set(['sum20', 'under10', 'atLeast10']);
const numericPublicFields = new Set([
  'revision', 'round', 'turnDeadlineAt', 'startedAt', 'updatedAt', 'finishedAt',
  'phaseSeq', 'turnSeq', 'dataSeq', 'resumeEpoch', 'currentRound.round',
  'lastRoundResult.round', 'earlyEnd.remainingRounds', 'earlyEnd.gap',
]);

function allowedPublicNumber(path) {
  // Scores, rounds and timestamps can equal a tile by chance; only contract fields may carry numbers.
  const joined = path.join('.');
  return numericPublicFields.has(joined) ||
    (path.length === 2 && path[0] === 'scores') ||
    (path.length === 3 && path[0] === 'players' && path[2] === 'seatIndex') ||
    (path.length === 3 && path[0] === 'draw' && path[1] === 'picks') ||
    (path.length === 3 && path[0] === 'draw' && path[1] === 'revealed');
}

function assertBoundary(game, expectedLastRound, submittedValues = []) {
  const pub = game.public;
  // resolveRound clears server.submissions, so its just-judged values are passed explicitly.
  const secretValues = new Set([...Object.values(game.server.submissions), ...submittedValues]);
  const walk = (value, path = []) => {
    if (!value || typeof value !== 'object') return;
    for (const [key, child] of Object.entries(value)) {
      assert.equal(forbiddenKeys.has(key), false, `public leaks ${key}`);
      const childPath = [...path, key];
      if (typeof child === 'string') {
        assert.equal(forbiddenReasons.has(child), false, `public leaks judgement at ${childPath.join('.')}`);
      }
      if (typeof child === 'number' && !allowedPublicNumber(childPath)) {
        assert.equal(secretValues.has(child), false, `public leaks submitted tile at ${childPath.join('.')}`);
        assert.fail(`unexpected public number at ${childPath.join('.')}`);
      }
      if (key === 'revealed') assert.ok(['drawReveal', 'finished'].includes(pub.phase),
        'draw numbers only after both picks');
      walk(child, childPath);
    }
  };
  walk(pub);
  assert.equal('history' in pub, false);
  assert.equal('server' in pub, false);
  assert.equal('private' in pub, false);
  assert.deepEqual(pub.lastRoundResult, expectedLastRound);
  if (pub.draw && pub.phase === 'drawPick') {
    assert.equal('revealed' in pub.draw, false);
    assert.equal('slots' in pub.draw, false);
  }
  for (const row of game.controller.history) {
    assert.deepEqual(Object.keys(row).sort(),
      (row.autoSubmitted ? ['autoSubmitted', 'colors', 'firstUid', 'round', 'winnerUid'] :
        ['colors', 'firstUid', 'round', 'winnerUid']).sort());
    assert.ok(Object.values(row.colors).every(color => color === 'black' || color === 'white'));
  }
}

function begin(game) {
  assertBoundary(game, undefined);
  const [first, second] = game.public.draw.order;
  assert.deepEqual([...game.server.draw.slots].sort((a, b) => a - b), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
  pickElevenTile(game, first, 0, 1100);
  assert.equal(game.public.phase, 'drawPick');
  assertBoundary(game, undefined);
  pickElevenTile(game, second, 8, 1101);
  assert.equal(game.public.phase, 'drawReveal');
  assert.equal(Object.keys(game.public.draw.revealed).length, 2);
  assertBoundary(game, undefined);
  assert.equal(completeElevenPhase(game, game.public.revision, 1102), true);
  assert.equal(game.public.phase, 'firstSubmit');
  assertBoundary(game, undefined);
}

function round(game, firstValue, secondValue, now) {
  const {round: number, firstUid: first, secondUid: second} = game.public;
  assert.equal(game.public.phase, 'firstSubmit');
  const prior = game.public.lastRoundResult;
  assertBoundary(game, prior);
  submitElevenTile(game, first, number, firstValue, now);
  assert.equal(game.public.phase, 'secondSubmit');
  assertBoundary(game, prior);
  submitElevenTile(game, second, number, secondValue, now + 1);
  assert.equal(game.public.phase, 'roundResult');
  const result = {round: number, winnerUid: game.controller.history.at(-1).winnerUid};
  assertBoundary(game, result, [firstValue, secondValue]);
  const staleRevision = game.public.revision - 1;
  const before = structuredClone(game);
  assert.equal(completeElevenPhase(game, staleRevision, now + 2), false);
  assert.deepEqual(game, before, 'stale complete_phase does not mutate');
  assert.equal(completeElevenPhase(game, game.public.revision, now + 2), true);
  assertBoundary(game, result, [firstValue, secondValue]);
  return result;
}

test('eleven rounds can reach allRounds with only the last result published', () => {
  const game = makeGame(); begin(game);
  const initialFirst = game.public.firstUid;
  const initialSecond = game.public.secondUid;
  for (let value = 0; value < 8; value++) {
    assert.deepEqual(round(game, value, value, 2000 + value * 10), {round: value + 1, winnerUid: null});
    assert.equal(game.public.firstUid, initialFirst);
  }
  assert.deepEqual(round(game, 8, 9, 2100), {round: 9, winnerUid: initialFirst});
  assert.deepEqual(round(game, 9, 11, 2110), {round: 10, winnerUid: initialSecond});
  assert.equal(game.public.firstUid, initialSecond);
  assert.deepEqual(round(game, 8, 11, 2120), {round: 11, winnerUid: initialSecond});
  assert.equal(game.public.status, 'finished');
  assert.equal(game.public.finishReason, 'winner');
  assert.equal(game.public.finishDetail, 'allRounds');
  assert.equal(game.public.winnerUid, initialSecond);
  assert.equal(game.controller.history.length, 11);
});

test('gap equal to remaining rounds continues; greater gap finishes early', () => {
  const game = makeGame(); begin(game);
  const first = game.public.firstUid;
  round(game, 7, 7, 2000);
  for (const [index, pair] of [[11, 9], [1, 0], [2, 1], [3, 2], [4, 3]].entries()) {
    round(game, pair[0], pair[1], 2010 + index * 10);
  }
  assert.equal(game.public.round, 7, 'five-point gap with five rounds left must continue');
  assert.equal(game.public.status, 'playing');
  round(game, 5, 4, 2100);
  assert.equal(game.public.status, 'finished');
  assert.equal(game.public.finishDetail, 'earlyEnd');
  assert.deepEqual(game.public.earlyEnd, {remainingRounds: 4, leaderUid: first, gap: 6});
  assert.equal(game.public.winnerUid, first);
});

test('eleven ties lead to final shared draw, then tieDraw finish', () => {
  const game = makeGame(); begin(game);
  for (const [index, value] of [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11].entries()) {
    assert.deepEqual(round(game, value, value, 3000 + index * 10), {round: index + 1, winnerUid: null});
  }
  assert.equal(game.public.phase, 'drawPick');
  assert.equal(game.public.draw.purpose, 'finalTie');
  assert.deepEqual(game.public.draw.order, [game.public.firstUid, game.public.secondUid]);
  const [first, second] = game.public.draw.order;
  pickElevenTile(game, first, 0, 3200);
  assertBoundary(game, {round: 11, winnerUid: null});
  pickElevenTile(game, second, 8, 3201);
  assertBoundary(game, {round: 11, winnerUid: null});
  const winner = game.public.draw.winnerUid;
  assert.equal(completeElevenPhase(game, game.public.revision, 3202), true);
  assert.equal(game.public.finishReason, 'winner');
  assert.equal(game.public.finishDetail, 'tieDraw');
  assert.equal(game.public.winnerUid, winner);
  assertBoundary(game, {round: 11, winnerUid: null});
});

test('tablet and two phones racing timeout apply only one submission', () => {
  const game = makeGame(); begin(game);
  const deadline = game.public.turnDeadlineAt;
  assert.equal(timeoutElevenTurn(game, 1, 'firstSubmit', deadline - 1), false);
  const observed = ['tablet', 'phone-a', 'phone-b'].map(() =>
    timeoutElevenTurn(game, 1, 'firstSubmit', deadline));
  assert.deepEqual(observed, [true, false, false]);
  assert.equal(game.public.phase, 'secondSubmit');
  assert.equal(Object.keys(game.server.submissions).length, 1);
  assert.equal(game.private[game.public.firstUid].submission.auto, true);
  assertBoundary(game, undefined);
});

test('public boundary catches judgement aliases and submitted numbers under new keys', () => {
  const game = makeGame(); begin(game);
  const first = game.public.firstUid;
  submitElevenTile(game, first, 1, 4, 2000);
  game.public.hiddenOutcome = 'sum20';
  assert.throws(() => assertBoundary(game, undefined), /public leaks judgement/);
  delete game.public.hiddenOutcome;
  game.public.hiddenTile = game.server.submissions[first];
  assert.throws(() => assertBoundary(game, undefined), /public leaks submitted tile/);
});

test('exclude, insufficient-player finish and manual end have no winner', () => {
  for (const [reason, finish] of [
    ['insufficientPlayers', game => excludeElevenPlayer(game, 'a', 5000)],
    ['insufficientPlayers', game => finishElevenForInsufficientPlayers(game, 5000)],
    ['manual', game => finishElevenGame(game, 5000)],
  ]) {
    const game = makeGame(); finish(game);
    assert.equal(game.public.status, 'finished');
    assert.equal(game.public.finishReason, reason);
    assert.equal(game.public.winnerUid, null);
  }
});

test('old instance command cannot mutate a restarted game; duplicate command replays', async () => {
  const session = '11111111-1111-4111-8111-111111111111';
  const game = makeGame();
  Object.assign(game.public, {gameInstanceId: 'old-game', phaseSeq: 1, turnSeq: 1});
  const room = {roomInstanceId: 'room-one', controllerUid: 'tablet', controllerSessionId: session,
    controllerCurrentConnectionId: 'ct', controllerConnectionSeq: 1, status: 'playing', selectedGame: 'eleven',
    connections: {tablet: {ct: {roomInstanceId: 'room-one', connectionSeq: 1, connected: true}}},
    players: {}, game};
  const ref = {value: room, on(_event, cb) {cb({val: () => this.value});}, off() {},
    async transaction(update) {const next = update(structuredClone(this.value));
      if (next === undefined) return {committed: false, snapshot: {val: () => this.value}};
      this.value = next;
      return {committed: true, snapshot: {val: () => this.value}};}};
  const request = {auth: {uid: 'tablet'}, data: {roomCode: 'ABCDE', roomInstanceId: 'room-one',
    role: 'controller', controllerSessionId: session, connectionId: 'ct', connectionSeq: 1,
    commandId: 'pick-one', gameInstanceId: 'old-game', phaseSeq: 1, turnSeq: 1,
    pickerUid: game.public.draw.order[0], slotIndex: 0}};
  const action = (raw, now) => {pickElevenTile(raw.game, request.data.pickerUid, 0, now); return raw;};
  const first = await runGameCommandTransaction(ref, request, 'game_eleven_pick_draw_tile', action);
  const replay = await runGameCommandTransaction(ref, request, 'game_eleven_pick_draw_tile', () => {
    throw new Error('duplicate command mutated game');
  });
  assert.equal(first.committed, true);
  assert.deepEqual(replay.operationResult, first.operationResult);
  assert.equal(Object.keys(ref.value.game.public.draw.picks).length, 1);
  ref.value.game = makeGame();
  Object.assign(ref.value.game.public, {gameInstanceId: 'new-game', phaseSeq: 1, turnSeq: 1});
  const restarted = structuredClone(ref.value.game);
  await assert.rejects(runGameCommandTransaction(ref, {...request, data: {...request.data,
    commandId: 'old-after-restart'}}, 'game_eleven_pick_draw_tile', action),
  error => error.code === 'failed-precondition' && error.details?.reason === 'staleContext');
  assert.deepEqual(ref.value.game, restarted);
});

test('RTDB game rules deny controller/server/other private reads', () => {
  const rules = JSON.parse(readFileSync(new URL('../../database.rules.json', import.meta.url), 'utf8')).rules;
  const game = rules.rooms.$roomCode.game;
  const root = {child: key => ({child: code => ({child: field => ({val: () =>
    key === 'rooms' && code === 'ABCDE' && field === 'controllerUid' ? 'tablet' : null})})})};
  const allowed = (expression, uid, playerUid) => vm.runInNewContext(String(expression),
    {auth: uid ? {uid} : null, root, $roomCode: 'ABCDE', $playerUid: playerUid});
  assert.equal(game['.read'], false);
  for (const uid of ['a', 'b', 'outsider', null]) {
    assert.equal(allowed(game.controller['.read'], uid), false);
    assert.equal(allowed(game.server['.read'], uid), false);
    assert.equal(allowed(game.private.$playerUid['.read'], uid, uid === 'a' ? 'b' : 'a'), false);
  }
  assert.equal(allowed(game.controller['.read'], 'tablet'), true);
  assert.equal(allowed(game.private.$playerUid['.read'], 'a', 'a'), true);
});
