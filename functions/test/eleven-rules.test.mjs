import assert from "node:assert/strict";
import test from "node:test";

import {
  ELEVEN_DRAW_TILES,
  ELEVEN_MAX_ROUNDS,
  ELEVEN_TILES,
  ElevenRuleError,
  createElevenDraw,
  decideElevenAfterRound,
  elevenTileColor,
  isElevenTile,
  judgeElevenRound,
  nextElevenDrawPicker,
  pickElevenDrawSlot,
  pickElevenTimeoutTile,
  randomElevenDrawOrder,
  removeElevenTile,
  resolveElevenRound,
  revealElevenDraw,
  shuffleEleven,
} from "../lib/eleven/rules.js";

const A = "uid-a";
const B = "uid-b";

/** 규칙 문장을 그대로 옮긴 독립 판정입니다. 구현과 비교만 합니다. */
function oracle(first, second) {
  if (first === second) return "tie";
  const sum = first + second;
  if (sum === 20) return first === 11 ? "first" : "second";
  const firstWins = sum < 10 ? first > second : first < second;
  return firstWins ? "first" : "second";
}

/** 정해진 순서로 값을 돌려주는 무작위 함수입니다. */
function sequence(...values) {
  let index = 0;
  return (max) => {
    const value = values[index % values.length];
    index += 1;
    assert.ok(value < max, `random ${value} must be < ${max}`);
    return value;
  };
}

function freshTiles() {
  return {[A]: [...ELEVEN_TILES], [B]: [...ELEVEN_TILES]};
}

function assertRuleError(fn, code) {
  assert.throws(fn, (error) => error instanceof ElevenRuleError && error.code === code);
}

test("타일은 0–9와 11, 10은 없다", () => {
  assert.deepEqual([...ELEVEN_TILES], [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11]);
  assert.deepEqual([...ELEVEN_DRAW_TILES], [1, 2, 3, 4, 5, 6, 7, 8, 9], "공용 뽑기는 1–9 9장(2026-11-25)");
  assert.equal(isElevenTile(10), false);
  assert.equal(isElevenTile(-1), false);
  assert.equal(isElevenTile(12), false);
  assert.equal(isElevenTile(1.5), false);
  assert.equal(isElevenTile("1"), false);
});

test("색: 흑 0,2,4,6,8,11 6장 / 백 1,3,5,7,9 5장", () => {
  const black = ELEVEN_TILES.filter((v) => elevenTileColor(v) === "black");
  const white = ELEVEN_TILES.filter((v) => elevenTileColor(v) === "white");
  assert.deepEqual(black, [0, 2, 4, 6, 8, 11]);
  assert.deepEqual(white, [1, 3, 5, 7, 9]);
  assertRuleError(() => elevenTileColor(10), "invalidTile");
});

test("121개 순서쌍 전수 판정이 규칙과 일치한다", () => {
  let count = 0;
  for (const first of ELEVEN_TILES) {
    for (const second of ELEVEN_TILES) {
      assert.equal(judgeElevenRound(first, second).outcome, oracle(first, second), `${first} vs ${second}`);
      count += 1;
    }
  }
  assert.equal(count, 121);
});

test("판정은 순서를 바꾸면 결과도 뒤집힌다(동점 제외)", () => {
  for (const a of ELEVEN_TILES) {
    for (const b of ELEVEN_TILES) {
      const ab = judgeElevenRound(a, b).outcome;
      const ba = judgeElevenRound(b, a).outcome;
      if (a === b) assert.equal(ab, "tie");
      else assert.equal(ab === "first" ? "second" : "first", ba);
    }
  }
});

