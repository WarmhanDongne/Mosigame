# GAME-DEVICE-BOARD-01

게임 패키지 기기별 화면·흐름 구조 정리

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

- 검증 대기 전환일: 2026-09-17.
- 사용자 승인: 게임 패키지를 phone/tablet board 및 기기별 화면·Provider·Service·애니메이션 구조로 정리.
- 구현: 번들 게임 3개와 game_template의 진입점·흐름·세션 소유권 정리, 공용 셸의 문구 OFF 완료 처리.
- 다음 행동: 관련 검사 완료 후 사용자 승인으로 `validate --full` 실행. 삭제된 핵심 테스트의
  복원·추가 작성과 검증 배선은 [TEST-REGRESSION-01](TEST-REGRESSION-01.md#test-regression-01)에서 관리한다.
- 기록: [9월 작업 기록](../logs/2026-09.md#game-device-board-01).

<a id="phone-start-copy-removal-20261109"></a>
## 2026-11-09 — 휴대폰 시작·라운드 사전 문구 제거

- Final Call `phone_board.dart`의 `gameStart`·`roundIntro`에서 `GAME START`,
  `ROUND N` 문구와 전용 대기 연출을 제거했다. `PhoneGameShell`의 문구 OFF
  완료 콜백은 유지해 로컬 단계가 멈추지 않는다.
- Liar's Poker `phone_board.dart`의 `gameStart`·`roundIntro`·`tableIntro`에서
  `GAME START`, `ROUND N`, 기준 카드 문구를 제거했다.
  `LiarsPokerPhoneGameScreen` 초기화에서 시작 안내가 꺼진 구성은 문구
  완료 콜백을 기다리지 않고 손패 공개를 즉시 시작한다.
- 서버 준비, private hand 확인, `round`·`phase`, 카드 공개 완료 계약과
  Cloud Functions는 변경하지 않았다.
- 검증: board 구조 5개, Final Call 패키지 29개, Liar's Poker 패키지
  21개 PASS/exit0. 변경 6개 Dart 파일은 영문 임시 경로 분석 PASS/exit0.
  원본 한글 경로 분석은 기존 Flutter LSP JSON 절단으로 exit255였고,
  동일 소스 영문 경로에서 `No issues found`를 확인했다.
- `validate --full`, 실기기 확인, commit·push·배포는 미실행이다.
