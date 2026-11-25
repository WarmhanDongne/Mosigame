# ELEVEN-01 레인 공통 규칙 (레인 A·B·C 모두)

작업 방식 원본: 노션 '개발 계획·검증·출시' 하위 'ELEVEN S5–S7 작업 방식 · Claude·Codex 병렬 운영 ·
2026-11-25'. 이 파일과 다르면 그 페이지가 우선한다. 레인 지시문(LANE-A/B/C.md)은 이 파일을 먼저 읽은
뒤 읽는다.

## 1. 출발점과 작업 트리

- 출발점: S5-0 기준 커밋(feature/black-and-white-ui). 레인 worktree는 `scripts/eleven_lanes.sh`가
  `~/Developer/projects/project00-lanes/<레인>`에 만든다.

  | 레인 | 폴더 | 브랜치 |
  | --- | --- | --- |
  | A 휴대폰 | `project00-lanes/lane-a` | `eleven/lane-a-phone` |
  | B 태블릿 | `project00-lanes/lane-b` | `eleven/lane-b-tablet` |
  | C 통합 준비 | `project00-lanes/lane-c` | `eleven/lane-c-integration` |

- 자기 worktree 폴더 안에서만 작업한다. 다른 레인 폴더와 원본 `project00` 폴더는 읽기만 한다.
- 브랜치를 바꾸거나 새로 만들지 않는다. rebase·reset·stash·merge를 하지 않는다.
- 커밋·push·배포·새 dependency·`validate --full`·운영 Firebase 접근을 하지 않는다(하준 승인 대상).
  작업 결과는 커밋하지 않은 채 worktree에 남긴다. 병합은 S6-M에서 Claude Code가 한다.
- AGENTS.md 1절(Issue·담당자 브랜치)은 이 레인 작업에 적용하지 않는다. 레인 브랜치는 작업 방식
  페이지 4절이 정했다. 그 밖의 AGENTS.md 규칙(생성 파일 직접 수정 금지, 서버 권위, 데이터 경계)은 따른다.

## 2. 파일 소유권

| 영역 | 레인에서 |
| --- | --- |
| `docs/design/eleven/**`(기준 PNG·screens.md·motion.md·data·motion-frames) | 읽기만 |
| `docs/engineering/ELEVEN_GAME_CONTRACT.md`, `functions/src/**`, `database.rules.json` | 수정 금지 |
| `packages/game_eleven/lib/shared/**`, `lib/game_copy.dart`, `lib/game_theme.dart`, `lib/game_eleven.dart` | 수정 금지 |
| `packages/game_eleven/test/shared/**`, `test/support/**` | 수정 금지 |
| 루트·패키지 `pubspec.yaml`, `assets/**`, arb, `.gitignore`, `tool/**`, `scripts/**` | 수정 금지 |
| `docs/planning/tasks/ELEVEN-01.md`, `docs/planning/ELEVEN_HANDOFF.md`, `TASKS.md` | 수정 금지 |
| 자기 레인 경로(각 지시문 2절)와 `docs/planning/eleven-lanes/LOG-<레인>.md` | 수정 |

공유 파일 수정이 필요하면 고치지 말고 LOG의 "공유 파일 요청"에 적는다. S6-M 병합에서 한 번에 반영한다.

## 3. 디자인 값 규칙 (레인 A·B)

- 색·글꼴·크기·간격·반경·그림자·연출 시간·곡선을 정하지 않는다. 다음에서만 가져온다.
  - 토큰: `lib/shared/noir/noir_tokens.dart`(`ElevenNoirColors`·`Radius`·`Border`·`Shadow`·`Opacity`·`Spacing`)
  - 글자: `lib/shared/noir/noir_text.dart`(`ElevenNoirText`)
  - 모션: `lib/shared/noir/noir_motion.dart`(`ElevenCurves`, `Eleven*Motion`), `lib/shared/models/timing.dart`
  - 토스트: `lib/shared/noir/noir_toast_schedule.dart`, `lib/shared/widgets/noir_toast.dart`
  - 타일: `lib/shared/widgets/noir_tile.dart`(`ElevenNoirTile`, `ElevenTileSpec`, `ElevenNoirBadge`)
  - 문구: `lib/game_copy.dart`의 `ElevenScreenCopy`(원문 그대로, 새 문구 금지)
  - 화면 결정: `resolveElevenPhoneScreen` / `resolveElevenTabletScreen`(각 `providers/game_stage.dart`)
- screens.md의 크기·위치 숫자(예: 패널 268px, 슬롯 줄 간격 40px)는 토큰에 있으면 토큰을 쓰고, 없는
  배치 숫자(특정 요소의 x·y)는 레이아웃 계산에만 쓴다. 색·글꼴·시간·곡선은 숫자로 쓰지 않는다.
- `test/shared/design_guard_test.dart`가 `lib/phone/**`, `lib/tablet/**`에서 `Color(0x`, `Colors.`,
  `fontFamily:`, `TextStyle(` 직접 생성, 숫자 `Duration(`, `Curves.`, `Cubic(`을 찾으면 실패한다.
  S4 골격의 기존 위반은 자기 레인 허용 목록(`test/phone|tablet/design_guard_allowlist.dart`)에 있다.
  화면을 바꿔 그 줄이 사라지면 허용 목록에서도 지운다. 새 항목은 추가하지 않는다.