test("대표 경계 사례", () => {
  // 합 20: 9와 11뿐이며 11이 이긴다.
  assert.deepEqual(judgeElevenRound(11, 9), {outcome: "first", reason: "sum20"});
  assert.deepEqual(judgeElevenRound(9, 11), {outcome: "second", reason: "sum20"});
  const sum20 = [];
  for (const a of ELEVEN_TILES) for (const b of ELEVEN_TILES) if (a + b === 20) sum20.push([a, b]);
  assert.deepEqual(sum20, [[9, 11], [11, 9]]);
  // 합 10: 작은 숫자 승.
  assert.deepEqual(judgeElevenRound(8, 2), {outcome: "second", reason: "atLeast10"});
  assert.deepEqual(judgeElevenRound(1, 9), {outcome: "first", reason: "atLeast10"});
  // 합 9: 큰 숫자 승.
  assert.deepEqual(judgeElevenRound(7, 2), {outcome: "first", reason: "under10"});
  assert.deepEqual(judgeElevenRound(0, 9), {outcome: "second", reason: "under10"});
  // 11과 다른 숫자(합 11 이상, 20 아님): 작은 숫자 승.
  assert.deepEqual(judgeElevenRound(11, 0), {outcome: "second", reason: "atLeast10"});
  assert.deepEqual(judgeElevenRound(8, 11), {outcome: "first", reason: "atLeast10"});
  // 같은 숫자는 합보다 우선해 동점.
  assert.deepEqual(judgeElevenRound(5, 5), {outcome: "tie", reason: "sameNumber"});
  assert.deepEqual(judgeElevenRound(11, 11), {outcome: "tie", reason: "sameNumber"});
  assert.deepEqual(judgeElevenRound(0, 0), {outcome: "tie", reason: "sameNumber"});
  assertRuleError(() => judgeElevenRound(10, 1), "invalidTile");
});

test("라운드 반영: 승자 +1, 두 타일 소모, 승자가 다음 선공", () => {
  const result = resolveElevenRound({
    round: 1, firstUid: A, secondUid: B,
    values: {[A]: 8, [B]: 9},
    scores: {[A]: 0, [B]: 0},
    tiles: freshTiles(),
  });
  assert.equal(result.winnerUid, A);
  assert.deepEqual(result.scores, {[A]: 1, [B]: 0});
  assert.deepEqual(result.colors, {[A]: "black", [B]: "white"});
  assert.deepEqual(result.tiles[A], [0, 1, 2, 3, 4, 5, 6, 7, 9, 11]);
  assert.deepEqual(result.tiles[B], [0, 1, 2, 3, 4, 5, 6, 7, 8, 11]);
  assert.equal(result.nextFirstUid, A);

  const secondWins = resolveElevenRound({
    round: 2, firstUid: A, secondUid: B,
    values: {[A]: 3, [B]: 5},
    scores: result.scores,
    tiles: result.tiles,
  });
  assert.equal(secondWins.winnerUid, B);
  assert.equal(secondWins.nextFirstUid, B);
});

test("동점: 둘 다 0점, 두 타일 모두 소모, 선공 유지", () => {
  const result = resolveElevenRound({
    round: 3, firstUid: B, secondUid: A,
    values: {[A]: 1, [B]: 1},
    scores: {[A]: 1, [B]: 1},
    tiles: freshTiles(),
  });
  assert.equal(result.outcome, "tie");
  assert.equal(result.winnerUid, null);
  assert.deepEqual(result.scores, {[A]: 1, [B]: 1});
  assert.equal(result.tiles[A].includes(1), false);
  assert.equal(result.tiles[B].includes(1), false);
  assert.equal(result.nextFirstUid, B);
});

test("이미 쓴 타일, 없는 타일, 잘못된 라운드는 거절", () => {
  const tiles = {[A]: [0, 2], [B]: [1, 3]};
  const base = {round: 10, firstUid: A, secondUid: B, scores: {}, tiles};
  assertRuleError(() => resolveElevenRound({...base, values: {[A]: 4, [B]: 1}}), "tileNotOwned");
  assertRuleError(() => resolveElevenRound({...base, values: {[A]: 10, [B]: 1}}), "invalidTile");
  assertRuleError(() => resolveElevenRound({...base, round: 0, values: {[A]: 0, [B]: 1}}), "invalidRound");
  assertRuleError(() => resolveElevenRound({...base, round: 12, values: {[A]: 0, [B]: 1}}), "invalidRound");
  assertRuleError(() => resolveElevenRound({...base, secondUid: A, values: {[A]: 0}}), "invalidPlayers");
  assertRuleError(() => removeElevenTile([1, 2], 3), "tileNotOwned");
  // 원본 배열은 바뀌지 않는다.
  assert.deepEqual(tiles, {[A]: [0, 2], [B]: [1, 3]});
});

