# Mosigame AI development guide

이 파일은 Mosigame에서 AI와 개발자가 작업을 시작할 때 읽는 **단일 필수 진입점**이다.
현재 제품 상태는 [`CURRENT_PROJECT.md`](docs/CURRENT_PROJECT.md), 공통 완료 계약은
[`ENGINEERING_CONTRACT.md`](docs/engineering/ENGINEERING_CONTRACT.md)가 소유한다. 코드·테스트·설정과
문서가 다르면 현재 코드·테스트·설정을 먼저 조사하고 차이를 보고한다.

## 1. 작업 시작

읽기 전용 질문·조사·검토는 브랜치를 바꾸지 않는다. 파일을 변경하는 새 작업은 다음 순서로
시작한다.

1. 요청에 담당자가 없으면 `hajun` 또는 `jinsung` 중 담당 개발자를 묻는다.
2. branch, HEAD, upstream, staged, unstaged, untracked 상태를 기록한다.
3. 기존 변경을 reset, restore, stash, 삭제, 자동 stage 또는 commit하지 않는다.
4. `origin/develop`과 원격 브랜치 목록을 fetch한다.
5. `origin/<개발자>`가 있으면 개발자 브랜치를 원격 최신 상태로 맞추고 최신 `develop`을
   병합한다. 아직 없으면 최신 `origin/develop`에서 `<개발자>` 브랜치를 처음 만든다고
   보고한다. 충돌하거나 기존 변경과 겹치면 중단한다.
6. 작업 범위와 완료 조건을 적은 GitHub Issue를 먼저 만들고 이슈 번호를 확인한다.
7. 최신 개발자 브랜치에서 `<개발자>_<기능명>_<이슈번호>` 브랜치를 만든다. 이슈 번호에는
   `#`을 붙이지 않고, 하나의 이슈에 하나의 기능 브랜치를 연결한다.
8. GitHub Issue를 만들 도구나 인증이 없으면 보류 사유를 보고하고 새 작업의 파일 편집과
   브랜치 생성을 시작하지 않는다. 임의 API 호출이나 임시 이슈 번호를 사용하지 않는다.

이 순서는 새 작업에 적용한다. 이미 진행 중인 브랜치와 미커밋 변경은 임의로 이름을 바꾸거나
옮기지 않는다.

예시:

```text
jinsung_방퇴장오류수정_123
hajun_로그인안내개선_124
```

## 2. 브랜치 역할과 병합 흐름

```text
개발자_기능A_이슈번호 ─┐
개발자_기능B_이슈번호 ─┼→ 개발자 → TEST 검증 → develop → 스토어 배포 → main
개발자_기능C_이슈번호 ─┘
```

| 브랜치 | 역할 | Firebase | 삭제 |
| --- | --- | --- | --- |
| `main` | App Store·Google Play에 실제 배포가 끝난 버전 | 운영 | 금지 |
| `develop` | 검증을 마치고 다음 스토어 등록을 기다리는 버전 | 운영 설정 | 금지 |
| `TEST` | 최신 develop 후보의 테스트 서버·실기기 검증 | TEST | 금지 |
| `hajun`, `jinsung` | 개발자별 기능 통합 | TEST로 실행 | 금지 |
| `<개발자>_<기능>_<이슈번호>` | 해당 GitHub Issue 하나의 작업 공간 | TEST로 실행 | 병합 후 삭제 |

- 기능 브랜치는 개발자 브랜치로 PR을 보낸다.
- 기능 개발이 끝나 `<개발자>_<기능>_<이슈번호>`를 `hajun` 또는 `jinsung` 브랜치에 합치기 전,
  [`MOSIGAME_SYSTEM_MAP.html`](docs/engineering/MOSIGAME_SYSTEM_MAP.html)을 같은 기능
  브랜치에서 현재 코드에 맞게 갱신한다. 변경된 화면·기능 흐름·파일 위치·Functions·Firebase
  데이터 경계와 확인일을 반영하는 것은 개발자 브랜치 병합 조건이다.
