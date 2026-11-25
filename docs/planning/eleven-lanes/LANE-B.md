# ELEVEN-01 레인 B · 태블릿 화면 (T01–T13, T13-B)

먼저 `docs/planning/eleven-lanes/LANES-COMMON.md`를 읽고 그 규칙을 모두 따른다.
작업 트리: `~/Developer/projects/project00-lanes/lane-b`, 브랜치 `eleven/lane-b-tablet`.

## 1. 목표

S4 임시 골격 태블릿 화면을 시안 A 느와르 화면으로 바꾼다. 태블릿은 가로 1194×834 기준이며 양쪽에
앉은 두 사람이 읽도록 A측(왼쪽)·B측(오른쪽) 영역을 돌려 그린다. 기존 진행 책임(뽑기 입력,
연출 뒤 `complete_phase`, 마감 뒤 `timeout_turn`, 설정·수동 종료, 다시하기·HOME, 승부 없는 종료 시 방 복귀,
복구 레이어)은 그대로 유지한다. `AppOrientation` 규칙은 바꾸지 않는다.

## 2. 수정 가능 경로

- `packages/game_eleven/lib/tablet/**`
- `packages/game_eleven/test/tablet/**`(허용 목록 `design_guard_allowlist.dart`, `draw_grid_test.dart` 포함)
- `docs/planning/eleven-lanes/LOG-B.md`
- `packages/game_eleven/review_out/lane-b/**`(git 제외, 커밋 안 함)

## 3. 먼저 읽을 것

1. `docs/engineering/ELEVEN_GAME_CONTRACT.md` 3절(상태도)·4절·5절·6절·7절
2. `docs/design/eleven/README.md`, `screens.md` 1절·2-1절(태블릿 부품)·3절(뽑기 9장)·4절 T01–T13·T13-B,
   기준 PNG `docs/design/eleven/screens/T*.png`(토스트 변형 `--base`, `--toastN` 포함)
3. `docs/design/eleven/motion.md` 1–4절 전체(프로토타입 ①–⑧의 태블릿 레이어, MotionKit 1·3–9)
4. `docs/planning/eleven-lanes/S5-0B.md` 3절
5. 현재 코드: `lib/tablet/tablet_board.dart`, `lib/tablet/src/board_state.dart`,
   `lib/tablet/providers/game_stage.dart`(`resolveElevenTabletScreen`), `lib/shared/**`

## 4. 만들 것

- 화면 고르기는 `resolveElevenTabletScreen` 하나로 한다. 연출 플래그:
  - `roundIntroActive`: 2라운드부터 `firstSubmit` 진입 뒤 T09 토스트(`ElevenToastSchedule.roundIntro`)가 도는 동안.
  - `roundResultRevealed`: 자동 제출이 있던 라운드는 `roundResult` 진입 뒤 `ElevenRoundFlowMotion.emphasisAt`
    전까지 false(T06).
  - `gameEndRevealed`: 조기 종료 진입 뒤 `ElevenGameEndFlowMotion.finalScreenAt`(3.3초)까지 false(T10).
  - 재접속으로 이미 지난 상태를 받으면 연출 없이 최종 상태(플래그 true)로 그린다.
- 배치(screens.md 1-5·2-1): 바탕 `.stage`(테이블 색 + 사선 무늬), 회전 영역 `.side` 760×320을
  A는 `quarterTurns: 1`, B는 `quarterTurns: 3`으로 그린다(로컬 좌표를 그대로 쓴다). 화면이 1194×834와
  다르면 전체를 비율 유지로 맞춘다(`FittedBox` 등). 오른쪽 위 메뉴(규칙·설정 72×72)는 기존 설정 창과
  게임 규칙 열기를 연결한다.
- 회전 영역: 상태 pill(내 차례·상대 차례·선택 완료·제출 완료·자동 제출·승리·패배·동점·게임 종료) →
  시간 바(제출 phase, `ElevenTimeBarMotion`, 서버 deadline 기준 선형, 남은 10초부터 진한 빨강) →
  슬롯(`ElevenTileSpec.tabletSlot`, 뽑기 화면은 `tabletDrawSlot`) · 점수(라벨 + 숫자 + `+1`/`+0` 배지).