test("조기 종료: 점수 차 > 남은 라운드일 때만", () => {
  // 9라운드 후 남은 2. 차이 3 → 종료.
  assert.deepEqual(decideElevenAfterRound({[A]: 5, [B]: 2}, 9, A, B), {
    kind: "finish", winnerUid: A, detail: "earlyEnd", remainingRounds: 2, gap: 3,
  });
  // 차이 = 남은 라운드 → 동점 가능, 계속.
  assert.deepEqual(decideElevenAfterRound({[A]: 4, [B]: 2}, 9, A, B), {kind: "continue", nextRound: 10});
  // 뒤진 쪽이 선공이어도 앞선 사람이 승자(6라운드 후 남은 5, 차이 6).
  assert.equal(decideElevenAfterRound({[A]: 0, [B]: 6}, 6, A, B).winnerUid, B);
  // 5라운드 후 남은 6, 차이 6 → 아직 동점 가능.
  assert.equal(decideElevenAfterRound({[A]: 0, [B]: 6}, 5, A, B).kind, "continue");
  // 가장 이른 조기 종료: 6라운드 6:0 (남은 5).
  assert.equal(decideElevenAfterRound({[A]: 6, [B]: 0}, 6, B, A).detail, "earlyEnd");
  assert.equal(decideElevenAfterRound({[A]: 5, [B]: 0}, 5, A, B).kind, "continue");
});

test("모든 점수 조합에서 조기 종료 조건이 정확하다", () => {
  for (let completed = 1; completed <= ELEVEN_MAX_ROUNDS; completed += 1) {
    for (let a = 0; a <= completed; a += 1) {
      for (let b = 0; a + b <= completed; b += 1) {
        const decision = decideElevenAfterRound({[A]: a, [B]: b}, completed, A, B);
        const remaining = ELEVEN_MAX_ROUNDS - completed;
        const gap = Math.abs(a - b);
        if (gap > remaining) {
          assert.equal(decision.kind, "finish");
          assert.equal(decision.winnerUid, a > b ? A : B);
          assert.equal(decision.detail, remaining > 0 ? "earlyEnd" : "allRounds");
        } else if (remaining > 0) {
          assert.deepEqual(decision, {kind: "continue", nextRound: completed + 1});
        } else {
          assert.deepEqual(decision, {kind: "finalTie", order: [A, B]});
        }
      }
    }
  }
});

test("11라운드 동점이면 직전 선공 → 후공 순서로 최종 뽑기", () => {
  assert.deepEqual(decideElevenAfterRound({[A]: 5, [B]: 5}, 11, B, A), {kind: "finalTie", order: [B, A]});
  assert.deepEqual(decideElevenAfterRound({[A]: 6, [B]: 5}, 11, B, A), {
    kind: "finish", winnerUid: A, detail: "allRounds", remainingRounds: 0, gap: 1,
  });
  assertRuleError(() => decideElevenAfterRound({}, 0, A, B), "invalidRound");
  assertRuleError(() => decideElevenAfterRound({}, 12, A, B), "invalidRound");
});

test("시간 초과는 남은 타일에서만 무작위로 고른다", () => {
  assert.equal(pickElevenTimeoutTile([3, 7, 11], sequence(2)), 11);
  assert.equal(pickElevenTimeoutTile([3, 7, 11], sequence(0)), 3);
  assert.equal(pickElevenTimeoutTile([4], sequence(0)), 4);
  assertRuleError(() => pickElevenTimeoutTile([], sequence(0)), "noTilesLeft");
  for (let i = 0; i < 200; i += 1) {
    assert.ok([1, 5, 9].includes(pickElevenTimeoutTile([1, 5, 9])));
  }
});

test("섞기는 같은 값의 순열이고 원본을 바꾸지 않는다", () => {
  const original = [...ELEVEN_TILES];
  const shuffled = shuffleEleven(original, sequence(0));
  assert.deepEqual([...shuffled].sort((a, b) => a - b), original);
  assert.deepEqual(original, [...ELEVEN_TILES]);
  assert.notDeepEqual(shuffled, original);
});

test("첫 선공 뽑기 순서는 무작위", () => {
  assert.deepEqual(randomElevenDrawOrder([A, B], sequence(0)), [A, B]);
  assert.deepEqual(randomElevenDrawOrder([A, B], sequence(1)), [B, A]);
  assertRuleError(() => randomElevenDrawOrder([A, A], sequence(0)), "invalidPlayers");
});

