# ELEVEN 디자인 기준 D0 · 화면 명세 (시안 A 느와르 카드룸)

원본: Claude 디자인 캔버스 아티팩트 `6ea11ac6-e281-491d-9726-f891fca89aa7` 버전 `1795541629-f371` 의 `project/Noir*.dc.html`.
이 문서의 모든 값은 소스 CSS/인라인 스타일 원문, 또는 Chromium(Playwright)에서 렌더링한 DOM의 `getBoundingClientRect()`/`getComputedStyle()` 측정값이다. 추측 값은 없다.
측정 원자료(요소별 전체 계산 스타일)는 `data/screens-dom/<ID>.json`, 화면별 애니메이션 목록은 `data/screens-meta.json`.

좌표 규칙
- `화면 x,y,w,h` = 화면 왼쪽 위 원점(px, deviceScaleFactor 1), 변형(회전·이동) 적용 후의 축 정렬 상자. 소수점 0.5는 브라우저 측정 그대로.
- 태블릿 `로컬 x,y,w,h` = 회전 영역(`.side`, 760×320)의 회전 전 좌표. A측은 화면에 `rotate(90deg)`(A 플레이어가 왼쪽에 앉아 읽는 방향), B측은 `rotate(-90deg)`로 그려진다. Flutter에서는 760×320 위젯을 만든 뒤 `RotatedBox`/`Transform.rotate`로 돌리면 이 로컬 좌표를 그대로 쓸 수 있다.
- 기준 PNG `screens/<ID>.png` 는 `prefers-reduced-motion: reduce` 상태로 캡처했다. 소스가 이 미디어쿼리에서 "마지막 토스트만 보이게(opacity 1)·깜빡임 없음"을 직접 정의해 두었으므로 이것이 시안이 정의한 정지 화면이다. 토스트가 있는 태블릿 화면은 `--base`(토스트 없음)·`--toastN`(N번째 토스트 유지 구간 중간) PNG를 함께 두었다.
- 글꼴 한계: 렌더링 환경에서 Google Fonts 접속이 막혀(HTTP 403) Noto Sans KR 은 같은 글리프의 로컬 `Noto Sans CJK KR`(Medium/Bold/Black)로 대체했고, **Stardos Stencil 은 구할 수 없어 숫자가 Noto Sans KR 로 그려졌다.** 숫자 글꼴 모양과 숫자 텍스트 상자 폭(예: fhNum, 슬롯·타일 숫자)은 실제 시안과 다르다. 상자 크기가 CSS로 고정된 부품(타일·슬롯 등)의 위치·크기는 영향 없음.

## 1. 공통 토큰 (소스 실제 값만)

### 1-1. 색

| hex | 이름(이 문서에서 붙인 이름) | 소스상 용도 |
|---|---|---|
| `#141414` | 잉크 | 모든 굵은 테두리(3–4px), 단단한 그림자(`0 5px 0` 등), 기본 글자색, 태그/타이머 배경, HOME 버튼 배경, 토스트 외곽 획(`-webkit-text-stroke:12px`)·글자그림자 |
| `#f7f0e4` | 크림 | 칩·pill·메뉴 버튼·휴대폰 패널 바탕, 백(白) 타일 바탕, 흑 타일·빨강 위 글자, 기본 토스트 글자(`.cToast`) |
| `#efe6d6` | 크림-카드 | 태블릿 중앙 카드(`.card`) 바탕, P05 상단 요약줄 바탕, 프로토타입 빈 타일 바탕 |
| `#e7dccb` | 아바타 크림 | 휴대폰 상단 아바타 원(38×38) 바탕 |
| `#ece3d3` | 비활성 크림 | 잠긴 제출 버튼 바탕(P03 “선공 제출 후 제출 가능”) |
| `#e9e1d3` | 밝은 회크림 | 태블릿 `.legend`/`.note` 글자, P10/P11 하단 안내 글자, MotionKit 규칙 글자 |
| `#b9ae9c` | 회베이지 | 빈 슬롯·빈 전적칸·대시 상자 점선(`dashed`), 잠긴 버튼 테두리, `fhLabel`, “—” 자리표시 |
| `#6e655a` | 보조 글자 | `resRn`/`colHead`/`resTie`, 휴대폰 안내 본문·라벨, “vs” |
| `#5a524a` | (MotionKit 전용) | MotionKit 캡션 본문 |
| `#262524` | 테이블 배경 | `.stage` 바탕색 |
| `#1b1b1b` | 흑 타일 | 흑(黑) 타일/슬롯/전적칸 바탕 |
| `#1e1d1c` / `#1a1918` / `#121110` | (보드 전용) | MotionKit 칸 배경 / 프로토타입 보드 배경 / 프로토타입 진행바 배경 — 게임 화면에는 없음 |
| `#c9242a` | 주 빨강 | `pillOn`, 휴대폰 “내 차례” 상태칩, 점수 숫자(휴대폰 상단), 선 배지(`.sun`), A/B 표식(`.chip`), 승자 아바타 링, 링크색, 제출하기 버튼 |
| `#e23a3a` | 강조 빨강 | `cToastOn` 글자, 승리·선택 외곽선(`winT`/`pickA`/`sel`), 시간 바 채움(`.barFill`), `+1` 배지(`.plus`), 선택 배지(`.badge`), 왕관 채움, `turnFlash` 시작색, WINNER 글자 |
| `#d42a2f` | 경고 빨강 | `pillWarn`(자동 제출), 자동 제출/제출 완료 기울어진 배지(`.auto`), 카드 모서리 점(radial-gradient), 다시하기 버튼, MotionKit 시간 바 기본색 |
| `#8e1a1f` | 진한 빨강 | 시간 바 “남은 10초부터” 색(MotionKit `kNBarC`, 프로토타입 ③ `kQBf`), MotionKit 링크 hover |
| `#7d1d22` + `#9b262c` | 카드 뒷면 | `.back` = `repeating-linear-gradient(45deg,#7d1d22 0 8px,#9b262c 8px 16px)` |
| `rgba(255,255,255,.035)` | 사선 무늬 | `.stage` 배경 무늬 `repeating-linear-gradient(135deg,rgba(255,255,255,.035) 0 2px,transparent 2px 14px)` |
| `rgba(255,255,255,.08)` | 빈 슬롯 바탕 | `.empty` 바탕 (그리고 덮어써진 이전 점무늬) |
| `rgba(226,58,58,.22)` | 승리 번짐 | `winT` 바깥 링 `0 0 0 7px`(전적행은 6px) |
| `color-mix(in srgb,#141414 55%,transparent)` / `color-mix(in srgb,#f7f0e4 45%,transparent)` | 안쪽 테두리선 | 타일·슬롯·전적칸 `::before` 1px 안쪽 선 (흑 타일은 크림 45%) |

주의: `.stage` 는 앞쪽 규칙의 점무늬(`radial-gradient(rgba(255,255,255,.08) 1.5px,transparent 1.5px)` 22px)를 뒤쪽 “시안 A” 블록이 사선 무늬로 덮어쓴다. 최종 렌더는 사선 무늬다.

### 1-2. 글꼴

| 패밀리 | 굵기(로드) | 쓰임 |
|---|---|---|
| `"Noto Sans KR",system-ui,sans-serif` | 500·700·900 (Google Fonts `wght@500;700;900`) | 모든 한글·UI 글자. 굵기 지정 없는 본문(400)은 로드된 굵기가 없어 브라우저가 500으로 그린다 — 기준 PNG도 그렇게 렌더링함 |
| `"Stardos Stencil","Noto Sans KR",serif` | 700 | 숫자: `.slot`/`.tile`/`.mini` 본문, 타일 모서리 숫자(`::before content:attr(data-n)` 11px), `.score` 숫자(라벨 “점수”는 Noto), `fhNum`, MotionKit 카드·카운터 |
| `ui-monospace,Menlo,monospace` | — | MotionKit `.curve` 표기만 |

글자 크기 단계 (px/굵기)
- 태블릿: 토스트 72/900 · 점수 숫자 88/900(Stardos) · 최종 헤더 84(fhNum 700 Stardos, fhName 900) · 슬롯 숫자 68/900 · 뽑기카드 숫자 36/900 · pill 26/900(T09 30, T10 28, T13 19→인라인 26) · 점수 라벨 22/700 · 버튼 22/900 · 결과 `◀ 승` 20/900 · fhLabel 20/700(자간 2px) · `+1` 20/900 · tag 16/700 · 선 배지 15/900(전적행 12) · resRn 14/700 · A/B 표식 14/900 · colHead 13/900 · note 15/700(T13 13) · 타일 모서리 숫자 11
- 휴대폰: G7 점수 46/900 · 패널 큰 타일 40 · P09 11 타일 36 · 승자 아바타 글자 36/900 · 안내 제목 34/900 · 손패 타일 32 · G4/G5 타일 30, P08 “6라운드” 30/900 · 승자 이름 26/900 · 패널 값(흑 6) 22/900, `?` 22 · vs 20/900(G6 22) · 안내 본문 19 · 제출 버튼 18/900, P08 18/900 · 상단 바 17/900 · 아바타 16/900, 안내 부문 16 · WINNER 15/900 자간 3px, 대시 상자 15/700, 잠긴 버튼 15 · 태그 13/700, 패널 라벨 13/700 · 배지 12/900, 작은 안내 12

### 1-3. 모서리 반경

태블릿: 중앙 카드 28 · pill 18 · 메뉴 버튼 18 · 버튼 18 · 슬롯 18 (안쪽선 9) · 뽑기카드 12 · 전적행 12 · 전적칸 8(`aspect-ratio:166/124`, 안쪽선 4) · tag 8 · 선 배지 8(전적행 6) · `+1` 8 · 시간 바 8 / 채움 5 · A/B 표식 15(원) · 아바타 40(원)
휴대폰: 칩 16 · 오른쪽 패널 24 · 안내 카드 32 · 타일 12(안쪽선 6) · 버튼 16 · 배지 8 · 태그 8 · 타이머 10 · 아바타 19 · 대시 상자 16 · 요약줄 12 · 승자 아바타 58/43

### 1-4. 테두리·그림자·외곽선

- 기본 테두리: `3px solid #141414` (칩·pill·타일·슬롯·버튼·메뉴). `4px` = 중앙 카드·아바타 링. `2px` = 선 배지·`+1`·배지·휴대폰 아바타·전적칸(`.row2 .mini`).
- 빈 자리: `.empty` 슬롯 `3px dashed #b9ae9c`, 전적 빈칸 `2px dashed #b9ae9c`, 휴대폰 대시 상자 `3px dashed #b9ae9c`.
- 안쪽선: `::before` 1px, inset 슬롯 9 / 타일 5 / 전적칸 4 (색은 1-1 color-mix).
- 단단한 그림자(블러 0): `0 5px 0 #141414`(pill·메뉴버튼·휴대폰 칩·타일·휴대폰 버튼) · `0 6px 0 #141414`(슬롯·태블릿 버튼) · `0 8px 0 #141414`(중앙 카드). 전적칸은 플레이어 쪽으로만 `-3px 0 0`(A) / `3px 0 0`(B).
- 승리: `winT` = `outline:4px solid #e23a3a; outline-offset:2px; box-shadow:0 0 0 7px rgba(226,58,58,.22)` (전적행 안에서는 outline 3px/offset 1px, 번짐 6px). `pickA` = `outline:5px solid #e23a3a; outline-offset:3px`. 휴대폰 `sel` = `outline:4px solid #e23a3a; outline-offset:4px; transform:translateY(-8px) rotate(-3deg)`.
- 토스트 글자: `-webkit-text-stroke:12px #141414; paint-order:stroke fill; text-shadow:0 8px 0 #141414; line-height:1.8`.
- 흐림: 쓴 타일 `.used{opacity:.28;box-shadow:none}`, 대기 `.wait{opacity:.6}`, 진 전적칸 `.loseT{opacity:.38}`, 뽑기 후 남은 카드 `.dim{opacity:.35;box-shadow:none}`.

### 1-5. 간격

- 휴대폰 stage: `padding:16px 20px; gap:16px` (세로 flex). 상단 바 높이 56, `gap:14px`; 플레이어 칩 `padding:6px 14px 6px 6px; gap:10px; height:52px`; 상태 칩 `padding:0 8px 0 16px; gap:12px; height:52px`; 본문 `gap:20px`; 손패 줄 사이 22, 타일 사이 10; 오른쪽 패널 `width:268px; padding:18px; gap:14px`; 안내 카드 680×240 `padding:16px 40px`.
- 태블릿: `.side` 760×320 `top:257px`, 세로 flex `gap:8px`(T13/T13-B 10px); pill `padding:0 20px; gap:12px; height:66px`; 슬롯 줄 `gap:40px`(양옆 116px 자리); 중앙 카드(전적) `left:342 top:16 510×802 padding:12px 18px gap:3px`; 중앙 카드(뽑기) `left:357 top:182 480×470 padding:30px 20px` 3×3 grid; 전적행 `grid-template-columns:1fr 110px 1fr; height:64px`; 메뉴 `top:20 right:20 gap:8`; 최종 버튼 묶음 `left:357 top:267 480×300 gap:22px`.

## 2. 부품

### 2-1. 태블릿 부품

