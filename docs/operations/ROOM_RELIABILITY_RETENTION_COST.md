# 방 연결 안정성·보관·비용 정책

2026-11-05 작업 후보. 기준은 `develop`의 `f292f274`, 작업 브랜치는
`codex/investigate-room-stream-disconnect`다. 운영 배포·데이터 삭제 완료를 뜻하지 않는다.

사용자는 화면 끊김 감소, 방 생성·초기화 개선, 플레이 후 잔여 데이터의 보관·정리,
서버 비용 절감을 요청했다. 개인정보 조회와 노트북 보안 설정 변경은 범위에서 제외했다.
실기기 없이 로컬·에뮬레이터 검증을 우선하도록 확인했다.

## 확인한 결함과 수정

### 결과 화면의 방 보존

기존 `cleanupDeadline`은 게임이 끝났을 때 설정한 `retainUntil`을 절대 기한으로
사용했다. 큐를 처리하는 서버는 그 시각 이후 방을 축약하므로, 진행 기기가 계속
heartbeat를 보내도 결과 화면의 방이 사라질 수 있었다. 예전의 lastSeen 선조회에
의존하는 설명은 현재 큐·cursor 구현과 맞지 않았다.

결과 방의 기한을 `max(retainUntil, 현재 진행 기기의 lastSeen + 15분)`으로 계산한다.
작업 큐의 기한은 후보일 뿐이며, 실제 방 transaction 안에서 최신 접속 신원과 시각을
다시 확인한다. protocol 2의 유효한 현재 접속을 찾지 못하면 오래된 요약만으로 방을
종료하지 않는다. 현재 접속이 없는 손상 데이터는 별도 확인 대상이다.

이는 코드에서 재현한 결함이다. 11월 5일 13~15시(KST)의 사용자 테스트 원인으로
확정한 것은 아니다. 이번 작업에서는 운영 데이터·기기 로그를 추가로 조회하지 않았다.

### 게임 사이 화면 전환

휴대폰 대기 화면은 게임 route가 열려 있는 동안 추가 시작 처리를 막는다. 이전
게임의 퇴장 연출이 끝나기 전에 다음 시작 신호가 도착하면, route 완료 뒤 그 신호를
재평가하지 않아 대기 화면에 남을 수 있었다.

현재 방 구독에서 관찰한 새 시작 신호를 기억하고 이전 route의 완료 뒤 다시 확인한다.
새 신호 없는 옛 `playing` 캐시로 같은 게임을 다시 열지 않으며, 에셋 준비 중 방·참가
신원·게임 선택이 바뀐 경우 이전 화면을 열거나 새 참가자를 퇴장시키지 않는다.

현재 대기 화면의 구독은 status 한 값만 읽는다. 중간 종료 상태를 관찰하지 못한
`playing → playing`의 game instance 교체나 다른 경로의 게임 선택과 상태가 서로
엇갈리는 모든 순서를 완전히 구분하지는 못한다. 이 범위를 해결하려면 게임 instance·
종류·상태가 대응하는 작은 시작 신호 계약과 회귀가 추가로 필요하다. 매 턴의 공개
게임 전체 데이터를 중복 구독하는 방식은 다운로드 비용 때문에 채택하지 않는다.

### 정리의 실패 격리와 중복 작업

- 방 순회의 한 항목에서 접속 복구나 큐 갱신이 실패해도 나머지 방과 due 큐를 처리한다.
  해당 항목은 cursor가 다음에 돌아왔을 때 재시도한다. `scanFailed`로 개수를 기록한다.
- 같은 방·세대·revision·기한·실패 횟수의 정리 큐는 다시 쓰지 않는다. 최신 세대와
  실패 backoff를 보존한다. transaction의 사전 읽기 자체가 없어지는 것은 아니다.
- 게임 중단 만료 처리는 동시에 최대 10개 transaction만 실행한다. 한 방의 실패는
  다른 방의 처리를 취소하지 않고 다음 분 조회에서 다시 판정한다. transaction 안에서
  종료·연장·원인 해소 여부를 다시 확인한다.
- 집계 로그에는 개수·처리 시간만 남긴다. 방 코드·UID·세션·손패·오류 원문은 넣지 않는다.
  중단 만료 대상이 없는 순회에서는 새 집계 로그를 추가하지 않는다.

## 데이터별 보관 정책