- 중앙: 뽑기판 3×3 9장(`ElevenTileSpec.drawCard`, `ElevenDrawView.canPick`으로 누를 수 있는 위치만,
  누르면 기존 `pickDrawTile`, A쪽 표식·`picked`, 공개 뒤 숫자는 A쪽 `numberQuarterTurns: 1`·B쪽 `3`,
  남은 카드 `dim`) / 전적판 11행(controller 기록, `ElevenTileSpec.historyCell`, 승 `win`·패 `lose`,
  선공 칸 “선” 배지, 가운데 `◀ 승`·`승 ▶`·`동점 =`·라운드 번호, 진행 전 행은 빈칸) / 최종 화면(T13
  “최종 점수 x : y”, T13-B “승자 / 이름”, 다시하기·HOME 버튼, 안내 문구, 승자 쪽 왕관).
- 중앙 토스트: `ElevenToastSequence` + `ElevenToastSchedule`(T01–T12). 뽑기 공개는
  `ElevenDrawMotion.revealToastAt`·`resultToastAt` 시점에 나눠 띄운다. `playKey`는 phase·round·revision 조합.
- 연출(상태가 바뀔 때 한 번): 뽑기 카드 딜·집기·뒤집기(`ElevenDrawMotion`, `ElevenFlipMotion`), 슬롯 딜
  (`ElevenDealMotion`), 결과 강조(`ElevenResultMotion`), 점수 넘김·+1(`ElevenScoreMotion`), 전적행 채우기
  (`ElevenHistoryRowMotion`), 판 모핑, 왕관·조각·pill(`ElevenGameEndMotion`).
- `complete_phase` 시점은 이미 `ElevenTiming.drawReveal`(4.7초)·`roundResult`(3.2초)로 맞춰져 있다. 바꾸지 않는다.
- 숫자 비공개: 본 게임 슬롯·전적칸은 색만. 숫자는 공개된 공용 뽑기 카드에만 그린다.

## 5. 테스트와 검수 산출물

- `test/tablet/screen_widget_test.dart`(이름 자유): T01–T13, T13-B 대표 상태 위젯 테스트. 뽑기 탭 →
  `pickDrawTile(slot)`(slot 0–8, 고른 위치·범위 밖 불가), 전적판 11행과 승·패·동점 표시, 숫자 비공개,
  다시하기·HOME 버튼 동작, 연출 뒤 `complete_phase` 1회 호출을 포함한다.
- 기존 `test/tablet/game_stage_test.dart`, `screen_test.dart`는 지우거나 약하게 바꾸지 않는다.
- `test/tablet/review_capture_test.dart`: 1194×834로 T01–T13, T13-B와 토스트 유지 구간 변형
  (`T03-toast1`처럼 screens.md 4절의 `--toastN` 시점)을 `review_out/lane-b/`에 저장한다. 모션은 프로토타입
  ①–⑧의 motion.md “기준 프레임” 시점마다 태블릿 부분을 `<폴더>-<ms>` 이름으로 찍는다.
- LANES-COMMON.md 7절 검증을 모두 실행하고 LOG-B.md에 남긴 뒤 "검수 요청: 예".

## 6. 완료 기준

- 14개 화면(T01–T13, T13-B)이 시안 구조로 그려지고 위젯 테스트가 있다.
- `test/tablet/design_guard_allowlist.dart`가 비었거나, 남은 항목의 이유가 LOG에 있다.
- 패키지 테스트 전체·analyze·format·경계 검사 PASS, 레인 밖 변경 없음.
- `review_out/lane-b/` 스크린샷·모션 프레임 생성, Claude 검수 PASS(REVIEW-B.md).
- 실제 태블릿을 세워 양쪽에서 읽는 확인은 S8 D15로 미룬다.
