import assert from 'node:assert/strict';
import test from 'node:test';
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

function firestoreValue(data) {
  if (data === null) return {nullValue: null};
  if (typeof data === 'string') return {stringValue: data};
  if (typeof data === 'boolean') return {booleanValue: data};
  if (typeof data === 'number') return Number.isInteger(data) ? {integerValue: String(data)} : {doubleValue: data};
  if (Array.isArray(data)) return {arrayValue: {values: data.map(firestoreValue)}};
  return {mapValue: {fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, firestoreValue(v)]))}};
}

function firestoreDocument(path) {
  const url = `http://127.0.0.1:8080/v1/projects/${project}/databases/(default)/documents/${path}`;
  const request = (options = {}) => fetch(url, {...options, signal: AbortSignal.timeout(10000),
    headers: {Authorization: 'Bearer owner', 'Content-Type': 'application/json'}});
  return {
    // 문서가 없으면 null, 있으면 원본 fields(REST 형식)를 그대로 돌려준다.
    async get() {
      const response = await request();
      if (response.status === 404) return null;
      assert.equal(response.ok, true, `catalog read HTTP ${response.status}`);
      return (await response.json()).fields ?? {};
    },
    async set(data) {
      const response = await request({method: 'PATCH',
        body: JSON.stringify({fields: firestoreValue(data).mapValue.fields})});
      assert.equal(response.ok, true, `catalog write HTTP ${response.status}`);
    },
    async restore(fields) {
      const response = await request({method: 'PATCH', body: JSON.stringify({fields})});
      assert.equal(response.ok, true, `catalog restore HTTP ${response.status}`);
    },
    async delete() {
      const response = await request({method: 'DELETE'});
      assert.ok(response.ok || response.status === 404, `catalog delete HTTP ${response.status}`);
    },
  };
}

// 시작·재시작은 준비 직전 참가자·좌석 지문이 바뀌면 ABORTED(“다시 시도해주세요”)로 거절한다.
// 직전 명령 뒤 접속 동기화 트리거가 같은 방을 쓰는 동안 생길 수 있으며, 앱은 재시도 버튼을 보여 준다.
// 테스트도 사용자가 재시도하듯 이 경우만 짧게 다시 보낸다.
async function startWithRetry(person, data, attempts = 5) {
  for (let attempt = 1; ; attempt++) {
    try {
      return await callable(person, 'game_eleven_start_game', {...data, commandId: id()});
    } catch (error) {
      if (error.code !== 'ABORTED' || attempt >= attempts) throw error;
      await new Promise(resolve => setTimeout(resolve, 300));
    }
  }
}

test('ELEVEN callable room, full game, reconnect, restart, manual end and leave',
  {skip: !enabled, timeout: 240000}, async () => {
    assertLocalEnvironment();
    assert.equal(process.env.GCLOUD_PROJECT, project);
    await seedLocalFixtures();
    // firebase-admin Firestore는 인증서·ADC 자격 증명만 받으므로, 공용 fixture처럼 에뮬레이터
    // REST API(Bearer owner)로 카탈로그 문서를 다룬다.
    const catalog = firestoreDocument('games/eleven');
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
      await startWithRetry(tablet, controller);
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

      await startWithRetry(tablet, {...controller, restart: true});
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
      // 수동 종료 직후에는 방 상태 동기화 트리거가 같은 방을 쓰고 있어 바로 재시작하면 transaction이
      // 경합으로 abort될 수 있다. 실제 앱처럼 방 상태가 finished로 정리된 뒤 다시하기를 보낸다.
      await waitRoom(code, room => room.status === 'finished', 'room finished after manual end');
      await startWithRetry(tablet, {...controller, restart: true});
      const leave = await callable(a, 'game_eleven_leave_game', {...players[0].session, operationId: id()});
      assert.equal(leave.success, true);
      state = await roomValue(code, 'game/public');
      assert.equal(state.finishReason, 'insufficientPlayers');
      assert.equal(state.winnerUid ?? null, null);
    } finally {
      // 방만 지우면 태블릿의 방 연결 기록이 남아 다음 실행에서 방을 만들 수 없다. 함께 지운다.
      const tabletUid = accounts[0].uid;
      for (const path of [code && `rooms/${code}`, `controllerRooms/${tabletUid}`,
        `roomCreateSlots/${tabletUid}`, `roomCreateRequests/${tabletUid}`].filter(Boolean)) {
        await fetch(`${base}/${path}.json?ns=${namespace}`, {method: 'DELETE',
          headers: {Authorization: 'Bearer owner'}, signal: AbortSignal.timeout(10000)});
      }
      if (original) await catalog.restore(original);
      else await catalog.delete();
    }
  });
