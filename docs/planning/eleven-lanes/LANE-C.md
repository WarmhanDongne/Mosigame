# ELEVEN-01 레인 C · 통합 준비 (S7 자동화 선행)

먼저 `docs/planning/eleven-lanes/LANES-COMMON.md`를 읽고 그 규칙을 모두 따른다(3·4절 디자인·스크린샷 규칙은
이 레인에 해당하지 않는다).
작업 트리: `~/Developer/projects/project00-lanes/lane-c`, 브랜치 `eleven/lane-c-integration`.

## 1. 목표

S7(가) 통합 검증을 바로 실행할 수 있게 서버 시나리오 테스트, 에뮬레이터 시나리오, 회귀 목록, 시스템 맵
초안을 미리 만든다. 서버·rules·앱 코드는 고치지 않는다. 결함을 찾으면 재현 테스트와 함께 LOG에 보고만 한다.

## 2. 수정 가능 경로

- `functions/test/eleven-*.test.mjs`(새 파일 추가, 기존 `eleven-game.test.mjs`·`eleven-rules.test.mjs`에
  테스트 추가 가능. 기존 단언을 지우거나 약하게 바꾸지 않는다)
- `docs/planning/eleven-lanes/lane-c/**`(초안 문서), `docs/planning/eleven-lanes/LOG-C.md`

`functions/src/**`, `database.rules.json`, `tool/**`, `docs/engineering/**`, `docs/operations/**`, 앱 코드는
수정 금지다. 바꿔야 하면 LOG "공유 파일 요청"에 적는다.

## 3. 먼저 읽을 것

1. `docs/engineering/ELEVEN_GAME_CONTRACT.md` 전체
2. `functions/src/eleven/*.ts`, `functions/test/eleven-game.test.mjs`(이미 있는 도우미·테스트를 재사용)
3. `functions/test/room-presence-rules.test.mjs`(rules 식을 vm으로 평가하는 방식)
4. `docs/operations/EMULATOR_TEST_EXECUTION.md`, `EMULATOR_PILOT.md`, `tool/emulator/README.md`
5. `docs/planning/tasks/ELEVEN-01.md`의 “S4 로컬 에뮬레이터 한 판 검증”(알려진 문제 포함)
6. `docs/engineering/MOSIGAME_SYSTEM_MAP.html`(구조만 참고, 수정하지 않음)

## 4. 만들 것

1. **서버 시나리오 테스트**(`functions/test/eleven-scenarios.test.mjs` 등, Firebase 없이 실행):
   - 한 판 전체: 첫 선공 뽑기(slot 0–8) → 11라운드 → `allRounds` 종료, 조기 종료 경계(차 = 남은 라운드면 계속,
     크면 종료), 11라운드 뒤 동점 → 최종 동점 뽑기 → `tieDraw` 종료.
   - 매 전이에서 public에 실제 숫자·합·판정 유형·공개 전 뽑기 배치가 없는지, `lastRoundResult`가 계약 4.1대로
     (첫 판정 전 없음, 동점이면 winnerUid 없음/null, 다음 판정 때 덮어씀) 바뀌는지 확인.
   - 시간 초과 동시 도착(태블릿·두 휴대폰), 같은 commandId 재전송, revision 불일치 `complete_phase` 무시.
   - 퇴장·제외·수동 종료 시 승자 없음(`winnerUid: null`)과 `finishReason`.
   - 다시하기(새 게임 인스턴스) 뒤 이전 인스턴스 명령이 반영되지 않음.
2. **데이터 경계 rules 테스트**: 휴대폰 참가자·외부인·비로그인은 `game/controller`·`game/server`·다른 사람
   `game/private`를 읽지 못하고, controller만 `game/controller`를 읽는다. 기존 테스트에 없는 경우만 더한다.
3. **에뮬레이터 시나리오**(`functions/test/eleven-emulator.test.mjs`): 환경 변수 `ELEVEN_EMULATOR=1`일 때만
   실행하고 아니면 skip. 로컬 에뮬레이터(`node tool/emulator/local.mjs start`, demo 프로젝트, 운영 접근 없음)에
   방 생성 → 2인 참가 → ELEVEN 시작 → 한 판 진행 → 결과, 재접속·퇴장·수동 종료·다시하기를 callable로
   돌린다. `tool/emulator/functions.cjs`의 RTDB 트리거 개수 고정 문제(ELEVEN-01 S4 기록)로 막히면 tool은
   고치지 말고 BLOCKED와 공유 파일 요청으로 남긴다.
4. **회귀 목록**(`docs/planning/eleven-lanes/lane-c/REGRESSION.md`): ELEVEN 추가로 영향받을 수 있는 공통 경로
   (게임 선택·자리 배치·중단·복구·finish-now·인원 부족 종료·카탈로그·패키지 경계)와 기존 게임별 확인 항목,
   자동 테스트 위치 또는 수동 확인 절차.
5. **시스템 맵 초안**(`docs/planning/eleven-lanes/lane-c/SYSTEM_MAP_ELEVEN.md`): ELEVEN 화면 흐름, 파일 위치,
   Functions 명령, RTDB 데이터 경계(public·private·controller·server), 확인일. S6-M에서 Claude Code가
   `MOSIGAME_SYSTEM_MAP.html`에 옮긴다.
6. **S7 실행 순서 초안**(`docs/planning/eleven-lanes/lane-c/S7_RUNBOOK.md`): S6-M 병합 뒤 실행할 명령·순서·
   예상 결과(에뮬레이터 시작, 시뮬레이터 휴대폰 2대·태블릿 1대, 확인 화면 ID 목록).

## 5. 검증

- `functions/`: `npm run build`, `npm run lint`, `node --test test/*.test.mjs` 모두 exit 0(에뮬레이터 테스트는 skip).
- 에뮬레이터를 썼다면 `ELEVEN_EMULATOR=1 node --test test/eleven-emulator.test.mjs` 결과와 끈 뒤 정리 상태.
- 루트 `python3 tool/check_package_boundaries.py --max 0` 위반 0건.
- 실행 전후 `git status --porcelain` 비교(빌드 산출물 외 레인 밖 변경 없음). LOG-C.md 기록 후 "검수 요청: 예".

## 6. 완료 기준

- 4절 1–6 산출물이 있고 테스트가 PASS(또는 BLOCKED 이유가 LOG에 있음).
- 찾은 서버 결함은 실패 재현 테스트를 `test.todo` 또는 skip 사유와 함께 남기고 LOG에 보고(서버 수정은 하지 않음).
- Claude 검수 PASS(REVIEW-C.md).
