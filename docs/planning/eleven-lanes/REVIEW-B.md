# REVIEW-B · 레인 B 태블릿 검수 1회차

- 검수: Claude Code(맥), 2026-11-25
- 대상: `project00-lanes/lane-b`, 브랜치 `eleven/lane-b-tablet`, HEAD `6dce2b69`(공통 부품 fast-forward 뒤) +
  미커밋 변경(LOG-B 17:18 기록)
- 비교 기준: `docs/design/eleven/screens/T*.png`, `motion-frames/01_draw`·`04_result`, `motion.md`, `data/animations.json`

## 판정: FIX

구조·회전 좌석·뽑기판·전적판·최종 화면이 시안대로 나왔다(T13은 거의 같다). 공통 부품 반영 뒤 내가 다시
실행한 결과: `flutter analyze` 문제 없음, `flutter test --no-pub` 126 통과·2 skip. 디자인 가드 허용 목록 비움,
`complete_phase` 1회·오래된 phase 억제 테스트도 확인했다. 아래 A 항목을 고치고 스크린샷을 다시 만든 뒤
LOG에 "검수 요청: 예"를 남긴다. B 항목은 Claude가 공통 부품으로 고친다.

숫자 글꼴 차이와 T13 패배 pill이 어두운 것(MotionKit 칸 9 확정값, 결정 1–9)은 FIX가 아니다.

## A. 레인 B가 고칠 것

| # | 화면 | 차이 | 수정 지시 |
| --- | --- | --- | --- |
| A1 | 정적 화면 PNG 전체 | `T05.png`·`T03.png` 등에 토스트가 없다. 기준 `<ID>.png`는 동작 줄이기 상태로 **마지막 토스트가 보이는** 정지 화면이다(screens.md 좌표 규칙) | `<ID>.png`는 마지막 토스트를 opacity 1로 둔 상태, `<ID>--base.png`는 토스트 없음, `--toastN`은 지금처럼 |
| A2 | fixture | 상태가 기준과 다르다. T05·T06·T07: 기준은 1–4R 기록(4R A 승, B 선공)·A 점수 2·B 1인데 검수 PNG는 1–3R·A 3. 모션 `04_result-*`는 프로토타입 ④(1라운드, 0 : 0, 기록 없음) 장면이어야 하는데 T05 상태를 썼다 | `test/tablet/screen_fixtures.dart`를 screens.md 4절 표(전적 행·점수·pill·슬롯)와 같게 맞춘다. 모션 프레임은 motion.md 4절 각 프로토타입 부제의 장면(라운드·점수·뽑은 숫자)으로 만든다 |
| A3 | T07 | 진 쪽(B) 점수 옆에 `+0` 배지가 있다. 기준 T07은 이긴 쪽에만 `+1`, 진 쪽은 배지 없음. `+0`은 동점(T08) 양쪽에만 | 배지 규칙: 승 `+1`(이긴 쪽만), 동점 `+0`(양쪽), 패 없음 |
| A4 | T03 | B가 고른 카드에도 빨간 외곽선이 있다. 기준은 이긴 쪽(A)만 `pickA` 외곽선, B는 표식만 | 공개 뒤 외곽선은 `draw.winnerUid` 카드에만 |
| A5 | T01–T03·T11–T12 슬롯 | A측 슬롯이 기준보다 약 20px 위, B측은 약 20px 아래로 밀렸다(좌석 로컬 좌표로 같은 쪽 치우침). 뽑기 화면에 점수 칸이 없어 줄 가운데 정렬이 달라진 것으로 보인다 | screens.md 2-1 `.side` 줄 구성 그대로: [116px 빈칸 · 슬롯 · 점수 자리(116px, 뽑기 화면은 비움)]. 슬롯 로컬 x=318 |
| A6 | 전적판(T04–T09) | 열 머리 A·B가 칸 가운데가 아니다(A x≈434, 기준 453 / B 759, 기준 741). 행 시작이 기준보다 약 14px 위(1R 칸 top 52, 기준 66) | screens.md 4절 좌표: 열 머리 `364,37,466,19`, 행 `364, 63 + 67n, 466, 64`, 칸은 `grid 1fr 110px 1fr` 안 가운데 |
| A7 | 전적판 동점 행 | “동점” 아래 `=`가 없다 | `ElevenScreenCopy.historyTie` + `historyTieMark`(24px, line-height .8 → 공통 글자 스타일 요청 B4) |
| A8 | 전적판 진 칸 | 진 칸의 “선” 배지가 흐려지지 않는다(기준 2R A칸·4R B칸은 배지까지 .38) | 배지를 칸과 같은 `Opacity` 안에 둔다 |
| A9 | 점수 | A측 점수 블록이 기준보다 약 15px 아래, B측 약 20px 위 | `.score` 로컬 `482,149,116,120` 기준으로 맞춘다 |
| A10 | 메뉴 아이콘 | 레인 안 `_MenuIconPainter`로 그렸다 | 공통 `ElevenNoirIcon.tablet(ElevenNoirIconKind.rules / settings)`로 바꾸고 레인 painter 삭제 |
| A11 | 규칙 버튼 | 뽑기 규칙 두 줄만 연다(LOG 요청) | 공통에 들어왔다: `TabletGameRulebookDialog`(game_kit)에 `ElevenScreenCopy.rulebookTitle`·`rulebookMarkdown` |
| A12 | 왕관·조각·배경 무늬 | `_CrownPainter`, `_StageStripePainter`를 레인에서 따로 그렸다(레인 A에도 같은 것이 있다) | B1·B2가 들어오면 공통 위젯으로 바꾸고 레인 painter 삭제 |

