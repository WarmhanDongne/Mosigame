# REVIEW-A · 레인 A 휴대폰 검수 1회차

- 검수: Claude Code(맥), 2026-11-25
- 대상: `project00-lanes/lane-a`, 브랜치 `eleven/lane-a-phone`, HEAD `41831872` + 미커밋 변경(LOG-A 13:36 기록)
- 비교 기준: `docs/design/eleven/screens/P*.png`·`G*.png`, `motion-frames/02_round/`·`06_early-end/`,
  `motion.md` 4절 ②·⑥ 키프레임

## 판정: FIX

구조와 배치는 시안과 잘 맞는다(P02·P05·P08·P10·P11·G4는 위치·크기·색이 거의 같다). 검증 명령도 내가
다시 실행해 모두 통과했다: `flutter test --no-pub` 131 통과(캡처 33건 skip), `flutter analyze` 문제 없음,
`dart format` 변경 0, 패키지 경계 0건, 디자인 가드 허용 목록 비움. 아래 A 항목을 고치고 스크린샷을 다시
만든 뒤 LOG에 "검수 요청: 예"를 남긴다. B 항목은 공통 부품이라 Claude가 고친다(레인 A는 손대지 않는다).

숫자 글꼴 차이(기준 PNG는 Stardos 없이 Noto로 그려짐)와 카드 모서리 점 간격은 FIX 대상이 아니다.

## A. 레인 A가 고칠 것

| # | 화면 | 차이 | 수정 지시 |
| --- | --- | --- | --- |
| A1 | 전체(fixture) | 검수 PNG의 상태가 기준 PNG와 달라 비교가 어렵다. G1–G5·P01 상단 점수가 `2 : 1`(뽑기 단계는 항상 `0 : 0`), P08이 `2 : 1`(기준 `3 : 1`, 결과 반영 뒤 점수), P10/P11이 `2 : 1`(기준 `6 : 2` / `2 : 6`), P05 쓴 타일이 4·8·1·3(기준 2·1·5·9) | `test/phone/screen_fixtures.dart`의 화면별 상태를 screens.md 4절 표(손패 `used`·`wait`·`sel`, 점수, 라운드)와 같게 맞춘다. 화면마다 따로 fixture를 둔다 |
| A2 | P06 | 자동 제출된 흑 0이 손패에서 “남은 타일”(잠김 .6)로 보인다. 서버는 제출한 타일을 `tiles`에서 뺀다 | fixture에서 제출 값은 `tiles`에 넣지 않는다(P04·P07·P08도 같은 규칙). 기준처럼 0은 `used` |
| A3 | P01·G1·G4·G8 등 안내 카드 | 내용이 기준보다 10–18px 위로 몰렸다(G4: 제목 y≈150 vs 157, 그림 줄 212 vs 225, 본문 270 vs 288) | screens.md 2-2 안내 카드 값으로 세로 간격을 맞춘다: 제목 34/900 `line-height 1.2`, 그림 줄 `margin 14 0 4`, 본문 `margin-top 12`·`line-height 1.35`, 보조 `margin-top 4`, 카드 `padding 16 40` 세로 가운데 |
| A4 | 모션 `02_round-*` | 0·700ms 프레임이 이미 6을 고른 P02다. 기준 프레임은 라운드 시작 직후라 선택 전(패널 빈 자리, 제출 버튼 흐림)이다 | 연출 시작 시점의 실제 상태로 찍는다: 0·700ms는 선택 전, 2900·3100ms는 기준 프레임과 같은 단계. 선택 전 패널 문구는 B3 키가 들어온 뒤 채우고, 그전에는 빈 자리 타일만 둔다 |
| A5 | 모션 `06_early-end-*` | 3950ms에 왕관이 아직 위쪽(y≈60)에 있고 WINNER가 흐리게 보인다. 기준은 3950ms에 G7→P10 전환이 끝났고 왕관은 아바타 위에 거의 내려왔으며 WINNER는 아직 없다 | B4 상수가 들어오면 그것으로 다시 맞춘다. 레인에서 시간 숫자를 새로 정하지 않는다 |
| A6 | 규칙 `?` 버튼 | `AlertDialog`에 문구 세 줄을 임의로 묶은 규칙 창이다(시안·기존 흐름에 없음) | 기존 `game_kit` `PhoneGameRulebookDialog`로 연다. 규칙 본문은 B5가 들어올 때까지 연결만 해 두고 LOG에 남긴다 |
| A7 | P05 요약줄 작은 타일 | `lib/phone/noir_view.dart`에서 `ElevenTileSpec(size: Size(22, 30), …)`을 직접 만들었다(디자인 값 결정) | B2의 공통 spec을 쓴다. 들어오기 전까지 지금 값 유지, LOG에 표시 |
| A8 | 기울어진 배지 | `Transform.rotate(angle: 8 * math.pi / 180)`, `top: -15, left: 16` 등 배지 회전·위치를 직접 정했다 | B2의 공통 배지 배치(회전 포함)를 쓴다. 들어오기 전까지 유지 |
| A9 | 나가기 버튼 | 테스트에서 아이콘 글꼴이 없어 네모로 찍힌다. 시안은 22×22 선 아이콘(stroke 2.6) | 검수 PNG에서 보이도록 `CustomPainter` 선 아이콘으로 그린다(색 `ElevenNoirColors.ink`, 선 굵기 2.6은 B2에 같이 들어온다). 의미 라벨은 지금처럼 유지 |
| A10 | 차례 전환 | 뽑기 차례(G1, G8 내 차례)가 와도 칩 반전·진동이 없다. 지금은 `turnUid`가 있는 제출 phase에서만 재생한다. 프로토타입 ①·⑧은 뽑기 차례에도 크림 반전 + 진동 1회 | `draw.nextPickerUid`가 나로 바뀔 때도 같은 연출을 한 번 재생한다(재접속 때는 재생 안 함) |

