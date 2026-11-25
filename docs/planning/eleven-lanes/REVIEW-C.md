# REVIEW-C · 레인 C 통합 준비 검수 1회차

- 검수: Claude Code(맥), 2026-11-25
- 대상: `project00-lanes/lane-c`, 브랜치 `eleven/lane-c-integration`, HEAD `6dce2b69`(공통 부품 fast-forward 뒤) +
  미커밋 변경(LOG-C 13:25 기록)

## 판정: FIX (가벼움)

내가 다시 실행한 결과: `functions/`에서 `npm run build` exit 0, `npm run lint` exit 0,
`node --test test/*.test.mjs` 681개 중 680 통과·1 skip(에뮬레이터, 의도됨)·0 실패. 시나리오 테스트는
한 판 전체(`allRounds`), 조기 종료 경계(차 = 남은 라운드면 계속), 11번 동점 → 최종 뽑기 → `tieDraw`,
시간 초과 3중 도착, 같은 commandId 재전송, 재시작 뒤 오래된 명령 거절, 승자 없는 종료,
rules 읽기 차단을 잘 다룬다. 문서 초안의 파일 경로는 모두 실제로 있었다. 레인 밖 변경 없음.

에뮬레이터 BLOCKED는 레인 결함이 아니다. 이 맥에 Java 런타임이 없다(`java -version` 실패를 나도 확인).
Java 설치는 새 도구라 하준 승인 대상이며, 승인되면 S7(가)에서 실행한다. 레인 C에서는 더 시도하지 않는다.

## A. 레인 C가 고칠 것

| # | 파일 | 차이 | 수정 지시 |
| --- | --- | --- | --- |
| A1 | `lane-c/SYSTEM_MAP_ELEVEN.md` | 휴대폰 열이 계약 7절의 P 화면만 적었다. 뽑기는 G1–G5(내 차례·상대 먼저·뽑은 뒤·결과 선공/후공), 라운드 결과는 G6 → P08, 조기 종료는 G7 → P10/P11, 최종 동점 뽑기는 P01이 아니라 G8이고 공개 직후 P10/P11이다 | `resolveElevenPhoneScreen`(`phone/providers/game_stage.dart`)과 `test/phone/screen_test.dart`를 근거로 휴대폰 열을 고친다. 태블릿 열에 T13-B(동점 뽑기 결과)와 T10 → T13 전환을 넣는다 |
| A2 | `eleven-scenarios.test.mjs` `assertBoundary` | 금지 목록이 키 이름(`value`, `sum`, `reason` …)만 본다. 계약 4절 누출 금지 값인 판정 유형 문자열(`sum20`·`under10`·`atLeast10`)이 다른 키 이름으로 들어가도 잡지 못한다 | public 전체를 돌며 문자열 값이 이 셋 중 하나면 실패하게 추가한다. 본 게임 실제 숫자도 `server.submissions` 값과 대조해, 같은 판의 제출 숫자가 public 어디에도(공개된 `draw.revealed` 제외) 없는지 확인한다 |
| A3 | `eleven-scenarios.test.mjs` | 테스트 이름 “exclude, leave and manual end”인데 퇴장(`leave_game` → 공통 `leaveSessionRequest`) 경로는 실행하지 않는다 | 이름을 실제 범위(제외·인원 부족·수동 종료)로 고치거나, 공통 퇴장 처리 함수로 한 명이 나간 경우를 추가한다 |
| A4 | `lane-c/REGRESSION.md` | “ELEVEN이 2인·무료·선택 가능” — 로컬 에뮬레이터 카탈로그는 free지만 TEST는 노션 결정대로 `paid` + 테스트 계정 `ownedGames`다 | 환경별로 나눠 적는다(로컬: free fixture / TEST: paid + ownedGames, storeVisible false) |
| A5 | `lane-c/S7_RUNBOOK.md` 1단계 | Java가 없으면 3–4단계가 막힌다는 점이 없다 | 1단계에 “Java 21 없으면 3–4단계 BLOCKED, 설치는 하준 승인” 한 줄과 확인 명령(`/usr/libexec/java_home -v 21`)을 넣는다 |

## B. Claude 쪽

없음. 공유 파일 요청이 없었다.

## 다음

- Codex 입력: `docs/planning/eleven-lanes/REVIEW-C.md 반영`
- 다 고치면 `functions/`에서 build·lint·`node --test test/*.test.mjs` 결과와 "검수 요청: 예"를 LOG-C.md에 남긴다.

---

# REVIEW-C · 2회차 (2026-11-25)

- 대상: HEAD `02e43e77` + 미커밋 변경(LOG-C 18:14까지)
- 재실행: `functions/` build exit 0, lint exit 0, `node --test test/*.test.mjs` 681 통과·1 skip·0 실패. 레인 밖 변경 없음.

## 판정: PASS

A1 시스템 맵 휴대폰 열(G1–G8, G6 → P08, G7 → P10/P11, G8 → P10/P11, T13-B), A2 판정 유형 값·제출 숫자 누출 검사와
그 검사가 실제로 잡는지 확인하는 테스트, A3 테스트 이름, A4 로컬·TEST 카탈로그 구분, A5 Java 21 안내가 모두 반영됐다.

에뮬레이터 시나리오는 Java 21이 없어 미실행 상태로 S7(가)에 넘긴다(하준 승인 뒤 설치). 레인 C는 S6-M 병합 대기.
