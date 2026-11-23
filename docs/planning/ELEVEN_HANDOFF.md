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
