# ELEVEN S7 회귀 목록 (초안)

기준: 2026-11-25 코드·계약. S6-M 병합 후 TEST Firebase와 실기기에서 다시 판정한다. 자동 검사가 있어도 실제 화면·복구 흐름은 별도로 확인한다.

| 공통 경로 | 자동 검사 | S7 수동 확인 |
| --- | --- | --- |
| 카탈로그·게임 선택 | `test/eleven_integration_test.dart`, `functions/test/game-rules-catalog.test.mjs`, `functions/test/game-preview-catalog.test.mjs` | 로컬은 free fixture에서 2인·선택 가능 확인. TEST는 `paid`·`storeVisible: false`와 테스트 계정 `ownedGames` 보유 상태에서 선택 가능 여부 확인. 다른 게임 선택 뒤 다시 ELEVEN으로 바꿔도 이전 게임 상태가 남지 않는지 확인 |
| 자리 배치·시작 | `functions/test/eleven-game.test.mjs`, `functions/test/eleven-scenarios.test.mjs`, `functions/test/room-seating-response.test.mjs` | 두 휴대폰을 입장시켜 A/B 좌석 지정, 1인일 때 시작 거절, 2인 시작 후 T01/P01 표시 |
| 중단·재접속·복구 | `functions/test/game-recovery-state.test.mjs`, `packages/game_kit/test/recovery/`, `functions/test/eleven-emulator.test.mjs` | T/P 세 기기 중 한 대 연결을 끊고 복구 띠·입력 차단·동일 `gameInstanceId` 복귀 확인. 제출 중 단절은 중복 제출 없이 최신 색·점수로 복원 |
| 퇴장·제외·인원 부족 종료 | `functions/test/eleven-scenarios.test.mjs`, `functions/test/eleven-game.test.mjs` | 휴대폰 한 대 퇴장과 태블릿 제외 각각 `finishReason: insufficientPlayers`, `winnerUid: null`, 방 복귀 확인 |
| 수동 종료·finish-now | `functions/test/eleven-scenarios.test.mjs`, `functions/test/game-recovery-state.test.mjs` | T 설정에서 종료, 복구 판단에서 즉시 종료 각각 `winnerUid: null`; 재시작 뒤에도 종료 명령이 잠기지 않는지 확인 |
| 다시하기·오래된 명령 | `functions/test/eleven-scenarios.test.mjs`, `functions/test/eleven-emulator.test.mjs` | 결과 T13 뒤 다시하기, 새 뽑기·손패·점수 초기화. 이전 판의 늦은 제출·완료 명령이 새 판에 반영되지 않음 |
| 패키지 경계 | `python3 tool/check_package_boundaries.py --max 0`, `test/mosigame_cli/package_test_manifest_test.dart` | `GameRegistry`에서 ELEVEN 진입 후 다른 게임으로 돌아와도 라우트·세션 구독이 겹치지 않음 |

## 기존 게임별 확인

| 게임 | 자동 검사 | S7 수동 확인 |
| --- | --- | --- |
| 라이어스 포커 | `packages/game_liars_poker/test/`, `functions/test/liars-poker-rtdb-recovery.test.mjs` | 2인 시작→분배→제출→결과·벌칙, 복구 후 다음 턴 |
| 파이널콜 | `packages/game_final_call/test/`, `functions/test/game-recovery-state.test.mjs` | 4인 시작→뽑기·선언→결과, 시간 초과와 중단 복구 |
| 마피아 | `packages/game_mafia/test/`, `functions/test/mafia-rules.test.mjs` | 최소 인원 시작→역할 공개→밤/낮·투표; ELEVEN 선택 후 전환 시 역할 비공개 유지 |
| 홀덤 | `packages/game_holdem/test/`, `functions/test/holdem-rules.test.mjs` | 카탈로그 노출 정책 유지, 2인 시작→액션→결과 |
| 윷놀이 계열 | `packages/game_yut/test/`, `functions/test/game-rules-catalog.test.mjs` | 일반/전략 에디션 선택·자리·한 턴 진행·종료 |
| 러시안 룰렛 | `packages/game_russian_roulette/test/`, `functions/test/game-recovery-state.test.mjs` | 선택→공개→회전→발사→결과와 중단·제외 흐름 |

수동 확인은 각 항목의 방 코드, 기기, phase, 예상/실제 결과를 S7 기록에 남긴다. 자동 테스트 경로는 S6-M 병합 후 존재 여부를 다시 확인한다.