- 토큰·공통 부품에 없는 값이 필요하면 만들지 말고 LOG에 요청하고 BLOCKED 항목으로 남긴다.
  그 부분만 비워 두고 나머지는 계속한다.
- 시안끼리 다른 값은 S5-0B.md 3절 결정을 따른다(모션 키트 확정값 우선, 뽑기 카드 색 짝수 흑·홀수 백,
  P11도 승자 표시, P01·G1 같은 화면).
- 사람 표시: 문구의 `who`(“A가 …”, “A 승리”)에는 실제 닉네임을 넣는다. 아바타·A/B 표식 원 안의 글자는
  좌석 표시(seatIndex 0 = A, 1 = B)다. 숫자·점수는 실제 public·private 값이다.
- 숫자 비공개: 태블릿 본 게임 슬롯·전적칸은 색만 그린다. 휴대폰은 본인 숫자만 그린다. 공개된 공용 뽑기
  숫자(`draw.revealed`) 외의 숫자를 다른 사람 화면에 그리지 않는다.
- 연출은 상태가 바뀔 때 한 번만 재생하고, 재접속·복원 때는 애니메이션 없이 최종 상태로 그린다.
  `MediaQuery.disableAnimations`가 켜져 있으면 이동·확대·흔들림 없이 색·투명도만 바꾼다.
- 연출이 서버 deadline을 늦추지 않는다. 입력은 연출 중에도 막지 않는다(계약 3절).

## 4. 검수용 스크린샷·모션 프레임

- 테스트 도우미: `test/support/eleven_test_support.dart`
  - `setUpAll(loadElevenTestFonts)`: 숫자 StardosStencil, 한글 대체 글꼴(IBMPlexSansKR)을 불러 실제 글자로 그린다.
  - `captureElevenReview(tester, finder, lane: 'lane-a', name: 'P02')`: `review_out/<레인>/<name>.png` 저장.
  - 캡처 테스트는 `skip: elevenReviewSkip`으로 묶는다. 평소 `flutter test`에서는 건너뛴다.
- 만들기: `packages/game_eleven`에서
  `ELEVEN_REVIEW=1 flutter test --no-pub --update-goldens test/<phone|tablet>/review_capture_test.dart`
- 이름: 화면은 화면 ID(`P02`, `T07`, `T13-B`), 같은 화면의 변형은 `P08-lose`처럼 뒤에 붙인다.
  모션은 `<프로토타입 폴더>-<ms 5자리>`(예: `02_round-02600`)로, motion.md 4절 “기준 프레임” 시점과
  같은 시점을 `tester.pump(Duration)`으로 넘겨 찍는다. 기준 프레임: `docs/design/eleven/motion-frames/`.
- 크기: 휴대폰 844×390, 태블릿 1194×834(시안 기준 PNG와 같은 크기, devicePixelRatio 1).
- `review_out/`은 git에서 제외된다. 커밋하지 않는다.

## 5. 검수와 반복

- 레인을 끝내면 LOG에 "검수 요청"을 적는다. Claude가 `docs/planning/eleven-lanes/REVIEW-<레인>.md`에
  화면 ID별 차이·수정 지시·판정(PASS/FIX)을 쓴다.
- “REVIEW-A.md 반영” 같은 지시를 받으면 그 파일의 FIX 항목만 고치고 스크린샷을 다시 만든다.
- 3회째에도 FIX가 남으면 하준에게 보고한다(Claude가 판단).

## 6. 멈춤 조건

다음이면 LOG에 `BLOCKED: <이유>`를 적고 그 항목을 멈춘다. 다른 레인을 기다리지 않는다.
- 계약·서버·RTDB rules·공유 파일·새 dependency가 필요하다.
- 시안 기준과 다르게 만들어야 할 이유가 생겼다.
- 기존 동작(제출·예비 시간 초과·퇴장·복구·방 복귀·다시하기)을 깨야만 진행할 수 있다.

## 7. 검증 (각 레인이 끝날 때)

- `packages/game_eleven`: `flutter test --no-pub` 전체 PASS(레인 C는 생략 가능)
- 저장소 루트: `flutter analyze --no-pub packages/game_eleven` No issues(레인 C는 생략 가능)
- `dart format --output=none --set-exit-if-changed <바꾼 Dart 경로>` exit 0
- 저장소 루트: `python3 tool/check_package_boundaries.py --max 0` 위반 0건
- 레인 C: `functions/`에서 `npm run build`, `npm run lint`, `node --test test/*.test.mjs`
- 실행 전후 `git status --porcelain`을 비교해 자기 레인 경로 밖 변경이 없는지 확인한다.

## 8. LOG 형식 (`docs/planning/eleven-lanes/LOG-<레인>.md`)

```text
## <날짜 시각 KST> <한 줄 요약>
작업 트리: <폴더> / <브랜치> / HEAD <짧은 해시>
바꾼 파일: <경로 목록>
실행: <명령> → PASS/FAIL/BLOCKED, exit <코드>
화면·연출 진행: <ID 목록과 상태(완료/진행/BLOCKED)>
공유 파일 요청: <파일 · 바꿀 내용 · 이유> 또는 없음
BLOCKED: <이유> 또는 없음
남은 일: <목록>
검수 요청: 예/아니오
```

LOG는 덧붙이기만 한다. 앞의 기록을 지우거나 고치지 않는다.