아래 시각은 정리 대상이 되는 기준이다. 방 정리는 5분마다 실행되며 큐·페이지 순회와
실패 backoff 때문에 늦어질 수 있다. 정확한 삭제 시각이나 처리 SLA로 해석하지 않는다.

| 데이터·상태 | 보관과 정리 기준 | 보호 조건 |
| --- | --- | --- |
| 대기·자리 배치 방 | 현재 진행 기기의 마지막 서버 접속 시각 + 3분 | 계속 접속 신호가 오면 유지 |
| 진행 중 게임 방 | 현재 진행 기기의 마지막 서버 접속 시각 + 15분 | 게임 복구 시간 보장, 진행 중 유령 참가자 자동 제거 금지 |
| 게임 종료·결과 방 | 종료 후 최소 15분과 현재 진행 기기의 마지막 접속 + 15분 중 늦은 시각 | 결과 확인·같은 방의 다음 게임 가능 |
| 명시적으로 닫은 방 | 종료 후 60초부터 큰 payload 정리 | heartbeat로 종료 의도를 연장하지 않음 |
| 게임 선택 변경 | 이전 게임의 공개·private·server 데이터와 이전 종료 기한 제거 | 현재 권한·게임 비진행 상태를 서버 transaction에서 검증 |
| 비진행 방의 끊긴 참가자 | 현재 접속의 명시적 연결 끊김 + 마지막 신호 후 5분 초과 | 현재 membership/connection과 최신 상태 재확인 |
| 종료된 방의 큰 데이터 | 위 기한 후 game/private/server, connections, sessionOperations 등을 제거 | 동일 roomInstanceId·allocationGeneration인 경우만 축약 |
| controllerRooms 매핑·정리 큐 | 해당 세대의 종료 정합성 처리가 완료되면 제거 | 새 방·새 큐로 바뀌면 보존 |
| 종료 방의 최소 표식 | 현 프로토콜에서는 만료 없이 유지 | 방 instance·할당 세대를 보존해 옛 실행의 재생 차단 |
| 확정 종료 생성 요청 | transport 정보를 제거하고 최소 terminal 요청 유지 | 같은 operationId가 새 방을 만들지 않도록 만료 없이 보존 |
| UID별 생성 슬롯 | UID당 현재 슬롯 하나, 종료 시 terminal 표시 | 새 생성이 안전하게 교체. 미확정 reserved 슬롯 일괄 삭제 금지 |
| 활성 방의 작업 결과·이전 접속 | 방 수명까지 유지 | 미확정 응답 재생·현재 접속·옛 단절 이벤트의 안전성 유지 |

방의 최소 표식은 instance·generation·status·terminalAt·cleanupPending만 남는다.
확정 종료 생성 요청은 roomCode·instance·generation·status와 기존 createdAt만 남는다.
이것은 잔여 손패나 게임 이력이 아니다. 데이터가 남는다는 사실만으로 정리 실패로 보지 않는다.

반대로 큰 game/private/connections/작업 결과가 기한 이후에도 남으면 `cleanupPending`,
큐의 실패 횟수·가장 오래된 due 지연, 유효한 현재 접속 누락을 확인해야 한다.
실패한 정리 작업의 backoff는 기존 1~30분을 유지한다.

### 무기한 표식을 없애려면 필요한 후속 계약

기존 클라이언트는 미확정 operationId를 TTL로 버리지 않고 응답을 다시 요청한다.
서버 표식을 먼저 지우면 오래된 요청이 새 생성·새 게임 행동으로 처리될 수 있다.
따라서 이번 정책에서 최소 표식의 무기한 보존을 명시한다. 전체 기록 수가 제한된다고
표현하지 않는다.

물리 삭제까지 하려면 서버가 검증하는 요청 epoch 또는 재생 가능 기한, 만료된
클라이언트의 결과 확인·재시도 동작, 이미 실행 중인 생성 예약의 차단을 함께 설계해야 한다.
방 없는 reserved 요청·슬롯, 세대 정보 없는 legacy 데이터도 별도 관찰·이전 대상으로 둔다.
나이만 보고 제거하는 migration은 포함하지 않는다.

## 비용 절감 범위와 측정

이번 후보는 동일 정리 큐 재쓰기와 실패 전파를 줄인다. 중단 만료 transaction의
동시 실행 상한으로 순간 부하를 제한한다. 이것이 다운로드·transaction 읽기 전체를
제거하거나 청구액의 특정 비율을 절감한다는 뜻은 아니다.

