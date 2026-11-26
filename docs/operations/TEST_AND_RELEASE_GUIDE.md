# TEST·실기기·스토어 배포 가이드

이 문서는 개발 후보를 TEST Firebase에서 검증하고 스토어 배포 뒤 `main`으로 보내는 현재
절차입니다. production 접근과 실제 배포는 항상 별도 사용자 승인이 필요합니다.

## 1. 흐름

```text
jinsung 작업 → TEST → develop → 스토어 배포 → main
```

1. `jinsung`에서 작업하고 [`MOSIGAME_SYSTEM_MAP.html`](../engineering/MOSIGAME_SYSTEM_MAP.html)을
   현재 코드에 맞게 갱신합니다.
2. 최신 원격 `TEST`와 `develop`을 fetch합니다.
3. `jinsung` 후보를 `TEST`에서 테스트 Firebase로 실행합니다.
4. Cloud Functions 변경이 있으면 테스트 프로젝트에 먼저 배포합니다.
5. 휴대폰·태블릿 실기기에서 관련 흐름과 혼합 버전 호환성을 확인합니다.
6. 사용자 컨펌 후 검증된 `jinsung` 커밋을 `develop`에 병합합니다.
7. 스토어 제출 전 FULL과 최종 실기기 체크를 다시 수행합니다.
8. 실제 App Store·Google Play 배포 완료 뒤 `develop`을 `main`에 반영합니다.

## 2. TEST 앱 실행

```bash
flutter run --dart-define=MOSIGAME_BACKEND=test
```

앱 로그에서 선택된 Firebase backend가 TEST인지 확인합니다. 운영 기본 앱이 네이티브에서
초기화돼 있어도 제품 코드는 이름이 있는 `mosigame-test` 앱을 사용해야 합니다.

## 3. TEST Functions 배포

전체 후보를 테스트 프로젝트에 배포할 때:

```bash
npm --prefix functions run deploy:test -- --project=ban-pick-simulator
```

이 스크립트는 운영 project ID와 `default`를 거부하고 `firebase.test.json`을 사용합니다.
배포 전후 Functions build·test와 앱의 동일 TEST 프로젝트 연결을 확인합니다.

## 4. 운영 배포 보호

- 프로젝트를 생략한 `firebase deploy`를 실행하지 않습니다.
- 운영 별칭은 `mosigame-production`이며 TEST 검증과 분리합니다.
- 변경한 함수만 `functions:<name>`으로 명시합니다.
- 앱이 새 함수와 동작하는지, 새 함수가 기존 앱과 동작하는지 양방향으로 확인합니다.
- 함수 삭제, rules, Auth provider, Firestore catalog, migration은 각각 별도 승인합니다.
- 앱 배포라는 이유로 Cloud Functions 전체를 다시 배포하지 않습니다.
- 배포 결과에는 project, 함수 목록, source commit, 명령, exit code와 사후 확인을 기록합니다.

## 5. 실기기 최소 확인

- iPhone과 iPad
- Android 휴대폰과 태블릿
- 로그인·회원가입·로그아웃·회원탈퇴 관련 변경 범위
- 방 생성, QR 참가, 자리 배치, 게임 시작과 종료
- 네트워크 단절·복귀, background/resume
- 변경 게임의 전체 한 판과 다시하기·퇴장
- 기존 앱/새 Functions와 새 앱/기존 Functions 혼합 버전
- TEST 프로젝트의 Auth·RTDB·Firestore·Storage·Functions 일치

## 6. 현재 공개 계획

공개 예정:

```text
liars_poker
final_call
yut
strategy_yut
russian_roulette
```

보류:

```text
mafia
holdem
strategy_yut_edition
```

registry에 있다는 이유로 보류 게임의 Firestore `enabled`를 켜지 않습니다. 공개 플래그는
앱·Functions·rules·실기기·스토어 후보가 모두 준비된 뒤 별도 승인으로 변경합니다.

## 7. 스토어 후보

현재 source 버전은 `1.0.1+9`입니다. 실제 스토어에서 사용 가능한 다음 build 번호와 제출
상태는 콘솔에서 사람이 확인해야 합니다. 문서의 과거 `1.0.0+7` 명령을 재사용하지 않습니다.

Shorebird release·patch는 현재 source와 store base version을 다시 확인해 실행하며 asset,
plugin/native code, plist·entitlement·manifest 변경은 patch가 아니라 새 스토어 릴리스로
처리합니다.

## 8. 기록

최종 보고에는 다음을 남깁니다.

- Issue·브랜치·commit·PR
- 앱 버전과 source commit
- TEST 앱과 Functions project
- 변경 함수와 rules
- 실행한 검증 명령, status, exit code
- 실제 기기·OS·빌드·결과
- 미실행 검증과 남은 위험

과거 1.0.0 출시 준비와 세부 체크는 `STORE_RELEASE_CHECKLIST.md`, 과거 실기기·성능 결과는
날짜가 붙은 operations 문서에 증거로 보존합니다.