## B. Claude가 공통 부품에서 고칠 것 (레인 B 수정 금지)

| # | 내용 |
| --- | --- |
| B1 | 왕관 위젯(screens.md 2-1 svg path, 태블릿 54×34·휴대폰 76×44)과 조각 6개: 10×10, 테두리 2px 잉크, 반경 2, 크림·경고 빨강 번갈아(`kESp0–5` 원자료), 왕관 가운데에서 출발. LOG-B 요청의 “조각 크기”는 원자료에 있었다 |
| B2 | `.stage` 배경(테이블 색 + 135° 사선 무늬) 공통 위젯 |
| B3 | 전적칸 모서리 점: 기준 PNG의 전적칸에 점이 있다(측정: 오른쪽에서 7px·위 10.2px, 반지름 1.2). 지금 `ElevenTileSpec.historyCell`에 빠져 있다 |
| B4 | 전적 동점 기호 `=` 글자 스타일(24/900 보조색, line-height .8) |

B가 들어오면 이 브랜치를 fast-forward하고 이 파일 끝에 알린다. 그 전에 A1–A11을 고친다.

## 다음

- Codex 입력: `docs/planning/eleven-lanes/REVIEW-B.md 반영`
- 다 고치면 LOG-B.md에 실행 결과와 "검수 요청: 예"를 남긴다.

## 추가 (2026-11-25): B1–B4 반영 완료

공통 부품이 `02e43e77`로 들어왔고 이 브랜치를 fast-forward했다(레인 미커밋 작업 그대로). A12를 마무리한다.

| 항목 | 쓸 것 |
| --- | --- |
| B1 왕관·조각 | `lib/shared/widgets/noir_crown.dart`: `ElevenNoirCrown()`(54×34, 겹침 `ElevenNoirCrown.tabletOverlap`), `ElevenNoirSparkBurst(progress: …)`(왕관 가운데에 둔다. 진행 시간은 `ElevenGameEndMotion.sparkDelay` 뒤 `sparkTravel` 980ms) |
| B2 배경 | `lib/shared/widgets/noir_stage.dart`: `ElevenNoirStage(child: …)` |
| B3 전적칸 점 | `ElevenTileSpec.historyCell`에 들어갔다. 따로 할 일 없음 |
| B4 동점 행 | `ElevenNoirText.historyTie()` + `ElevenNoirText.historyTieMark()` |

레인의 `_CrownPainter`, `_StageStripePainter`, `_MenuIconPainter`(A10)는 지운다.

---

# REVIEW-B · 2회차 (2026-11-25)

- 대상: HEAD `02e43e77` + 미커밋 변경(LOG-B 18:21까지)
- 재실행: analyze No issues, `flutter test --no-pub` 130 통과·2 skip, format 변경 0, 경계 0건, 레인 밖 변경 없음.

## 판정: PASS

1회차 A1–A12가 반영됐다. T05는 전적 1–4R·점수·pill·시간 바·토스트까지 기준과 같고, T03은 이긴 쪽만 외곽선·
슬롯 위치 정상, T07 배지 규칙(승자만 `+1`), 동점 `=`, 진 칸 “선” 배지 흐림, 열 머리·행 좌표, T13-B,
프로토타입 ④ 1400ms 장면(1R·0 : 0)이 맞다. 레인 painter 3개 삭제, 공통 아이콘·왕관·조각·배경·룰북 연결 확인.

참고(FIX 아님):
- 설정 톱니 아이콘 모양은 공통 `ElevenNoirIcon`이 시안 svg와 다르다(Claude 공통 부품에서 다룬다).
- 토스트 이름은 닉네임(“Ann 승리”)이다. 레인 공통 규칙대로다.
- 실제 태블릿 양쪽 가독성은 S8 D15.

레인 B는 S6-M 병합 대기. 더 고치지 않는다.
