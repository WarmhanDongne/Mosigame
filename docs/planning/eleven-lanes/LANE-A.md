# ELEVEN-01 레인 A · 휴대폰 화면 (P01–P11, G1–G8)

먼저 `docs/planning/eleven-lanes/LANES-COMMON.md`를 읽고 그 규칙을 모두 따른다.
작업 트리: `~/Developer/projects/project00-lanes/lane-a`, 브랜치 `eleven/lane-a-phone`.

## 1. 목표

S4 임시 골격 휴대폰 화면을 시안 A 느와르 화면으로 바꾼다. 휴대폰은 가로 844×390 기준이다.
기존 동작(로컬 선택·제출 명령·예비 `timeout_turn`·퇴장 창·복구 레이어·승부 없는 종료 시 방 복귀)은
그대로 유지한다. 한국어 문구로 기능과 화면을 먼저 완성한다(번역은 S7).

## 2. 수정 가능 경로

- `packages/game_eleven/lib/phone/**`
- `packages/game_eleven/test/phone/**`(허용 목록 `design_guard_allowlist.dart`, `tile_rack_test.dart` 포함)
- `docs/planning/eleven-lanes/LOG-A.md`
- `packages/game_eleven/review_out/lane-a/**`(git 제외, 커밋 안 함)

`lib/phone/widgets/tile_rack.dart`처럼 S4 골격 위젯을 지우거나 바꾸면 그 테스트도 같은 레인에서 고친다.

## 3. 먼저 읽을 것

1. `docs/engineering/ELEVEN_GAME_CONTRACT.md` 4절(데이터 경계)·5절(명령)·7절(화면 대응)
2. `docs/design/eleven/README.md`, `screens.md` 1절(토큰)·2-2절(휴대폰 부품)·4절의 P01–P11·G1–G8,
   기준 PNG `docs/design/eleven/screens/P*.png`, `G*.png`
3. `docs/design/eleven/motion.md` 3절 MotionKit 칸 2(차례 전환)·9(게임 승패), 4절 프로토타입 ①②③④⑥⑦⑧의
   휴대폰 레이어, 5절(정적 화면 반복 연출 — 결정 2에 따라 MotionKit 값을 쓴다)
4. `docs/planning/eleven-lanes/S5-0B.md` 3절(디자인 모순 결정)
5. 현재 코드: `lib/phone/phone_board.dart`, `lib/phone/src/board_state.dart`,
   `lib/phone/providers/game_stage.dart`(`resolveElevenPhoneScreen`), `lib/shared/**`

## 4. 만들 것

- 화면 고르기는 `resolveElevenPhoneScreen` 하나로 한다. 입력 가능 여부는 기존 `ElevenPhoneStage`를 쓴다.
  - `roundResultRevealed`: `roundResult` 진입 뒤 `ElevenRoundFlowMotion.toastAt`(1.4초)까지 false(G6) → 이후
    true(P08). 재접속으로 이미 지난 결과를 받으면 바로 true.
  - `gameEndRevealed`: 조기 종료 진입 뒤 `ElevenGameEndFlowMotion.crownAt`(3.7초)까지 false(G7) → 이후 true.
- 공통 틀(screens.md 2-2): 상단 바(플레이어 칩·상태 칩·규칙 `?`·나가기 버튼), 본문(손패 2줄 + 오른쪽 패널),
  안내 카드(P01·G1–G8). 손패는 흑 줄 `[0,2,4,6,8,11]`, 백 줄 `[1,3,5,7,9]` 순서이고 `ElevenNoirTile`
  (`ElevenTileSpec.phoneHand`)로 그린다. 상태: 남은 타일 보통, 쓴 타일 `used`, 고른 타일 `selected`
  (배지 `ElevenScreenCopy.selectedBadge`), 제출 뒤·차례 아님 `locked`.
- 상태 칩: 내 차례면 빨강(`ElevenNoirColors.red`) 바탕 크림 글자, 아니면 크림 바탕. 태그는
  `ElevenScreenCopy.tag*`. 타이머는 서버 `turnDeadlineAt` 기준 `m:ss`(기존 `GameTurnCountdown` 사용).
- 화면별 문구는 `ElevenScreenCopy`에서 screens.md 4절과 같은 자리에 쓴다. 값 자리(점수 `x : y`, 타이머,
  타일 숫자)는 실제 값이다.
- P08: `game.roundOutcomeFor(uid)`로 승·패·동점. 시안에는 승리 문구(`roundIWon`)와 선공 안내
  (`iPlayFirst`)만 있다. 패배·동점 상태 문구와 후공 안내 문구는 없으므로 만들지 않고, 그 자리는 태그와
  점수만 보이게 둔 뒤 LOG "공유 파일 요청"에 `ElevenScreenCopy` 키 요청을 적는다(BLOCKED 항목, 하준 결정 대기).
- P10/P11: 왕관(screens.md 2-1 svg path)·승자 아바타·이름·WINNER·안내. P11도 승자를 그대로 보여 준다(결정 10).
  왕관 svg는 `CustomPainter`로 그리되 색은 토큰을 쓴다.
- 연출(상태가 바뀔 때 한 번):
  - 차례 전환: `ElevenTurnMotion` — 칩 크림 0.5초 → 빨강, ±3px 흔들림, 진동 `HapticFeedback` 1회,
    제출 버튼 흐림 → 1.04배 → 복귀.
  - 화면 레이어 교차 전환 `ElevenPhoneLayerMotion.crossFade`.
  - P10/P11 왕관 낙하·조각 6개 `ElevenGameEndMotion`(진동 없음).
- 작은 화면(667×375)과 긴 닉네임(12자 이상)에서 넘침 없이 그려지게 한다(말줄임).

## 5. 테스트와 검수 산출물

- `test/phone/screen_widget_test.dart`(이름 자유): P01–P11, G1–G8 각각 대표 상태를 서버 snapshot으로
  만들어 위젯을 그리고, 핵심 문구·버튼 활성 여부·숫자 비공개(상대 숫자 없음)를 확인한다.
  P02 제출 → 명령 호출, P03 제출 버튼 잠김, P06 자동 제출 값 표시, P09 마지막 타일 제출을 포함한다.
- 기존 `test/phone/game_stage_test.dart`, `screen_test.dart`는 지우거나 약하게 바꾸지 않는다.
- `test/phone/review_capture_test.dart`: 844×390으로 P01–P11, G1–G8(P08은 `P08`·`P08-lose`·`P08-tie`)을
  `review_out/lane-a/`에 저장한다. 모션은 프로토타입 ② 차례 전환(`02_round-` 0·700·2900·3100ms 부근),
  ⑥ 휴대폰 P10 왕관(`06_early-end-` 3700·3800·3950·4050·4200·4450ms)을 연출 시작 기준으로 맞춰 찍는다.
  667×375 작은 화면 P02·P05 두 장(`P02-small`, `P05-small`)도 찍는다.
- LANES-COMMON.md 7절 검증을 모두 실행하고 LOG-A.md에 남긴 뒤 "검수 요청: 예".

## 6. 완료 기준

- 19개 화면(P01–P11, G1–G8)이 시안 구조로 그려지고 위젯 테스트가 있다.
- `test/phone/design_guard_allowlist.dart`가 비었거나, 남은 항목의 이유가 LOG에 있다.
- 패키지 테스트 전체·analyze·format·경계 검사 PASS, 레인 밖 변경 없음.
- `review_out/lane-a/` 스크린샷·모션 프레임 생성, Claude 검수 PASS(REVIEW-A.md).
