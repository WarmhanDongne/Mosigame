<a id="eleven-01"></a>
# ELEVEN-01

2인 숫자 추리 게임 ELEVEN(기획명 '흑과 백 리버스') 신규 개발.

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

## 목적과 범위

- 제품 결정 원본: 노션 ELEVEN 페이지와 하위 '게임 룰 및 정책', '정보 공개 정책',
  '기기별 UX·UI', '개발 계획·검증·출시'.
- 화면 참고(2026-11-25 갱신): Claude 디자인 캔버스 'ELEVEN · 화면 디자인'(아티팩트
  6ea11ac6-e281-491d-9726-f891fca89aa7)의 시안 A 느와르 — 태블릿 T01–T13·T13-B, 휴대폰
  P01–P11·G1–G8, 모션 키트 · 시안 A, 느와르 프로토타입 ①~⑧. 보라·흑백 화면과 다른 시안은
  구현 대상이 아니다. 저장소 기준 사본: `docs/design/eleven/`.
- 작업 방식(S5–S7 병렬·Codex 운영) 원본: 노션 'ELEVEN S5–S7 작업 방식 · Claude·Codex 병렬
  운영 · 2026-11-25'. 지시문: `docs/planning/eleven-lanes/`.
- 구현 계약: [ELEVEN 게임 계약](../../engineering/ELEVEN_GAME_CONTRACT.md).
- 단계: 노션 '개발 계획·검증·출시' 5절의 S0–S9. 저장소와 노션 모두 이 작업 ID 하나로
  단계를 기록한다(2026-11-23 노션의 가칭 BWR-S0~S9 표기를 ELEVEN-01로 정리).
- 인계: [ELEVEN 인계](../ELEVEN_HANDOFF.md).

## 승인 경계

- 데이터 계약·state machine([계약](../../engineering/ELEVEN_GAME_CONTRACT.md))은 사용자
  승인 대상이다. 노션 '개발 계획·검증·출시' S1에 2026-11-23 승인 완료가 기록됐고,
  이번 사용자의 S3 진행 요청에 따라 해당 범위의 서버 구현을 진행했다.
- TEST·운영 배포, 카탈로그 등록·공개, 새 dependency는 각각 별도 승인.
- 공통 복구 코드(`game-adapters.ts`, `finish-now-resolution.ts`) 연결은 S3 범위다.

## 완료 조건

- S0–S9 각 단계의 노션 완료 기준.
- 최종: 관련 테스트와 `validate --full` PASS, D01–D17 실기기 통과, 결함 기준 0건.

## 기록

<a id="s1-s2-20261123"></a>
### 2026-11-23 S1 계약 초안·S2 순수 규칙

- 사용자 요청으로 S1과 S2를 이어서 진행했다. S0의 브랜치 정리는 하지 않았다:
  현재 브랜치 `feature/black-and-white-ui`(HEAD `cb13e579`)에 사용자 미커밋 변경
  (`ios/*`, `pubspec.yaml`, 목업 HTML)이 있어 그대로 보존하고, 새 파일만 추가했다.
- S1: [계약 초안](../../engineering/ELEVEN_GAME_CONTRACT.md) 작성. 기존 러시안 룰렛·파이널콜
  명명에 맞춰 시간 초과는 `game_eleven_timeout_turn`, 다음 단계는
  `game_eleven_complete_phase`로 정했다(노션의 'force_timeout 방식'과 동작은 같다).
  정상 승부 종료는 `finishReason: "winner"` + `finishDetail`로 두어 공용
  `isNaturalGameResult`를 그대로 쓴다.
- S2: `functions/src/eleven/rules.ts` 순수 규칙(판정·색·타일 소모·다음 선공·조기 종료·
  최종 동점 순서·시간 초과 무작위·공용 뽑기)과 `functions/test/eleven-rules.test.mjs`
  17개 테스트. 무작위는 `gameRandomInt` 기본값에 테스트용 주입을 허용한다.