| 부품 | 크기·스타일(소스 원문) | 변형 |
|---|---|---|
| 회전 영역 `.side` | `position:absolute;width:760px;height:320px;top:257px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px` | A: `left:-208px;transform:rotate(90deg)` / B: `left:642px;transform:rotate(-90deg)` (T13 계열은 -220 / 654). 안 구성: pill → (시간 바 또는 16px 빈칸) → [116px 빈칸 · 슬롯 · 점수] 줄 |
| 상태 pill `.pill` | `border:3px solid #141414;border-radius:18px;box-shadow:0 5px 0 #141414;height:66px;padding:0 20px;font-size:26px;font-weight:900;background:#f7f0e4` | `pillOn` 배경 #c9242a 글자 #f7f0e4 · `pillWarn` 배경 #d42a2f 글자 #f7f0e4 · T09 인라인 76px/30px · T10 76px/28px · T13 계열 CSS 54px/19px/`padding:0 16px` 를 인라인 68px/26px/`0 22px`로 덮음 |
| 시간 바 `.bar` | `width:360px;height:16px;border:3px solid #141414;border-radius:8px;background:#141414;overflow:hidden`; 채움 `.barFill{height:100%;background:#e23a3a;border-radius:5px}` + 인라인 `width:%` | T04 80%, T05 70% |
| 슬롯 카드 `.slot` | `124×166;border-radius:18px;border:3px solid #141414;box-shadow:0 6px 0 #141414;font-size:68px;font-weight:900` + Stardos 700, 안쪽선 inset 9 r9, 모서리 점 6개(`::after`, #d42a2f 반지름 2.4px, 오른쪽 위·왼쪽 아래 대각 3개씩) | `blk`(#1b1b1b) · `wht`(#f7f0e4) · `back`(빨강 사선) · `empty`(점선 #b9ae9c, 바탕 rgba(255,255,255,.08), 글자 “?” #b9ae9c, 장식 없음). 뽑기 화면(T01–T03, T11–T12)은 `.slot::after{display:none}` = 모서리 점 없음 |
| 점수 `.score` | `width:116px;column;color:#f7f0e4`; 라벨 “점수” 22/700 Noto; 숫자 88/900 `line-height:1` Stardos | 숫자 옆 `.plus`(“+1”/“+0”): 20/900 글자 #141414 배경 #e23a3a 테두리 2px 반경 8 `padding:0 6px` |
| 중앙 카드 `.card` | `background:#efe6d6;border:4px solid #141414;border-radius:28px;box-shadow:0 8px 0 #141414` | 전적판(510×802) / 뽑기판(480×470) |
| 전적 행 `.row2` | `grid 1fr 110px 1fr;height:64px`; 칸 `.mini` `height:58px;aspect-ratio:166/124;border-radius:8px;border:2px solid #141414`(→ 측정 77.6×58), 빈칸 `.miniEmpty` `2px dashed #b9ae9c`; 가운데 `.res`: `.resTxt` 20/900 #141414(동점은 `.resTie` #6e655a, “=” 24px line-height .8), `.resRn` 14/700 #6e655a | 칸 변형 `blk`/`wht` + `winT`(빨강 외곽선) / `loseT`(opacity .38) / 무표시(동점) ; 선공 칸에 `.sun`“선”(전적행: `top:-9px;left:-10px;font-size:12px;line-height:16px;padding:0 4px;border-radius:6px`, 배경 #c9242a 글자 #f7f0e4 테두리 2px). 결과 문구 원문: `◀ 승`, `승 ▶`, `동점`+`=` |
| 열 머리 `.colHead` | `grid 1fr 110px 1fr;font-size:13px;font-weight:900;color:#6e655a;margin-bottom:4px` | “A / 라운드 / B” |
| 뽑기 카드 `.ptile` | `92×68;border-radius:12px;border:3px solid #141414;box-shadow:0 5px 0 #141414;font-size:36px;font-weight:900` | `back` · `wht`/`blk`(숫자 공개, 숫자 span을 A쪽 `rotate(90deg)`, B쪽 `rotate(-90deg)`) · `pickA` · `dim`. 표식 `.chip` 30×30 원 #c9242a 테두리 3px 14/900 “A”(`left:-12px;top:-12px`) / “B”(`right:-12px;top:-12px`) |
| 중앙 토스트 `.toastWrap`/`.cToast` | 영역 `left:77px;top:278px;1040×278`; 글자 72/900 `line-height:1.8` 크림 #f7f0e4 + 12px 잉크 획 + `0 8px 0` 그림자, 가운데 정렬 `white-space:nowrap` | `cToastOn` = 글자 #e23a3a. 줄바꿈 `<br>` 사용(T09 “6라운드/A 선공”, T10 “승자/A”) |
| 메뉴 `.menu` | `top:20px;right:20px;gap:8px`; `.menuBtn` 72×72 반경 18 테두리 3 그림자 `0 5px 0` 바탕 #f7f0e4, 아이콘 svg 34×34 stroke #141414 2.4 | 책(게임 규칙 열기) · 톱니(게임 설정 열기) |
| 최종 헤더 `.finalHead` | `left:357px;top:96px;width:480px;column;gap:4px;color:#f7f0e4`; `.fhLabel` 20/700 #b9ae9c 자간 2px; `.fhNum` Stardos 84/700 자간 2px; `.fhName` 84/900 | T13 “최종 점수 / 6 : 2”, T13-B “승자 / B” |
| 버튼 `.btn` | `border:3px solid #141414;border-radius:18px;box-shadow:0 6px 0 #141414;font-size:22px;font-weight:900;height:68px;width:240px` | 다시하기 배경 #d42a2f 글자 #f7f0e4 / HOME 배경 #141414 글자 #f7f0e4 |
| 왕관 svg | `viewBox 0 0 54 34`, path `M4 30 L8 8 L19 20 L27 3 L35 20 L46 8 L50 30 Z` fill #e23a3a stroke #141414 3 round | 태블릿 54×34 `margin-bottom:-10px`(T10·T13·T13-B 승자 측) · 휴대폰 76×44 `margin-bottom:-16px` |

### 2-2. 휴대폰 부품 (844×390 가로)

| 부품 | 크기·스타일(소스 원문) | 변형 |
|---|---|---|
| 칩 `.chip` (공통 바탕) | `background:#f7f0e4;border:3px solid #141414;border-radius:16px;box-shadow:0 5px 0 #141414` | 아래 플레이어 칩·상태 칩·패널·안내 카드가 이 클래스 |
| 플레이어 칩 | 높이 52, `padding:6px 14px 6px 6px;gap:10px`; 아바타 38×38 원 #e7dccb 테두리 2px 글자 16/900 (“A”/“B”); “나” 17/900; 점수 “x : y” 17/900 #c9242a | 화면 x=20,y=18 |
| 상태 칩 | `flex:1;height:52px;padding:0 8px 0 16px;gap:12px`; 태그 13/700 글자 #f7f0e4 배경 #141414 반경 8 `padding:2px 8px`; 메시지 17/900 `flex:1`; 타이머(있을 때) 17/900 배경 #141414 반경 10 `padding:4px 12px` | 내 차례 = 배경 #c9242a 글자 #f7f0e4 (`turnFlash` 반복 연출 붙음) · 기다림 = 배경 #f7f0e4 글자 #141414 |
| 아이콘 버튼 | `.btn` 52×52 바탕 #f7f0e4: “?”(22px, aria 규칙 보기) · 나가기 svg 22×22 stroke 2.6 | 상단 오른쪽 x=706, 772 |
| 손패 타일 `.tile` | `64×84;border-radius:12px;border:3px solid #141414;box-shadow:0 5px 0 #141414;font-size:32px;font-weight:900` + Stardos 700; 모서리 숫자 `::before content:attr(data-n)` 11px inset 5 r6; 모서리 점 `::after` #d42a2f 1.5px | 흑 줄 `[0,2,4,6,8,11]`, 백 줄 `[1,3,5,7,9]` (소스 `renderVals`). `used` opacity .28 · `wait` opacity .6 · `sel` 빨강 외곽선+들림+기울임 + `.badge`“선택”(12/900, 배경 #e23a3a, `bottom:-16px; rotate(-3deg)`) |
| 오른쪽 패널 | `width:268px;border-radius:24px;padding:18px;gap:14px` | 큰 타일 78×104(40px), 라벨 13/700 #6e655a, 값 22/900, 보조 12 #6e655a; 아래 버튼 또는 대시 상자(`height:56px;border-radius:16px;border:3px dashed #b9ae9c;15/700 #6e655a`) |
| 제출 버튼 | `.btn` `height:56px;background:#c9242a;color:#f7f0e4;font-size:18px` (P05 52px) | `submitPop` 반복 연출 · 잠김: 배경 #ece3d3 글자 #6e655a 15px `box-shadow:none;border-color:#b9ae9c` disabled |
| 기울어진 배지 `.auto` | `position:absolute;top:-12px;left:22px;transform:rotate(8deg);background:#d42a2f;color:#f7f0e4;border:2px solid #141414;border-radius:8px;font-size:12px;font-weight:900;padding:1px 8px` | “자동 제출”(P06) · “제출 완료”(P07; P04는 같은 모양 인라인, `left:30px`) |
| 안내 카드 | `.chip` `border-radius:32px;width:680px;height:240px;padding:16px 40px` 가운데 정렬; 제목 34/900 `line-height:1.2`; 그림 줄 `margin:14px 0 4px;gap:10px`; 본문 19px #6e655a `margin-top:12px;line-height:1.35`; 보조 16px #6e655a `margin-top:4px` | G1–G8, P01. 그림 줄 타일 50×66 `border-width:3px;box-shadow:none` (뒷면 사선 / 숫자 30px / 승자 `outline:4px solid #e23a3a;outline-offset:3px` / 패자 opacity .45(G6 .4)) |
| 승자 표시 (P10/P11) | 왕관 76×44 → 아바타 116×116 원 #c9242a 테두리 4 그림자 `0 5px 0` 안쪽 86×86 #f7f0e4 테두리 3 글자 36/900 → 이름 26/900 #f7f0e4 → “WINNER” 15/900 #e23a3a 자간 3px → 안내 13/700 #e9e1d3 | 진 사람 화면(P11)도 승자 A 를 보여 줌 |

## 3. 공용 뽑기 카드 장수 확인 (계약: 1–9, 9장)

| 화면 | 뽑기 카드 표시 | 장수 | 보이는 숫자 |
|---|---|---|---|
| T01 첫 선공 뽑기 시작 | 중앙 3×3 `.ptile back` | **9** | — |
| T02 A가 고른 뒤 | 3×3, 가운데(5번째) `pickA`+A | **9** | — |
| T03 동시 공개 | 3×3, A=가운데 `wht` 7, B=오른쪽 아래 `wht` 3, 나머지 7장 `dim` | **9** | 7, 3 |
| T11 최종 동점 뽑기 | 3×3 `back` | **9** | — |
| T12 동점 뽑기 결과 | 3×3, B=오른쪽 위 `wht` 9, A=오른쪽 아래 `blk` 4, 나머지 7장 `dim` | **9** | 4, 9 |
| T04–T10, T13, T13-B | 뽑기판 없음(전적판 11행 1R–11R / 최종 화면) | — | — |
| 프로토타입 ① | 부제 “뽑기 카드 9장, 숫자 공개”, 자막 “뽑기 카드 9장(1~9)이 딜되듯 깔림”, `.ptile` 9개(`kDT0`–`kDT8`) | **9 (1~9)** | A 7, B 3 |
| 프로토타입 ⑧ | 부제 “뽑기 카드 9장”, 자막 “카드 9장(1~9)”, `.ptile` 9개(`kTT0`–`kTT8`) | **9 (1~9)** | A 4, B 9 |
| P01, G1, G2, G8 | 안내 카드 그림: 뒷면 타일 3장(장식) | 장수 표시 아님 | — |
| G3 | 뒷면 1장(내가 뽑은 카드) | — | — |
| G4 / G5 | 7 vs 3 (`wht`) | — | 7, 3 |

결론: 공용 뽑기 카드는 모든 시안에서 9장(1–9)이며 0–9·11 11장 구성은 없다. 0–9·11(10 없음) 11장은 **각 플레이어의 손패**(P02–P09, 흑 0·2·4·6·8·11 / 백 1·3·5·7·9)다.

## 4. 화면별 명세

부품 이름은 2절 기준. “스타일” 열은 부품이 아닌 인라인 요소만 적었다(글자 크기/굵기 · 색 · 배경 · 테두리 · 반경 · 그림자). 문구는 원문 그대로. `[A]`/`[B]` = 태블릿 회전 영역 소속.

### T01 — 느와르 · T01 · 첫 선공 뽑기 시작

- 원본: `project/NoirTabletDrawStart.dc.html` · 크기 1194×834 · 기준 PNG `screens/T01.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 추가 PNG: `screens/T01--base.png` (모든 토스트 opacity 0, t=0); `screens/T01--toast1.png` (t=550ms, "타일 선택" 유지 구간 중간)
- 화면 내 반복 애니메이션: `tq1` 2100ms → “타일 선택”
- 소스 주석: `토스트 시간 (확정): 등장 0.2s · 유지 0.7s · 퇴장 0.2s · 단계 사이 0.2s · 한 바퀴 2.1s`
- 회전 영역: A(좌) `.side` left -208px · rotate(90deg) → 회전 전 상자 -208,257,760,320, 화면상 상자 12,37,320,760; B(우) left 642px · rotate(-90deg) → 회전 전 642,257,760,320, 화면상 862,37,320,760. 아래 ‘로컬’은 회전 전 측면 상자(760×320) 기준 좌표.

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,1194,834 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| [A] 상태 pill | pillOn | 238,354.5,66,125 | 317.5,28,125,66 | 내 차례 | |
| [A] 슬롯 카드 slot | empty | 40,355,166,124 | 318,126,124,166 | ? | |
| [B] 상태 pill | 기본 | 890,342.5,66,149 | 305.5,28,149,66 | 상대 차례 | |
| [B] 슬롯 카드 slot | empty | 988,355,166,124 | 318,126,124,166 | ? | |
| 중앙 카드 card | — | 357,182,480,470 | | | 인라인 left: 357px; top: 182px; width: 480px; height: 470px; display: grid; grid-template-columns: repeat(3, minmax(0px, 1fr)); |
| 뽑기 카드 ptile | back | 407,249,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 551,249,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 695,249,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 407,383,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 551,383,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 695,383,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 407,517,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 551,517,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 695,517,92,68 | | 뒤집힌 타일 |  |
| 토스트 영역 toastWrap | — | 77,278,1040,278 | | aria: 타일 선택. | |
| 중앙 토스트 cToast | cToastOn(빨강) tq1 | 77,278,1040,278 | | 타일 선택 | |
| 메뉴(룰북·설정) menu | — | 1022,20,152,72 | | 버튼 72×72 ×2: 게임 규칙 열기 / 게임 설정 열기 | |

### T02 — 느와르 · T02 · 첫 선공 뽑기 · A가 고른 뒤 B 차례

- 원본: `project/NoirTabletDrawFirst.dc.html` · 크기 1194×834 · 기준 PNG `screens/T02.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 추가 PNG: `screens/T02--base.png` (모든 토스트 opacity 0, t=0); `screens/T02--toast1.png` (t=550ms, "타일 선택" 유지 구간 중간)
- 화면 내 반복 애니메이션: `tq1` 2100ms → “타일 선택”
- 소스 주석: `토스트 시간 (확정): 등장 0.2s · 유지 0.7s · 퇴장 0.2s · 단계 사이 0.2s · 한 바퀴 2.1s`
- 회전 영역: A(좌) `.side` left -208px · rotate(90deg) → 회전 전 상자 -208,257,760,320, 화면상 상자 12,37,320,760; B(우) left 642px · rotate(-90deg) → 회전 전 642,257,760,320, 화면상 862,37,320,760. 아래 ‘로컬’은 회전 전 측면 상자(760×320) 기준 좌표.

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,1194,834 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| [A] 상태 pill | 기본 | 238,342.5,66,149 | 305.5,28,149,66 | 선택 완료 | |
| [A] 슬롯 카드 slot | back | 40,355,166,124 | 318,126,124,166 | A가 고른 뒤집힌 타일 | |
| [B] 상태 pill | pillOn | 890,354.5,66,125 | 317.5,28,125,66 | 내 차례 | |
| [B] 슬롯 카드 slot | empty | 988,355,166,124 | 318,126,124,166 | ? | |
| 중앙 카드 card | — | 357,182,480,470 | | | 인라인 left: 357px; top: 182px; width: 480px; height: 470px; display: grid; grid-template-columns: repeat(3, minmax(0px, 1fr)); |
| 뽑기 카드 ptile | back | 407,249,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 551,249,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 695,249,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 407,383,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back/pickA +표식 A | 551,383,92,68 | | A가 고른 타일 |  |
| 뽑기 카드 ptile | back | 695,383,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 407,517,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 551,517,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 695,517,92,68 | | 뒤집힌 타일 |  |
| 토스트 영역 toastWrap | — | 77,278,1040,278 | | aria: 타일 선택. | |
| 중앙 토스트 cToast | cToastOn(빨강) tq1 | 77,278,1040,278 | | 타일 선택 | |
| 메뉴(룰북·설정) menu | — | 1022,20,152,72 | | 버튼 72×72 ×2: 게임 규칙 열기 / 게임 설정 열기 | |

### T03 — 느와르 · T03 · 선공 뽑기 결과 동시 공개

- 원본: `project/NoirTabletDrawReveal.dc.html` · 크기 1194×834 · 기준 PNG `screens/T03.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 추가 PNG: `screens/T03--base.png` (모든 토스트 opacity 0, t=0); `screens/T03--toast1.png` (t=450ms, "숫자 공개" 유지 구간 중간); `screens/T03--toast2.png` (t=1800ms, "A 선공" 유지 구간 중간)
- 화면 내 반복 애니메이션: `tq1` 3500ms → “숫자 공개”; `tq2` 3500ms → “A 선공”
- 소스 주석: `토스트 시간 (확정): 등장 0.2s · 유지 0.5 / 1.0s · 퇴장 0.2s · 단계 사이 0.2s · 한 바퀴 3.5s`
- 회전 영역: A(좌) `.side` left -208px · rotate(90deg) → 회전 전 상자 -208,257,760,320, 화면상 상자 12,37,320,760; B(우) left 642px · rotate(-90deg) → 회전 전 642,257,760,320, 화면상 862,37,320,760. 아래 ‘로컬’은 회전 전 측면 상자(760×320) 기준 좌표.

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,1194,834 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| [A] 상태 pill | pillOn | 238,354.5,66,125 | 317.5,28,125,66 | 내 차례 | |
| [A] 슬롯 카드 slot | wht | 40,355,166,124 | 318,126,124,166 | 7 | |
| [B] 상태 pill | 기본 | 890,342.5,66,149 | 305.5,28,149,66 | 상대 차례 | |
| [B] 슬롯 카드 slot | wht | 988,355,166,124 | 318,126,124,166 | 3 | |
| 중앙 카드 card | — | 357,182,480,470 | | | 인라인 left: 357px; top: 182px; width: 480px; height: 470px; display: grid; grid-template-columns: repeat(3, minmax(0px, 1fr)); |
| 뽑기 카드 ptile | back/dim | 407,249,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back/dim | 551,249,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back/dim | 695,249,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back/dim | 407,383,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | wht/pickA +표식 A | 551,383,92,68 | | A가 뽑은 타일 7 | 숫자 span display: inline-block; transform: rotate(90deg); |
| 뽑기 카드 ptile | back/dim | 695,383,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back/dim | 407,517,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back/dim | 551,517,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | wht +표식 B | 695,517,92,68 | | B가 뽑은 타일 3 | 숫자 span display: inline-block; transform: rotate(-90deg); |
| 토스트 영역 toastWrap | — | 77,278,1040,278 | | aria: 숫자 공개. A 선공. | |
| 중앙 토스트 cToast | 기본(크림) tq1 | 77,278,1040,278 | | 숫자 공개 | |
| 중앙 토스트 cToast | cToastOn(빨강) tq2 | 77,278,1040,278 | | A 선공 | |
| 메뉴(룰북·설정) menu | — | 1022,20,152,72 | | 버튼 72×72 ×2: 게임 규칙 열기 / 게임 설정 열기 | |

### T04 — 느와르 · T04 · 라운드 진행 · 선공이 고르는 중

- 원본: `project/NoirTabletFirstChoosing.dc.html` · 크기 1194×834 · 기준 PNG `screens/T04.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 추가 PNG: `screens/T04--base.png` (모든 토스트 opacity 0, t=0); `screens/T04--toast1.png` (t=600ms, "1라운드" 유지 구간 중간)
- 화면 내 반복 애니메이션: `tq1` 2200ms → “1라운드”
- 소스 주석: `토스트 시간 (확정): 등장 0.2s · 유지 0.8s · 퇴장 0.2s · 단계 사이 0.2s · 한 바퀴 2.2s`
- 회전 영역: A(좌) `.side` left -208px · rotate(90deg) → 회전 전 상자 -208,257,760,320, 화면상 상자 12,37,320,760; B(우) left 642px · rotate(-90deg) → 회전 전 642,257,760,320, 화면상 862,37,320,760. 아래 ‘로컬’은 회전 전 측면 상자(760×320) 기준 좌표.

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,1194,834 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| [A] 상태 pill | pillOn | 238,354.5,66,125 | 317.5,28,125,66 | 내 차례 | |
| [A] 시간 바 bar | — | 214,237,16,360 | 200,102,360,16 | 남은 시간 약 80% | 채움 width: 80%; |
| [A] 슬롯 카드 slot | empty | 40,355,166,124 | 318,126,124,166 | ? | |
| [A] 점수 score | — | 63,519,120,116 | 482,149,116,120 | 점수 0 | |
| [B] 상태 pill | 기본 | 890,342.5,66,149 | 305.5,28,149,66 | 상대 차례 | |
| [B] 슬롯 카드 slot | empty | 988,355,166,124 | 318,126,124,166 | ? | |
| [B] 점수 score | — | 1011,199,120,116 | 482,149,116,120 | 점수 0 | |
| 중앙 카드 card | — | 342,16,510,802 | | | 인라인 left: 342px; top: 16px; width: 510px; height: 802px; padding: 12px 18px; display: flex; flex-direction: column; justify- |
| 전적 열 머리 colHead | — | 364,37,466,19 | | A 라운드 B | |
| 전적 행 row2 | 1R | 364,63,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “1R” \| B칸 빈칸(miniEmpty) | aria: 1라운드 진행 중 · 결과는 라운드가 끝난 뒤 표시 |
| 전적 행 row2 | 2R | 364,130,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “2R” \| B칸 빈칸(miniEmpty) | aria: 2라운드 진행 전 |
| 전적 행 row2 | 3R | 364,197,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “3R” \| B칸 빈칸(miniEmpty) | aria: 3라운드 진행 전 |
| 전적 행 row2 | 4R | 364,264,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “4R” \| B칸 빈칸(miniEmpty) | aria: 4라운드 진행 전 |
| 전적 행 row2 | 5R | 364,331,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “5R” \| B칸 빈칸(miniEmpty) | aria: 5라운드 진행 전 |
| 전적 행 row2 | 6R | 364,398,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “6R” \| B칸 빈칸(miniEmpty) | aria: 6라운드 진행 전 |
| 전적 행 row2 | 7R | 364,465,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “7R” \| B칸 빈칸(miniEmpty) | aria: 7라운드 진행 전 |
| 전적 행 row2 | 8R | 364,532,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “8R” \| B칸 빈칸(miniEmpty) | aria: 8라운드 진행 전 |
| 전적 행 row2 | 9R | 364,599,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “9R” \| B칸 빈칸(miniEmpty) | aria: 9라운드 진행 전 |
| 전적 행 row2 | 10R | 364,666,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “10R” \| B칸 빈칸(miniEmpty) | aria: 10라운드 진행 전 |
| 전적 행 row2 | 11R | 364,733,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “11R” \| B칸 빈칸(miniEmpty) | aria: 11라운드 진행 전 |
| 토스트 영역 toastWrap | — | 77,278,1040,278 | | aria: 1라운드. | |
| 중앙 토스트 cToast | cToastOn(빨강) tq1 | 77,278,1040,278 | | 1라운드 | |
| 메뉴(룰북·설정) menu | — | 1022,20,152,72 | | 버튼 72×72 ×2: 게임 규칙 열기 / 게임 설정 열기 | |

### T05 — 느와르 · T05 · 라운드 진행 · 선공 제출 후 후공 차례

- 원본: `project/NoirTabletPlay.dc.html` · 크기 1194×834 · 기준 PNG `screens/T05.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 추가 PNG: `screens/T05--base.png` (모든 토스트 opacity 0, t=0); `screens/T05--toast1.png` (t=500ms, "제출 완료" 유지 구간 중간)
- 화면 내 반복 애니메이션: `tq1` 2000ms → “제출 완료”
- 소스 주석: `토스트 시간 (확정): 등장 0.2s · 유지 0.6s · 퇴장 0.2s · 단계 사이 0.2s · 한 바퀴 2.0s`
- 회전 영역: A(좌) `.side` left -208px · rotate(90deg) → 회전 전 상자 -208,257,760,320, 화면상 상자 12,37,320,760; B(우) left 642px · rotate(-90deg) → 회전 전 642,257,760,320, 화면상 862,37,320,760. 아래 ‘로컬’은 회전 전 측면 상자(760×320) 기준 좌표.

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,1194,834 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| [A] 상태 pill | 기본 | 238,342.5,66,149 | 305.5,28,149,66 | 제출 완료 | |
| [A] 슬롯 카드 slot | blk | 40,355,166,124 | 318,126,124,166 | A가 낸 흑 타일 | |
| [A] 점수 score | — | 63,519,120,116 | 482,149,116,120 | 점수 2 | |
| [B] 상태 pill | pillOn | 890,354.5,66,125 | 317.5,28,125,66 | 내 차례 | |
| [B] 시간 바 bar | — | 964,237,16,360 | 200,102,360,16 | 남은 시간 약 70% | 채움 width: 70%; |
| [B] 슬롯 카드 slot | empty | 988,355,166,124 | 318,126,124,166 | ? | |
| [B] 점수 score | — | 1011,199,120,116 | 482,149,116,120 | 점수 1 | |
| 중앙 카드 card | — | 342,16,510,802 | | | 인라인 left: 342px; top: 16px; width: 510px; height: 802px; padding: 12px 18px; display: flex; flex-direction: column; justify- |
| 전적 열 머리 colHead | — | 364,37,466,19 | | A 라운드 B | |
| 전적 행 row2 | 1R | 364,63,466,64 | | A칸 blk winT +선배지 \| 가운데 “◀ 승 1R” \| B칸 wht loseT | aria: 1라운드 A 승 · A 선공 |
| 전적 행 row2 | 2R | 364,130,466,64 | | A칸 wht loseT +선배지 \| 가운데 “승 ▶ 2R” \| B칸 wht winT | aria: 2라운드 B 승 · A 선공 |
| 전적 행 row2 | 3R | 364,197,466,64 | | A칸 wht \| 가운데 “동점 = 3R” \| B칸 wht +선배지 | aria: 3라운드 동점 · B 선공 |
| 전적 행 row2 | 4R | 364,264,466,64 | | A칸 blk winT \| 가운데 “◀ 승 4R” \| B칸 blk loseT +선배지 | aria: 4라운드 A 승 · B 선공 |
| 전적 행 row2 | 5R | 364,331,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “5R” \| B칸 빈칸(miniEmpty) | aria: 5라운드 진행 중 · 결과는 라운드가 끝난 뒤 표시 |
| 전적 행 row2 | 6R | 364,398,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “6R” \| B칸 빈칸(miniEmpty) | aria: 6라운드 진행 전 |
| 전적 행 row2 | 7R | 364,465,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “7R” \| B칸 빈칸(miniEmpty) | aria: 7라운드 진행 전 |
| 전적 행 row2 | 8R | 364,532,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “8R” \| B칸 빈칸(miniEmpty) | aria: 8라운드 진행 전 |
| 전적 행 row2 | 9R | 364,599,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “9R” \| B칸 빈칸(miniEmpty) | aria: 9라운드 진행 전 |
| 전적 행 row2 | 10R | 364,666,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “10R” \| B칸 빈칸(miniEmpty) | aria: 10라운드 진행 전 |
| 전적 행 row2 | 11R | 364,733,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “11R” \| B칸 빈칸(miniEmpty) | aria: 11라운드 진행 전 |
| 토스트 영역 toastWrap | — | 77,278,1040,278 | | aria: 제출 완료. | |
| 중앙 토스트 cToast | cToastOn(빨강) tq1 | 77,278,1040,278 | | 제출 완료 | |
| 메뉴(룰북·설정) menu | — | 1022,20,152,72 | | 버튼 72×72 ×2: 게임 규칙 열기 / 게임 설정 열기 | |

### T06 — 느와르 · T06 · 시간 초과 자동 제출

- 원본: `project/NoirTabletTimeout.dc.html` · 크기 1194×834 · 기준 PNG `screens/T06.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 추가 PNG: `screens/T06--base.png` (모든 토스트 opacity 0, t=0); `screens/T06--toast1.png` (t=650ms, "타일 자동 제출" 유지 구간 중간)
- 화면 내 반복 애니메이션: `tq1` 2300ms → “타일 자동 제출”
- 소스 주석: `토스트 시간 (확정): 등장 0.2s · 유지 0.9s · 퇴장 0.2s · 단계 사이 0.2s · 한 바퀴 2.3s`
- 회전 영역: A(좌) `.side` left -208px · rotate(90deg) → 회전 전 상자 -208,257,760,320, 화면상 상자 12,37,320,760; B(우) left 642px · rotate(-90deg) → 회전 전 642,257,760,320, 화면상 862,37,320,760. 아래 ‘로컬’은 회전 전 측면 상자(760×320) 기준 좌표.

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,1194,834 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| [A] 상태 pill | 기본 | 238,342.5,66,149 | 305.5,28,149,66 | 자동 제출 | |
| [A] 슬롯 카드 slot | blk | 40,355,166,124 | 318,126,124,166 | A가 낸 흑 타일 | |
| [A] 점수 score | — | 63,519,120,116 | 482,149,116,120 | 점수 2 | |
| [B] 상태 pill | pillWarn | 890,342.5,66,149 | 305.5,28,149,66 | 자동 제출 | |
| [B] 슬롯 카드 slot | blk | 988,355,166,124 | 318,126,124,166 | B가 자동 제출한 흑 타일 | |
| [B] 점수 score | — | 1011,199,120,116 | 482,149,116,120 | 점수 1 | |
| 중앙 카드 card | — | 342,16,510,802 | | | 인라인 left: 342px; top: 16px; width: 510px; height: 802px; padding: 12px 18px; display: flex; flex-direction: column; justify- |
| 전적 열 머리 colHead | — | 364,37,466,19 | | A 라운드 B | |
| 전적 행 row2 | 1R | 364,63,466,64 | | A칸 blk winT +선배지 \| 가운데 “◀ 승 1R” \| B칸 wht loseT | aria: 1라운드 A 승 · A 선공 |
| 전적 행 row2 | 2R | 364,130,466,64 | | A칸 wht loseT +선배지 \| 가운데 “승 ▶ 2R” \| B칸 wht winT | aria: 2라운드 B 승 · A 선공 |
| 전적 행 row2 | 3R | 364,197,466,64 | | A칸 wht \| 가운데 “동점 = 3R” \| B칸 wht +선배지 | aria: 3라운드 동점 · B 선공 |
| 전적 행 row2 | 4R | 364,264,466,64 | | A칸 blk winT \| 가운데 “◀ 승 4R” \| B칸 blk loseT +선배지 | aria: 4라운드 A 승 · B 선공 |
| 전적 행 row2 | 5R | 364,331,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “5R” \| B칸 빈칸(miniEmpty) | aria: 5라운드 진행 중 · 결과는 라운드가 끝난 뒤 표시 |
| 전적 행 row2 | 6R | 364,398,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “6R” \| B칸 빈칸(miniEmpty) | aria: 6라운드 진행 전 |
| 전적 행 row2 | 7R | 364,465,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “7R” \| B칸 빈칸(miniEmpty) | aria: 7라운드 진행 전 |
| 전적 행 row2 | 8R | 364,532,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “8R” \| B칸 빈칸(miniEmpty) | aria: 8라운드 진행 전 |
| 전적 행 row2 | 9R | 364,599,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “9R” \| B칸 빈칸(miniEmpty) | aria: 9라운드 진행 전 |
| 전적 행 row2 | 10R | 364,666,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “10R” \| B칸 빈칸(miniEmpty) | aria: 10라운드 진행 전 |
| 전적 행 row2 | 11R | 364,733,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “11R” \| B칸 빈칸(miniEmpty) | aria: 11라운드 진행 전 |
| 토스트 영역 toastWrap | — | 77,278,1040,278 | | aria: 타일 자동 제출. | |
| 중앙 토스트 cToast | cToastOn(빨강) tq1 | 77,278,1040,278 | | 타일 자동 제출 | |
| 메뉴(룰북·설정) menu | — | 1022,20,152,72 | | 버튼 72×72 ×2: 게임 규칙 열기 / 게임 설정 열기 | |

### T07 — 느와르 · T07 · 라운드 결과 · 승리

- 원본: `project/NoirTabletRoundResult.dc.html` · 크기 1194×834 · 기준 PNG `screens/T07.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 추가 PNG: `screens/T07--base.png` (모든 토스트 opacity 0, t=0); `screens/T07--toast1.png` (t=650ms, "A 승리" 유지 구간 중간)
- 화면 내 반복 애니메이션: `tq1` 2300ms → “A 승리”
- 소스 주석: `토스트 시간 (확정): 등장 0.2s · 유지 0.9s · 퇴장 0.2s · 단계 사이 0.2s · 한 바퀴 2.3s`
- 회전 영역: A(좌) `.side` left -208px · rotate(90deg) → 회전 전 상자 -208,257,760,320, 화면상 상자 12,37,320,760; B(우) left 642px · rotate(-90deg) → 회전 전 642,257,760,320, 화면상 862,37,320,760. 아래 ‘로컬’은 회전 전 측면 상자(760×320) 기준 좌표.

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,1194,834 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| [A] 상태 pill | pillOn | 238,370.1,66,93.8 | 333.1,28,93.8,66 | 승리 | |
| [A] 슬롯 카드 slot | blk | 40,355,166,124 | 318,126,124,166 | A가 낸 흑 타일 | |
| [A] 점수 score | +배지 +1 | 63,519,120,116 | 482,149,116,120 | 점수 3 +1 | |
| [B] 상태 pill | 기본 | 890,370.1,66,93.8 | 333.1,28,93.8,66 | 패배 | |
| [B] 슬롯 카드 slot | wht | 988,355,166,124 | 318,126,124,166 | B가 낸 백 타일 | |
| [B] 점수 score | — | 1011,199,120,116 | 482,149,116,120 | 점수 1 | |
| 중앙 카드 card | — | 342,16,510,802 | | | 인라인 left: 342px; top: 16px; width: 510px; height: 802px; padding: 12px 18px; display: flex; flex-direction: column; justify- |
| 전적 열 머리 colHead | — | 364,37,466,19 | | A 라운드 B | |
| 전적 행 row2 | 1R | 364,63,466,64 | | A칸 blk winT +선배지 \| 가운데 “◀ 승 1R” \| B칸 wht loseT | aria: 1라운드 A 승 · A 선공 |
| 전적 행 row2 | 2R | 364,130,466,64 | | A칸 wht loseT +선배지 \| 가운데 “승 ▶ 2R” \| B칸 wht winT | aria: 2라운드 B 승 · A 선공 |
| 전적 행 row2 | 3R | 364,197,466,64 | | A칸 wht \| 가운데 “동점 = 3R” \| B칸 wht +선배지 | aria: 3라운드 동점 · B 선공 |
| 전적 행 row2 | 4R | 364,264,466,64 | | A칸 blk winT \| 가운데 “◀ 승 4R” \| B칸 blk loseT +선배지 | aria: 4라운드 A 승 · B 선공 |
| 전적 행 row2 | 5R | 364,331,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “5R” \| B칸 빈칸(miniEmpty) | aria: 5라운드 진행 중 · 결과는 라운드가 끝난 뒤 표시 |
| 전적 행 row2 | 6R | 364,398,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “6R” \| B칸 빈칸(miniEmpty) | aria: 6라운드 진행 전 |
| 전적 행 row2 | 7R | 364,465,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “7R” \| B칸 빈칸(miniEmpty) | aria: 7라운드 진행 전 |
| 전적 행 row2 | 8R | 364,532,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “8R” \| B칸 빈칸(miniEmpty) | aria: 8라운드 진행 전 |
| 전적 행 row2 | 9R | 364,599,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “9R” \| B칸 빈칸(miniEmpty) | aria: 9라운드 진행 전 |
| 전적 행 row2 | 10R | 364,666,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “10R” \| B칸 빈칸(miniEmpty) | aria: 10라운드 진행 전 |
| 전적 행 row2 | 11R | 364,733,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “11R” \| B칸 빈칸(miniEmpty) | aria: 11라운드 진행 전 |
| 토스트 영역 toastWrap | — | 77,278,1040,278 | | aria: A 승리. | |
| 중앙 토스트 cToast | cToastOn(빨강) tq1 | 77,278,1040,278 | | A 승리 | |
| 메뉴(룰북·설정) menu | — | 1022,20,152,72 | | 버튼 72×72 ×2: 게임 규칙 열기 / 게임 설정 열기 | |

### T08 — 느와르 · T08 · 라운드 결과 · 동점

- 원본: `project/NoirTabletRoundTie.dc.html` · 크기 1194×834 · 기준 PNG `screens/T08.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 추가 PNG: `screens/T08--base.png` (모든 토스트 opacity 0, t=0); `screens/T08--toast1.png` (t=650ms, "동점" 유지 구간 중간)
- 화면 내 반복 애니메이션: `tq1` 2300ms → “동점”
- 소스 주석: `토스트 시간 (확정): 등장 0.2s · 유지 0.9s · 퇴장 0.2s · 단계 사이 0.2s · 한 바퀴 2.3s`
- 회전 영역: A(좌) `.side` left -208px · rotate(90deg) → 회전 전 상자 -208,257,760,320, 화면상 상자 12,37,320,760; B(우) left 642px · rotate(-90deg) → 회전 전 642,257,760,320, 화면상 862,37,320,760. 아래 ‘로컬’은 회전 전 측면 상자(760×320) 기준 좌표.

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,1194,834 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| [A] 상태 pill | pillOn | 238,370.1,66,93.8 | 333.1,28,93.8,66 | 동점 | |
| [A] 슬롯 카드 slot | blk | 40,355,166,124 | 318,126,124,166 | A가 낸 흑 타일 | |
| [A] 점수 score | +배지 +0 | 63,519,120,116 | 482,149,116,120 | 점수 2 +0 | |
| [B] 상태 pill | pillOn | 890,370.1,66,93.8 | 333.1,28,93.8,66 | 동점 | |
| [B] 슬롯 카드 slot | blk | 988,355,166,124 | 318,126,124,166 | B가 낸 흑 타일 | |
| [B] 점수 score | +배지 +0 | 1011,199,120,116 | 482,149,116,120 | 점수 1 +0 | |
| 중앙 카드 card | — | 342,16,510,802 | | | 인라인 left: 342px; top: 16px; width: 510px; height: 802px; padding: 12px 18px; display: flex; flex-direction: column; justify- |
| 전적 열 머리 colHead | — | 364,37,466,19 | | A 라운드 B | |
| 전적 행 row2 | 1R | 364,63,466,64 | | A칸 blk winT +선배지 \| 가운데 “◀ 승 1R” \| B칸 wht loseT | aria: 1라운드 A 승 · A 선공 |
| 전적 행 row2 | 2R | 364,130,466,64 | | A칸 wht loseT +선배지 \| 가운데 “승 ▶ 2R” \| B칸 wht winT | aria: 2라운드 B 승 · A 선공 |
| 전적 행 row2 | 3R | 364,197,466,64 | | A칸 wht \| 가운데 “동점 = 3R” \| B칸 wht +선배지 | aria: 3라운드 동점 · B 선공 |
| 전적 행 row2 | 4R | 364,264,466,64 | | A칸 blk winT \| 가운데 “◀ 승 4R” \| B칸 blk loseT +선배지 | aria: 4라운드 A 승 · B 선공 |
| 전적 행 row2 | 5R | 364,331,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “5R” \| B칸 빈칸(miniEmpty) | aria: 5라운드 진행 중 · 결과는 라운드가 끝난 뒤 표시 |
| 전적 행 row2 | 6R | 364,398,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “6R” \| B칸 빈칸(miniEmpty) | aria: 6라운드 진행 전 |
| 전적 행 row2 | 7R | 364,465,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “7R” \| B칸 빈칸(miniEmpty) | aria: 7라운드 진행 전 |
| 전적 행 row2 | 8R | 364,532,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “8R” \| B칸 빈칸(miniEmpty) | aria: 8라운드 진행 전 |
| 전적 행 row2 | 9R | 364,599,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “9R” \| B칸 빈칸(miniEmpty) | aria: 9라운드 진행 전 |
| 전적 행 row2 | 10R | 364,666,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “10R” \| B칸 빈칸(miniEmpty) | aria: 10라운드 진행 전 |
| 전적 행 row2 | 11R | 364,733,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “11R” \| B칸 빈칸(miniEmpty) | aria: 11라운드 진행 전 |
| 토스트 영역 toastWrap | — | 77,278,1040,278 | | aria: 동점. | |
| 중앙 토스트 cToast | cToastOn(빨강) tq1 | 77,278,1040,278 | | 동점 | |
| 메뉴(룰북·설정) menu | — | 1022,20,152,72 | | 버튼 72×72 ×2: 게임 규칙 열기 / 게임 설정 열기 | |

### T09 — 느와르 · T09 · 새 라운드·선후공 안내

- 원본: `project/NoirTabletNewRound.dc.html` · 크기 1194×834 · 기준 PNG `screens/T09.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 추가 PNG: `screens/T09--base.png` (모든 토스트 opacity 0, t=0); `screens/T09--toast1.png` (t=700ms, "6라운드 / A 선공" 유지 구간 중간)
- 화면 내 반복 애니메이션: `tq1` 2400ms → “6라운드 / A 선공”
- 소스 주석: `토스트 시간 (확정): 등장 0.2s · 유지 1.0s · 퇴장 0.2s · 단계 사이 0.2s · 한 바퀴 2.4s`
- 회전 영역: A(좌) `.side` left -208px · rotate(90deg) → 회전 전 상자 -208,257,760,320, 화면상 상자 12,37,320,760; B(우) left 642px · rotate(-90deg) → 회전 전 642,257,760,320, 화면상 862,37,320,760. 아래 ‘로컬’은 회전 전 측면 상자(760×320) 기준 좌표.

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,1194,834 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| [A] 상태 pill | pillOn · 인라인 height: 76px; font-size: 30px; | 233,348.4,76,137.2 | 311.4,23,137.2,76 | 내 차례 | |
| [A] 슬롯 카드 slot | empty | 35,355,166,124 | 318,131,124,166 | ? | |
| [A] 점수 score | — | 58,519,120,116 | 482,154,116,120 | 점수 3 | |
| [B] 상태 pill | 기본 · 인라인 height: 76px; font-size: 30px; | 885,334.6,76,164.8 | 297.6,23,164.8,76 | 상대 차례 | |
| [B] 슬롯 카드 slot | empty | 993,355,166,124 | 318,131,124,166 | ? | |
| [B] 점수 score | — | 1016,199,120,116 | 482,154,116,120 | 점수 1 | |
| 중앙 카드 card | — | 342,16,510,802 | | | 인라인 left: 342px; top: 16px; width: 510px; height: 802px; padding: 12px 18px; display: flex; flex-direction: column; justify- |
| 전적 열 머리 colHead | — | 364,37,466,19 | | A 라운드 B | |
| 전적 행 row2 | 1R | 364,63,466,64 | | A칸 blk winT +선배지 \| 가운데 “◀ 승 1R” \| B칸 wht loseT | aria: 1라운드 A 승 · A 선공 |
| 전적 행 row2 | 2R | 364,130,466,64 | | A칸 wht loseT +선배지 \| 가운데 “승 ▶ 2R” \| B칸 wht winT | aria: 2라운드 B 승 · A 선공 |
| 전적 행 row2 | 3R | 364,197,466,64 | | A칸 wht \| 가운데 “동점 = 3R” \| B칸 wht +선배지 | aria: 3라운드 동점 · B 선공 |
| 전적 행 row2 | 4R | 364,264,466,64 | | A칸 blk winT \| 가운데 “◀ 승 4R” \| B칸 blk loseT +선배지 | aria: 4라운드 A 승 · B 선공 |
| 전적 행 row2 | 5R | 364,331,466,64 | | A칸 blk winT +선배지 \| 가운데 “◀ 승 5R” \| B칸 wht loseT | aria: 5라운드 A 승 · A 선공 |
| 전적 행 row2 | 6R | 364,398,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “6R” \| B칸 빈칸(miniEmpty) | aria: 6라운드 진행 중 · 결과는 라운드가 끝난 뒤 표시 |
| 전적 행 row2 | 7R | 364,465,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “7R” \| B칸 빈칸(miniEmpty) | aria: 7라운드 진행 전 |
| 전적 행 row2 | 8R | 364,532,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “8R” \| B칸 빈칸(miniEmpty) | aria: 8라운드 진행 전 |
| 전적 행 row2 | 9R | 364,599,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “9R” \| B칸 빈칸(miniEmpty) | aria: 9라운드 진행 전 |
| 전적 행 row2 | 10R | 364,666,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “10R” \| B칸 빈칸(miniEmpty) | aria: 10라운드 진행 전 |
| 전적 행 row2 | 11R | 364,733,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “11R” \| B칸 빈칸(miniEmpty) | aria: 11라운드 진행 전 |
| 토스트 영역 toastWrap | — | 77,278,1040,278 | | aria: 6라운드 A 선공. | |
| 중앙 토스트 cToast | cToastOn(빨강) tq1 | 77,278,1040,278 | | 6라운드 A 선공 | |
| 메뉴(룰북·설정) menu | — | 1022,20,152,72 | | 버튼 72×72 ×2: 게임 규칙 열기 / 게임 설정 열기 | |

### T10 — 느와르 · T10 · 조기 종료 안내

- 원본: `project/NoirTabletEarlyEnd.dc.html` · 크기 1194×834 · 기준 PNG `screens/T10.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 추가 PNG: `screens/T10--base.png` (모든 토스트 opacity 0, t=0); `screens/T10--toast1.png` (t=600ms, "게임 조기 종료" 유지 구간 중간); `screens/T10--toast2.png` (t=2350ms, "승자 / A" 유지 구간 중간)
- 화면 내 반복 애니메이션: `tq1` 4300ms → “게임 조기 종료”; `tq2` 4300ms → “승자 / A”
- 소스 주석: `토스트 시간 (확정): 등장 0.2s · 유지 0.8 / 1.5s · 퇴장 0.2s · 단계 사이 0.2s · 한 바퀴 4.3s`
- 회전 영역: A(좌) `.side` left -208px · rotate(90deg) → 회전 전 상자 -208,257,760,320, 화면상 상자 12,37,320,760; B(우) left 642px · rotate(-90deg) → 회전 전 642,257,760,320, 화면상 862,37,320,760. 아래 ‘로컬’은 회전 전 측면 상자(760×320) 기준 좌표.

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,1194,834 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| [A] 상태 pill | pillOn · 인라인 height: 76px; font-size: 28px; | 226,338.5,76,156.9 | 301.5,30,156.9,76 | 게임 종료 | |
| [A] 점수 score | — | 74,499,120,116 | 462,138,116,120 | 점수 6 | |
| [A] 왕관 svg | — | 32,390,34,54 | 353,266,54,34 | 왕관 | 인라인 margin-bottom: -10px; |
| [B] 상태 pill | 기본 · 인라인 height: 76px; font-size: 28px; | 908,338.6,76,156.9 | 301.5,46,156.9,76 | 게임 종료 | |
| [B] 점수 score | — | 1016,219,120,116 | 462,154,116,120 | 점수 2 | |
| 중앙 카드 card | — | 342,16,510,802 | | | 인라인 left: 342px; top: 16px; width: 510px; height: 802px; padding: 12px 18px; display: flex; flex-direction: column; justify- |
| 전적 열 머리 colHead | — | 364,37,466,19 | | A 라운드 B | |
| 전적 행 row2 | 1R | 364,63,466,64 | | A칸 blk winT +선배지 \| 가운데 “◀ 승 1R” \| B칸 wht loseT | aria: 1라운드 A 승 · A 선공 |
| 전적 행 row2 | 2R | 364,130,466,64 | | A칸 wht loseT +선배지 \| 가운데 “승 ▶ 2R” \| B칸 wht winT | aria: 2라운드 B 승 · A 선공 |
| 전적 행 row2 | 3R | 364,197,466,64 | | A칸 wht \| 가운데 “동점 = 3R” \| B칸 wht +선배지 | aria: 3라운드 동점 · B 선공 |
| 전적 행 row2 | 4R | 364,264,466,64 | | A칸 blk winT \| 가운데 “◀ 승 4R” \| B칸 blk loseT +선배지 | aria: 4라운드 A 승 · B 선공 |
| 전적 행 row2 | 5R | 364,331,466,64 | | A칸 blk winT +선배지 \| 가운데 “◀ 승 5R” \| B칸 wht loseT | aria: 5라운드 A 승 · A 선공 |
| 전적 행 row2 | 6R | 364,398,466,64 | | A칸 wht winT +선배지 \| 가운데 “◀ 승 6R” \| B칸 blk loseT | aria: 6라운드 A 승 · A 선공 |
| 전적 행 row2 | 7R | 364,465,466,64 | | A칸 blk loseT +선배지 \| 가운데 “승 ▶ 7R” \| B칸 blk winT | aria: 7라운드 B 승 · A 선공 |
| 전적 행 row2 | 8R | 364,532,466,64 | | A칸 wht winT \| 가운데 “◀ 승 8R” \| B칸 blk loseT +선배지 | aria: 8라운드 A 승 · B 선공 |
| 전적 행 row2 | 9R | 364,599,466,64 | | A칸 blk winT +선배지 \| 가운데 “◀ 승 9R” \| B칸 wht loseT | aria: 9라운드 A 승 · A 선공 |
| 전적 행 row2 | 10R | 364,666,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “10R” \| B칸 빈칸(miniEmpty) | aria: 10라운드 진행 전 |
| 전적 행 row2 | 11R | 364,733,466,64 | | A칸 빈칸(miniEmpty) \| 가운데 “11R” \| B칸 빈칸(miniEmpty) | aria: 11라운드 진행 전 |
| 토스트 영역 toastWrap | — | 77,278,1040,278 | | aria: 게임 조기 종료. 승자 A. | |
| 중앙 토스트 cToast | 기본(크림) tq1 | 77,278,1040,278 | | 게임 조기 종료 | |
| 중앙 토스트 cToast | cToastOn(빨강) tq2 | 77,278,1040,278 | | 승자 A | |
| 메뉴(룰북·설정) menu | — | 1022,20,152,72 | | 버튼 72×72 ×2: 게임 규칙 열기 / 게임 설정 열기 | |

### T11 — 느와르 · T11 · 최종 동점 뽑기

- 원본: `project/NoirTabletTieDraw.dc.html` · 크기 1194×834 · 기준 PNG `screens/T11.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 추가 PNG: `screens/T11--base.png` (모든 토스트 opacity 0, t=0); `screens/T11--toast1.png` (t=500ms, "동점" 유지 구간 중간); `screens/T11--toast2.png` (t=1800ms, "최종 승부" 유지 구간 중간); `screens/T11--toast3.png` (t=3150ms, "타일 선택" 유지 구간 중간)
- 화면 내 반복 애니메이션: `tq1` 4700ms → “동점”; `tq2` 4700ms → “최종 승부”; `tq3` 4700ms → “타일 선택”
- 소스 주석: `토스트 시간 (확정): 등장 0.2s · 유지 0.6 / 0.8 / 0.7s · 퇴장 0.2s · 단계 사이 0.2s · 한 바퀴 4.7s`
- 회전 영역: A(좌) `.side` left -208px · rotate(90deg) → 회전 전 상자 -208,257,760,320, 화면상 상자 12,37,320,760; B(우) left 642px · rotate(-90deg) → 회전 전 642,257,760,320, 화면상 862,37,320,760. 아래 ‘로컬’은 회전 전 측면 상자(760×320) 기준 좌표.

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,1194,834 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| [A] 상태 pill | 기본 | 238,342.5,66,149 | 305.5,28,149,66 | 상대 차례 | |
| [A] 슬롯 카드 slot | empty | 40,355,166,124 | 318,126,124,166 | ? | |
| [A] 점수 score | — | 63,519,120,116 | 482,149,116,120 | 점수 5 | |
| [B] 상태 pill | pillOn | 890,354.5,66,125 | 317.5,28,125,66 | 내 차례 | |
| [B] 슬롯 카드 slot | empty | 988,355,166,124 | 318,126,124,166 | ? | |
| [B] 점수 score | — | 1011,199,120,116 | 482,149,116,120 | 점수 5 | |
| 중앙 카드 card | — | 357,182,480,470 | | | 인라인 left: 357px; top: 182px; width: 480px; height: 470px; display: grid; grid-template-columns: repeat(3, minmax(0px, 1fr)); |
| 뽑기 카드 ptile | back | 407,249,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 551,249,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 695,249,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 407,383,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 551,383,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 695,383,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 407,517,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 551,517,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back | 695,517,92,68 | | 뒤집힌 타일 |  |
| 토스트 영역 toastWrap | — | 77,278,1040,278 | | aria: 동점. 최종 승부. 타일 선택. | |
| 중앙 토스트 cToast | 기본(크림) tq1 | 77,278,1040,278 | | 동점 | |
| 중앙 토스트 cToast | 기본(크림) tq2 | 77,278,1040,278 | | 최종 승부 | |
| 중앙 토스트 cToast | cToastOn(빨강) tq3 | 77,278,1040,278 | | 타일 선택 | |
| 메뉴(룰북·설정) menu | — | 1022,20,152,72 | | 버튼 72×72 ×2: 게임 규칙 열기 / 게임 설정 열기 | |

### T12 — 느와르 · T12 · 최종 동점 뽑기 결과

- 원본: `project/NoirTabletTieReveal.dc.html` · 크기 1194×834 · 기준 PNG `screens/T12.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 추가 PNG: `screens/T12--base.png` (모든 토스트 opacity 0, t=0); `screens/T12--toast1.png` (t=450ms, "타일 공개" 유지 구간 중간); `screens/T12--toast2.png` (t=2050ms, "B 승리" 유지 구간 중간)
- 화면 내 반복 애니메이션: `tq1` 4000ms → “타일 공개”; `tq2` 4000ms → “B 승리”
- 소스 주석: `토스트 시간 (확정): 등장 0.2s · 유지 0.5 / 1.5s · 퇴장 0.2s · 단계 사이 0.2s · 한 바퀴 4.0s`
- 회전 영역: A(좌) `.side` left -208px · rotate(90deg) → 회전 전 상자 -208,257,760,320, 화면상 상자 12,37,320,760; B(우) left 642px · rotate(-90deg) → 회전 전 642,257,760,320, 화면상 862,37,320,760. 아래 ‘로컬’은 회전 전 측면 상자(760×320) 기준 좌표.

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,1194,834 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| [A] 상태 pill | 기본 | 238,370.1,66,93.8 | 333.1,28,93.8,66 | 패배 | |
| [A] 슬롯 카드 slot | blk | 40,355,166,124 | 318,126,124,166 | 4 | |
| [A] 점수 score | — | 63,519,120,116 | 482,149,116,120 | 점수 5 | |
| [B] 상태 pill | pillOn | 890,370.1,66,93.8 | 333.1,28,93.8,66 | 승리 | |
| [B] 슬롯 카드 slot | wht | 988,355,166,124 | 318,126,124,166 | 9 | |
| [B] 점수 score | — | 1011,199,120,116 | 482,149,116,120 | 점수 5 | |
| 중앙 카드 card | — | 357,182,480,470 | | | 인라인 left: 357px; top: 182px; width: 480px; height: 470px; display: grid; grid-template-columns: repeat(3, minmax(0px, 1fr)); |
| 뽑기 카드 ptile | back/dim | 407,249,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back/dim | 551,249,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | wht/pickA +표식 B | 695,249,92,68 | | B가 뽑은 백 타일 9 | 숫자 span display: inline-block; transform: rotate(-90deg); |
| 뽑기 카드 ptile | back/dim | 407,383,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back/dim | 551,383,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back/dim | 695,383,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back/dim | 407,517,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | back/dim | 551,517,92,68 | | 뒤집힌 타일 |  |
| 뽑기 카드 ptile | blk +표식 A | 695,517,92,68 | | A가 뽑은 흑 타일 4 | 숫자 span display: inline-block; transform: rotate(90deg); |
| 토스트 영역 toastWrap | — | 77,278,1040,278 | | aria: 타일 공개. B 승리. | |
| 중앙 토스트 cToast | 기본(크림) tq1 | 77,278,1040,278 | | 타일 공개 | |
| 중앙 토스트 cToast | cToastOn(빨강) tq2 | 77,278,1040,278 | | B 승리 | |
| 메뉴(룰북·설정) menu | — | 1022,20,152,72 | | 버튼 72×72 ×2: 게임 규칙 열기 / 게임 설정 열기 | |

### T13 — 느와르 · T13 · 최종 결과

- 원본: `project/NoirTabletFinal.dc.html` · 크기 1194×834 · 기준 PNG `screens/T13.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 회전 영역: A(좌) `.side` left -220px · rotate(90deg) → 회전 전 상자 -220,257,760,320, 화면상 상자 0,37,320,760; B(우) left 654px · rotate(-90deg) → 회전 전 654,257,760,320, 화면상 874,37,320,760. 아래 ‘로컬’은 회전 전 측면 상자(760×320) 기준 좌표.

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,1194,834 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| fhLabel | — | 552.4,96,89.2,29 | | 최종 점수 | 20px/700 · 글자 #b9ae9c · 자간 2px |
| fhNum | — | 505.2,129,183.5,84 | | 6 : 2 | 84px/700 · Stardos Stencil · 글자 #f7f0e4 · 자간 2px |
| [A] 상태 pill | pillOn · 인라인 height: 68px; font-size: 26px; padding: 0px 22px; | 143,368.1,68,97.8 | 331.1,109,97.8,68 | 승리 | |
| [A] 왕관 svg | — | 99,390,34,54 | 353,187,54,34 | 왕관 | 인라인 margin-bottom: -10px; |
| [B] 상태 pill | 기본 · 인라인 height: 68px; font-size: 26px; padding: 0px 22px; | 1000,368.1,68,97.8 | 331.1,126,97.8,68 | 패배 | |
| 버튼 btn | 기본 | 477,317.5,240,68 | | 다시하기 | 22px/900 · 글자 #f7f0e4 · 배경 #d42a2f · 테두리 3px solid #141414 · 반경 18px · 그림자 #141414 0px 6px 0px 0px |
| 버튼 btn | 기본 | 477,407.5,240,68 | | HOME | 22px/900 · 글자 #f7f0e4 · 배경 #141414 · 테두리 3px solid #141414 · 반경 18px · 그림자 #141414 0px 6px 0px 0px |
| note | — | 500,497.5,194,19 | | 결과 화면은 자동으로 닫히지 않아요 | 13px/700 · 글자 #e9e1d3 |
| 메뉴(룰북·설정) menu | — | 1022,20,152,72 | | 버튼 72×72 ×2: 게임 규칙 열기 / 게임 설정 열기 | |

### T13-B — 느와르 · T13-B · 최종 결과 · 동점 뽑기로 승패 결정

- 원본: `project/NoirTabletFinalTieDraw.dc.html` · 크기 1194×834 · 기준 PNG `screens/T13-B.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 회전 영역: A(좌) `.side` left -220px · rotate(90deg) → 회전 전 상자 -220,257,760,320, 화면상 상자 0,37,320,760; B(우) left 654px · rotate(-90deg) → 회전 전 654,257,760,320, 화면상 874,37,320,760. 아래 ‘로컬’은 회전 전 측면 상자(760×320) 기준 좌표.

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,1194,834 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| fhLabel | — | 576.6,96,40.8,29 | | 승자 | 20px/700 · 글자 #b9ae9c · 자간 2px |
| fhName | — | 566.8,129,60.4,84 | | B | 84px/900 · 글자 #f7f0e4 · 자간 2px |
| [A] 상태 pill | 기본 · 인라인 height: 68px; font-size: 26px; padding: 0px 22px; | 126,368.1,68,97.8 | 331.1,126,97.8,68 | 패배 | |
| [B] 상태 pill | pillOn · 인라인 height: 68px; font-size: 26px; padding: 0px 22px; | 983,368.1,68,97.8 | 331.1,109,97.8,68 | 승리 | |
| [B] 왕관 svg | — | 1061,390,34,54 | 353,187,54,34 | 왕관 | 인라인 margin-bottom: -10px; |
| 버튼 btn | 기본 | 477,317.5,240,68 | | 다시하기 | 22px/900 · 글자 #f7f0e4 · 배경 #d42a2f · 테두리 3px solid #141414 · 반경 18px · 그림자 #141414 0px 6px 0px 0px |
| 버튼 btn | 기본 | 477,407.5,240,68 | | HOME | 22px/900 · 글자 #f7f0e4 · 배경 #141414 · 테두리 3px solid #141414 · 반경 18px · 그림자 #141414 0px 6px 0px 0px |
| note | — | 500,497.5,194,19 | | 결과 화면은 자동으로 닫히지 않아요 | 13px/700 · 글자 #e9e1d3 |
| 메뉴(룰북·설정) menu | — | 1022,20,152,72 | | 버튼 72×72 ×2: 게임 규칙 열기 / 게임 설정 열기 | |

### P01 — 느와르 · P01 · 선공 뽑기 안내 (T01–T03)

- 원본: `project/NoirPhoneDrawWait.dc.html` · 크기 844×390 · 기준 PNG `screens/P01.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 화면 내 반복 애니메이션: `turnFlash` 4000ms → “선공 뽑기 / 내가 먼저 뽑아요”

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | A | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 0 : 0 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | turnFlash | 173.9,18,518.1,52 | | | 배경 #c9242a · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,67.5,23 |  | 선공 뽑기 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 272.4,31.5,408.6,25 |  | 내가 먼저 뽑아요 | 17px/900 · 글자 #f7f0e4 |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 안내 카드 chip | 기본 | 82,111,680,240 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 32px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 240.4,137,363.1,40.8 |  | 태블릿에서 카드를 뽑아요 | 34px/900 · 글자 #141414 |
| 타일(인라인 크기) tile | 기본 | 337,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: repeating-linear-gradient(45deg, rgb(125, 29, 34) 0px, rgb(125, 29, 34) 8p |
| 타일(인라인 크기) tile | 기본 | 397,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: repeating-linear-gradient(45deg, rgb(125, 29, 34) 0px, rgb(125, 29, 34) 8p |
| 타일(인라인 크기) tile | 기본 | 457,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: repeating-linear-gradient(45deg, rgb(125, 29, 34) 0px, rgb(125, 29, 34) 8p |
| div | — | 248.7,273.8,346.6,25.6 |  | 태블릿의 뒤집힌 타일 중 하나를 골라 주세요 | 19px/400 · 글자 #6e655a |
| div | — | 271.5,303.4,301,21.6 |  | 더 큰 숫자를 뽑은 사람이 1라운드 선공이에요 | 16px/400 · 글자 #6e655a |

### P02 — 느와르 · P02 · 선공 · 타일 선택 중 (A)

- 원본: `project/NoirStyledSelect.dc.html` · 크기 844×390 · 기준 PNG `screens/P02.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 화면 내 반복 애니메이션: `turnFlash` 4000ms → “5R · 선공 / 타일을 고르고 제출하세요 / 0:42”; `submitPop` 4000ms → “제출하기”

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | A | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 2 : 1 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | turnFlash | 173.9,18,518.1,52 | | | 배경 #c9242a · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,68,23 |  | 5R · 선공 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 272.9,31.5,335.1,25 |  | 타일을 고르고 제출하세요 | 17px/900 · 글자 #f7f0e4 |
| div | — | 619.9,27.5,61.1,33 |  | 0:42 | 17px/900 · 글자 #f7f0e4 · 배경 #141414 · 반경 10px |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 손패 타일 tile | blk | 61,136,64,84 | | 0 |  |
| 손패 타일 tile | blk | 135,136,64,84 | | 2 |  |
| 손패 타일 tile | blk/used | 209,136,64,84 | | 4 |  |
| 손패 타일 tile | blk/sel +선택 배지 | 280.8,126.4,68.3,87.2 | | 6 |  |
| 손패 타일 tile | blk/used | 357,136,64,84 | | 8 |  |
| 손패 타일 tile | blk | 431,136,64,84 | | 11 |  |
| 손패 타일 tile | wht/used | 98,242,64,84 | | 1 |  |
| 손패 타일 tile | wht/used | 172,242,64,84 | | 3 |  |
| 손패 타일 tile | wht | 246,242,64,84 | | 5 |  |
| 손패 타일 tile | wht | 320,242,64,84 | | 7 |  |
| 손패 타일 tile | wht | 394,242,64,84 | | 9 |  |
| 오른쪽 패널 chip | 기본 | 556,88,268,286 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 24px · 그림자 #141414 0px 5px 0px 0px |
| 타일(인라인 크기) tile | blk | 577,128.5,78,104 | | 6 | 인라인 width: 78px; height: 104px; font-size: 40px; |
| div | — | 671,153,97.7,19 |  | 이 타일을 낼까요? | 13px/700 · 글자 #6e655a |
| div | — | 671,176,97.7,32 |  | 흑 6 | 22px/900 · 글자 #141414 |
| 버튼 btn | submitPop | 577,266,226,56 | | 제출하기 | 18px/900 · 글자 #f7f0e4 · 배경 #c9242a · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 577,336,226,17 |  | 제출하면 취소할 수 없어요 | 12px/400 · 글자 #6e655a |

### P03 — 느와르 · P03 · 후공 · 미리 선택, 제출 잠김 (B)

- 원본: `project/NoirStyledLocked.dc.html` · 크기 844×390 · 기준 PNG `screens/P03.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | B | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 1 : 2 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | 기본 | 173.9,18,518.1,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,68,23 |  | 5R · 후공 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 272.9,31.5,400.1,25 |  | 상대가 고르는 중 · 미리 골라두세요 | 17px/900 · 글자 #141414 |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 손패 타일 tile | blk | 61,136,64,84 | | 0 |  |
| 손패 타일 tile | blk/used | 135,136,64,84 | | 2 |  |
| 손패 타일 tile | blk | 209,136,64,84 | | 4 |  |
| 손패 타일 tile | blk | 283,136,64,84 | | 6 |  |
| 손패 타일 tile | blk | 357,136,64,84 | | 8 |  |
| 손패 타일 tile | blk | 431,136,64,84 | | 11 |  |
| 손패 타일 tile | wht/used | 98,242,64,84 | | 1 |  |
| 손패 타일 tile | wht | 172,242,64,84 | | 3 |  |
| 손패 타일 tile | wht/used | 246,242,64,84 | | 5 |  |
| 손패 타일 tile | wht/sel +선택 배지 | 317.8,232.4,68.3,87.2 | | 7 |  |
| 손패 타일 tile | wht/used | 394,242,64,84 | | 9 |  |
| 오른쪽 패널 chip | 기본 | 556,88,268,286 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 24px · 그림자 #141414 0px 5px 0px 0px |
| 타일(인라인 크기) tile | wht | 577,128.5,75.9,104 | | 7 | 인라인 width: 78px; height: 104px; font-size: 40px; |
| div | — | 668.9,134,134.1,19 |  | 선택한 타일 | 13px/700 · 글자 #6e655a |
| div | — | 668.9,157,134.1,32 |  | 백 7 | 22px/900 · 글자 #141414 |
| div | — | 668.9,193,134.1,34 |  | 선공 색을 본 뒤 바꿔도 돼요 | 12px/400 · 글자 #6e655a |
| 버튼 btn | 기본 | 577,266,226,56 | | 선공 제출 후 제출 가능 | 15px/900 · 글자 #6e655a · 배경 #ece3d3 · 테두리 3px solid #b9ae9c · 반경 16px |
| div | — | 577,336,226,17 |  | 내 차례는 A 차례 이후 시작해요 | 12px/400 · 글자 #6e655a |

### P04 — 느와르 · P04 · 선공 · 제출 완료, 상대 차례 (A)

- 원본: `project/NoirStyledSubmitted.dc.html` · 크기 844×390 · 기준 PNG `screens/P04.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | A | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 2 : 1 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | 기본 | 173.9,18,518.1,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,95.5,23 |  | 5R · 후공 차례 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 300.4,31.5,372.6,25 |  | 상대가 고르는 중이에요 | 17px/900 · 글자 #141414 |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 손패 타일 tile | blk/wait | 61,136,64,84 | | 0 |  |
| 손패 타일 tile | blk/wait | 135,136,64,84 | | 2 |  |
| 손패 타일 tile | blk/used | 209,136,64,84 | | 4 |  |
| 손패 타일 tile | blk/used | 283,136,64,84 | | 6 |  |
| 손패 타일 tile | blk/used | 357,136,64,84 | | 8 |  |
| 손패 타일 tile | blk/wait | 431,136,64,84 | | 11 |  |
| 손패 타일 tile | wht/used | 98,242,64,84 | | 1 |  |
| 손패 타일 tile | wht/used | 172,242,64,84 | | 3 |  |
| 손패 타일 tile | wht/wait | 246,242,64,84 | | 5 |  |
| 손패 타일 tile | wht/wait | 320,242,64,84 | | 7 |  |
| 손패 타일 tile | wht/wait | 394,242,64,84 | | 9 |  |
| 오른쪽 패널 chip | 기본 | 556,88,268,286 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 24px · 그림자 #141414 0px 5px 0px 0px |
| 타일(인라인 크기) tile | blk | 577,141,78,104 | | 6 | 인라인 width: 78px; height: 104px; font-size: 40px; |
| div | — | 605.7,124.4,70.1,32.2 |  | 제출 완료 | 12px/900 · 글자 #f7f0e4 · 배경 #d42a2f · 테두리 2px solid #141414 · 반경 8px · transform rotate(8deg) |
| div | — | 671,155,128.2,19 |  | 이번 라운드에 낸 타일 | 13px/700 · 글자 #6e655a |
| div | — | 671,178,128.2,32 |  | 흑 6 | 22px/900 · 글자 #141414 |
| div | — | 671,214,128.2,17 |  | 태블릿에는 흑색만 보여요 | 12px/400 · 글자 #6e655a |
| div | — | 577,291,226,62 |  | 결과는 태블릿에서 확인해요 | 15px/700 · 글자 #6e655a · 테두리 3px dashed #b9ae9c · 반경 16px |

### P05 — 느와르 · P05 · 후공 · 제출 가능 (B)

- 원본: `project/NoirPhoneSecondSubmit.dc.html` · 크기 844×390 · 기준 PNG `screens/P05.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 화면 내 반복 애니메이션: `turnFlash` 4000ms → “5R · 후공 / 내 차례예요 · 타일을 고르고 제출하세요 / 0:58”; `submitPop` 4000ms → “제출하기”

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | B | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 1 : 2 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | turnFlash | 173.9,18,518.1,52 | | | 배경 #c9242a · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,68,23 |  | 5R · 후공 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 272.9,31.5,335.1,25 |  | 내 차례예요 · 타일을 고르고 제출하세요 | 17px/900 · 글자 #f7f0e4 |
| div | — | 619.9,27.5,61.1,33 |  | 0:58 | 17px/900 · 글자 #f7f0e4 · 배경 #141414 · 반경 10px |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 손패 타일 tile | blk | 61,136,64,84 | | 0 |  |
| 손패 타일 tile | blk/used | 135,136,64,84 | | 2 |  |
| 손패 타일 tile | blk | 209,136,64,84 | | 4 |  |
| 손패 타일 tile | blk | 283,136,64,84 | | 6 |  |
| 손패 타일 tile | blk | 357,136,64,84 | | 8 |  |
| 손패 타일 tile | blk | 431,136,64,84 | | 11 |  |
| 손패 타일 tile | wht/used | 98,242,64,84 | | 1 |  |
| 손패 타일 tile | wht | 172,242,64,84 | | 3 |  |
| 손패 타일 tile | wht/used | 246,242,64,84 | | 5 |  |
| 손패 타일 tile | wht/sel +선택 배지 | 317.8,232.4,68.3,87.2 | | 7 |  |
| 손패 타일 tile | wht/used | 394,242,64,84 | | 9 |  |
| 오른쪽 패널 chip | 기본 | 556,88,268,286 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 24px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 577,109,226,42 |  |  | 배경 #efe6d6 · 반경 12px |
| 타일(인라인 크기) tile | blk | 587,115,22,30 | |  | 인라인 width: 22px; height: 30px; border-width: 2px; box-shadow: none; |
| div | — | 617,120.5,114.9,19 |  | A가 흑 타일을 냈어요 | 13px/700 · 글자 #141414 |
| 타일(인라인 크기) tile | wht | 577,182,66,88 | | 7 | 인라인 width: 66px; height: 88px; font-size: 36px; |
| div | — | 659,198.5,63.5,19 |  | 선택한 타일 | 13px/700 · 글자 #6e655a |
| div | — | 659,221.5,63.5,32 |  | 백 7 | 22px/900 · 글자 #141414 |
| 버튼 btn | submitPop | 577,301,226,52 | | 제출하기 | 18px/900 · 글자 #f7f0e4 · 배경 #c9242a · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |

### P06 — 느와르 · P06 · 시간 초과 자동 제출 (B)

- 원본: `project/NoirPhoneTimeout.dc.html` · 크기 844×390 · 기준 PNG `screens/P06.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | B | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 1 : 2 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | 기본 | 173.9,18,518.1,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,95.5,23 |  | 5R · 시간 초과 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 300.4,31.5,380.6,25 |  | 시간이 지나 타일이 자동으로 제출됐어요 | 17px/900 · 글자 #141414 |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 손패 타일 tile | blk/used | 61,136,64,84 | | 0 |  |
| 손패 타일 tile | blk/used | 135,136,64,84 | | 2 |  |
| 손패 타일 tile | blk/wait | 209,136,64,84 | | 4 |  |
| 손패 타일 tile | blk/wait | 283,136,64,84 | | 6 |  |
| 손패 타일 tile | blk/wait | 357,136,64,84 | | 8 |  |
| 손패 타일 tile | blk/wait | 431,136,64,84 | | 11 |  |
| 손패 타일 tile | wht/used | 98,242,64,84 | | 1 |  |
| 손패 타일 tile | wht/wait | 172,242,64,84 | | 3 |  |
| 손패 타일 tile | wht/used | 246,242,64,84 | | 5 |  |
| 손패 타일 tile | wht/wait | 320,242,64,84 | | 7 |  |
| 손패 타일 tile | wht/used | 394,242,64,84 | | 9 |  |
| 오른쪽 패널 chip | 기본 | 556,88,268,286 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 24px · 그림자 #141414 0px 5px 0px 0px |
| 타일(인라인 크기) tile | blk | 577,141,78,104 | | 0 | 인라인 width: 78px; height: 104px; font-size: 40px; |
| 배지 auto | — | 597.7,124.4,70.1,32.2 | | 자동 제출 | 12px/900 · 글자 #f7f0e4 · 배경 #d42a2f · 테두리 2px solid #141414 · 반경 8px |
| div | — | 671,155,118.6,19 |  | 남은 타일 중 무작위로 | 13px/700 · 글자 #6e655a |
| div | — | 671,178,118.6,32 |  | 흑 0 | 22px/900 · 글자 #141414 |
| div | — | 671,214,118.6,17 |  | 이번 라운드에 냈어요 | 12px/400 · 글자 #6e655a |
| div | — | 577,291,226,62 |  | 결과는 태블릿에서 확인해요 | 15px/700 · 글자 #6e655a · 테두리 3px dashed #b9ae9c · 반경 16px |

### P07 — 느와르 · P07 · 후공 · 제출 완료, 결과 대기 (B)

- 원본: `project/NoirPhoneSecondDone.dc.html` · 크기 844×390 · 기준 PNG `screens/P07.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | B | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 1 : 2 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | 기본 | 173.9,18,518.1,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,95.5,23 |  | 5R · 결과 대기 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 300.4,31.5,380.6,25 |  | 두 사람 모두 냈어요 | 17px/900 · 글자 #141414 |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 손패 타일 tile | blk/wait | 61,136,64,84 | | 0 |  |
| 손패 타일 tile | blk/used | 135,136,64,84 | | 2 |  |
| 손패 타일 tile | blk/wait | 209,136,64,84 | | 4 |  |
| 손패 타일 tile | blk/wait | 283,136,64,84 | | 6 |  |
| 손패 타일 tile | blk/wait | 357,136,64,84 | | 8 |  |
| 손패 타일 tile | blk/wait | 431,136,64,84 | | 11 |  |
| 손패 타일 tile | wht/used | 98,242,64,84 | | 1 |  |
| 손패 타일 tile | wht/wait | 172,242,64,84 | | 3 |  |
| 손패 타일 tile | wht/used | 246,242,64,84 | | 5 |  |
| 손패 타일 tile | wht/used | 320,242,64,84 | | 7 |  |
| 손패 타일 tile | wht/used | 394,242,64,84 | | 9 |  |
| 오른쪽 패널 chip | 기본 | 556,88,268,286 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 24px · 그림자 #141414 0px 5px 0px 0px |
| 타일(인라인 크기) tile | wht | 577,141,78,104 | | 7 | 인라인 width: 78px; height: 104px; font-size: 40px; |
| 배지 auto | — | 597.7,124.4,70.1,32.2 | | 제출 완료 | 12px/900 · 글자 #f7f0e4 · 배경 #d42a2f · 테두리 2px solid #141414 · 반경 8px |
| div | — | 671,155,128.2,19 |  | 이번 라운드에 낸 타일 | 13px/700 · 글자 #6e655a |
| div | — | 671,178,128.2,32 |  | 백 7 | 22px/900 · 글자 #141414 |
| div | — | 671,214,128.2,17 |  | 태블릿에는 백색만 보여요 | 12px/400 · 글자 #6e655a |
| div | — | 577,291,226,62 |  | 결과는 태블릿에서 확인해요 | 15px/700 · 글자 #6e655a · 테두리 3px dashed #b9ae9c · 반경 16px |

### P08 — 느와르 · P08 · 결과·다음 라운드 전환 중 (A)

- 원본: `project/NoirPhoneTransition.dc.html` · 크기 844×390 · 기준 PNG `screens/P08.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | A | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 3 : 1 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | 기본 | 173.9,18,518.1,52 | | | 배경 #c9242a · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,60.1,23 |  | 5R 결과 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 265,31.5,416,25 |  | 내가 이겼어요! +1 | 17px/900 · 글자 #f7f0e4 |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 손패 타일 tile | blk/wait | 61,136,64,84 | | 0 |  |
| 손패 타일 tile | blk/wait | 135,136,64,84 | | 2 |  |
| 손패 타일 tile | blk/used | 209,136,64,84 | | 4 |  |
| 손패 타일 tile | blk/used | 283,136,64,84 | | 6 |  |
| 손패 타일 tile | blk/used | 357,136,64,84 | | 8 |  |
| 손패 타일 tile | blk/wait | 431,136,64,84 | | 11 |  |
| 손패 타일 tile | wht/used | 98,242,64,84 | | 1 |  |
| 손패 타일 tile | wht/used | 172,242,64,84 | | 3 |  |
| 손패 타일 tile | wht/wait | 246,242,64,84 | | 5 |  |
| 손패 타일 tile | wht/wait | 320,242,64,84 | | 7 |  |
| 손패 타일 tile | wht/wait | 394,242,64,84 | | 9 |  |
| 오른쪽 패널 chip | 기본 | 556,88,268,286 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 24px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 577,140.5,226,19 |  | 곧 다음 라운드가 시작돼요 | 13px/700 · 글자 #6e655a |
| div | — | 577,167.5,226,44 |  | 6라운드 | 30px/900 · 글자 #141414 |
| span | — | 577,221,39.9,23 |  | 선공 | 13px/700 · 글자 #f7f0e4 · 배경 #c9242a · 반경 8px |
| span | — | 624.9,219.5,109.5,26 |  | 내가 먼저 내요 | 18px/900 · 글자 #141414 |
| div | — | 577,291,226,62 |  | 태블릿에서 결과를 보여주는 중 | 15px/700 · 글자 #6e655a · 테두리 3px dashed #b9ae9c · 반경 16px |

### P09 — 느와르 · P09 · 마지막 타일 1개 (A, 11R)

- 원본: `project/NoirPhoneLastTile.dc.html` · 크기 844×390 · 기준 PNG `screens/P09.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 화면 내 반복 애니메이션: `turnFlash` 4000ms → “11R · 선공 / 마지막 타일이에요 · 제출 버튼을 눌러 주세요 / 0:51”; `submitPop` 4000ms → “제출하기”

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | A | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 4 : 5 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | turnFlash | 173.9,18,518.1,52 | | | 배경 #c9242a · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,75.7,23 |  | 11R · 선공 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 280.5,31.5,327.4,25 |  | 마지막 타일이에요 · 제출 버튼을 눌러 주세요 | 17px/900 · 글자 #f7f0e4 |
| div | — | 619.9,27.5,61.1,33 |  | 0:51 | 17px/900 · 글자 #f7f0e4 · 배경 #141414 · 반경 10px |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 손패 타일 tile | blk/used | 61,136,64,84 | | 0 |  |
| 손패 타일 tile | blk/used | 135,136,64,84 | | 2 |  |
| 손패 타일 tile | blk/used | 209,136,64,84 | | 4 |  |
| 손패 타일 tile | blk/used | 283,136,64,84 | | 6 |  |
| 손패 타일 tile | blk/used | 357,136,64,84 | | 8 |  |
| 손패 타일 tile | blk/sel +선택 배지 | 428.8,126.4,68.3,87.2 | | 11 |  |
| 손패 타일 tile | wht/used | 98,242,64,84 | | 1 |  |
| 손패 타일 tile | wht/used | 172,242,64,84 | | 3 |  |
| 손패 타일 tile | wht/used | 246,242,64,84 | | 5 |  |
| 손패 타일 tile | wht/used | 320,242,64,84 | | 7 |  |
| 손패 타일 tile | wht/used | 394,242,64,84 | | 9 |  |
| 오른쪽 패널 chip | 기본 | 556,88,268,286 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 24px · 그림자 #141414 0px 5px 0px 0px |
| 타일(인라인 크기) tile | blk | 577,128.5,78,104 | | 11 | 인라인 width: 78px; height: 104px; font-size: 36px; |
| div | — | 671,153,91,19 |  | 마지막 남은 타일 | 13px/700 · 글자 #6e655a |
| div | — | 671,176,91,32 |  | 흑 11 | 22px/900 · 글자 #141414 |
| 버튼 btn | submitPop | 577,266,226,56 | | 제출하기 | 18px/900 · 글자 #f7f0e4 · 배경 #c9242a · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 577,336,226,17 |  | 제출하면 취소할 수 없어요 | 12px/400 · 글자 #6e655a |

### P10 — 느와르 · P10 · 게임 종료 · 이긴 사람 (A)

- 원본: `project/NoirPhoneGameEnd.dc.html` · 크기 844×390 · 기준 PNG `screens/P10.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | A | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 6 : 2 | 17px/900 · 글자 #c9242a |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 왕관 svg | — | 384,105.5,76,44 |  | 왕관 | 인라인 margin-bottom: -16px; position: relative; |
| div | — | 364,139.5,116,116 |  |  | 배경 #c9242a · 테두리 4px solid #141414 · 반경 58px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 379,154.5,86,86 |  | A | 36px/900 · 글자 #141414 · 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 43px |
| div | — | 413.4,267.5,17.2,37 |  | A | 26px/900 · 글자 #f7f0e4 |
| div | — | 381.9,310.5,80.3,21 |  | WINNER | 15px/900 · 글자 #e23a3a · 자간 3px |
| div | — | 273,337.5,298,19 |  | 최종 6 : 2 · 다시하기와 HOME은 태블릿에서 선택해요 | 13px/700 · 글자 #e9e1d3 |

### P11 — 느와르 · P11 · 게임 종료 · 진 사람 (B)

- 원본: `project/NoirPhoneGameEndLose.dc.html` · 크기 844×390 · 기준 PNG `screens/P11.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | B | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 2 : 6 | 17px/900 · 글자 #c9242a |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 왕관 svg | — | 384,105.5,76,44 |  | 왕관 | 인라인 margin-bottom: -16px; position: relative; |
| div | — | 364,139.5,116,116 |  |  | 배경 #c9242a · 테두리 4px solid #141414 · 반경 58px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 379,154.5,86,86 |  | A | 36px/900 · 글자 #141414 · 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 43px |
| div | — | 413.4,267.5,17.2,37 |  | A | 26px/900 · 글자 #f7f0e4 |
| div | — | 381.9,310.5,80.3,21 |  | WINNER | 15px/900 · 글자 #e23a3a · 자간 3px |
| div | — | 273,337.5,298,19 |  | 최종 2 : 6 · 다시하기와 HOME은 태블릿에서 선택해요 | 13px/700 · 글자 #e9e1d3 |

### G1 — 느와르 · G1 · 선공 뽑기 · 내 차례 안내 (A)

- 원본: `project/NoirPhoneDrawGuide.dc.html` · 크기 844×390 · 기준 PNG `screens/G1.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 화면 내 반복 애니메이션: `turnFlash` 4000ms → “선공 뽑기 / 내가 먼저 뽑아요”

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | A | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 0 : 0 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | turnFlash | 173.9,18,518.1,52 | | | 배경 #c9242a · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,67.5,23 |  | 선공 뽑기 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 272.4,31.5,408.6,25 |  | 내가 먼저 뽑아요 | 17px/900 · 글자 #f7f0e4 |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 안내 카드 chip | 기본 | 82,111,680,240 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 32px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 240.4,137,363.1,40.8 |  | 태블릿에서 카드를 뽑아요 | 34px/900 · 글자 #141414 |
| 타일(인라인 크기) tile | 기본 | 337,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: repeating-linear-gradient(45deg, rgb(125, 29, 34) 0px, rgb(125, 29, 34) 8p |
| 타일(인라인 크기) tile | 기본 | 397,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: repeating-linear-gradient(45deg, rgb(125, 29, 34) 0px, rgb(125, 29, 34) 8p |
| 타일(인라인 크기) tile | 기본 | 457,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: repeating-linear-gradient(45deg, rgb(125, 29, 34) 0px, rgb(125, 29, 34) 8p |
| div | — | 248.7,273.8,346.6,25.6 |  | 태블릿의 뒤집힌 타일 중 하나를 골라 주세요 | 19px/400 · 글자 #6e655a |
| div | — | 271.5,303.4,301,21.6 |  | 더 큰 숫자를 뽑은 사람이 1라운드 선공이에요 | 16px/400 · 글자 #6e655a |

### G2 — 느와르 · G2 · 선공 뽑기 · 상대가 먼저 뽑는 중 (B)

- 원본: `project/NoirPhoneDrawOtherWait.dc.html` · 크기 844×390 · 기준 PNG `screens/G2.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | B | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 0 : 0 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | 기본 | 173.9,18,518.1,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,67.5,23 |  | 선공 뽑기 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 272.4,31.5,408.6,25 |  | A가 먼저 뽑고 있어요 | 17px/900 · 글자 #141414 |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 안내 카드 chip | 기본 | 82,111,680,240 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 32px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 271.4,137,301.3,40.8 |  | A가 먼저 뽑고 있어요 | 34px/900 · 글자 #141414 |
| 타일(인라인 크기) tile | 기본 | 337,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: repeating-linear-gradient(45deg, rgb(125, 29, 34) 0px, rgb(125, 29, 34) 8p |
| 타일(인라인 크기) tile | 기본 | 397,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: repeating-linear-gradient(45deg, rgb(125, 29, 34) 0px, rgb(125, 29, 34) 8p |
| 타일(인라인 크기) tile | 기본 | 457,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: repeating-linear-gradient(45deg, rgb(125, 29, 34) 0px, rgb(125, 29, 34) 8p |
| div | — | 329.4,273.8,185.1,25.6 |  | A가 뽑으면 내 차례예요 | 19px/400 · 글자 #6e655a |
| div | — | 271.5,303.4,301,21.6 |  | 더 큰 숫자를 뽑은 사람이 1라운드 선공이에요 | 16px/400 · 글자 #6e655a |

### G3 — 느와르 · G3 · 선공 뽑기 · 뽑은 뒤 대기 (A)

- 원본: `project/NoirPhoneDrawPicked.dc.html` · 크기 844×390 · 기준 PNG `screens/G3.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | A | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 0 : 0 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | 기본 | 173.9,18,518.1,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,67.5,23 |  | 선공 뽑기 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 272.4,31.5,408.6,25 |  | 뽑았어요 · B를 기다려요 | 17px/900 · 글자 #141414 |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 안내 카드 chip | 기본 | 82,111,680,240 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 32px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 359.4,137,125.1,40.8 |  | 뽑았어요 | 34px/900 · 글자 #141414 |
| 타일(인라인 크기) tile | 기본 | 397,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: repeating-linear-gradient(45deg, rgb(125, 29, 34) 0px, rgb(125, 29, 34) 8p |
| div | — | 280,273.8,284,25.6 |  | B가 뽑으면 두 숫자를 함께 공개해요 | 19px/400 · 글자 #6e655a |
| div | — | 329.2,303.4,185.6,21.6 |  | 결과는 태블릿에서 확인해요 | 16px/400 · 글자 #6e655a |

### G4 — 느와르 · G4 · 선공 뽑기 결과 · 내가 선공 (A)

- 원본: `project/NoirPhoneDrawResultWin.dc.html` · 크기 844×390 · 기준 PNG `screens/G4.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | A | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 0 : 0 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | 기본 | 173.9,18,518.1,52 | | | 배경 #c9242a · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,67.5,23 |  | 선공 뽑기 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 272.4,31.5,408.6,25 |  | 내가 선공이에요 | 17px/900 · 글자 #f7f0e4 |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 안내 카드 chip | 기본 | 82,111,680,240 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 32px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 307.8,137,228.5,40.8 |  | 내가 선공이에요 | 34px/900 · 글자 #141414 |
| 타일(인라인 크기) tile | wht | 346.8,191.8,50,66 | | 7 | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; font-size: 30px; outline: rgb(226, 58, 58) solid 4px; outline-offset: 3px; |
| div | — | 406.8,210.3,30.3,29 |  | vs | 20px/900 · 글자 #6e655a |
| 타일(인라인 크기) tile | wht | 447.2,191.8,50,66 | | 3 | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; font-size: 30px; opacity: 0.45; |
| div | — | 301.3,273.8,241.4,25.6 |  | 7 vs 3 · 더 큰 숫자를 뽑았어요 | 19px/400 · 글자 #6e655a |
| div | — | 337.1,303.4,169.8,21.6 |  | 1라운드는 내가 먼저 내요 | 16px/400 · 글자 #6e655a |

### G5 — 느와르 · G5 · 선공 뽑기 결과 · 상대가 선공 (B)

- 원본: `project/NoirPhoneDrawResultLose.dc.html` · 크기 844×390 · 기준 PNG `screens/G5.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | B | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 0 : 0 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | 기본 | 173.9,18,518.1,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,67.5,23 |  | 선공 뽑기 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 272.4,31.5,408.6,25 |  | A가 선공이에요 | 17px/900 · 글자 #141414 |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 안내 카드 chip | 기본 | 82,111,680,240 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 32px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 312.2,137,219.6,40.8 |  | A가 선공이에요 | 34px/900 · 글자 #141414 |
| 타일(인라인 크기) tile | wht | 346.8,191.8,50,66 | | 3 | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; font-size: 30px; opacity: 0.45; |
| div | — | 406.8,210.3,30.3,29 |  | vs | 20px/900 · 글자 #6e655a |
| 타일(인라인 크기) tile | wht | 447.2,191.8,50,66 | | 7 | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; font-size: 30px; outline: rgb(226, 58, 58) solid 4px; outline-offset: 3px; |
| div | — | 284,273.8,276,25.6 |  | 3 vs 7 · A가 더 큰 숫자를 뽑았어요 | 19px/400 · 글자 #6e655a |
| div | — | 339.5,303.4,165,21.6 |  | 1라운드는 A 다음에 내요 | 16px/400 · 글자 #6e655a |

### G6 — 느와르 · G6 · 라운드 결과 확인 안내 (T07–T09)

- 원본: `project/NoirPhoneRoundResultWait.dc.html` · 크기 844×390 · 기준 PNG `screens/G6.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | A | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 3 : 1 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | 기본 | 173.9,18,518.1,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,60.1,23 |  | 5R 결과 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 265,31.5,416,25 |  | 결과 확인 중 | 17px/900 · 글자 #141414 |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 안내 카드 chip | 기본 | 82,111,680,240 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 32px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 224.8,137,394.4,40.8 |  | 태블릿에서 결과를 확인해요 | 34px/900 · 글자 #141414 |
| 타일(인라인 크기) tile | 기본 | 343.7,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: rgb(27, 27, 27); outline: rgb(226, 58, 58) solid 4px; outline-offset: 3px; |
| div | — | 403.7,208.8,36.6,32 |  | vs | 22px/900 · 글자 #6e655a |
| 타일(인라인 크기) tile | 기본 | 450.3,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: rgb(247, 240, 228); opacity: 0.4; |
| div | — | 242.6,273.8,358.7,25.6 |  | 이번 라운드 승패와 점수가 태블릿에 표시돼요 | 19px/400 · 글자 #6e655a |
| div | — | 302.6,303.4,238.7,21.6 |  | 이긴 사람이 다음 라운드 선공이에요 | 16px/400 · 글자 #6e655a |

### G7 — 느와르 · G7 · 조기 종료 안내 (T10)

- 원본: `project/NoirPhoneEarlyEndWait.dc.html` · 크기 844×390 · 기준 PNG `screens/G7.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | A | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 6 : 2 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | 기본 | 173.9,18,518.1,52 | | | 배경 #c9242a · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,67.5,23 |  | 조기 종료 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 272.4,31.5,408.6,25 |  | 게임 종료 | 17px/900 · 글자 #f7f0e4 |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 안내 카드 chip | 기본 | 82,111,680,240 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 32px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 271.7,147,300.6,40.8 |  | 게임이 일찍 끝났어요 | 34px/900 · 글자 #141414 |
| div | — | 373,201.8,98,46 |  | 6 : 2 | 46px/900 · 글자 #c9242a |
| div | — | 231.2,263.8,381.5,25.6 |  | 남은 라운드를 모두 이겨도 결과가 바뀌지 않아요 | 19px/400 · 글자 #6e655a |
| div | — | 276.1,293.4,291.8,21.6 |  | 최종 결과는 태블릿과 이 화면에 곧 표시돼요 | 16px/400 · 글자 #6e655a |

### G8 — 느와르 · G8 · 최종 동점 뽑기 안내 (T11–T12)

- 원본: `project/NoirPhoneTieDrawWait.dc.html` · 크기 844×390 · 기준 PNG `screens/G8.png` (동작 줄이기 상태 = 소스가 정의한 정지 상태)
- 화면 내 반복 애니메이션: `turnFlash` 4000ms → “동점 뽑기 / 내 차례”

| 부품 / 요소 | 변형 | 화면 x,y,w,h | 로컬 x,y,w,h | 문구 | 스타일(부품 외 요소) |
|---|---|---|---|---|---|
| 배경 stage | — | 0,0,844,390 | | | 배경 #262524 · 배경이미지 repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(25 |
| 플레이어 칩 chip | 기본 | 20,18,139.9,52 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 29,23,42,42 |  | A | 16px/900 · 글자 #141414 · 배경 #e7dccb · 테두리 2px solid #141414 · 반경 19px |
| div | — | 81,31.5,15.6,25 |  | 나 | 17px/900 · 글자 #141414 |
| div | — | 106.6,31.5,36.2,25 |  | 5 : 5 | 17px/900 · 글자 #c9242a |
| 상태 칩 chip | turnFlash | 173.9,18,518.1,52 | | | 배경 #c9242a · 테두리 3px solid #141414 · 반경 16px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 192.9,32.5,67.5,23 |  | 동점 뽑기 | 13px/700 · 글자 #f7f0e4 · 배경 #141414 · 반경 8px |
| div | — | 272.4,31.5,408.6,25 |  | 내 차례 | 17px/900 · 글자 #f7f0e4 |
| 아이콘 버튼 btn | 규칙 보기 | 706,18,52,52 | | ? | 52×52 · 배경 #f7f0e4 |
| 아이콘 버튼 btn | 나가기 | 772,18,52,52 | |  | 52×52 · 배경 #f7f0e4 |
| 안내 카드 chip | 기본 | 82,111,680,240 | | | 배경 #f7f0e4 · 테두리 3px solid #141414 · 반경 32px · 그림자 #141414 0px 5px 0px 0px |
| div | — | 240.4,137,363.1,40.8 |  | 태블릿에서 카드를 뽑아요 | 34px/900 · 글자 #141414 |
| 타일(인라인 크기) tile | 기본 | 337,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: repeating-linear-gradient(45deg, rgb(125, 29, 34) 0px, rgb(125, 29, 34) 8p |
| 타일(인라인 크기) tile | 기본 | 397,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: repeating-linear-gradient(45deg, rgb(125, 29, 34) 0px, rgb(125, 29, 34) 8p |
| 타일(인라인 크기) tile | 기본 | 457,191.8,50,66 | |  | 인라인 width: 50px; height: 66px; border-width: 3px; box-shadow: none; background: repeating-linear-gradient(45deg, rgb(125, 29, 34) 0px, rgb(125, 29, 34) 8p |
| div | — | 307.6,273.8,228.8,25.6 |  | 최종 점수가 5 : 5 동점이에요 | 19px/400 · 글자 #6e655a |
| div | — | 290.8,303.4,262.4,21.6 |  | 더 큰 숫자를 뽑은 사람이 최종 승리해요 | 16px/400 · 글자 #6e655a |
