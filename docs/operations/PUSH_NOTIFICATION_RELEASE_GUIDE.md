# 푸시 알림 TEST·운영 준비 가이드

이 문서는 게임 시작·내 차례·게임 종료 자동 푸시와 운영 페이지 수동 알림을 TEST와 운영
Firebase에서 분리해 준비하는 현재 절차입니다. 실제 Functions·Rules·Hosting·스토어 배포는
사용자 승인 뒤 별도로 실행합니다.

## 환경 경계

| 앱 실행 값 | Firebase 프로젝트 | 용도 |
| --- | --- | --- |
| `MOSIGAME_BACKEND=test` | `ban-pick-simulator` | 개발자·TEST 실기기 검증 |
| `MOSIGAME_BACKEND=server` | `project0000-ec01e` | 운영 앱·스토어 후보 |
| `MOSIGAME_BACKEND=local` | 로컬 Emulator | 푸시 미사용 |

Android는 Gradle이 `dart-defines`의 backend를 읽어 앱 시작 전 Firebase 기본 앱 리소스를
선택합니다. iOS는 Xcode의 `Select Firebase Configuration` 단계가 같은 값을 읽어 최종 앱
번들의 `GoogleService-Info.plist`를 선택합니다. FCM 토큰과 Dart의 Auth·Functions가 서로
다른 프로젝트를 향하지 않도록 두 선택은 반드시 같아야 합니다.

```bash
flutter run --dart-define=MOSIGAME_BACKEND=test
flutter build appbundle --release --dart-define=MOSIGAME_BACKEND=server
flutter build ipa --release --dart-define=MOSIGAME_BACKEND=server
```

## 콘솔에서 사람이 등록할 항목

운영 프로젝트 `project0000-ec01e`에서 다음 항목을 확인합니다.

1. Firebase Authentication에서 Google 로그인을 활성화합니다.
2. Authentication의 승인된 도메인에 `warmhandongne.github.io`를 추가합니다.
3. Firebase 프로젝트 설정 → Cloud Messaging → Apple 앱
   `com.warmhandongne.msg`에 APNs 인증 키를 등록합니다. Key ID와 Apple Team ID가 실제
   배포 서명 계정과 같아야 합니다.
4. Android 앱 `com.warmhandongne.msg`에 Play App Signing과 업로드 키 SHA-1/SHA-256이
   모두 등록됐는지 확인합니다.
5. 운영 페이지에 로그인할 Firebase Auth 사용자를 만든 뒤 UID를 확인합니다. 실제 권한
   부여는 다음 명령을 별도 승인 후 한 번 실행하고, 사용자는 다시 로그인해 새 토큰을
   받아야 합니다.

```bash
node functions/scripts/grant-operations-admin.mjs \
  --apply \
  --project=project0000-ec01e \
  --confirm-project=project0000-ec01e \
  --uid=<운영자 Firebase Auth UID>
```

APNs `.p8` 파일, Key ID, Team ID 또는 서비스 계정 키를 저장소나 채팅에 올리지 않습니다.

## 운영 Functions 배포 대상

현재 운영에는 수동 발송 함수만 있으며 다음 네 함수가 추가 배포 대상입니다. 전체 Functions
배포를 사용하지 않고 정확한 함수만 명시합니다.

```text
registerPushDevice
unregisterPushDevice
pushGameStatus
pushGameTurn
```

배포 승인 시 source commit과 TEST 실기기 결과를 다시 확인한 뒤 운영 프로젝트 ID를 명시합니다.

```bash
firebase deploy \
  --project=project0000-ec01e \
  --only functions:registerPushDevice,functions:unregisterPushDevice,functions:pushGameStatus,functions:pushGameTurn
```

이 문서의 명령은 배포 기록이 아닙니다. 실행 결과와 exit code가 별도로 있어야 배포 완료로
판정합니다.

## 운영 페이지 확인

[모시겜 운영사이트](https://warmhandongne.github.io/Mosigame_Management/)에서 `모시겜 본
서버`를 선택합니다. 운영 프로젝트의 `operationsAdmin` claim이 있는 Google 계정으로 로그인한
뒤 알림 제목·본문과 전체 기기 발송 확인란을 확인하고 발송합니다.

발송 결과의 `success`는 FCM API가 요청을 수락했다는 의미이며 실제 화면 표시나 사용자 확인을
증명하지 않습니다. `total=0`이면 운영 앱에서 알림 권한을 허용한 사용자가 로그인한 뒤
`registerPushDevice` 호출에 성공했는지 먼저 확인합니다.

## 배포 후 최소 실기기 확인

- TEST iPhone·Android 각각 한 대에서 기기 등록 후 수동 알림 수신
- 운영 내부 계정 iPhone·Android 각각 한 대에서 기기 등록 후 수동 알림 수신
- 앱 포그라운드, 백그라운드, 종료 상태의 표시와 소리
- 게임 시작, 내 차례, 게임 종료의 대상자와 중복 방지
- TEST 발송이 운영 기기에, 운영 발송이 TEST 기기에 도착하지 않음
- 운영 페이지 최근 발송 이력과 자동 푸시 집계 확인
