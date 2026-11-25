# ELEVEN 디자인 기준 자료 D0 (시안 A · 느와르 카드룸)

Codex 에이전트가 화면·애니메이션을 시안대로 구현하고, Claude 가 구현 스크린샷을 비교 검수할 때 쓰는 기준 자료.

## 원본

- Claude 디자인 캔버스 아티팩트(Design 타입): https://claude.ai/artifact/6ea11ac6-e281-491d-9726-f891fca89aa7
- 버전: `1795541629-f371` (캔버스 제목 “ELEVEN · 화면 디자인”)
- 추출 일시: 2026-11-25 03:04 UTC (읽기 전용으로 받았고 아티팩트는 수정하지 않음)
- 대상: `project/NoirTablet*`(14), `NoirPhone*`·`NoirStyled*`(19), `MotionKitNoir`, `NoirProto*`(8). 보라·흑백 이전 시안·`Theme*`·`Pal*` 은 제외.

## 폴더 구성

| 경로 | 내용 |
|---|---|
| `screens.md` | 공통 토큰(색·글꼴·반경·테두리·그림자·간격) → 부품 → 공용 뽑기 카드 장수 확인 → 화면 ID별 요소 표(위치·스타일·문구 원문·회전 영역 로컬 좌표) |
| `motion.md` | 연출 목록, 정적 화면 토스트 시간표, MotionKit 1–9, 프로토타입 ①–⑧ 전체 키프레임(원본 %·ms·값), 소스 간 모순, 프레임 추출 방법 |
| `screens/<ID>.png` | 화면 기준 PNG, 원래 크기·deviceScaleFactor 1 (태블릿 1194×834, 휴대폰 844×390). 동작 줄이기 상태 = 소스가 정의한 정지 화면 |

## 정리한 자료 (2026-11-25)

develop 병합 전 저장소 용량을 줄이려고 다음을 지웠다. 필요하면 위 디자인 캔버스 아티팩트(같은 버전)에서 다시 추출한다.

- `screens/<ID>--base.png`, `--toastN.png`(토스트 변형 29장): 대표 `screens/<ID>.png`와 `screens.md` 시간표로 대체
- `motion-frames/`(프레임 128장): 시점·값은 `motion.md`에 글로 남아 있다
- `data/`(`screens-dom/`, `screens-meta.json`, `animations.json`): 측정값은 `screens.md`·`motion.md` 표에 옮겨 두었다

`screens.md`·`motion.md` 안의 위 경로 언급은 추출 당시 기록이다.

## 화면 ID → 원본 파일

| ID | 원본 | 캔버스 제목 |
|---|---|---|
| T01 | `project/NoirTabletDrawStart.dc.html` | 첫 선공 뽑기 시작 |
| T02 | `project/NoirTabletDrawFirst.dc.html` | 첫 선공 뽑기 · A가 고른 뒤 B 차례 |
| T03 | `project/NoirTabletDrawReveal.dc.html` | 선공 뽑기 결과 동시 공개 |
| T04 | `project/NoirTabletFirstChoosing.dc.html` | 라운드 진행 · 선공이 고르는 중 |
| T05 | `project/NoirTabletPlay.dc.html` | 라운드 진행 · 선공 제출 후 후공 차례 |
| T06 | `project/NoirTabletTimeout.dc.html` | 시간 초과 자동 제출 |
| T07 | `project/NoirTabletRoundResult.dc.html` | 라운드 결과 · 승리 |
| T08 | `project/NoirTabletRoundTie.dc.html` | 라운드 결과 · 동점 |
| T09 | `project/NoirTabletNewRound.dc.html` | 새 라운드·선후공 안내 |
| T10 | `project/NoirTabletEarlyEnd.dc.html` | 조기 종료 안내 |
| T11 | `project/NoirTabletTieDraw.dc.html` | 최종 동점 뽑기 |
| T12 | `project/NoirTabletTieReveal.dc.html` | 최종 동점 뽑기 결과 |
| T13 | `project/NoirTabletFinal.dc.html` | 최종 결과 |
| T13-B | `project/NoirTabletFinalTieDraw.dc.html` | 최종 결과 · 동점 뽑기로 승패 결정 |
| P01 | `project/NoirPhoneDrawWait.dc.html` | 선공 뽑기 안내 (T01–T03) |
| P02 | `project/NoirStyledSelect.dc.html` | 선공 · 타일 선택 중 (A) |
| P03 | `project/NoirStyledLocked.dc.html` | 후공 · 미리 선택, 제출 잠김 (B) |
| P04 | `project/NoirStyledSubmitted.dc.html` | 선공 · 제출 완료, 상대 차례 (A) |
| P05 | `project/NoirPhoneSecondSubmit.dc.html` | 후공 · 제출 가능 (B) |
| P06 | `project/NoirPhoneTimeout.dc.html` | 시간 초과 자동 제출 (B) |
| P07 | `project/NoirPhoneSecondDone.dc.html` | 후공 · 제출 완료, 결과 대기 (B) |
| P08 | `project/NoirPhoneTransition.dc.html` | 결과·다음 라운드 전환 중 (A) |
| P09 | `project/NoirPhoneLastTile.dc.html` | 마지막 타일 1개 (A, 11R) |
| P10 | `project/NoirPhoneGameEnd.dc.html` | 게임 종료 · 이긴 사람 (A) |
| P11 | `project/NoirPhoneGameEndLose.dc.html` | 게임 종료 · 진 사람 (B) |
| G1 | `project/NoirPhoneDrawGuide.dc.html` | 선공 뽑기 · 내 차례 안내 (A) |
| G2 | `project/NoirPhoneDrawOtherWait.dc.html` | 선공 뽑기 · 상대가 먼저 뽑는 중 (B) |
| G3 | `project/NoirPhoneDrawPicked.dc.html` | 선공 뽑기 · 뽑은 뒤 대기 (A) |
| G4 | `project/NoirPhoneDrawResultWin.dc.html` | 선공 뽑기 결과 · 내가 선공 (A) |
| G5 | `project/NoirPhoneDrawResultLose.dc.html` | 선공 뽑기 결과 · 상대가 선공 (B) |
| G6 | `project/NoirPhoneRoundResultWait.dc.html` | 라운드 결과 확인 안내 (T07–T09) |
| G7 | `project/NoirPhoneEarlyEndWait.dc.html` | 조기 종료 안내 (T10) |
| G8 | `project/NoirPhoneTieDrawWait.dc.html` | 최종 동점 뽑기 안내 (T11–T12) |
| 모션 키트 | `project/MotionKitNoir.dc.html` | 모션 키트 · 시안 A 느와르 (확정값) |
| ①–⑧ | `project/NoirProtoDraw` · `NoirProtoRound` · `NoirProtoTimeout` · `NoirProtoResult` · `NoirProtoResultTie` · `NoirProtoEarlyEnd` · `NoirProtoFinal11` · `NoirProtoTieDraw` (`.dc.html`) | 프로토타입 (motion.md 1절) |

