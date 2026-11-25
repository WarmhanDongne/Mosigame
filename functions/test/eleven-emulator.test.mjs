import assert from 'node:assert/strict';
import test from 'node:test';
import {createRequire} from 'node:module';
import {accounts, password, project, seedLocalFixtures, assertLocalEnvironment}
  from '../../tool/emulator/local-fixtures.mjs';

const enabled = process.env.ELEVEN_EMULATOR === '1';
const namespace = `${project}-default-rtdb`;
const base = `http://127.0.0.1:9000`;
let operation = 0;
const id = () => `eleven-emulator-${Date.now()}-${++operation}`;

async function json(url, options = {}) {
  const response = await fetch(url, {signal: AbortSignal.timeout(20000), ...options});
  const body = await response.json();
  return {response, body};
}

async function login(account) {
  const {response, body} = await json('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=local-only', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({email: account.email, password, returnSecureToken: true}),
  });
  assert.equal(response.ok, true);
  assert.equal(body.localId, account.uid);
  return {...account, token: body.idToken};
}

async function callable(person, name, data) {
  const {response, body} = await json(`http://127.0.0.1:5001/${project}/asia-northeast3/${name}`, {
    method: 'POST', headers: {'Content-Type': 'application/json', Authorization: `Bearer ${person.token}`},
    body: JSON.stringify({data: {presenceProtocol: 2, ...data}}),
  });
  if (body.error) throw Object.assign(new Error(`${name}: ${body.error.status}`), {code: body.error.status});
  assert.equal(response.ok, true, `${name}: HTTP ${response.status}`);
  return body.result;
}

async function roomValue(code, path = '') {
  const {response, body} = await json(`${base}/rooms/${code}${path ? `/${path}` : ''}.json?ns=${namespace}`, {
    headers: {Authorization: 'Bearer owner'},
  });
  assert.equal(response.ok, true);
  return body;
}

const context = pub => Object.fromEntries(['gameInstanceId', 'phaseSeq', 'turnSeq', 'dataSeq',
  'resumeEpoch'].map(key => [key, pub[key]]));

async function gameCommand(person, name, session, code, data = {}) {
  const pub = await roomValue(code, 'game/public');
  return callable(person, `game_eleven_${name}`, {...session, ...context(pub),
    commandId: id(), ...data});
}

