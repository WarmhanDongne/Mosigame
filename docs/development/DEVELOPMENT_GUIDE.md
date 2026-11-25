# Mosigame 개발환경 가이드

이 문서는 현재 개발환경 준비와 Firebase 실행 모드의 단일 사람용 안내입니다. AI 작업은
먼저 루트 `AGENTS.md`를 읽습니다.

## 기준 도구

- Git
- Flutter stable `3.47.5` CI 기준
- Node.js major 22 (`.nvmrc`, Functions engine)
- Java 17 이상
- Android 개발: Android SDK·ADB
- iOS 개발: macOS·Xcode·CocoaPods

## 작업 전

```bash
git branch --show-current
git rev-parse HEAD
git status --short --branch
```

기존 변경을 자동으로 stash, reset, restore, stage 또는 commit하지 않습니다.

## 환경 점검

macOS:

```bash
bash ./tool/setup_mosigame.sh
dart run :mosigame doctor
```

Windows:

```powershell
.\tool\setup_mosigame.ps1
.\tool\invoke_mosigame.ps1 doctor
```

dependency가 없을 때만 승인 후 준비합니다.

```bash
bash ./tool/setup_mosigame.sh --prepare
```

```powershell
.\tool\setup_mosigame.ps1 -Prepare
```

Prepare는 repository-local `flutter pub get`과 `npm ci`만 수행합니다. 관리자 설치,
license 동의, Firebase 로그인과 secret 입력은 사람이 처리합니다.

## Firebase 백엔드 선택

### TEST 프로젝트

`jinsung` 개발 브랜치, 기능 브랜치와 `TEST` 실기기 검증의 기본 모드입니다.
`jinsung`에서는 `MOSIGAME_BACKEND`를 생략해도 TEST가 선택됩니다.

```bash
flutter run --dart-define=MOSIGAME_BACKEND=test
```

### 로컬 Emulator Suite

debug 빌드에서만 사용합니다.

```bash
flutter run --dart-define=MOSIGAME_BACKEND=local
```

### 운영 서버

운영 Firebase는 `MOSIGAME_BACKEND=server`를 명시해야 합니다. 일반 기능 개발과
TEST 실기기 검증에서는 운영 모드를 사용하지 않습니다.

```bash
flutter run --dart-define=MOSIGAME_BACKEND=server
```

운영 모드는 승인된 운영 확인에서만 사용합니다.

## 검증

관련 영역만 빠르게 확인한 뒤 완료 후보는 사용자 승인 후 FULL을 실행합니다.

```bash
dart run :mosigame test session
dart run :mosigame test auth
dart run :mosigame validate --full
```

Windows에서는 `tool/invoke_mosigame.ps1` 경로를 사용합니다. 정확한 timeout과 exit code는
`docs/engineering/PROJECT_CLI.md`가 소유합니다.

## 중단해야 하는 경우

- 시스템 패키지 설치나 관리자 권한이 필요함
- Xcode·Android license 동의가 필요함
- Firebase 로그인, credential 또는 secret 입력이 필요함
- dependency 준비가 tracked 파일을 예상 밖으로 변경함
- 기존 작업과 충돌함
- production 접근·배포·migration이 필요함
- Project CLI가 BLOCKED 또는 INTERNAL ERROR를 반환함

과거 환경 구축 과정은 `AGENT_SETUP.md`, `DEVELOPMENT_SETUP.md`,
`DEVELOPMENT_ENVIRONMENT_PLAN.md`, 세부 Emulator 절차는 `LOCAL_FIREBASE.md`에 보존합니다.
새 작업은 이 문서를 우선합니다.
