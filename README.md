# 모시겜 (Mosigame)

모시겜은 태블릿 한 대를 함께 보는 게임판으로 쓰고, 각자의 휴대폰을 개인 손패와
컨트롤러로 사용하는 오프라인 파티게임 앱입니다. Flutter 앱과 Firebase Functions가
함께 동작하며 게임 규칙, 턴, 승패와 비공개 정보는 서버가 결정합니다.

## 게임 공개 계획

코드 등록과 사용자 공개는 서로 다른 상태입니다. 아래 표는 2026-11-18에 사용자가 확정한
제품 계획이며, 실제 공개에는 TEST 실기기 검증과 스토어 배포가 추가로 필요합니다.

| 게임 ID | 이름 | 계획 |
| --- | --- | --- |
| `liars_poker` | 라이어스 포커 | 공개 예정 |
| `final_call` | 파이널 콜 | 공개 예정 |
| `yut` | 윷놀이 | 공개 예정 |
| `strategy_yut` | 전략 윷놀이 | 공개 예정 |
| `russian_roulette` | 러시안 룰렛 | 공개 예정 |
| `mafia` | 마피아 | 보류 |
| `holdem` | 텍사스 홀덤 | 보류 |
| `strategy_yut_edition` | 전략 윷놀이 에디션 | 보류 |

현재 앱 registry에는 위 게임이 모두 등록되어 있지만 Firestore `enabled`와 실제 배포 상태는
별도입니다. 공개 예정이라는 표현은 운영 카탈로그가 이미 활성화됐다는 뜻이 아닙니다.

## 현재 기술 기준

- 앱 버전: `pubspec.yaml`의 `1.0.1+9`
- 앱: Flutter, Android·iOS
- 백엔드: Firebase Authentication, Realtime Database, Firestore, Storage
- 서버: Firebase Functions, Node.js 22
- 게임 패키지: 라이어스 포커, 파이널 콜, 마피아, 홀덤, 윷놀이, 러시안 룰렛
- 공용 패키지: `game_kit`
- 새 게임 스켈레톤: `game_template`

정확한 현재 구현과 공개 계획은 [`Current project`](docs/CURRENT_PROJECT.md), 구조는
[`Architecture`](docs/engineering/ARCHITECTURE.md)를 따릅니다.

## 문서 시작점

- AI 작업: [`AGENTS.md`](AGENTS.md) 하나를 먼저 읽습니다.
- 사람용 문서 목차: [`docs/README.md`](docs/README.md)
- 개발환경: [`Development guide`](docs/development/DEVELOPMENT_GUIDE.md)
- TEST·실기기·배포: [`Test and release guide`](docs/operations/TEST_AND_RELEASE_GUIDE.md)

과거 날짜가 붙은 planning/operations 문서는 당시 증거이며 현재 구현 설명이 아닙니다.

## 개발환경 준비

필수 기준은 Flutter `3.47.5` CI, Node.js 22, Java 17 이상입니다.

```bash
nvm use
bash ./tool/setup_mosigame.sh
```

dependency 준비가 필요한 경우에만 명시적으로 실행합니다.

```bash
bash ./tool/setup_mosigame.sh --prepare
```

## Firebase 실행 모드

개발자 브랜치와 `TEST` 검증은 TEST Firebase를 명시합니다.

```bash
flutter run --dart-define=MOSIGAME_BACKEND=test
```

로컬 Emulator Suite를 사용할 때:

```bash
flutter run --dart-define=MOSIGAME_BACKEND=local
```

`MOSIGAME_BACKEND`를 생략하면 운영 `server` 모드이므로 일반 개발·실기기 검증에서
생략하지 않습니다.

## Cloud Functions 테스트 배포

TEST 프로젝트는 명시적으로 지정합니다. 이 스크립트는 운영 프로젝트를 거부합니다.

```bash
npm --prefix functions run deploy:test -- --project=ban-pick-simulator
```

운영 배포는 이 명령의 연장선으로 실행하지 않습니다. TEST 검증 후 변경 함수 목록과 앱
호환성을 정리하고 사용자의 별도 승인을 받은 뒤, 운영 프로젝트와 함수 이름을 모두
명시합니다. 프로젝트를 생략한 `firebase deploy --only functions`는 사용하지 않습니다.

## 검증

macOS/Linux:

```bash
dart run :mosigame doctor
dart run :mosigame test session
dart run :mosigame test auth
dart run :mosigame validate --full
```

Windows 자동화와 제한된 환경은 [`PROJECT_CLI.md`](docs/engineering/PROJECT_CLI.md)의
guarded invocation을 사용합니다. 관련 suite는 빠른 피드백이며 완료 후보는 사용자 승인 후
FULL validation을 실행합니다.

## 저장소 구조

```text
lib/                         앱 조립과 플랫폼 기능
packages/game_kit/           공용 게임 계약·UI·Firebase 기반
packages/game_template/      새 게임 복사용 스켈레톤
packages/game_<game>/        게임별 Flutter 코드와 번들 에셋
functions/src/               서버 권위형 Functions
test/                        앱·통합·Project CLI 테스트
functions/test/              서버 테스트
docs/                        활성 문서와 과거 증거
```

새 게임은 [`NEW_GAME_GUIDE.md`](docs/engineering/NEW_GAME_GUIDE.md)를 따릅니다. 모든 게임
코드와 에셋은 현재 앱에 번들되며 Firebase Storage에서 Dart 코드를 내려받아 실행하지 않습니다.