async function waitRoom(code, predicate, label) {
  for (let attempt = 0; attempt < 100; attempt++) {
    const room = await roomValue(code);
    if (predicate(room)) return room;
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  throw new Error(`Local emulator did not reach ${label}`);
}

test('ELEVEN callable room, full game, reconnect, restart, manual end and leave',
  {skip: !enabled, timeout: 240000}, async () => {
    assertLocalEnvironment();
    assert.equal(process.env.GCLOUD_PROJECT, project);
    await seedLocalFixtures();
    const require = createRequire(new URL('../package.json', import.meta.url));
    const {initializeApp, deleteApp} = require('firebase-admin/app');
    const {getFirestore} = require('firebase-admin/firestore');
    const admin = initializeApp({projectId: project, credential: {
      getAccessToken: async () => ({access_token: 'owner', expires_in: 3600}),
    }}, `eleven-emulator-${Date.now()}`);
    const catalog = getFirestore(admin).collection('games').doc('eleven');
    const original = await catalog.get();
    let code;
    try {
      await catalog.set({enabled: true, accessType: 'free', minPlayers: 2, maxPlayers: 2,
        storeVisible: false, name: '일레븐'});
      const [tablet, a, b] = await Promise.all(accounts.slice(0, 3).map(login));
      const created = await callable(tablet, 'createRealtimeRoom', {operationId: id()});
      code = created.roomCode;
      const target = {roomCode: code, roomInstanceId: created.roomInstanceId};
      const controller = {...target, ...created, role: 'controller'};
      const players = [];
      for (const [index, person] of [a, b].entries()) {
        const joined = await callable(person, 'joinRealtimeRoom', {...target, nickname: person.displayName,
          characterId: index ? 'bee' : 'bear', operationId: id(), expectedConnectionSeq: 0});
        players.push({...person, session: {...target, ...joined, role: 'player'}});
      }
      await callable(tablet, 'selectRealtimeRoomGame', {...controller, gameId: 'eleven'});
      await callable(tablet, 'beginRealtimeRoomSeating', controller);
      await callable(tablet, 'saveRealtimePlayerSeatIndexes', {...controller,
        seatIndexesByUid: {[a.uid]: 0, [b.uid]: 1}});
      await callable(tablet, 'game_eleven_start_game', {...controller, commandId: id()});
      await waitRoom(code, room => room.status === 'playing', 'playing room');
      for (const person of players) {
        const pub = await roomValue(code, 'game/public');
        await callable(person, 'game_common_recovery_report', {...person.session, ...context(pub),
          state: 'ready', screenUsable: true, assetsReady: true, reportSeq: 1, commandId: id()});
      }
      const pub = await roomValue(code, 'game/public');
      await callable(tablet, 'game_common_recovery_report', {...controller, ...context(pub),
        state: 'ready', screenUsable: true, assetsReady: true, reportSeq: 1, commandId: id()});
      assert.equal((await roomValue(code, 'game/public/recovery/paused')) ?? false, false);

      let state = await roomValue(code, 'game/public');
      const firstInstance = state.gameInstanceId;
      assert.equal(state.phase, 'drawPick');
      assert.equal(state.draw.revealed, undefined);
      for (const [index, pickerUid] of state.draw.order.entries()) {
        await gameCommand(tablet, 'pick_draw_tile', controller, code, {pickerUid, slotIndex: index});
      }
      state = await roomValue(code, 'game/public');
      assert.equal(state.phase, 'drawReveal');
      assert.equal(Object.keys(state.draw.revealed).length, 2);
      await gameCommand(tablet, 'complete_phase', controller, code, {revision: state.revision});

      // Eight ties and three decisive rounds exercise the complete 11-round path.
      for (let round = 1; round <= 11; round++) {
        state = await roomValue(code, 'game/public');
        assert.equal(state.round, round);
        const pair = round <= 8 ? [round - 1, round - 1] :
          round === 9 ? [8, 9] : round === 10 ? [9, 11] : [8, 11];
        const first = players.find(person => person.uid === state.firstUid);
        const second = players.find(person => person.uid === state.secondUid);
        await gameCommand(first, 'submit_tile', first.session, code, {round, value: pair[0]});
        await gameCommand(second, 'submit_tile', second.session, code, {round, value: pair[1]});
        state = await roomValue(code, 'game/public');
        assert.equal(state.phase, 'roundResult');
        assert.equal(state.lastRoundResult.round, round);
        assert.equal('value' in state.currentRound, false);
        await gameCommand(tablet, 'complete_phase', controller, code, {revision: state.revision});
      }
      state = await roomValue(code, 'game/public');
      assert.equal(state.status, 'finished');
      assert.equal(state.finishDetail, 'allRounds');

      // A new Auth token reads the same server snapshot after reconnect.
      const reconnected = await login(accounts[1]);
      const read = await json(`${base}/rooms/${code}/game/public.json?ns=${namespace}&auth=${reconnected.token}`);
      assert.equal(read.response.ok, true);
      assert.equal(read.body.status, 'finished');

      await callable(tablet, 'game_eleven_start_game', {...controller, restart: true, commandId: id()});
      const restarted = await roomValue(code, 'game/public');
      assert.notEqual(restarted.gameInstanceId, firstInstance);
      const old = await callable(tablet, 'game_eleven_complete_phase', {...controller,
        gameInstanceId: firstInstance, phaseSeq: 1, turnSeq: 1, commandId: id(), revision: state.revision});
      assert.equal(old.ignored, true);
      assert.equal((await roomValue(code, 'game/public')).gameInstanceId, restarted.gameInstanceId);
      await gameCommand(tablet, 'end_game', controller, code);
      state = await roomValue(code, 'game/public');
      assert.equal(state.finishReason, 'manual');
      assert.equal(state.winnerUid ?? null, null);
      await callable(tablet, 'game_eleven_start_game', {...controller, restart: true, commandId: id()});
      const leave = await callable(a, 'game_eleven_leave_game', {...players[0].session, operationId: id()});
      assert.equal(leave.success, true);
      state = await roomValue(code, 'game/public');
      assert.equal(state.finishReason, 'insufficientPlayers');
      assert.equal(state.winnerUid ?? null, null);
    } finally {
      if (code) await fetch(`${base}/rooms/${code}.json?ns=${namespace}`, {method: 'DELETE',
        headers: {Authorization: 'Bearer owner'}, signal: AbortSignal.timeout(10000)});
      if (original.exists) await catalog.set(original.data());
      else await catalog.delete();
      await deleteApp(admin);
    }
  });