- 검증(작업 폴더 `functions/`):
  - `npx tsc` exit 0
  - `node --test test/eleven-rules.test.mjs` 17/17 PASS, exit 0
  - `node --test test/*.test.mjs` 625/625 PASS, exit 0
  - `npm run lint` exit 0
  - 실행 전후 `git status` 비교: 빌드로 인한 tracked/unignored 변경 없음
  - `dart run :mosigame validate --full`은 실행하지 않았다(사용자 승인 대기).
- 테스트 작성 중 기대값 하나를 잘못 적었다(5라운드 후 0:6은 남은 6라운드라 계속이 맞다).
  구현이 아닌 테스트 기대값을 고쳤고, 경계 사례를 별도 단언으로 추가했다.
- 미정: 계약 승인, zh 표시 이름, `server.roundLog` 보관 여부.

<a id="s3-server-20261123"></a>
### 2026-11-23 S3 서버 상태 전이·명령 후보

- [Notion S3 실행 계획](https://app.notion.com/p/42109716f87e813e8792e3cb4b41feb1)을
  '개발 계획·검증·출시' 아래에 먼저 만들었다. Notion S1은 계약 승인 완료·지난 라운드
  기록의 `game/controller/history` 분리를 명시하므로 로컬 초안의 `public/history`
  설명을 바로잡았다. 종료 후 실제 숫자 기록(Q23)은 현재 범위 밖이라 보관하지 않는다.
- `functions/src/eleven/`의 상태·명령·타입을 추가하고, `index.ts` export·2인 자리 배치·
  공통 중단 adapter·인원 부족 즉시 종료·60초 복구 타이머를 연결했다. RTDB rules에는
  controller UID만 읽는 `game/controller` 경로를 추가했다. game 경로 클라이언트 쓰기는
  계속 금지한다. 명령 재시도는 기존 공통 `sessionOperations` 멱등 처리를 사용한다.
- 단위 테스트는 11라운드 동점→최종 뽑기, 제출·타임아웃, 이중 처리, 비밀 기록 분리,
  인원 부족 종료를 확인한다. RTDB 에뮬레이터는 demo project에서 controller 기록 읽기,
  참가자·외부 사용자 거절, private/server 차단과 직접 쓰기 거절을 확인했다.
  실제 callable도 태블릿·휴대폰의 동시 시간 초과 중 한 번만 반영하고, 이전 접속 ID로
  같은 commandId를 재시도해도 결과를 재생하며, 외부 참가자의 제출을 거절하는지 확인했다.
- 검증(모두 exit 0): `functions/`에서 `npm run build`, `npm run lint`,
  `node --test test/*.test.mjs` 634/634 PASS;
  `dart run :mosigame test session` 5단계 PASS(Flutter 264/Functions 217);
  `dart run :mosigame test auth` 5단계 PASS(Functions 38 포함);
  저장소 루트에서 `PATH='/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin':$PATH functions/node_modules/.bin/firebase emulators:exec --only database --project demo-eleven --config firebase.test.json 'node functions/emulator-tests/eleven-rules.mjs'` PASS.
- 에뮬레이터의 최초 시도는 Java PATH 부족(exit 2), 다음은 sandbox localhost 포트 거부
  (exit 2)였다. 동시 시간 초과 검사 첫 시도는 RTDB가 빈 `server` 객체를 저장하지 않아
  `TypeError`로 FAIL(exit 1)이었고, 명령 시 누락된 빈 슬롯을 복원하도록 수정한 뒤
  최종 PASS했다. Android Studio 포함 Java를 PATH에 넣고 로컬 포트 실행을 승인받아
  수행했다. 생성된 untracked `database-debug.log`는 제거했고, 기존 iOS·pubspec·
  목업 사용자 변경은 보존했다.
- `dart run :mosigame validate --full`은 2026-11-23 사용자가 건너뛰도록 지시해
  실행하지 않았다. 따라서 최종 Definition of Done은 충족하지 않은 검증 대기 후보다.
  TEST/운영 배포·카탈로그 접근·S4 앱 구현은 하지 않았다.

<a id="s4-app-skeleton-20261123"></a>
### 2026-11-23 S4 앱 골격

- 요청에 적힌 `claude/HANDOFF_20261123.md`는 저장소에 없어
  [ELEVEN 인계](../ELEVEN_HANDOFF.md)를 기준으로 진행했다. 이 세션의 Notion 연결은 다른
  workspace라 S3 계획 페이지가 404였다. 따라서 Notion S4 완료 기준은 대조하지 못했고,
  범위는 계약 1·4·5·7절과 [새 게임 가이드](../../engineering/NEW_GAME_GUIDE.md) 2.2–2.3으로 잡았다.
- `packages/game_eleven` 추가: `ElevenGame`(gameId `eleven`, 고정 2인, 번들,
  `requiredAssetVersion` 0), 공개·개인·controller 기록 순수 파서, callable 7개 이름과 1:1인
  명령 서비스, `GameSessionController` 상속 컨트롤러(휴대폰 = 공개+본인 private,
  태블릿 = 공개+`game/controller/history`, 태블릿은 private 미구독).
- 휴대폰 단계 P01–P11, 태블릿 단계 T01–T13을 순수 resolver로 번역하고 board에서 실제
  화면을 반환한다. 태블릿: 공용 뽑기 입력, 공개 0.6초·결과 2초 뒤 `complete_phase`,
  마감 1초 뒤 `timeout_turn`(`GameProgressCommand` 재시도), T09 0.8초 겹침 안내(입력·
  deadline 비차단). 휴대폰: 타일 선택·제출, P03 미리 선택 유지, P06·P09 안내, 마감 3초 뒤
  예비 `timeout_turn`. 제출은 요청 중·실패 UI 없이 성공 응답일 때만 완료 표시한다.
  `PhoneGameShell` 미사용 이유는 `phone_board.dart` 머리 주석에 남겼다.
- 앱 연결: 루트 `pubspec.yaml` workspace/dependency 두 줄(사용자 미커밋 version·공백
  변경 보존), `GameRegistry`, `check_package_boundaries.py` 번들 목록, Project CLI
  package test manifest와 그 계약 테스트(7→8), `GameCommandService` 진단 이름 4개.
- 시각 디자인·에셋·소리·상점/상세 미리보기 아트(`MosiGameArt`)·zh 문구 확정은 하지 않았다.
  Firestore 카탈로그, 배포, 실기기 검증도 하지 않았다.
- 검증(모두 exit 0):
  - `packages/game_eleven`: `flutter analyze` No issues, `flutter test` 24/24 PASS
  - 루트: `python3 tool/check_package_boundaries.py` 위반 0건
  - 루트: `flutter analyze lib test tool packages/game_kit/lib` No issues
  - 루트: `flutter test test/eleven_integration_test.dart test/mosigame_cli/package_test_manifest_test.dart` PASS
  - 루트: registry 소비 테스트 5개 파일(lobby·asset prepare·room leave·bundled free·roulette) 48 PASS
  - `dart run :mosigame test session` 5단계 PASS(Functions 217), working-tree mutation 없음
  - `dart run :mosigame validate --full`은 사용자 승인 전이라 실행하지 않았다.

<a id="s4-notion-review-20261123"></a>
### 2026-11-23 S4 Notion 대조·수정

- 내장 브라우저로 Notion '개발 계획·검증·출시', '게임 룰 및 정책', '정보 공개 정책',
  '기기별 UX·UI'를 읽고 코드와 대조했다. 서버(S2·S3) 판정·점수·선공·조기 종료·최종
  뽑기·시간·데이터 경계는 기획과 일치했다.
- S4 앱에서 기획과 달랐던 네 가지를 고쳤다.
  1. 휴대폰 방향: 개발 계획 "휴대폰은 시안의 가로 플레이 화면"(목업 비율 약 2.08:1)에 맞춰
     `phoneOrientation`을 `landscapeOnly`로 바꾸고, 왼쪽 안내·시간 / 오른쪽 손패·제출의
     가로 배치로 바꿨다. 손패는 폭·높이 중 작은 쪽에 맞춘다.
  2. 태블릿 종료 복귀: 승부 없는 종료(퇴장·수동 종료·인원 부족)는 사유 안내 1초 뒤
     `exitGameRoute`로 기존 방에 돌아간다(UX '종료 후', D13). 정상 승부 결과는 유지한다.
  3. 진동: UX 문서상 "휴대폰 진동은 미정"이라 `GameFeedback` 호출을 모두 뺐다.
  4. 문구: S4·Q64대로 번역 키(getter)는 두고 화면 문구는 한국어 임시 표시로 바꿨다.
     en·zh 번역은 S7. 게임 이름만 계약 1절 값 유지.
- 남은 차이(이번에 고치지 않음): S4 완료 기준인 에뮬레이터 한 판 진행 미검증. P08 휴대폰
  '내 승패·점수 변화'는 public에 라운드 승자 필드가 없어 계약 변경 판단 필요. 공통
  `TabletGameMenuOverlay`·연결 띠·태블릿 90° 배치·T07 +1·T09 선후공 강조·P04/P07 본인 숫자
  표시는 S5·S6.
- 검증(모두 exit 0): `packages/game_eleven` analyze 0건, test 25/25 PASS; 경계 검사 위반 0건;
  루트 registry·manifest 테스트 PASS; `dart run :mosigame test session` 5단계 PASS,
  working-tree mutation 없음. `validate --full` 미실행.

<a id="s4-emulator-e2e-20261123"></a>
### 2026-11-23 S4 로컬 에뮬레이터 한 판 검증

- 환경: `node tool/emulator/local.mjs start`(demo-mosigame-e13, 운영 접근 없음), iOS 시뮬레이터
  iPad Pro 11(태블릿)·iPhone 17 2대(휴대폰), `flutter build ios --simulator --debug
  --dart-define=MOSIGAME_BACKEND=local` exit 0. 게스트 계정 2개와 태블릿 게스트 계정을 썼다.
- 사전 조치(저장소 변경 없음): 로컬 Firestore에만 `games/eleven`(enabled·free) 문서를 추가했다.
  `tool/emulator/functions.cjs`가 RTDB 트리거를 5개로 고정 검사하는데 현재 코드는 6개
  (`syncRealtimeRoomJoinPreview`, 2026-11-12 `1135425a` 추가)라 Functions 로드가 실패했다.
  ELEVEN과 무관한 기존 결함이며, 이번에는 ignored `build/e13-runtime/index.cjs`만 6으로
  바꿔 진행했다. tracked 파일 수정은 별도 판단이 필요하다.
- 결과(PASS): 방 생성→2인 참가→ELEVEN 선택→자리 배치→`start_game`→첫 선공 뽑기 2회→
  공개·자동 `complete_phase`→R1 선공 제출·후공 미리 선택·후공 60초 시간 초과(태블릿
  `timeout_turn` 1회만 반영, 무작위 자동 제출)→R2 동점(점수 유지·선공 유지)→R3–R7 승리→
  6:0, 남은 4라운드로 `earlyEnd` 종료. R6 뒤 5:0·남은 5라운드에서는 계속(경계 확인).
  태블릿 T01·T02·T04·T05·T10/T13(조기 종료 이유·기록 색만), 휴대폰 P01·P02·P03·P04·P05·P08·
  P10·P11을 화면으로 확인했다. 휴대폰은 가로로 표시됐다. 다시 하기(`restart`)도 새 판을 만들었다.
- 발견·수정(S3 서버 결함): RTDB가 빈 객체를 저장하지 않아 시작 직후 `public.draw.picks`가
  사라지고 첫 뽑기가 "뽑기 순서 또는 타일 위치가 올바르지 않습니다"로 거절됐다.
  `normalizeElevenGame`에서 `draw.picks`와 플레이어 `tiles`를 복원하도록 고치고 RTDB 저장
  모양을 흉내 낸 회귀 테스트 2개를 추가했다. `npm run build`·`npm run lint` exit 0,
  `node --test test/*.test.mjs` 636/636 PASS. 수정 뒤 같은 판에서 뽑기가 정상 진행됐다.
- 미확인·후속:
  - 다시 하기 직후 태블릿 설정의 '게임 종료'가 서버를 호출하지 않았다. 새 게임 인스턴스로
    구독을 다시 묶으며 `run()`의 `commandInFlight`가 해제되지 않았을 가능성이 높다(추정,
    미확인). 라이어스포커는 이 플래그를 직접 해제한다. 그래서 수동 종료·퇴장 시 방 복귀(수정 2)는
    이번에 실기 확인하지 못했다.
  - 결과·공개 연출(T03·T06·T07·T08·T09, P06)은 0.6–2초라 화면 포착 전 지나갔다. 서버 상태로는
    자동 제출·동점·승자 기록을 확인했다.
  - 운영과 무관한 관찰: 첫 `selectRealtimeRoomGame` 콜드 스타트가 6.8초라 시작 버튼이 멈춘 것처럼
    보였다. 휴대폰 제출 버튼의 비활성 상태가 어두운 배경에서 거의 보이지 않는다(S5 디자인).
- 작업 트리: 빌드 전후 `ios/` tracked diff 해시와 swiftpm `Package.resolved` 해시가 같았다.
  새 변경은 `functions/src/eleven/game.ts`, `functions/test/eleven-game.test.mjs`뿐이다.
  `validate --full`은 실행하지 않았다.


<a id="s4-restart-end-followup-20261123"></a>
### 2026-11-23 S4 다시 하기 뒤 종료 후속

- 원인 확인: `GameSessionController.run()`이 명령 중 `retrySession()`으로 구독 세대가
  바뀌면 응답을 무시하면서 `finally`의 `commandInFlight` 해제도 건너뛰었다. 재구독 후에도
  같은 컨트롤러가 살아 있어 뒤이은 `end_game`이 시작 전에 거절될 수 있었다.
- 공통 컨트롤러에서 이전 구독의 응답·오류는 계속 무시하되, 완료된 명령의 진행 잠금은
  컨트롤러가 살아 있는 한 해제하도록 고쳤다. 재구독 전후 요청 순서를 재현한
  `game_session_controller_test.dart` 회귀 테스트를 추가했다. 수정 전에는 플래그가
  `true`로 남아 FAIL(exit 1), 수정 뒤 7/7 PASS(exit 0)였다.
- 로컬 에뮬레이터 도구의 RTDB trigger 수를 실제 export 6개로 맞췄다. smoke의 카탈로그
  기대값 4개도 현재 fixture 8개와 달라, fixture의 ID 목록과 직접 비교하도록 고쳤다.
  `node tool/emulator/local.mjs check`는 첫 실행에서 카탈로그 기대값으로 FAIL(exit 1),
  수정 뒤 1/1 PASS(exit 0), Functions와 RTDB trigger 6개 로드, 포트 해제를 확인했다.
- 관련 검증(모두 exit 0): `dart run :mosigame test session` 5단계 PASS(루트 Flutter
  264개, Functions 217개), `packages/game_kit` `flutter test --no-pub` 155/155,
  `packages/game_eleven` `flutter test --no-pub` 25/25, Functions ELEVEN 규칙·게임
  26/26, 수정 파일 `flutter analyze` 0건, 패키지 경계 위반 0건, `git diff --check` 0건.
  `flutter build ios --simulator --debug --dart-define=MOSIGAME_BACKEND=local`도 exit 0.
  빌드 전후 `ios/` tracked diff와 SwiftPM `Package.resolved` 해시는 동일했다.
- demo 로컬 에뮬레이터와 iPad 1대·iPhone 2대에서 앱을 설치·실행했지만, 화면 조작
  도구가 Simulator 창을 열지 못해 '다시 하기 → 수동 종료'와 휴대폰 퇴장 뒤 방 복귀는
  이번에는 직접 확인하지 못했다. 에뮬레이터와 시뮬레이터 3대는 종료했다.
- `validate --full`은 사용자 지시로 실행하지 않았다. 운영 접근, 배포, 커밋, push 없음.
  다음은 해당 화면 흐름의 수동 재검증이며, 결과를 확인하기 전에는 종료·방 복귀를
  실기 통과로 기록하지 않는다.


<a id="s4-manual-end-leave-20261123"></a>
### 2026-11-23 S4 종료·퇴장 수동 재검증 결과

- 사용자가 로컬 백엔드와 iOS 시뮬레이터에서 앞서 남은 두 테스트 영역
  (`다시 하기 → 게임 종료`, `진행 중 휴대폰 퇴장`) 모두 성공했다고 보고했다.
  이 결과는 사용자 수동 확인이며, 이번 기록에서 서버 상태나 화면 영상을 별도로 재조회하지 않았다.
- 기본 iPhone 17에는 이전 앱 빌드가 설치되어 로컬 방 코드를 찾지 못했다.
  동일한 `MOSIGAME_BACKEND=local` 빌드를 기본 iPhone 17에 설치·실행하고 실행 파일
  해시가 Player 2·Player 3·iPad와 일치함을 확인한 뒤 재검증했다.
- `validate --full`은 사용자 지시대로 미실행이다. 커밋·push·배포도 하지 않았다.

<a id="s5-0a-20261125"></a>
### 2026-11-25 S5 계획 병렬화 · D0 디자인 기준 · S5-0a 계약·서버 (Claude, Cowork)

- 노션 5절 S5·S6·S7을 병렬 레인 구조로 수정하고 작업 방식 하위 페이지를 만들었다.
  하준 확인 지점: ① S5-0 기준 커밋 승인 ② 병합 후 스크린샷 검토 ③ validate --full 승인·결과.
- `lib/gen/*.gen.dart` 기존 수정 원인: 이미 등록된 자산·글꼴을 build_runner가 다시 만든 결과
  (2026-11-25 02:19 KST, 수동 수정 흔적 없음).
- 루트 `pubspec.yaml`에 `StardosStencil`(Bold, weight 700) 등록. 생성은 S5-0b에서.
- D0: 디자인 캔버스 버전 1795541629-f371에서 `docs/design/eleven/` 생성(화면 PNG, screens.md,
  motion.md, motion-frames, data). Playwright 렌더링, 숫자 글꼴은 Stardos 미로드라 PNG의 숫자
  모양은 screens.md 토큰 기준. 시안의 공용 뽑기 카드는 모두 1–9 9장.
- S5-0a 계약 변경(2026-11-25 하준 승인): 공용 뽑기 1–9 9장·slotIndex 0–8,
  `public.lastRoundResult: {round, winnerUid}` 추가. 계약 문서 2·4.1·4.2·4.4·5·7·9절,
  `functions/src/eleven/{rules,game,callables,types}.ts`, 테스트 2개 파일 수정.
  RTDB rules는 game/public 필드 검증이 없어 변경 없음.
- 검증(작업 폴더 `functions/`, Cowork 리눅스 VM에서 맥 node_modules 사용):
  - `npx tsc` exit 0
  - `node --test test/eleven-rules.test.mjs test/eleven-game.test.mjs` 28/28 PASS
  - `node --test test/*.test.mjs` 673/673 PASS, exit 0
  - `npm run lint` exit 0
  - `python3 tool/check_package_boundaries.py` 위반 0건, exit 0
  - validate --full 미실행(승인 대상). 커밋 없음.
- 다음: S5-0b(맥 Claude Code, `docs/planning/eleven-lanes/S5-0B.md`).

<a id="s5-0b-20261125"></a>
### 2026-11-25 S5-0b 앱 공통 기반 (Claude Code, 맥 로컬)

- 지시: `docs/planning/eleven-lanes/S5-0B.md`. 브랜치 `feature/black-and-white-ui`, HEAD
  `5db37ff1`, 기존 미커밋 변경과 `stash@{0}` 보존. 새 Issue·브랜치는 만들지 않았다(지시문이
  이 작업 트리에서 진행하도록 정함). 커밋 없음.
- 생성: 루트에서 `dart run build_runner build --delete-conflicting-outputs` exit 0(옵션 무시
  경고만), `flutter pub get` exit 0. `lib/gen/fonts.gen.dart`에 `FontFamily.stardosStencil`
  생성 확인. 패키지는 앱 `lib/gen`을 import할 수 없어 `ElevenNoirFonts.number = 'StardosStencil'`
  문자열 상수를 쓴다.
- 앱 계약 반영(`packages/game_eleven`):
  - `tiles.dart`: `elevenDrawSlotCount` 11 → 9, `elevenDrawTiles = [1..9]`,
    `elevenIsDrawSlot(0–8)`. 공개된 뽑기 카드 색은 손패 규칙(짝수 흑, 홀수 백, 결정 4).
  - `public_state_mapper.dart`: `ElevenRoundResult`(`lastRoundResult` 키 없음 → null,
    `winnerUid` 없음·null·빈 값 → 동점), `ElevenRoundOutcome{win,lose,tie}`,
    `ElevenDrawView.canPick`(범위 밖·이미 고른 위치 false). 숫자·합·판정 유형 필드 없음.
  - `game_state.dart`: P08용 `currentRoundResult`(현재 라운드 결과만), `roundOutcomeFor(uid)`.
- 공통 디자인 부품(`lib/shared/`). 토큰 폴더 이름은 `noir/`다. 루트 `.gitignore` 59행
  `design/`이 모든 `design` 폴더를 무시해 `lib/shared/design/`은 git에 올라가지 않기 때문이다
  (`.gitignore`는 바꾸지 않음).
  - `noir/noir_tokens.dart`(screens.md 1절 색·반경·테두리·그림자·흐림·간격),
    `noir/noir_text.dart`(글자 단계, 숫자 StardosStencil 700·결정 8, 본문 400 → 500),
    `noir/noir_motion.dart`(MotionKit 1–9·프로토타입 흐름 시점·`Cubic` 곡선),
    `noir/noir_toast_schedule.dart`(T01–T12 토스트 문구·유지·색 시간표).
  - `widgets/noir_tile.dart`(흑/백/뒷면/빈 자리 × 보통·선택·사용함·잠김·흐림·승리·패배·고름,
    손패·패널·안내·슬롯·뽑기 카드·전적칸 크기), `widgets/noir_toast.dart`(8px 떠오름·
    한 번만 재생·동작 줄이기 시 투명도만·재접속 시 최종 상태).
- `timing.dart` 변경(motion.md 기준, 값은 noir_motion.dart에서 계산):
  roundResult 2000 → 3200ms(프로토타입 ④ 새 라운드 전환), drawReveal 600 → 4700ms(①·⑧ 두 번째
  선택 → 판 전환), roundIntro 800 → 1400ms(T09 토스트 0.2+1.0+0.2), submit 300 → 350ms
  (MotionKit 3 딜). finalWin 1500ms 유지. 지금 S4 태블릿 골격의 `complete_phase`·T09 겹침
  시간도 이 값으로 바뀐다.
- 화면 문구: `game_copy.dart`에 `ElevenScreenCopy` 추가(T01–T13·T13-B, P01–P11, G1–G8 원문).
  `test/shared/screen_copy_test.dart`가 screens.md 표와 화면별로 양방향 비교한다.
- 화면 ID: `ElevenPhoneScreen`·`resolveElevenPhoneScreen`(P01–P11·G1–G8),
  `ElevenTabletScreen`·`resolveElevenTabletScreen`(T01–T13·T13-B)을 기존 `game_stage.dart`에
  추가. 시간 연출로 갈리는 화면(G6→P08, G7→P10/P11, T06→T07, T10→T13, T09)은 레인이 넘기는
  `roundResultRevealed`·`gameEndRevealed`·`roundIntroActive`로 고른다. 기존 Stage enum은 유지.
- 디자인 가드 `test/shared/design_guard_test.dart`: `lib/phone/**`, `lib/tablet/**`에서
  `Color(0x`, `Colors.`, `fontFamily:`, `TextStyle(`, 숫자 `Duration(`, `Curves.`, `Cubic(`
  금지. 기존 위반 20줄(S4 골격 `TextStyle(` 18, `Color(0x99000000)` 1, `Duration(200ms)` 1)은
  레인 범위 화면이라 허용 목록(파일·규칙·줄 내용·이유)에 두었고, 사라지면 테스트가 허용 목록
  정리를 요구한다.
- 골든 3개(`test/shared/goldens/`): 휴대폰 손패 상태, 태블릿 슬롯·뽑기 카드·전적칸, 토스트 글자.
  macOS에서만 비교(다른 OS는 group skip). 테스트에는 한글 글꼴이 없어 한글은 상자로 그려진다.
- 검증(작업 폴더 `packages/game_eleven`):
  - `flutter test --no-pub` 111/111 PASS, exit 0
  - 루트 `flutter analyze --no-pub packages/game_eleven` No issues, exit 0
  - `dart format --output=none --set-exit-if-changed packages/game_eleven/lib packages/game_eleven/test` exit 0
  - 루트 `python3 tool/check_package_boundaries.py --max 0` 위반 0건, exit 0
  - 실행 전후 `git status --porcelain` 비교: 이번 작업 파일 외 tracked/unignored 변경 없음
    (pubspec.lock 변화 없음). functions는 손대지 않아 생략. validate --full 미실행(승인 대상).
- 하준 확인 필요:
  1. 본문 글꼴 Noto Sans KR은 앱에 번들되어 있지 않아 기기 글꼴로 대체된다. 번들은 새 asset.
  2. P08은 시안에 “내가 이겼어요! +1”과 선공 안내 “내가 먼저 내요”만 있다. 진 경우·동점·후공
     문구가 없어 키를 만들지 않았다.
  3. 카드 모서리 점은 측정 자료에 첫 점 위치만 있어 나머지 두 점 간격은 기준 PNG를 보고 맞췄다.
  4. `game_theme.dart`의 S4 임시 색(`ElevenColors`)은 가드 규칙 밖이라 남겨 두었다. 게임 목록
     테이블 색(`ElevenColors.table` #111111)도 바꾸지 않았다.

<a id="s5-lanes-setup-20261125"></a>
### 2026-11-25 S5 레인 준비 (Claude Code, 맥 로컬)

- 하준 지시로 S5-0 기준 커밋을 승인받아 진행. 커밋: `6e6a1ede`(S5-0a), `06cb21cf`(S5-0b),
  `678104e5`(디자인 기준 자료 추적), 이 항목의 레인 준비 커밋.
- 디자인 기준 자료: `.gitignore` 59행 `design/`이 `docs/design/eleven`을 무시해 레인 worktree에 없고
  `screen_copy_test`가 다른 checkout에서 실패하는 문제를 고쳤다. `!docs/design/` 예외로 추적하고, 모션
  프레임은 긴 변 1080px·JPEG 품질 60으로 줄였다(45MB → 10MB, 원본 PNG는 git 밖
  `motion-frames-full/`). 추적 용량 약 19MB.
- 레인이 같은 파일을 고치지 않도록: 디자인 가드 허용 목록을 `test/phone/`·`test/tablet/`의 레인 소유 파일로
  나눴고, `test/widgets_test.dart`를 `test/shared/entry_test.dart`·`test/phone/tile_rack_test.dart`·
  `test/tablet/draw_grid_test.dart`로 나눴다(뽑기 테스트 값을 1–9로 정정).
- 검수 스크린샷 도우미 `test/support/eleven_test_support.dart`: 숫자 StardosStencil, 한글은 저장소의
  IBMPlexSansKR을 “Noto Sans KR” 이름으로 등록해 실제 글자로 그린다. `ELEVEN_REVIEW=1`일 때만
  `review_out/<레인>/`에 저장(`.gitignore`에 `review_out/` 추가). 골든 3개를 이 글꼴로 다시 만들었다.
- 지시문: `docs/planning/eleven-lanes/LANES-COMMON.md`, `LANE-A.md`, `LANE-B.md`, `LANE-C.md`.
  스크립트: `scripts/eleven_lanes.sh`(worktree `~/Developer/projects/project00-lanes/lane-{a,b,c}`,
  브랜치 `eleven/lane-a-phone`·`eleven/lane-b-tablet`·`eleven/lane-c-integration`).
- 레인 표시 결정(Claude): 문구의 사람 이름은 실제 닉네임, 아바타·A/B 표식 글자는 좌석 표시(seatIndex 0 = A).
  P08 패배·동점·후공 문구는 하준 결정 전까지 만들지 않고 레인 A가 요청으로 남긴다.
- 검증: `packages/game_eleven` `flutter test --no-pub` 111/111 PASS exit 0, `flutter analyze --no-pub
  packages/game_eleven` exit 0, `dart format --set-exit-if-changed` exit 0, 패키지 경계 0건 exit 0,
  `bash -n scripts/eleven_lanes.sh` exit 0. validate --full 미실행.