- 여러 기능을 개발자 브랜치에서 통합한 뒤 `TEST`에서 테스트 Firebase와 실기기를 검증한다.
- `TEST` 전용 설정을 `develop`에 가져오지 않는다. 검증 완료 후 같은 기능 커밋을 개발자
  브랜치에서 `develop`로 병합하는 방식을 우선한다.
- 사용자 컨펌 전에는 `develop` 병합, 이슈 Close, 기능 브랜치 삭제, 운영 배포를 하지 않는다.
- 앱스토어·Google Play 배포 완료를 확인한 뒤에만 `develop`을 `main`에 반영한다.

## 3. Issue, 커밋, PR 형식

Issue 제목:

```text
[수정] 방 퇴장 요청이 중복 처리되는 문제
[기능추가] 게임 재접속 상태 안내
[문서수정] AI 개발 문서 구조 정리
```

Issue 본문에는 작업 이유, 현재 문제, 변경 범위, 제외 범위, 완료 조건, 필요한 테스트,
Cloud Functions 변경 여부와 예상 브랜치를 적는다. 이슈 번호를 받은 뒤 예상 브랜치 이름을
`<개발자>_<기능명>_<이슈번호>`로 확정하고 Issue 본문에도 반영한다. 완료된 Issue는 삭제하지
않고 Close한다.

커밋 제목은 쉬운 한국어로 작성한다.

```text
수정: 방 퇴장 요청 중복 처리 문제 해결
기능추가: 게임 재접속 상태 안내 추가
기능개선: 로그인 오류 안내 개선
테스트추가: 퇴장 중복 요청 회귀 테스트 추가
문서수정: AI 개발 및 브랜치 운영 기준 통합
설정변경: Firebase CLI 기본 프로젝트를 TEST로 변경
코드정리: 게임 상태 변환 코드 정리
```

커밋 본문:

```text
핵심 변화:
- 가장 중요한 변경

기능:
- 사용자가 보게 되는 동작

기타 알아야 할 사항:
- 영향 범위, Firebase·배포 순서, 제한 또는 후속 작업

검증:
- 실제 실행 명령, PASS/FAIL/BLOCKED, exit code

관련 이슈:
- #번호
```

PR은 기능 브랜치→개발자, 개발자→TEST 검증, 검증 완료 개발자→develop 순서로 관리한다.
PR 본문에는 관련 이슈, 핵심 변화, 사용자 기능, Firebase 변경, 운영 Map HTML 갱신 내용,
검증 결과와 미확인 사항을 적는다.

## 4. Firebase 환경과 배포 안전

앱 백엔드는 코드가 지원하는 모드를 명시해서 실행한다.

```text
server  운영 Firebase. 기본값이므로 개발·실기기 검증에서 무심코 사용하지 않는다.
test    TEST Firebase. 개발자·기능·TEST 브랜치의 기본 검증 대상이다.
local   로컬 Emulator Suite. debug 빌드만 허용한다.
```

```bash
flutter run --dart-define=MOSIGAME_BACKEND=test
flutter run --dart-define=MOSIGAME_BACKEND=local
```

`.firebaserc`의 CLI 기본 프로젝트는 TEST다. 운영은 반드시 `mosigame-production` 별칭이나
고정 project ID를 명시하고 사용자에게 정확한 함수·rules·시간·영향을 승인받은 뒤 실행한다.

테스트 Functions 전체 후보:

```bash
npm --prefix functions run deploy:test -- --project=ban-pick-simulator
```

운영 배포에서 프로젝트를 생략하거나 `--only functions`로 전체 함수를 임의 배포하지 않는다.
변경 함수만 명시하고 앱·기존 함수의 양방향 호환성과 TEST 실기기 결과를 먼저 확인한다.
production RTDB 조회·서버 로그는 각각
[`FIREBASE_MCP.md`](docs/operations/FIREBASE_MCP.md)와
[`FIREBASE_SERVER_LOGS.md`](docs/operations/FIREBASE_SERVER_LOGS.md)의 읽기 전용 절차를 따른다.