test("공용 뽑기: 순서대로, 서로 다른 위치, 둘 다 뽑은 뒤 공개", () => {
  let draw = createElevenDraw("firstPlayer", [B, A], sequence(0));
  assert.equal(draw.slots.length, 9);
  assert.deepEqual([...draw.slots].sort((a, b) => a - b), [...ELEVEN_DRAW_TILES]);
  assert.equal(nextElevenDrawPicker(draw), B);
  assertRuleError(() => revealElevenDraw(draw), "drawIncomplete");
  assertRuleError(() => pickElevenDrawSlot(draw, A, 0), "notYourPick");
  assertRuleError(() => pickElevenDrawSlot(draw, B, 9), "invalidSlot");
  assertRuleError(() => pickElevenDrawSlot(draw, B, -1), "invalidSlot");

  const before = draw;
  draw = pickElevenDrawSlot(draw, B, 4);
  assert.deepEqual(before.picks, {}, "원본 뽑기는 바뀌지 않는다");
  assert.equal(nextElevenDrawPicker(draw), A);
  assertRuleError(() => revealElevenDraw(draw), "drawIncomplete");
  assertRuleError(() => pickElevenDrawSlot(draw, A, 4), "slotTaken");

  draw = pickElevenDrawSlot(draw, A, 7);
  assert.equal(nextElevenDrawPicker(draw), null);
  assertRuleError(() => pickElevenDrawSlot(draw, A, 1), "drawComplete");

  const reveal = revealElevenDraw(draw);
  assert.deepEqual(reveal.values, {[B]: draw.slots[4], [A]: draw.slots[7]});
  assert.equal(reveal.winnerUid, draw.slots[4] > draw.slots[7] ? B : A);
});

test("공용 뽑기는 모든 위치 조합에서 큰 숫자가 이긴다", () => {
  const draw = {purpose: "finalTie", order: [A, B], slots: [...ELEVEN_DRAW_TILES], picks: {}};
  for (let x = 0; x < 9; x += 1) {
    for (let y = 0; y < 9; y += 1) {
      if (x === y) continue;
      const done = pickElevenDrawSlot(pickElevenDrawSlot(draw, A, x), B, y);
      const {values, winnerUid} = revealElevenDraw(done);
      assert.notEqual(values[A], values[B]);
      assert.equal(winnerUid, values[A] > values[B] ? A : B);
    }
  }
});

test("한 판 시뮬레이션: 11라운드면 타일이 모두 소모되고 점수+동점 = 라운드 수", () => {
  for (let seed = 0; seed < 50; seed += 1) {
    let tiles = freshTiles();
    let scores = {[A]: 0, [B]: 0};
    let first = seed % 2 === 0 ? A : B;
    let ties = 0;
    let rounds = 0;
    let decision = {kind: "continue", nextRound: 1};
    let rng = seed;
    const randomInt = (max) => {
      rng = (rng * 1103515245 + 12345) % 2147483648;
      return rng % max;
    };
    while (decision.kind === "continue") {
      const second = first === A ? B : A;
      const values = {
        [first]: pickElevenTimeoutTile(tiles[first], randomInt),
        [second]: pickElevenTimeoutTile(tiles[second], randomInt),
      };
      const result = resolveElevenRound({round: decision.nextRound, firstUid: first, secondUid: second, values, scores, tiles});
      rounds += 1;
      if (result.winnerUid === null) ties += 1;
      tiles = result.tiles;
      scores = result.scores;
      decision = decideElevenAfterRound(scores, rounds, first, second);
      first = result.nextFirstUid;
    }
    assert.equal(scores[A] + scores[B] + ties, rounds);
    assert.equal(tiles[A].length, 11 - rounds);
    assert.equal(tiles[B].length, 11 - rounds);
    if (decision.kind === "finalTie") {
      assert.equal(rounds, 11);
      assert.equal(scores[A], scores[B]);
    }
    if (decision.kind === "finish" && decision.detail === "earlyEnd") {
      assert.ok(rounds < 11);
      assert.ok(Math.abs(scores[A] - scores[B]) > 11 - rounds);
    }
  }
});