기존 B1의 정상 heartbeat는 timestamp leaf만 갱신하고 접속/정리 트리거를 발생시키지
않는다. 10초 heartbeat와 복구 감지 유예는 유지한다. 소스의 함수별 maxInstances=20도
유지하며, cold start를 줄이려고 minInstances를 새로 늘리지 않는다.

다음 큰 비용 후보는 매분 모든 playing 방을 읽는 중단 만료 작업, 5분마다 최대
101개·501개 방의 전체 payload를 받는 방·유령 참가자 순회다. 활성 방의 작업 이력이
커지면 이 읽기와 room-root transaction도 커진다. 얕은 별도 due index로 전환하려면
작성자·게임 상태 전이·실패 복구·기존 데이터의 혼합 배포를 함께 다뤄야 한다.
이번에 주기를 늘리거나 필수 기록을 삭제하는 방식으로 대체하지 않는다.

Firebase는 listeners의 조회 범위를 좁히고 사용량을 측정한 뒤 개선하도록 안내한다.
[RTDB 최적화](https://firebase.google.com/docs/database/usage/optimize)와
[RTDB 과금 설명](https://firebase.google.com/docs/database/usage/billing)을 기준으로
다음 비교를 동일한 게임·인원·플레이 시간에서 수행한다.

| 지표 | 판정 방법 |
| --- | --- |
| 화면/방 생성·초기화 지연 | p50·p95와 실패율을 전후 비교. 로컬 시간과 실제 기기 시간을 구분 |
| 정리 진척 | failed·scanFailed·oldestDueAgeMs·queueLimitReached, 중단 만료 failed 확인 |
| 실제 비용 | 서비스별 청구·RTDB 다운로드/저장량·Functions 실행시간·호출량·로그량 비교 |
| 잔여 데이터 | 큰 payload 정리와 최소 표식 개수를 분리. completed는 물리 삭제 수가 아님 |

청구·운영 사용량에 접근했다고 주장하지 않는다. 기존 보안 절차 밖의 운영 전체 덤프,
개인정보나 credential 조회, 계정 역할 추가, 보안 설정 변경은 하지 않는다.

## 검증과 적용

프로젝트 doctor가 처음에는 Functions 의존성 누락으로 BLOCKED(exit 3)였다.
기존 lockfile 그대로 `npm ci --no-audit --no-fund` 실행 후
`dart run :mosigame doctor`는 PASS(exit 0)다. SDK cache의 정상 실행 권한만 사용했으며
SDK·ACL·OS 보안 설정을 수정하지 않았다.

관련 회귀 검사, session suite, 분석·lint의 최종 결과는 작업 기록에서 관리한다.
session은 Flutter 240·Functions 196개, 전체 Functions는 562개가 PASS(exit 0)다.
로컬 Firebase check는 smoke와 실제 RTDB 보존·정리 회귀의 7개 판정이 PASS(exit 0)이며
서비스 종료 후 loopback 포트 반환을 확인했다. 주기 handler는 직접 호출하므로 실제
Cloud Scheduler 전달 검사는 포함하지 않는다.
사용자는 최종 후보에 대해 `validate --full` 보류를 선택했다. 이 검사는 실행하지 않았고
최종 완료·출시 PASS로 판정하지 않는다.
실제 FlutterFire 기기 수명주기·20분 이상 연속 플레이·과금 효과는 별도 확인이 필요하다.

기존 `tool/emulator/backend.test.mjs`는 export 수를 81개로 고정하고 현재 소스는
86개를 내보낸다. 이 오래된 전체 harness의 검증 범위를 이번 PASS로 확대하지 않는다.
고정 demo 프로젝트·loopback의 local check에 방 보존/정리 회귀를 추가해 검증한다.

운영 적용 후보는 앱의 대기 화면/접속 주기 코드와 서버의 방 정리·게임 선택·중단 만료다.
새 export·dependency·DB rules·IAM 변경은 없다. 로컬 테스트는 운영 변경을 뜻하지 않는다.
운영 배포 전에 현재 함수 소스와 대상 export를 대조하고 앱/서버 적용 범위를 확정한다.
기존 데이터의 대량 삭제와 migration은 실행하지 않는다.

관련 작업: [네트워크 지연](../planning/tasks/NET-RECOVERY-01.md),
[방 생성 기록 잔류](../planning/tasks/ROOM-CREATE-REQUEST-01.md),
[비용](../planning/tasks/COST-01.md),
[이전 RTDB 검토](RTDB_RETENTION_REVIEW.md).