## 5. 구현 계약

- Mosigame은 Flutter 앱과 Firebase Functions(Node.js 22)가 함께 동작한다.
- 게임 규칙, 턴, 승패, 비공개 정보와 중요한 상태 전이는 서버가 결정한다.
- Flutter는 callable로 변경을 요청하고 허용된 Firebase 상태를 화면으로 변환한다.
- public, 사용자 private, server-only 데이터 경계를 유지한다.
- 배포된 callable 이름, public API, persistent data와 state machine을 바꾸기 전에는 하위
  호환성과 모든 소비자를 확인하고 사용자 승인을 받는다.
- 생성 파일을 직접 수정하지 않는다.
- 새 dependency, production 접근, deploy/migration, 중요한 제품·architecture 결정,
  기존 사용자 변경과의 충돌, 범위 밖 수정은 중단하고 승인받는다.

기능 구현·버그 수정 완료 작업에는
[`Mosigame Implement and Validate`](.agents/skills/mosigame-implement-and-validate/SKILL.md)
Skill을 사용한다. 질문, 조사, 계획, 독립 검토, 문서 전용·Git 전용 작업에는 사용하지 않는다.

## 6. 검증

실행 전 플랫폼 경로는 [`PROJECT_CLI.md`](docs/engineering/PROJECT_CLI.md)를 확인한다.

```text
dart run :mosigame test session
dart run :mosigame test auth
dart run :mosigame validate --full
```

- targeted suite는 관련 작업 중 빠른 피드백이며 FULL을 대체하지 않는다.
- 구현 후보의 관련 검사가 통과하면 사용자에게 FULL 실행 승인을 요청한다.
- FULL은 승인 후 macOS/Linux raw 명령 또는 Windows guarded 명령으로 한 번 실행한다.
- 실행한 명령, status, exit code, 실행 전후 working tree와 미실행 검증을 보고한다.
- `FAIL`이나 `BLOCKED`를 완료라고 표현하지 않는다.

## 7. 필요한 문서만 읽기

모든 문서를 미리 읽지 않는다. 이 파일을 읽은 뒤 작업에 해당하는 활성 문서만 추가로 읽는다.

| 작업 | 추가 문서·코드 |
| --- | --- |
| 현재 제품·공개 계획 | [`CURRENT_PROJECT.md`](docs/CURRENT_PROJECT.md) |
| 공통 완료·승인 계약 | [`ENGINEERING_CONTRACT.md`](docs/engineering/ENGINEERING_CONTRACT.md) |
| 구조·패키지·게임 경계 | [`ARCHITECTURE.md`](docs/engineering/ARCHITECTURE.md)와 관련 코드·테스트 |
| 개발환경·TEST/local 실행 | [`DEVELOPMENT_GUIDE.md`](docs/development/DEVELOPMENT_GUIDE.md) |
| Cloud Functions | [`CLOUD_FUNCTIONS.md`](docs/engineering/CLOUD_FUNCTIONS.md), `functions/src/index.ts` |
| 새 게임 | [`NEW_GAME_GUIDE.md`](docs/engineering/NEW_GAME_GUIDE.md), `packages/game_template/` |
| 테스트·스토어·Firebase 운영 | [`TEST_AND_RELEASE_GUIDE.md`](docs/operations/TEST_AND_RELEASE_GUIDE.md) |
| 현재 작업 | [`TASKS.md`](docs/planning/TASKS.md)와 해당 task 상세 |

날짜가 붙은 planning/operations 문서와 월별 log는 과거 근거다. 현재 구현 설명으로 사용하지
않고, 현재 문서가 연결한 증거가 필요할 때만 읽는다. 전체 문서 분류는
[`docs/README.md`](docs/README.md)를 따른다.
