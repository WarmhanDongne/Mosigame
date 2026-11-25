# S7 통합 실행 순서 (S6-M 병합 뒤 사용)

작성: 2026-11-25. S6-M 병합과 Claude 검수 후 현재 코드·화면 ID·로컬 도구를 재확인하고 실행한다. 이 레인에서는 실기기 결과를 주장하지 않는다.

1. **출발 상태 기록.** 병합 브랜치/HEAD와 `git status --porcelain`을 남긴다. `node -v`(22), `java -version`(21), `/usr/libexec/java_home -v 21`, `flutter --version`, `xcrun simctl list devices available`을 확인한다. Java 21이 없으면 3–4단계는 `BLOCKED`로 기록하고, 설치는 하준 승인을 받는다. 운영 Firebase 접근·배포는 하지 않는다.
2. **정적·서버 검사.** `cd functions && npm run build && npm run lint && node --test test/*.test.mjs`와 루트 `python3 tool/check_package_boundaries.py --max 0`을 실행한다. 에뮬레이터 시나리오는 기본 실행에서 `SKIP`이어야 한다. FAIL이면 해당 단계에서 멈추고 LOG에 재현 조건을 남긴다.
3. **로컬 에뮬레이터.** 루트에서 `node tool/emulator/local.mjs start`를 별도 터미널로 시작한다. `LOCAL READY`와 UI `http://127.0.0.1:4000`, Auth/RTDB/Firestore/Functions 포트 준비를 확인한다. 이 도구는 `demo-mosigame-e13`만 사용한다. 이전 S4의 RTDB 트리거 수 문제는 후속 기록에서 6개로 수정됐으나 현재 실행으로 재확인한다.
4. **callable 시나리오.** 에뮬레이터가 준비된 동안 루트에서 `ELEVEN_EMULATOR=1 GCLOUD_PROJECT=demo-mosigame-e13 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FIREBASE_DATABASE_EMULATOR_HOST=127.0.0.1:9000 FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 node --test functions/test/eleven-emulator.test.mjs`를 실행한다. 방 생성→2인 참가→ELEVEN 선택·자리→11라운드→결과→재인증 읽기→다시하기→오래된 명령 무시→수동 종료→다시하기→퇴장을 확인한다. 이 테스트는 로컬 카탈로그·방 데이터를 생성하고 자체 정리한다.
5. **시뮬레이터 3대.** `xcrun simctl list devices available`에서 iPad 1대와 iPhone 2대의 UDID를 각각 골라 `xcrun simctl boot <UDID>`로 켠다. 각 기기에 같은 debug 빌드를 설치하고 `flutter run -d <UDID> --dart-define=MOSIGAME_BACKEND=local`로 태블릿 1, 휴대폰 2 인스턴스를 연결한다. 로컬 계정은 `tool/emulator/local.mjs start`가 출력하는 `tablet@mosigame.test`, `phone1@mosigame.test`, `phone2@mosigame.test`를 쓴다. 화면·서버 상태를 함께 기록한다.
6. **화면 순서.** 방 생성·입장→2인 자리→T01/T02/P01→T03→T04/P02/P03→T05/P04/P05/P07→T07 또는 T08/P08→T09, 시간 초과 T06/P06, 마지막 타일 P09, 조기 종료 T10, 최종 동점 뽑기 T11/T12, 결과 T13/T13-B/P10/P11을 확인한다. 각 화면에 닉네임·실제 점수·본인 숫자만 보이는지, 태블릿 기록에는 색만 보이는지 확인한다. 짧은 연출은 녹화/프레임으로 기록하고 화면 포착 실패를 PASS로 간주하지 않는다.
7. **복구와 종료.** 연결 단절·재접속, 참가자 퇴장·제외, 다시하기 직후 수동 종료를 각각 새 방/판에서 확인한다. `winnerUid`·`finishReason`과 방 복귀 화면을 기록한다. [회귀 목록](REGRESSION.md)의 기존 게임별 항목도 실행한다.
8. **정리.** 앱 세 인스턴스를 종료하고 해당 시뮬레이터만 `xcrun simctl shutdown <UDID>`로 끈다. 에뮬레이터 시작 터미널에서 Ctrl+C를 누르고 `Local emulator ports released.`를 확인한다. `git status --porcelain`을 시작 상태와 비교해 레인 밖 변경·생성물을 보고한다. 테스트 결과는 명령, PASS/FAIL/BLOCKED, exit code, 기기·화면 ID와 함께 기록한다.

`node tool/emulator/local.mjs start`가 Functions 로드에서 막히면 `tool/emulator/functions.cjs`를 이 레인에서 수정하지 않는다. 트리거 개수와 실제 오류를 LOG의 `BLOCKED` 및 공유 파일 요청에 남기고 순수 테스트·문서 검증을 계속한다.