## B. Claude가 공통 부품에서 고칠 것 (레인 A 수정 금지)

| # | 내용 |
| --- | --- |
| B1 | 대시 상자(P04·P06·P07·P08 “결과는 태블릿에서 확인해요” 등)가 실선으로 나온다. 점선 그리기가 `noir_tile.dart` 안 비공개라 레인이 쓸 수 없다 → 공통 `ElevenNoirDashedBox` 추가 |
| B2 | 레인이 직접 정한 값을 공통으로: P05 요약줄 작은 타일 spec, 기울어진 배지 배치(`.auto` rotate 8°, top −12, left 22·P04 30), 아이콘 선 굵기 2.6 |
| B3 | 선택 전 패널 문구(프로토타입 ② “타일을 골라 주세요”, P03 미리 선택 전 문구) 키 추가 |
| B4 | 휴대폰 게임 종료 연출 상수(프로토타입 ⑥: G7→P10 교차 전환 250ms, 왕관 100ms 뒤 시작·250ms 낙하·8px 튐, WINNER 0.9→1.04→1 350ms). 지금 `ElevenGameEndMotion`은 MotionKit 칸 9 값만 있다 |
| B5 | ELEVEN 규칙 본문(룰북 markdown) |
| B6 | 안내 카드 승자 타일 외곽선(`outline 4px, offset 3px`, 번짐 없음) 상태와 안내 타일 모서리 숫자 — 지금 `win` 상태는 번짐이 있고 `phoneGuide` spec에 모서리 숫자가 없다(G4·G5 차이 원인) |
| B7 | P08 패배·동점 상태 문구와 후공 안내 문구: 하준 결정 대기(LOG-A의 요청 확인함). BLOCKED 유지가 맞다 |

B 항목이 기능 브랜치에 들어오면 Claude가 레인 A 브랜치에 반영 방법을 알린다. 그 뒤 A4·A5·A6·A7·A8·A9를
마무리한다. 나머지 A 항목(A1·A2·A3·A10)은 지금 바로 고친다.

## 다음

