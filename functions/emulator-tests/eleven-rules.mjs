import assert from 'node:assert/strict';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getDatabase} from 'firebase-admin/database';
import {createElevenGame, pickElevenTile, completeElevenPhase} from '../lib/eleven/game.js';
import {game_eleven_timeout_turn, game_eleven_submit_tile} from '../lib/eleven/callables.js';

if (!process.env.FIREBASE_DATABASE_EMULATOR_HOST) {
  throw new Error('Realtime Database emulator is required');
}
const databaseURL = 'https://demo-eleven-default-rtdb.firebaseio.com';
const owner = initializeApp({databaseURL});
const controller = initializeApp({databaseURL, databaseAuthVariableOverride: {uid: 'tablet'}}, 'controller');
const player = initializeApp({databaseURL, databaseAuthVariableOverride: {uid: 'phone'}}, 'player');
const outsider = initializeApp({databaseURL, databaseAuthVariableOverride: {uid: 'outsider'}}, 'outsider');
const path = 'rooms/ABCDE/game';
try {
  await getDatabase(owner).ref('rooms/ABCDE').set({
    controllerUid: 'tablet', players: {phone: {status: 'active'}},
    game: {public: {phase: 'roundResult'}, controller: {history: [{round: 1, firstUid: 'phone', winnerUid: 'phone'}]},
      private: {phone: {tiles: [1, 2]}}, server: {submissions: {phone: 3}}},
  });
  const read = (app, suffix = '') => getDatabase(app).ref(`${path}${suffix}`).get();
  assert.equal((await read(controller, '/controller/history')).val()[0].round, 1);
  assert.equal((await read(player, '/public/phase')).val(), 'roundResult');
  assert.deepEqual((await read(player, '/private/phone/tiles')).val(), [1, 2]);
  for (const app of [player, outsider]) await assert.rejects(read(app, '/controller/history'));
  await assert.rejects(read(outsider, '/public'));
  await assert.rejects(read(controller, '/private/phone'));
  for (const app of [controller, player, outsider]) {
    await assert.rejects(read(app, '/server'));
    await assert.rejects(read(app));
    await assert.rejects(getDatabase(app).ref(`${path}/public/phase`).set('tampered'));
  }
  const game = createElevenGame([
    {uid: 'a', nickname: 'A', characterId: 'bear', seatIndex: 0},
    {uid: 'b', nickname: 'B', characterId: 'bee', seatIndex: 1},
  ], Date.now());
  const [drawFirst, drawSecond] = game.public.draw.order;
  pickElevenTile(game, drawFirst, 0, Date.now());
  pickElevenTile(game, drawSecond, 1, Date.now());
  completeElevenPhase(game, game.public.revision, Date.now());
  game.public.turnDeadlineAt = Date.now() - 1;
  game.public.gameInstanceId = 'game-one';
  game.public.phaseSeq = 1;
  game.public.turnSeq = 1;
  game.public.dataSeq = 1;
  const session = '11111111-1111-4111-8111-111111111111';
  const activeRoom = {
    roomInstanceId: 'room-one', status: 'playing', selectedGame: 'eleven',
    controllerUid: 'tablet', controllerSessionId: session,
    controllerCurrentConnectionId: 'ct', controllerConnectionSeq: 1,
    players: {a: {status: 'active', membershipId: 'ma', currentConnectionId: 'ca', connectionSeq: 1},
      b: {status: 'active', membershipId: 'mb', currentConnectionId: 'cb', connectionSeq: 1}},
    connections: {tablet: {ct: {roomInstanceId: 'room-one', connectionSeq: 1, connected: true}},
      a: {ca: {roomInstanceId: 'room-one', connectionSeq: 1, connected: true}},
      b: {cb: {roomInstanceId: 'room-one', connectionSeq: 1, connected: true}}},
    game,
  };
  await getDatabase(owner).ref('rooms/FGHJK').set(activeRoom);
  const context = {roomCode: 'FGHJK', roomInstanceId: 'room-one', gameInstanceId: 'game-one',
    phaseSeq: 1, turnSeq: 1, round: 1, phase: 'firstSubmit'};
  const tabletRequest = {auth: {uid: 'tablet'}, data: {...context, role: 'controller',
    controllerSessionId: session, connectionId: 'ct', connectionSeq: 1, commandId: 'timeout-tablet'}};
  const phoneRequest = {auth: {uid: 'a'}, data: {...context, role: 'player',
    membershipId: 'ma', connectionId: 'ca', connectionSeq: 1, commandId: 'timeout-phone'}};
  const raced = await Promise.all([game_eleven_timeout_turn.run(tabletRequest),
    game_eleven_timeout_turn.run(phoneRequest)]);
  assert.equal(raced.filter((result) => result.ignored === true).length, 1);
  assert.equal(raced.filter((result) => result.ignored !== true).length, 1);
  const after = (await getDatabase(owner).ref('rooms/FGHJK').get()).val();
  assert.equal(after.game.public.phase, 'secondSubmit');
  assert.equal(after.game.private[after.game.public.firstUid].tiles.length, 10);
  assert.equal(Object.keys(after.sessionOperations).length, 1);
  const applied = raced.find((result) => result.ignored !== true);
  const appliedRequest = raced[0].ignored ? phoneRequest : tabletRequest;
  const replay = await game_eleven_timeout_turn.run({...appliedRequest,
    data: {...appliedRequest.data, connectionId: 'old-connection'}});
  assert.deepEqual(replay, applied);
  await assert.rejects(game_eleven_submit_tile.run({auth: {uid: 'outsider'},
    data: {...context, role: 'player', connectionId: 'cx', connectionSeq: 1,
      membershipId: 'mx', commandId: 'outsider-submit', value: 3}}));
  process.stdout.write('ELEVEN RTDB emulator rules and commands PASS\n');
} finally {
  await getDatabase(owner).ref('rooms/ABCDE').remove();
  await getDatabase(owner).ref('rooms/FGHJK').remove();
  await Promise.all([owner, controller, player, outsider].map(deleteApp));
}