## 렌더링 방법

1. 아티팩트 Artifact read 로 위 파일과 `artifact-type/dc-runtime.js` 를 받음.
2. `dc-runtime.js` 를 `project/support.js` 로 복사(각 페이지의 `<script src="./support.js">` 가 Design Component 런타임을 불러 `<x-dc>` 를 React 로 렌더링).
3. 로컬 HTTP 서버 + Playwright Chromium, viewport = 원래 크기, deviceScaleFactor 1. 화면 PNG 는 `reducedMotion:'reduce'` 로 열고 애니메이션을 t=0 에 멈춘 뒤 캡처. 토스트 변형·모션 프레임은 일반 모드에서 `document.getAnimations()` 를 모두 `pause()` 하고 `currentTime` 을 지정해 캡처.
4. 글꼴: Google Fonts 요청이 프록시에서 403 으로 막혀, `@font-face` 로 "Noto Sans KR" 500/700/900 을 로컬 `Noto Sans CJK KR` Medium/Bold/Black 에 연결(원본처럼 400 은 정의하지 않아 500 으로 그려짐).

## 한계

- **Stardos Stencil 미적용**: 숫자(슬롯·타일·전적칸·점수·최종 점수)가 대체 글꼴(Noto Sans KR)로 그려졌다. 숫자 모양·숫자 글자 폭은 시안과 다르니 숫자 글꼴은 PNG 가 아니라 `screens.md` 토큰을 기준으로 삼을 것. Noto Sans KR 도 동일 글리프의 CJK 판이라 자간·줄높이가 아주 약간 다를 수 있다.
- 브라우저 ↔ Flutter 렌더링 차이: `-webkit-text-stroke`+`paint-order`(토스트 외곽 획), `color-mix()` 안쪽선, `radial-gradient` 모서리 점, `outline-offset`, `filter: brightness()`, 서브픽셀 위치(0.5px)는 Flutter 에서 같은 픽셀로 나오지 않는다. 검수는 위치·크기·색 기준 허용 오차를 두고 비교할 것.
- 프로토타입은 반복 데모(“고민 시간은 줄여서 재생”)라 대기 시간 길이는 실제 게임 시간이 아니다. 연출 자체 길이(등장·유지·퇴장, 딜, 뒤집기 등)만 기준.
- 소스끼리 모순되는 값이 있다(motion.md 5–6절): 토스트 등장 방식, 휴대폰 차례 전환 색, 시간 바 색, 최종 동점 뽑기 카드 흑/백 등. 어느 쪽을 따를지는 사용자 결정 필요.
