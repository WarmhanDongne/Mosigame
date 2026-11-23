<a id="eleven-01"></a>
# ELEVEN-01

2인 숫자 추리 게임 ELEVEN(기획명 '흑과 백 리버스') 신규 개발.

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

## 목적과 범위

- 제품 결정 원본: 노션 ELEVEN 페이지와 하위 '게임 룰 및 정책', '정보 공개 정책',
  '기기별 UX·UI', '개발 계획·검증·출시'.
- 화면 참고: Claude 디자인 캔버스 'ELEVEN · 화면 디자인'의 T01–T13, P01–P11.
  이전 시안 4개는 구현 대상이 아니다.
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
