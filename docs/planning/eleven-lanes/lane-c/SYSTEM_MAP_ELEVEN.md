# ELEVEN 시스템 맵 이관 초안

확인일: 2026-11-25 (레인 C 기준 HEAD `02e43e77`). 이 문서는 S6-M에서 `docs/engineering/MOSIGAME_SYSTEM_MAP.html`에 옮길 초안이다. 레인 A/B 병합 결과에 맞춰 화면 파일과 ID를 재확인한다.

## 진입과 화면 흐름

`lib/games/game_registry.dart`의 `ElevenGame` → `packages/game_eleven/lib/game_eleven.dart` → `phone/phone_board.dart` / `tablet/tablet_board.dart`. 공통 세션은 `shared/providers/session_provider.dart`, `game_controller.dart`가 관리하고, `shared/services/{command,query,public_state_mapper,private_state_mapper,history_mapper}.dart`가 callable·RTDB를 화면 상태로 변환한다.

| 서버 단계 | 태블릿 | 휴대폰 | 진행 명령 |
| --- | --- | --- | --- |
| `drawPick(firstPlayer)` | T01→T02 | 뽑기 데이터 전 P01, 내 차례 G1, 상대가 먼저 G2, 뽑은 뒤 대기 G3 | `pick_draw_tile` 두 번 |
| `drawReveal(firstPlayer)` | T03 | 내가 선공 G4 / 상대가 선공 G5 | `complete_phase` |
| `firstSubmit` | T04, 다음 라운드 직후 T09 | 선공 P02/P09, 후공 P03 | `submit_tile` 또는 `timeout_turn` |
| `secondSubmit` | T05, 시간 초과 T06 | 선공 P04, 후공 P05/P07, 자동 제출 P06 | `submit_tile` 또는 `timeout_turn` |
| `roundResult` | 승리 T07/동점 T08 | 결과 공개 전 G6 → 공개 후 P08 | `complete_phase` |
| 조기 종료 | T10 → T13 | G7 → 승자 P10 / 패자 P11 | 서버가 `earlyEnd` 결정 |
| `drawPick(finalTie)`→`drawReveal(finalTie)` | T11→T12→T13-B | 뽑는 동안 G8 → 공개 직후 승자 P10 / 패자 P11 | `pick_draw_tile` 두 번→`complete_phase` |
| `finished` | T13(일반·조기 종료), T13-B(최종 동점 뽑기) | P10/P11 또는 상위 방 복귀 | 다시하기 `start_game(restart)`·수동 `end_game` |

화면 선택은 `phone/providers/game_stage.dart`의 `resolveElevenPhoneScreen`, `tablet/providers/game_stage.dart`의 `resolveElevenTabletScreen`을 따른다. G1–G8·P01–P11 전이는 `packages/game_eleven/test/phone/screen_test.dart`가 확인한다. 실제 위젯은 각 `phone/`, `tablet/`에 있고 레인 A/B 변경 뒤 이관 시 경로를 갱신한다. 연출은 클라이언트가 담당하며 서버 deadline은 즉시 시작한다.

## Functions와 공통 연결

`functions/src/eleven/callables.ts`가 `game_eleven_start_game`, `pick_draw_tile`, `submit_tile`, `timeout_turn`, `complete_phase`, `end_game`, `leave_game`을 내보낸다. `game.ts`가 상태 전이, `rules.ts`가 순수 규칙·뽑기, `types.ts`가 상태 형식을 정의한다. `functions/src/index.ts`가 callable을 export한다. 방 선택·자리 배치는 `room/realtime-room-lifecycle.ts`와 `room/room-seating-policy.ts`, 멱등·인스턴스 검사는 `game-interruption/game-command-transaction.ts`, 중단·제외·인원 부족 종료는 `game-interruption/game-adapters.ts`와 `finish-now-resolution.ts`가 연결한다.

## RTDB 경계

| 경로 `rooms/{roomCode}/game/…` | 읽는 주체 | 내용 |
| --- | --- | --- |
| `public` | 방 참가자·태블릿 | phase, 점수, 색, 선후공, deadline, 공개 후 공용 뽑기 값, 직전 결과. 본 게임 숫자·합·판정 유형·미공개 배치 없음 |
| `private/{uid}` | 해당 uid | 남은 손패와 본인 제출 값·자동 제출 여부 |
| `controller` | 방 controller UID | 숫자 없이 색·승자/동점 라운드 기록 |
| `server` | 서버만 | 공용 뽑기 배치, 현재 제출 숫자, 판정 근거·다음 선공, 복구 내부 상태 |

`sessionOperations`는 `game` 밖의 방 공통 경로이며 commandId 결과를 저장하고 클라이언트 읽기를 금지한다. 상위 `game` 읽기는 금지하고 각 자식 규칙으로만 허용한다(`database.rules.json`). `public.lastRoundResult`는 첫 판정 전 없고 다음 판정 때 덮어쓴다. 동점의 `winnerUid: null`은 RTDB 저장 시 키가 없어질 수 있다.
