# ELEVEN 인계

작업: [ELEVEN-01](tasks/ELEVEN-01.md#eleven-01) · 계약: [ELEVEN 게임 계약](../engineering/ELEVEN_GAME_CONTRACT.md)

다음 에이전트는 이 문서만 믿고 배포하지 않는다. 시작 전에 브랜치·HEAD·작업 트리·원격
상태와 노션 현재 결정을 다시 확인한다. 같은 작업 트리를 두 에이전트가 동시에 수정하지 않는다.

## 2026-11-23 · S1·S2 (Claude)

```text
Issue / branch / HEAD / base:
  Issue 없음(미생성) / feature/black-and-white-ui / cb13e579 / develop 기준 반영 안 함
  사용자 미커밋 변경 보존: ios/Podfile.lock, ios/Runner.xcodeproj/project.pbxproj,
  pubspec.yaml, docs/planning/BLACK_WHITE_REVERSE_PHONE_MOCKUP.html, ios swiftpm 폴더
노션 확인 시각 및 변경된 결정 / 디자인 화면 ID·참고 버전:
  2026-11-23 04:20 KST. 게임명·gameId eleven, 시간 초과 force timeout 방식(태블릿 호출+휴대폰 예비),
  태블릿 진행, 뽑기 신원 미확인, 한 명 퇴장 시 승자 없이 종료, TEST 카탈로그 paid+ownedGames.
  디자인 T01–T13, P01–P11 (캔버스 'ELEVEN · 화면 디자인', 2026-11-23 버전)
완료 범위와 변경 파일 / 아직 미완료 범위:
  완료: S1 계약 초안, S2 순수 규칙·테스트
  추가 파일: docs/engineering/ELEVEN_GAME_CONTRACT.md, functions/src/eleven/rules.ts,
  functions/test/eleven-rules.test.mjs, docs/planning/tasks/ELEVEN-01.md,
  docs/planning/ELEVEN_HANDOFF.md / 수정: docs/planning/TASKS.md(행 추가)
  미완료: S0 브랜치 정리, 계약 승인, S3 이후 전부
공개·private·server 필드 및 변경된 callable:
  계약 문서 4·5절에 정의만 함. callable·RTDB 쓰기 구현 없음, index.ts 변경 없음
실행 명령 / PASS·FAIL·BLOCKED / exit code / TEST project:
  functions/: npx tsc → exit 0 / node --test test/eleven-rules.test.mjs → 17 PASS exit 0 /
  node --test test/*.test.mjs → 625 PASS exit 0 / npm run lint → exit 0
  validate --full 미실행(사용자 승인 대기) / TEST project 사용 안 함
배포 여부와 배포된 함수·source commit:
  배포 없음. 커밋 없음(작업 트리에 새 파일로만 존재)
미확인 위험·재현 절차 / 다음 한 가지 작업:
  위험: 기능 브랜치가 develop보다 뒤처져 있음(노션 기록 기준 43커밋, 재확인 필요)
  다음: 사용자에게 계약 승인을 받은 뒤 S0 브랜치 정리 → S3 callable 구현
사용자가 검증할 화면·행동 및 예상 결과:
  계약 문서 3·4·5절 검토(숫자·합·판정 유형이 public에 없는지, 명령 이름과 호출자)
  규칙 테스트 요약(121쌍 전수, 합 10·20, 동점, 조기 종료 경계, 최종 동점 순서)
```

## 2026-11-23 · S3 서버 후보 (Codex)

```text
branch / HEAD: feature/black-and-white-ui / cb13e579 (develop과 로컬 HEAD 동일,
  origin/develop보다 43커밋 뒤, origin/feature/black-and-white-ui보다 20커밋 뒤)
계획: https://app.notion.com/p/42109716f87e813e8792e3cb4b41feb1
노션 기준: '개발 계획·검증·출시' S1 승인 완료, S3 서버 명령. controller/history만 태블릿 읽기.
완료 후보: functions/src/eleven/{types,game,callables}.ts, index export,
  game-adapters/finish-now/recovery-state/room-seating-policy, database.rules.json,
  functions/test/eleven-game.test.mjs, functions/emulator-tests/eleven-rules.mjs.
계약 수정: public/history 제거, controller/history 추가, sessionOperations 멱등 사용.
검증: npm run build exit0; npm run lint exit0; node --test test/*.test.mjs
  634 PASS exit0; Project CLI test session 5단계 PASS exit0 (Flutter264/Functions217),
  test auth 5단계 PASS exit0; demo-eleven RTDB 에뮬레이터 권한·동시 timeout·재시도 PASS exit0.
중간 실패: RTDB 빈 server 객체 탈락으로 callable TypeError(exit1) → 정규화 후 재검증 PASS.
FULL: 2026-11-23 사용자 지시로 미실행. 최종 완료 판정 아님. 배포·카탈로그 없음.
기존 사용자 변경: ios/Podfile.lock, ios/Runner.xcodeproj/project.pbxproj,
  pubspec.yaml, 목업 HTML 및 swiftpm 폴더 보존. S0 브랜치 정리 미실행.
다음: 관련 검사 PASS인 S3 후보를 기반으로 S4 앱 골격. 최종 FULL 미충족을 유지.
```

## 2026-11-23 · S4 앱 골격 (Claude)

```text
branch / HEAD: feature/black-and-white-ui / 1d44e538 (S3 커밋 위, S4는 미커밋)
노션: 이 세션 연결은 다른 workspace라 S3 계획 페이지 404. S4 완료 기준 미대조.
  요청된 claude/HANDOFF_20261123.md는 저장소에 없어 이 문서를 기준으로 진행.
완료 후보: packages/game_eleven 전체(lib 24파일, test 4파일), test/eleven_integration_test.dart.
  수정: pubspec.yaml(workspace·dependency 2줄), lib/games/game_registry.dart,
  tool/check_package_boundaries.py, tool/mosigame_cli/package_test_manifest.dart,
  test/mosigame_cli/package_test_manifest_test.dart, game_kit game_command_service.dart(진단 이름).
화면: P01–P11 / T01–T13 단계 연결만. 디자인·에셋·소리·MosiGameArt·zh 문구 확정 없음.
검증: game_eleven analyze 0건·test 24 PASS; 경계 검사 0건; 루트 analyze 0건;
  registry·manifest·소비 테스트 PASS; test session 5단계 PASS exit0. FULL 미실행(승인 대기).
배포·카탈로그·실기기: 없음.
기존 사용자 변경: ios/*, pubspec.yaml version·공백, 목업 HTML, swiftpm 폴더 보존.
다음: 사용자 승인 후 validate --full → Notion S4 기준 대조 → 디자인 반영 단계.
```

## 2026-11-23 · S4 Notion 대조 후 수정 (Claude)

```text
Notion: 내장 브라우저로 개발 계획·룰·정보 공개·기기별 UX 확인(연결·복구·이탈 페이지는 미확인).
수정: 휴대폰 landscapeOnly·가로 배치, 태블릿 승부 없는 종료 1초 뒤 방 복귀,
  미정 진동 제거, 화면 문구 한국어 임시 표시(키 유지). 서버 변경 없음.
검증: game_eleven analyze 0건·test 25 PASS; 경계 0건; 루트 테스트 PASS; test session 5단계 PASS exit0.
미완료: S4 에뮬레이터 한 판 검증, P08 라운드 승자 데이터(계약 판단), FULL(승인 대기). 미커밋.
```

## 2026-11-23 · S4 로컬 에뮬레이터 한 판 (Claude)

```text
결과: iOS 시뮬레이터 3대 + 로컬 에뮬레이터에서 시작→뽑기→7라운드→조기 종료→다시 하기 PASS.
수정: functions/src/eleven/game.ts normalize에 draw.picks·tiles 복원(RTDB 빈 객체 누락 결함),
  회귀 테스트 2개. functions build·lint exit0, 테스트 636 PASS.
미확인: 다시 하기 뒤 수동 종료 미호출(commandInFlight 고착 추정), 방 복귀 경로 실기 미확인.
기존 결함: tool/emulator/functions.cjs RTDB 트리거 수 5→6 불일치(ELEVEN 무관, 이번엔 build 사본만 수정).
FULL 미실행. 미커밋.
```


## 2026-11-23 · S4 다시 하기 뒤 종료 후속 (Codex)

```text
위치/브랜치/HEAD: /Users/user/Developer/projects/project00 /
  feature/black-and-white-ui / 1d44e538. 기존 미커밋 변경 보존.
원인·수정: GameSessionController.run()이 재구독 후 완료된 명령의
  commandInFlight를 해제하지 않는 경로를 회귀 테스트로 재현·수정.
에뮬레이터: RTDB trigger 기준 5→6, 로컬 smoke 카탈로그 기대값을
  현재 fixture ID 목록으로 변경. demo 로컬 smoke 재실행 PASS 1/1.
관련 검사: session 5단계 PASS, game_kit 155/155, game_eleven 25/25,
  Functions ELEVEN 26/26, 수정 파일 analyze·패키지 경계·diff check PASS.
  iOS simulator build PASS, ios/와 SwiftPM 해시 불변.
미확인: Simulator UI 조작 도구 오류로 다시 하기→수동 종료와 퇴장→방 복귀를
  화면에서 재검증하지 못함. 에뮬레이터·시뮬레이터 종료.
FULL: 사용자 지시로 미실행. 배포·커밋·push 없음.
다음: 종료·퇴장 화면 흐름 수동 확인 → S5. 원격 브랜치 분기 정리는 push 전 별도.
```


## 2026-11-23 · S4 종료·퇴장 사용자 수동 확인

```text
사용자 보고: 로컬 백엔드와 iOS 시뮬레이터에서 다시 하기→게임 종료,
  진행 중 휴대폰 퇴장 두 테스트 영역 모두 성공.
기기 빌드: 기본 iPhone 17만 이전 빌드였고, 같은 local 빌드를 재설치해
  Player 2·Player 3·iPad와 실행 파일 해시 일치 확인.
한계: 이번 보고의 화면 영상·종료 상태를 Codex가 별도로 재조회하지 않음.
FULL: 사용자 지시로 미실행. 커밋·push·배포 없음.
다음: S5 디자인/UX 단계. push 전 브랜치 분기 정리.
```


## 2026-11-25 · S5-0a 계약·서버 + D0 디자인 기준 (Claude, Cowork)

```text
브랜치/HEAD: feature/black-and-white-ui / 5db37ff1 (커밋 없음, stash@{0} 보존).
변경: 계약 문서, functions/src/eleven 4개, functions/test eleven 2개, pubspec(StardosStencil),
  docs/design/eleven/(신규, 약 55MB), docs/planning/eleven-lanes/S5-0B.md(신규).
검증: tsc 0, functions 테스트 673/673, lint 0, 패키지 경계 0건. FULL 미실행.
다음: 맥 Claude Code에서 "docs/planning/eleven-lanes/S5-0B.md 읽고 진행".
  끝나면 기준 커밋 승인 → 레인 지시문(LANE-A/B/C)·worktree 스크립트 작성.
참고: .gitignore 59행 `design/` 때문에 docs/design/eleven은 git 추적 밖이다. 레인 worktree에는
  생기지 않으므로 레인 지시문은 원본 폴더 절대경로로 참조한다. 추적 여부는 하준 결정.
```

## 2026-11-25 · S5-0b 앱 공통 기반 (Claude Code, 맥)

```text
브랜치/HEAD: feature/black-and-white-ui / 5db37ff1 (커밋 없음, stash@{0} 보존, Issue·새 브랜치 없음).
완료: FontFamily.stardosStencil 생성, 앱 9장·lastRoundResult 반영, 느와르 토큰·글자·모션 상수,
  타일·토스트 공통 위젯+골든 3개, 화면 문구 키(ElevenScreenCopy), 화면 ID 순수 함수
  (ElevenPhoneScreen P01–P11·G1–G8 / ElevenTabletScreen T01–T13·T13-B), 디자인 가드 테스트.
timing 변경: roundResult 2000→3200, drawReveal 600→4700, roundIntro 800→1400, submit 300→350ms.
검증: packages/game_eleven flutter test 111/111 exit 0, flutter analyze(패키지) exit 0,
  dart format 검사 exit 0, 패키지 경계 0건 exit 0. functions 미변경. FULL 미실행.
레인에게: lib/phone·lib/tablet은 lib/shared/noir/*와 lib/shared/widgets/noir_*.dart만 쓴다.
  화면을 시안으로 바꾸면 design_guard_test 허용 목록의 해당 줄도 지운다. 문구는
  ElevenScreenCopy만 쓰고 game_copy.dart는 고치지 않는다.
하준 확인: Noto Sans KR 번들 여부, P08 패배·동점·후공 문구 부재, 모서리 점 간격 검수.
다음: 하준 기준 커밋 승인 → 레인 지시문(LANE-A/B/C)·worktree 스크립트.
```

## 2026-11-25 · S5 레인 준비 (Claude Code, 맥)

```text
기준 커밋: feature/black-and-white-ui (6e6a1ede S5-0a, 06cb21cf S5-0b, 678104e5 디자인 자료, 레인 준비 커밋).
레인: scripts/eleven_lanes.sh → ~/Developer/projects/project00-lanes/lane-{a,b,c}
  (eleven/lane-a-phone, eleven/lane-b-tablet, eleven/lane-c-integration).
Codex 입력: 각 폴더에서 "docs/planning/eleven-lanes/LANE-A.md 읽고 진행"(B·C 같음).
검수: 레인 LOG에 "검수 요청: 예"가 오면 Claude가 review_out/<레인>/ 과 docs/design/eleven 기준을 비교해
  REVIEW-<레인>.md 작성 → Codex에 "REVIEW-A.md 반영".
하준 결정 대기: P08 패배·동점·후공 문구, Noto Sans KR 번들 여부.
다음: 세 레인 PASS 뒤 S6-M 지시문(S6-M.md) 작성·병합.
```

## 2026-11-25 · S6-M 병합 (Claude Code, 맥)

```text
브랜치/HEAD: feature/black-and-white-ui, 레인 A→B→C --no-ff 병합(충돌 없음) + S6-M 기록 커밋. push 안 함.
검증: game_eleven 159 PASS·37 skip, 루트 analyze No issues, format·경계 0, functions build·lint 0·681 PASS 1 skip.
시스템 맵: ELEVEN 추가, 확인일 2026.11.25, 단계별 캡처 16장(JPEG).
하준 확인 ②: packages/game_eleven/review_out/S6-M.html(시안 vs 구현). 참고: P05 선택 전 라벨 위치(시안 없음).
남은 것: 룰북 본문 초안 확인, Java 21 설치 승인(에뮬레이터 시나리오), S7(가) 통합·S7(나) 번역, validate --full 승인.
레인 worktree·브랜치는 아직 남겨 둠(정리는 하준 확인 뒤).
```