- Codex 입력: `docs/planning/eleven-lanes/REVIEW-A.md 반영`
- 다 고치면 LOG-A.md에 실행 결과와 "검수 요청: 예"를 남긴다. 2회차 검수는 같은 기준으로 한다.

## 추가 (2026-11-25): B1–B6 반영 완료

공통 부품이 `dbd9922d`로 들어왔고, 이 브랜치(`eleven/lane-a-phone`)를 그 커밋으로 fast-forward했다.
레인의 미커밋 작업은 그대로다(반영 뒤 analyze No issues, `flutter test` 141 통과·33 skip 확인).
이제 A4–A9도 아래 공통 부품으로 마무리한다.

| 항목 | 쓸 것 |
| --- | --- |
| B1 대시 상자 | `lib/shared/widgets/noir_dashed_box.dart` `ElevenNoirDashedBox(label: ...)` |
| B2 요약줄 타일·배지·아이콘 | `ElevenTileSpec.phoneSummaryMini`, `ElevenNoirTiltedBadge`(P04는 `left: ElevenNoirBadgeLayout.tiltedLeftP04`), `ElevenNoirIcon(ElevenNoirIconKind.exit)`, 요약줄 `ElevenNoirSpacing.summaryRow*` |
| B3 선택 전 패널 | `ElevenTileFace.placeholder`(`phonePanel` spec), `ElevenScreenCopy.pickTilePrompt`·`preselectPrompt`·`emptyValue` |
| B4 휴대폰 종료 연출 | `ElevenPhoneEndMotion`(교차 전환 250ms, 왕관 100ms 뒤 시작, WINNER 0.9→1.04→1). `ElevenGameEndMotion`은 휴대폰에서 쓰지 않는다 |
| B5 룰북 | `PhoneGameRulebookDialog(title: ElevenScreenCopy.rulebookTitle, markdown: ElevenScreenCopy.rulebookMarkdown)` |
| B6 안내 카드 타일 | `ElevenTileState.guideWin`·`guideLose`(G6은 `Opacity(ElevenNoirOpacity.guideLoserRoundResult)`), 안내 카드 간격 `ElevenNoirSpacing.guide*` |
| B7 | P08 패배·동점·후공 문구는 하준 결정 대기. 지금처럼 비워 둔다 |

## 추가 (2026-11-25): B7 해제 — P08 문구 확정

하준 결정으로 P08 문구가 정해졌다. 공통 문구가 `6dce2b69`로 들어왔고 이 브랜치를 fast-forward했다
(레인 미커밋 작업 그대로, analyze No issues). P08을 아래처럼 마무리하고 BLOCKED를 지운다.

| 경우 | 자리 | 키 |
| --- | --- | --- |
| 이김 | 상태 칩 | `ElevenScreenCopy.roundIWon`(지금처럼, 칩 빨강) |
| 짐 | 상태 칩 | `ElevenScreenCopy.roundOpponentWon`(칩 크림, “+” 배지 없음) |
| 동점 | 상태 칩 | `ElevenScreenCopy.roundTieStatus`(칩 크림) |
| 다음 라운드 선공 | 패널 표식·안내 | `firstMark` + `iPlayFirst`(지금처럼) |
| 다음 라운드 후공 | 패널 표식·안내 | `secondMark` + `iPlayAfterOpponent`. 표식은 선공 표식과 같은 모양·크기, 바탕은 잉크(`ElevenNoirColors.ink`) |

다음 라운드 선공·후공은 `lastRoundResult`로 정한다: 이긴 사람이 다음 선공, 동점이면 지금 선공이 그대로
(계약 2절). 서버 값을 기다리지 말고 이 규칙으로 표시만 한다.
검수 PNG `P08-lose`·`P08-tie`를 다시 만들고, 후공 안내가 보이는 `P08-second`도 하나 추가한다.

## 추가 (2026-11-25): 왕관·배경 공통 부품

`02e43e77`로 공통 왕관·배경이 들어왔고 이 브랜치를 fast-forward했다(레인 미커밋 작업 그대로).
레인 안에서 따로 그린 것도 공통으로 바꾼다.

