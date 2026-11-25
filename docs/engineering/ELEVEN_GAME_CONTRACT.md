# ELEVEN 게임 계약

상태: **S1 계약 승인 기록 확인 · 2026-11-23.** 노션 '개발 계획·검증·출시' 5절의 승인 기록을 기준으로 S3를 진행한다. 구현·배포 완료 기록이 아니다.
작업 관리: [ELEVEN-01](../planning/tasks/ELEVEN-01.md#eleven-01)

이 문서는 2인 숫자 추리 게임 ELEVEN(기획명 '흑과 백 리버스')의 서버·앱 계약이다.
[새 게임 제작·연결 가이드](NEW_GAME_GUIDE.md) 2.1의 항목 순서를 따른다. 제품 결정의
원본은 노션 ELEVEN 페이지와 하위 '게임 룰 및 정책', '정보 공개 정책', '기기별 UX·UI',
'개발 계획·검증·출시'이고, 화면 참고는 Claude 디자인 캔버스의 T01–T13, P01–P11이다.
이 문서와 노션이 다르면 추측하지 않고 차이를 보고한다.

## 1. 기본 정보

| 항목 | 값 | 근거 |
| --- | --- | --- |
| gameId | `eleven` (영구 ID, RTDB `gameType`·함수 접두사·패키지 이름 공통) | 노션 2026-11-23 사용자 결정 |
| 표시 이름 | ko `일레븐`, en·zh-Hans·zh-Hant `ELEVEN` | 노션 루트·룰 페이지, zh는 2026-11-25 하준 결정 |
| 인원 | 정확히 2명. 다른 인원은 시작 거절 | 룰 1. 기본 정보 |
| 함수 접두사 | `game_eleven_` | 가이드 3.2, 기존 명명 규칙 |
| 패키지 | `packages/game_eleven` (S4) | 가이드 2.2 |

## 2. 규칙 요약 (서버 순수 규칙의 기준)

- 각자 숫자 타일 11개: 0–9, 11. 10은 없다. 각 타일은 한 번만 쓴다.
- 색: **흑** = 0, 2, 4, 6, 8, 11 (6개) / **백** = 1, 3, 5, 7, 9 (5개).
- 판정(선공 값 a, 후공 값 b):
  1. a = b → 동점. 둘 다 0점, 두 타일 모두 소모.
  2. a + b = 20 → 11을 낸 사람 승. 10이 없으므로 이 경우는 9와 11뿐이다.
  3. a + b < 10 → 큰 숫자 승.
  4. a + b ≥ 10 → 작은 숫자 승.
- 라운드 승자 +1점. 다음 라운드 선공은 직전 승자, 동점이면 직전 선공 유지.
- 최대 11라운드. 라운드 결과 반영 후 `점수 차 > 남은 라운드 수`이면 조기 종료하고 앞선
  사람이 승리. 같으면 계속한다.
- 11라운드 뒤 누적 동점이면 별도 공용 타일 뽑기로 승자를 정한다. 순서는 직전(11라운드)
  선공 → 후공.
- 첫 선공도 별도 공용 타일 뽑기로 정한다. 뽑는 순서는 무작위. 큰 숫자가 1라운드 선공.
- 공용 뽑기 묶음은 1–9 9장이고 개인 손패(0–9, 11 11장)와 별개다(2026-11-25 사용자 승인,
  시안 A 반영). 첫 선공 뽑기와 최종 동점 뽑기 모두 같은 묶음을 쓴다. 두 사람은 서로 다른
  위치(slotIndex 0–8)를 고르며, 둘 다 고른 뒤 한 번에 공개한다. 숫자가 모두 달라 뽑기에는
  동점이 없다.

## 3. 상태도

`status`는 `playing` | `finished`. 세부 `phase`는 다음과 같다.

```text
start_game
  └─▶ drawPick(firstPlayer) ─pick×2─▶ drawReveal(firstPlayer)
                                         └─complete_phase─▶ firstSubmit(R1)

firstSubmit(Rn) ─선공 submit / timeout─▶ secondSubmit(Rn)
secondSubmit(Rn) ─후공 submit / timeout─▶ roundResult(Rn)

roundResult(Rn) ─complete_phase─▶
    ├ 조기 종료 조건            ─▶ finished (finishDetail: earlyEnd)
    ├ n < 11                    ─▶ firstSubmit(Rn+1)
    ├ n = 11, 점수 다름          ─▶ finished (finishDetail: allRounds)
    └ n = 11, 점수 같음          ─▶ drawPick(finalTie)

drawPick(finalTie) ─pick×2─▶ drawReveal(finalTie)
                              └─complete_phase─▶ finished (finishDetail: tieDraw)

어느 phase에서든: 인원 부족(제외·퇴장) ─▶ finished (finishReason: insufficientPlayers)
                  태블릿 수동 종료       ─▶ finished (finishReason: manual)
```

- 정상 승부 종료는 `finishReason: "winner"`와 `winnerUid`를 함께 둔다. 세부 경로는
  `finishDetail`에만 적는다. 그래서 공용 `isNaturalGameResult` 판정을 그대로 쓴다.
- 승부 없이 끝나면 `winnerUid: null`과 `finishReason`을 남긴다(기존 계약).
  2인 게임에서 한 명이 나가면 이 경로로 **승자 없이 종료**한다(노션 D13, 2026-11-23 결정).
- 새 라운드 안내(0.8초)는 별도 phase가 아니다. 서버가 `firstSubmit(Rn+1)`에 들어가며
  선공 deadline을 바로 시작하고, 기기는 라운드 번호 변화를 보고 안내를 겹쳐 보여 준다.
  연출이 deadline을 늦추지 않는다(노션 T09).

## 4. 데이터 경계

### 4.1 `game/public` — 참가자와 태블릿이 읽음

| 필드 | 형식 | 설명 |
| --- | --- | --- |
| `gameType` | `"eleven"` | |
| `status`, `phase`, `revision`, `round` | | `round`는 1–11. 뽑기 phase에서는 직전 값 유지 |
| `players` | `{uid: {uid, nickname, characterId, seatIndex}}` | 2명 |
| `scores` | `{uid: number}` | 누적 점수 |
| `firstUid`, `secondUid` | `string \| null` | 현재 라운드 선공·후공 |
| `turnUid`, `turnDeadlineAt` | `string \| null`, `number \| null` | 제출 phase에서만 값이 있다. 서버 시각 기준 |
| `currentRound` | `{round, firstColor, secondColor, autoSubmitted: {uid: true}}` | 색은 제출 즉시 공개. 숫자 없음 |
| `draw` | `{purpose, order: [uid, uid], picks: {uid: slotIndex}, nextPickerUid, revealed?: {uid: number}, winnerUid?}` | 공용 뽑기. `revealed`는 두 번째 선택이 반영되는 같은 전이에서만 쓴다 |
| `winnerUid`, `finishReason`, `finishDetail` | | `finishDetail`: `earlyEnd` \| `allRounds` \| `tieDraw` |
| `earlyEnd` | `{remainingRounds, leaderUid, gap}` | T10 이유 안내용. 숫자 없음 |
| `lastRoundResult` | `{round, winnerUid: string \| null}` 또는 없음 | 직전 라운드 결과(2026-11-25 사용자 승인). P08 표시용. 라운드가 판정되는 전이(`roundResult` 진입)에서 쓰고 다음 판정 때 덮어쓴다. 첫 판정 전에는 없다. `winnerUid`가 없거나 null이면 동점(RTDB는 null을 저장하지 않으므로 클라이언트는 키 없음을 동점으로 읽는다). 숫자·합·판정 유형은 넣지 않는다 |
| `startedAt`, `updatedAt`, `finishedAt` | | 서버 시각 |
| 공통 복구 필드 | `interruption`, `gameInstanceId`, `phaseSeq`, `turnSeq`, `dataSeq`, `resumeEpoch`, `recovery` | 러시안 룰렛과 같은 공통 계약을 따른다(S3에서 확인) |

### 4.2 `game/private/{uid}` — 본인만 읽음

| 필드 | 설명 |
| --- | --- |
| `tiles` | 남은 타일 값 배열. 사용한 타일은 전체 집합 − `tiles`로 기기가 계산해 흐리게 표시 |
| `submission` | `{round, value, auto}` 현재 라운드에 본인이 낸 타일. 다음 라운드 시작 때 지운다 |

휴대폰에 지난 라운드 기록과 이전 제출 숫자를 주지 않는다(정보 공개 정책). 선공 색처럼
공개된 값은 `public`에서 읽는다.
예외로 직전 1라운드의 승자 또는 동점만 `public.lastRoundResult`로 공개한다(2026-11-25 승인).
전체 기록은 계속 `controller/history`에만 둔다.

### 4.3 `game/controller` — 태블릿 controller만 읽음

`history`에는 라운드 번호·선공·양쪽 제출 색·승자 또는 동점만 저장한다. 본 게임의
실제 숫자·합·판정 유형은 포함하지 않는다. RTDB rules에서 방의 `controllerUid`와
일치하는 인증 사용자만 읽을 수 있다. 휴대폰은 이 경로를 구독하지 못한다.

### 4.4 `game/server` — 클라이언트 접근 불가

| 필드 | 설명 |
| --- | --- |
| `draw` | `{purpose, slots: number[9]}` 공용 뽑기 배치(1–9를 섞은 값). 공개 전 숫자는 여기에만 둔다 |
| `submissions` | `{uid: number}` 현재 라운드 실제 숫자 |
| `interruption` | 공통 복구 |

명령 멱등 기록은 `game/server`가 아닌 기존 공통 방 경로 `sessionOperations`에
`commandId`별 결과로 저장한다. 이 경로도 클라이언트 읽기가 금지된다.

**누출 금지 값:** 본 게임 실제 숫자, 두 숫자의 합, 판정 유형(`sum20`·`under10`·`atLeast10`),
공개 전 공용 뽑기 배치. 이 값은 `server` 또는 본인 `private`에만 있고 응답·로그에도 쓰지
않는다.

## 5. 명령

공통 순서는 가이드 3.2를 따른다: Auth·역할 → room instance·controller session 또는
membership → `selectedGame`·status·phase·round·revision → payload 범위·소유권 →
transaction 안에서 재검사 후 한 번에 갱신 → `commandId` 멱등 → 서버 시각 기록.

| 명령 | 호출자 | 입력 | 가능한 phase | 거절 조건 |
| --- | --- | --- | --- | --- |
| `game_eleven_start_game` | 태블릿(controller) | roomCode | 방 대기·재시작 | 참가자 ≠ 2명, 다른 게임 선택됨 |
| `game_eleven_pick_draw_tile` | 태블릿 | roomCode, slotIndex(0–8), pickerUid, commandId | `drawPick` | pickerUid ≠ `draw.nextPickerUid`, 이미 고른 위치, 범위 밖 |
| `game_eleven_submit_tile` | 휴대폰(본인) | roomCode, round, value, commandId | `firstSubmit`(선공만), `secondSubmit`(후공만) | 차례 아님, round 불일치, 남은 타일 아님, deadline 경과 |
| `game_eleven_timeout_turn` | 태블릿, 두 휴대폰 | roomCode, round, phase | `firstSubmit`, `secondSubmit` | 마감 전 → `success:false`. phase·round가 이미 바뀜 → `ignored:true` |
| `game_eleven_complete_phase` | 태블릿 | roomCode, revision | `drawReveal`, `roundResult` | revision 불일치 → `ignored:true` |
| `game_eleven_end_game` | 태블릿 | roomCode | playing | 기존 수동 종료 계약 |
| `game_eleven_leave_game` | 휴대폰 | roomCode | 모든 phase | 공통 `leaveSessionRequest` |

- **태블릿 뽑기의 신원:** 태블릿은 기기 하나라 누가 눌렀는지 서버가 확인할 수 없다.
  서버는 선택 순서(`nextPickerUid`)와 중복 위치만 검증한다(노션 T02, 2026-11-23 승인).
  `pickerUid`는 태블릿 화면이 안내한 차례를 서버 기대값과 맞추는 용도다.
- **후공 미리 선택:** 휴대폰 로컬 초안이다. 서버는 `firstSubmit`에서 후공의 제출을
  거절한다.
- **시간 초과:** 라이어스 포커의 force timeout 방식, 이름은 러시안 룰렛·파이널콜과 같은
  `timeout_turn`. 태블릿이 마감 약 1초 뒤 호출하고 두 휴대폰도 예비로 호출한다. 서버는
  `now ≥ turnDeadlineAt`과 현재 phase·round를 확인해 첫 요청만 반영하고, 남은 타일 중
  무작위 하나를 제출한다. 미리 고른 타일은 쓰지 않는다. 서버 스케줄러는 추가하지 않는다.
  모든 기기가 꺼지면 기존 중단·복구 흐름을 따르고 복귀한 기기가 다시 호출한다
  (노션 2026-11-23 승인).
- **다음 단계 진행:** 태블릿이 결과(2초)·공개(0.6초) 연출을 끝낸 뒤 `complete_phase`를
  호출한다. 휴대폰은 진행에 관여하지 않는다. 연출 시간은 클라이언트 상수이며 서버
  계약이 아니다.
- **응답:** 성공 여부, 새 revision, 무시 사유만 돌려준다. 실제 숫자는 본인 제출 응답의
  본인 값 외에는 돌려주지 않는다.

## 6. 시간

| 항목 | 값 |
| --- | --- |
| 선공·후공 제출 제한 | 각 60,000ms. 서버 시각 |
| 후공 deadline 시작 | 선공 제출(또는 선공 시간 초과)이 반영된 같은 transaction의 시각 |
| 뽑기·결과·공개 | 서버 제한 없음 |
| 시험용 연출(클라이언트 상수) | 제출 0.3초, 결과 2초, 새 라운드 0.8초, 뽑기 공개 0.6초, 최종 승리 1.5초 |

## 7. 화면 대응

| 화면 | phase / 조건 |
| --- | --- |
| T01 첫 선공 뽑기 시작 | `drawPick`, purpose `firstPlayer`, picks 0개 |
| T02 A 선택 후 B 차례 | `drawPick`, picks 1개 |
| T03 뽑기 결과 | `drawReveal`, purpose `firstPlayer` |
| T04 선공이 고르는 중 | `firstSubmit` |
| T05 선공 제출 후 후공 차례 | `secondSubmit` |
| T06 시간 초과 자동 제출 | `secondSubmit` 또는 `roundResult`에서 `currentRound.autoSubmitted` 있음 |
| T07 라운드 승리 결과 | `roundResult`, controller/history 마지막 `winnerUid` 있음 |
| T08 라운드 동점 결과 | `roundResult`, controller/history 마지막 `winnerUid: null` |
| T09 새 라운드 안내 | `firstSubmit`에서 `round`가 바뀐 직후(클라이언트 연출) |
| T10 조기 종료 | `finished`, `finishDetail: earlyEnd` |
| T11 최종 동점 뽑기 | `drawPick`, purpose `finalTie` |
| T12 동점 뽑기 결과 | `drawReveal`, purpose `finalTie` |
| T13 최종 결과 | `finished` (모든 finishDetail) |
| P01 뽑기 중 대기 | `drawPick`, `drawReveal` |
| P02 선공 선택 중 | `firstSubmit`, 본인 = 선공 |
| P03 후공 미리 선택 | `firstSubmit`, 본인 = 후공 |
| P04 선공 제출 완료 | `secondSubmit`, 본인 = 선공 |
| P05 후공 제출 가능 | `secondSubmit`, 본인 = 후공 |
| P06 시간 초과 자동 제출 | 본인 `submission.auto = true` |
| P07 후공 제출 완료 | 본인 제출 응답 성공 ~ `roundResult` 수신 전, 또는 `roundResult` 표시 직전 |
| P08 결과·다음 라운드 전환 | `roundResult`, 승패 표시는 `lastRoundResult` |
| P09 마지막 타일 | 제출 phase이고 본인 `tiles` 길이 1 |
| P10 / P11 게임 종료 | `finished`, 본인이 승자 / 아님 |

## 8. 공통 복구 연결 (S3에서 구현·확인)

- `game-interruption/game-adapters.ts`: 2인 게임은 제외 뒤 계속할 수 없으므로 제외 시
  인원 부족 종료로 연결한다.
- `game-interruption/finish-now-resolution.ts`: `eleven` 즉시 종료 등록.
- recovery state의 deadline·turn limit: `turnDeadlineAt` 사용.
- `GameCommandService` 진단용 명령 이름 목록.

## 9. 노션 추적

| 노션 결정 | 이 문서 |
| --- | --- |
| 게임명·gameId `eleven` | 1 |
| 룰(타일·판정·점수·선공·조기 종료·최종 동점 뽑기) | 2, 3 |
| 정보 공개 정책(숫자·합·판정 유형 비공개, 색 즉시 공개, 태블릿만 기록) | 4 |
| 휴대폰 제출 접수 완료만 표시, 요청 중·실패 UI 없음(서버 거절 시 완료 표시 안 함) | 5 응답 |
| 시간 초과 force timeout 방식, 태블릿 진행 | 5, 6 |
| 태블릿 뽑기 신원 미확인, 순서·중복만 검증 | 5 |
| 한 명 퇴장 시 승자 없이 종료 | 3 |
| 결과 단계 카운트다운 없음, 연출 시간 시험값 | 6 |
| 화면 시안 T01–T13, P01–P11 | 7 |
| 공용 뽑기 1–9 9장, `public.lastRoundResult` 추가(2026-11-25 계약 변경 승인) | 2, 4.1, 4.4, 5, 7 |

## 10. 후속 결정

1. ~~zh-Hans·zh-Hant 표시 이름~~ → `ELEVEN`으로 확정(2026-11-25 하준 결정, S7).
2. 종료 후 숫자 다시 보기(Q23)는 현재 범위가 아니므로 `server.roundLog`는 저장하지 않는다.