- 왕관: `ElevenNoirCrown(size: ElevenNoirCrown.phoneSize)`, 겹침 `ElevenNoirCrown.phoneOverlap`. 레인 왕관 painter 삭제.
- 배경: `ElevenNoirStage`. `noir_view.dart`의 `_StageStripes` 삭제.
- 휴대폰에는 승리 조각이 없다(프로토타입 ⑥ 휴대폰 레이어). `_endController` 길이는 `ElevenPhoneEndMotion.total`로 바꾼다.

---

# REVIEW-A · 2회차 (2026-11-25)

- 대상: HEAD `02e43e77` + 미커밋 변경(LOG-A 18:13까지)
- 재실행: analyze No issues, `flutter test --no-pub` 148 통과·34 skip, format 변경 0, 경계 0건, 레인 밖 변경 없음.

## 판정: FIX (2건)

1회차 A1–A10, B7(P08 문구)이 반영됐다. P06(자동 제출 0이 쓴 타일), G4(안내 카드 세로 간격), P08 승·패·동점·
후공 변형, P10 왕관·WINNER, 06_early-end 3950ms 왕관 위치가 기준과 맞는다.

| # | 화면 | 차이 | 수정 지시 |
| --- | --- | --- | --- |
| A11 | P02·P05 선택 전(실제 화면) | 아직 타일을 고르지 않은 선공·후공 제출 버튼이 회색 잠김 모양(P03 “선공 제출 후 제출 가능”과 같은 바탕·테두리)이다. 프로토타입 ②는 빨강 제출 버튼을 투명도 .5로 흐리게 두고, 타일을 고르는 순간 또렷해지며 1.04배로 튄다(MotionKit 칸 2 “흐림 → 1.04배 → 복귀”) | 제출할 수 있는 단계(P02·P05·P09)는 선택 전에도 빨강 버튼 모양을 유지하고 `Opacity(ElevenTurnMotion.popStartOpacity)`로 흐리게, 누를 수 없게 둔다. 선택하면 `ElevenTurnMotion.pop*`로 1→1.04→1. 회색 잠김 모양은 P03(후공 미리 선택)에만 쓴다 |
| A12 | 모션 `02_round-*` | 0·700ms 프레임이 5R·점수 2 : 1·쓴 타일 있는 상태다. 프로토타입 ② 장면은 1라운드·0 : 0·쓴 타일 없음·타이머 0:42(0ms 기준 1:00에서 흐름) | 모션 프레임용 fixture는 motion.md 4절 ② 부제 장면(1R, A 선공, 0 : 0, 손패 11장 전부)으로 따로 만든다 |

다 고치면 `review_out/lane-a/`의 P02·P05·02_round-*를 다시 만들고 LOG에 "검수 요청: 예".

---

# REVIEW-A · 3회차 (2026-11-25)

- 대상: HEAD `02e43e77` + 미커밋 변경(LOG-A 18:31까지)
- 재실행: analyze No issues, `flutter test --no-pub` 152 통과·35 skip, format 변경 0, 경계 0건, 레인 밖 변경 없음.

## 판정: PASS

- A11: P02·P05 선택 전 제출 버튼이 빨강·투명도 .5로 흐리고 누를 수 없다. P03만 회색 잠김. 선택 시 180ms 안에
  또렷해지며 1.04배 pop(위젯 테스트로 확인).
- A12: `02_round-*`가 프로토타입 ② 장면(1R·0 : 0·손패 11장)이다. 700ms(선택 전 빈 자리·흐린 버튼)와
  3100ms(후공 B, 7 선택, 0:58, “A가 흑 타일을 냈어요”)가 기준 프레임과 같다.

참고(FIX 아님): `P05-unselected`에서 “타일을 골라 주세요” 라벨이 빈 자리 타일보다 약 20px 위에 있다
(요약줄 아래로 타일만 내려가서). 시안에 이 상태 PNG가 없어 판정 대상이 아니며, S6-M 스크린샷 검토 때 하준이
보고 결정한다.

레인 A는 S6-M 병합 대기. 더 고치지 않는다.
