# NET-RECOVERY-01

네트워크 복구 체감 지연

## 2026-10-23 — develop 머지 승인·최신 통합 검증

사용자가 develop 머지를 승인했다. 작업16파일 커밋 d33a6194와 최신 origin/develop
7feae1ca를 통합한82189949의 guarded FULL3은13단계·1,371개 PASS/exit0(322.623초)다.
월별 기록 충돌은 양쪽 기록을 보존해 해결했고 제품 충돌은 없었다. 검증 뒤 결과 문서만
갱신한 후보를 로컬 develop에 fast-forward 반영한다. 기존 사용자 미추적2파일은 제외·
보존하고 push·재배포·APK 재빌드는 하지 않는다. 실측/실기기 후속은 계속 대기다.
[전체 병합·검증 근거](../ROOM_ACTION_EFFICIENCY_20261022.md).

## 2026-10-23 — release 복구 간단 확인 지시문

사용자 요청으로 [핵심 복구 확인 지시문](../../operations/NETWORK_RECOVERY_SMOKE_CHECKLIST_20261023.md)을
작성했다. 현재1.0.0+6 release의 로비·같은 게임 휴대폰2회·태블릿 단절 복구 및 이후
실제 행동·종료·새 그룹을 확인하고 앱 재실행은 선택 항목으로 분리한다. 속도 측정과
별도 영상으로 진행하며 실제 시험·수집은 미실행이다. 기존 상세 실기기 검증의 미완료나
전체 복구 기능의 통과로 확대하지 않는다. 이번 변경은 문서뿐이다.

## 2026-10-22 — 생성·추방·초기화 효율 개선

최신 origin/develop `cc293dff`에서 `codex/room-action-efficiency-20261022`를 만들어
세 동작×여섯 항목을 점검하고 구현 전에 근거·설계를 기록했다.
[점검·개발·검증 보고](../ROOM_ACTION_EFFICIENCY_20261022.md)에 위치 → 필요한 이유 →
전체 완료 영향 → 변경 방향 → 기능 보존 검증을 정리했다. 추방의 게임 public 선조회,
생성의 독립 준비 직렬 대기, 추방·초기화의 중복 서버 준비를 제거하며 close 미적용
거짓 성공도 방지한다. 현재 직접 Flutter52/Functions78 회귀와 guarded session은
PASS/exit0이다. 새 fixture 컴파일 실패와 SDK 실행환경 실패의 원인·해결도 보고서에
남겼다. FULL1은 DB 동기 초기화 예외의 오류 우선순위 회귀1개로 FAIL/exit1이었다.
초기화도 settled 결과로 처리하고 새 회귀3개를 더해 관련34개를 확인했다.
FULL2는296.981초, 13단계·총1,370개 PASS/exit0으로 최대3회 한도 내 성공했다.
실행 전후 트리와 기존 사용자 파일이 보존됐으며 검증 후에는 결과 문서만 갱신했다.

기존 세션·권한·세대·게임 중 추방 보호·멱등 재생·불확실 작업 복구를 보존한다.
개선 체감 시간은 미실측이며 기존10/20 비계측 실기기 후속은 유지한다.
develop 병합·commit·push·운영 조회·배포는 수행하지 않는다.

**같은 날 후속 승인:** 사용자가 배포 후 release APK와 비교 지시문을 요청했다.
대상3함수 배포 exit0·ACTIVE 확인, `1.0.0+6` 측정용 release 빌드/서명 검증 exit0이다.
제품 추가 수정 없이 빌드 입력1,076개가 보존됐다. 기존영상 대비 첫/반복·같은 화면 경계의
초/단축률을 분석하는 [실기기 지시문](../../operations/PERFORMANCE_CAPTURE_CHECKLIST_20261022.md)과
[APK·배포 기록](../../operations/ROOM_ACTION_RELEASE_20261022.md)을 작성했다.
새 APK 기기 설치·영상 촬영·개선율은 아직 미확인이다. 위 배포 보류는 이전 개발 단계의
범위이며 이번 후속 승인으로 세 함수만 배포했다. 병합·commit·push는 수행하지 않았다.

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

- 담당 Issue: 착수 승인 시 생성.
- 분류 결정 근거: 2026-10-08 사용자 요청으로 출시 전 필수 지정.

## 현재 동작

- RTDB의 `.info/connected`가 복구되면 저장된 휴대폰 또는 controller 세션으로 같은 방의
  presence와 구독을 복원한다.
- 앱의 주요 복구 단계는 각각 8초 제한을 사용한다.
- 복구 중에는 안내 화면을 표시한다. 일시적인 문제라면 그대로 기다릴 수 있고, 기다릴
  수 없으면 `게임과 그룹 나가기`를 선택할 수 있다.
- 참가자 단절 판정은 별도 계약이다. 기존 10초 heartbeat와 `onDisconnect`를 유지하며,
  태블릿이 마지막 `lastSeen` 후 20초를 초과한 후보를 서버에 한 번 검증 요청한다.

이 항목은 **세션과 방 상태를 보존하며 복구에는 성공했지만 시간이 길게 느껴지는 경우**만
다룬다. 두 번째 단절 뒤 방·게임을 잃는 현상은 체감 개선이 아니라 출시 차단
`SESSION-RECONNECT-01`이다.

- 현재 분류(2026-10-08): 사용자 요청으로 출시 전 필수로 옮겼다. 아래 과거 관찰 근거는
  보존하며, 측정 목표·점검 범위는 착수 시 확정한다.

## 기존 출시 후 관찰 분류의 근거

- 첫 단절은 30초 안에 앱 재시작 없이 같은 게임으로 복귀했다.
- 체감 시간에는 앱 코드뿐 아니라 OS 네트워크 전환과 Firebase SDK 재연결 시간이 포함된다.
- 상태를 보존한 단일 복구에서 출시를 막을 수준의 반복적인 지연 측정값은 아직 없다.
- 복구 안내와 명시적인 나가기 경로가 있어 앱이 무응답 상태로만 보이지는 않는다.

과거 반복 단절의 세션·방 유실에는 이 보류 근거를 적용하지 않았다. 수정 APK의
2026-08-31 라이어스포커 최종 테스트(Medium Tablet 에뮬레이터 + A32·A35)는 반복
단절을 포함해 통과했다. 당시 순수한 체감 지연만 출시 후 관찰하기로 했으며 상태 유실이 재발하면
다시 출시 차단 여부를 평가하기로 했다.

## 기존 우선순위 재평가 조건

기존 관찰 단계에서는 다음 중 하나가 확인되면 P1 또는 출시 차단 항목으로 재평가하기로 했다.

- 짧은 일시 단절 뒤에도 앱 재시작이 필요하다.
- SESSION-RECONNECT-01 수정 후에도 방, 게임 또는 남은 턴 상태가 유실된다.
- 일반적인 네트워크 전환에서 재연결이 반복적으로 30초 이상 걸린다.
- 같은 증상의 사용자 문의 또는 실제 세션 사례가 반복된다.
- Play Console, Crashlytics 또는 지원 기록에서 freeze·ANR·복구 실패가 확인된다.

30초와 반복 사례 기준은 최초 관찰 기준이며, 실제 배포 지표를 확보하면 조정한다.

## 조사할 때 수집할 근거

- 단절 시작, `.info/connected` 복구, 세션 복원 완료 시각
- 휴대폰/태블릿 역할, OS, 네트워크 전환 종류
- 앱 재시작 필요 여부와 방·게임 상태 보존 여부
- 개인정보를 제외한 `[dev_error]`, `[game_comm]`, `room_connection` 구조화 로그

production RTDB 관찰이 필요하면
[`Firebase MCP RTDB Read-only Pilot`](../../operations/FIREBASE_MCP.md)의 사전 승인과
단일 경로 조회 절차를 따른다.

## 완료 기준

- 짧은 단절 뒤 앱 재시작 없이 같은 방과 게임으로 자동 복귀한다.
- 게임 상태와 중단 시 보존한 남은 턴 시간이 유지된다.
- 측정한 복구 시간이 착수 시 합의한 목표 안에 들어온다.
- Android와 iOS 실제 기기에서 단절·복구 회귀 테스트를 완료한다.
- 관련 Flutter·Functions 자동 테스트와 Project CLI FULL validation이 통과한다.

## 관련 코드와 문서

- [`RoomProvider.retryConnectionRecovery`](../../../lib/platform/home/room/providers/room_provider.dart)
- [`RealtimeConnectionMonitor`](../../../packages/game_kit/lib/core/network/realtime_connection_monitor.dart)
- [`ControllerReconnectGuard`](../../../lib/platform/home/phone/widgets/controller_reconnect_guard.dart)
- [`사용자 로그인·네트워크·세션 안내`](../../operations/USER_AUTH_NETWORK_SESSION_GUIDE.md)
- [`인증·네트워크·세션 기술 참고`](../../operations/AUTH_NETWORK_SESSION_TECHNICAL_REFERENCE.md)

## 2026-10-08 보완 — newgui 복구 지연의 측정 경계

검토 후보는 [`newgui`의 `999c3e9`](https://github.com/WarmhanDongne/project00/tree/999c3e99086b9f917ea941cd8f283b8ac40f3f85)이며,
이 등록은 병합·구현·검증 완료를 뜻하지 않는다. 현재 작업의 순수 체감 지연 범위와
착수 시 목표·점검 범위를 합의하는 조건은 유지한다.

- [ ] 측정점을 단절 시작 → OS/SDK 연결 복구 → presence/참가 상태 복구 → 필요한 구독과
  같은 판의 게임 데이터 수신 → 에셋 준비 → 입력 보호 해제/서버 중단 해제로 나눈다.
  [플랫폼 복구 반환](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/room/providers/room_provider.dart#L1003)을
  게임 준비 완료로 간주하지 않는다. 완료 계약은 [SESSION-RECONNECT-02](SESSION-RECONNECT-02.md#session-reconnect-02)에서 합의한다.
- [ ] 새 연결 UI 6종의 안내/재시도/나가기 노출 시간은
  [NEWGUI-RECOVERY-01](NEWGUI-RECOVERY-01.md#newgui-recovery-01)과 함께 기록한다.
  [태블릿 단절 안내의 20초 나가기 노출](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/phone/widgets/controller_reconnect_guard.dart#L16)과
  stale 판정 유예·실제 네트워크 복구 시간을 구분한다. UI 문구나 버튼 표시만으로
  세션 복구 성공을 판정하지 않는다.
- [ ] [에셋 다운로드](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/game_assets/game_asset_prepare.dart#L5)와
  [960ms 퇴장 연출](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/packages/game_kit/lib/widgets/game_exit_route.dart#L5)의
  대기 시간을 SDK 재연결 지연과 분리한다. 캐시 유무·게임·기기·OS·빌드를 측정에 남긴다.
- [ ] 라이어스포커·Final Call·Mafia·홀덤 4게임의 휴대폰/태블릿 조합에서 상태 보존이
  확인된 성공 복구만 지연 측정 대상으로 삼는다. 반복 단절 뒤 방/손패/턴 유실,
  취소된 구독의 미복원, 다중 단절 누락, pause 중 timeout 진행, 퇴장 응답 유실,
  숨은 오류·AuthGate 실패 잔류와 상세/스토어 복원 경합은 지연 개선으로 축소하지 않고
  [SESSION-RECONNECT-02](SESSION-RECONNECT-02.md#session-reconnect-02) 및 새 UI 작업으로 보낸다.

위 측정 항목은 목표 수치나 재시도 횟수를 새로 확정하지 않는다. 운영 데이터 접근은 기존
Firebase MCP 사전 승인·단일 경로 제한을 유지한다.

## 2026-10-10 — 로비 생성·초기화 시간 측정

사용자가 iOS Simulator에서 방 생성·초기화가 각각 3~4초 걸린다고 보고하고 1초대 응답을
희망했다. 현재값은 체감 보고이며 원인이나 성능 합격선을 확정하지 않는다.
[측정 절차와 기록 의미](../../operations/ROOM_ACTION_LATENCY.md)에 따라 debug 클라이언트의
기존 호출·로컬 저장에 시간을 기록하는 후보를 추가했다. 생성 뒤 resume/presence, 초기화의
onDisconnect 취소/status 조회/close를 구분한다. 화면 프레임·760ms QR 연출은 별도다.
서버·rules·요청 내용·순서·재시도 정책은 변경하지 않았다.

사용자 승인 후 17:07~17:09 KST 실제 요청을 측정했다. 빈 방 초기화 1회는 7,418ms로
성공했고, 그중 status/close callable이 7,304ms였다. 생성은 3,901ms와 761ms로 두 번
실패하여 반복을 중단했다. 성공 생성 시간이나 5회 통계는 확보하지 못했다. 실패 후
빈 로비에 오류 안내가 없는 점도 확인했다. [측정 결과](../../operations/ROOM_ACTION_LATENCY.md)의
환경·한계를 따른다. 운영 서버 로그와 DB 직접 조회는 하지 않았다.

계측 관련 테스트 16개, session(Flutter 156·Functions 94), 분석과 iOS debug 빌드는
PASS/exit 0. 승인된 FULL 1회는 동일 소스 영문 경로 사본에서 FAIL/exit 1이었다.
포맷·전체 분석은 PASS, root 테스트 362 PASS/6 FAIL 후 fail-fast로 종료했다.
실패는 기존 `liars_poker_winner_restart_test.dart`의 Fake가 `watchServerConnection`을
구현하지 않아 발생했다. 후속 package 테스트·Functions lint/test는 FULL에서 미실행이며
검증 전후 mutation은 없었다. 계측 기능·지연 개선 전체 완료로 판정하지 않는다.


## 2026-10-10 — `디벨럽1` 개선 후보

사용자가 별도 브랜치에서 앞선 개선안을 구현하도록 요청했다. 시작 HEAD는 `7bb2b1e`,
이전 미커밋 계측과 디자인 export는 이어받아 보존했다. 최초 생성의 resume과 최초 close의
status 왕복을 생략하고, 미확정/재접속 경로는 유지했다. 서버의 종료 allocation에 일치하는
completed 생성 슬롯만 CAS로 교체해 즉시 재생성할 수 있도록 했다. 빈 로비의 생성 오류
안내와 표준 오류 코드/서버 단계별 계측을 추가했다. 이전 FULL 실패는 LP 테스트 Fake의
연결 스트림 구현 누락을 보완했으며 게임 동작과 기존 assertion은 유지했다.

로컬 재현은 수정 전 create→close→create가 creationPending으로 실패, 수정 후 성공했다.
신규 클라이언트 회귀는 fresh/replay/presence 실패/실제 restore/close 결과 유실을,
서버 회귀는 generation·동시 생성·옛 cleanup과 로그 비식별화를 검증한다.
최종 관련 클라이언트 30개·서버 9개 PASS, session Flutter 156·Functions 96 PASS.
FULL은 새 후보에 대한 사용자 1회 승인 후 PASS/exit 0(105.5초)였다.
포맷·전체 분석·root 378개·패키지 5개·Functions 397개 및 mutation 검사 모두 PASS. [검증 기록](../logs/2026-10.md#room-action-improvement-20261010).
서버 배포와 새 후보 실측은 별도이며 1초대 달성을 주장하지 않는다.

## 2026-10-10 — 앱 전체 동작 지연 정적 조사

사용자 요청으로 [전체 조사](../../operations/APP_LATENCY_AUDIT.md)를 작성했다.
직접 작성 소스 555개와 생성 번역 4개를 검색하고 검색행 1,090개 및 서버 export
79개를 바탕으로 시작·인증·로비·네 게임·리소스·공통 서버 경로를 추적했다.
고정 대기, 직렬 왕복, 연출 규칙, 실측이 필요한 구조상 가설을 구분한 후보 50개다.

우선 후보는 자리 배치의 서버 준비와 연출 병행, 입장/프로필 성공 후 대기, FC 명령 전
460ms 대기, 최초 leave 사전 조회, 카탈로그 독립 조회 병행이다. 서버 room 전체
transaction·ledger 누적·cleanup trigger는 데이터 크기/충돌/부하를 먼저 측정한다.
이번에는 앱 코드 수정이나 운영 요청을 하지 않았다. 제안은 구현 완료·성능 향상 확인을
뜻하지 않으며 기존 로비 후보의 배포·실측과 E14를 대체하지 않는다.

## 2026-10-10 — 앱 응답 개선 후속 후보

사용자가 개선과 개발팀 공유 문서를 요청했다. [개발팀 공유](../../engineering/NETWORK_LATENCY_IMPROVEMENTS.md)에
측정/가설, 이전 로비 후보와 이번 수정, 코드·회귀·배포 후 체크리스트를 구분했다.
이번 범위는 최초 leave status 생략, join의 독립 읽기 병행, 카탈로그/보유 조회 병행과
in-flight 공유, 착석 연출/서버 준비 병행, FC 교체 즉시 전송, 성공 check 뒤 추가 정지 제거,
에셋 파일 최대3개 병행 설치다. 서버/rules/schema/dependency/게임 규칙 변경은 없다.

직접 관련53개 및 추가8개(일부 중복), session Flutter156/Functions97, auth Flutter34/Functions12,
전체 Flutter 분석이 PASS/exit0다. session/auth 검증 전후 mutation 없음. 이번 후보의
FULL은 새 명시 승인 대기이며 앞선 후보의 FULL PASS를 재사용하지 않는다. 실제 지연 절감은
아직 미측정이고 운영 접근·배포·commit/push를 하지 않았다.

후속 승인 결과: 사용자가 FULL 실행을 승인하여 동일 소스 영문 경로 사본에서
Node22 PATH `dart run :mosigame validate --full --json`을 1회 실행했다. PASS/exit0,
99초·12단계, root393·game_kit100·LP12·FC14·Mafia55·Holdem31·Functions397 및
포맷·분석·lint 통과. 사본 mutation 검사와 원본 파일 해시도 변경 없음이다.
이후 결과 문서만 갱신했다. 배포·개선 후 실측 대기는 유지한다.


## 2026-10-10 — createRealtimeRoom 승인 배포

앱만 재실행한 상태에서 재생성 오류가 반복되어 사용자 승인 후 `createRealtimeRoom`만
운영 `project0000-ec01e`의 서울 리전에 배포했다. FULL 통과 소스 일치 확인,
predeploy lint/build와 CLI 업데이트 PASS·exit0. 배포 전후 소스·Git 상태 변경 없음.
다른 함수 timing 배포와 실제 생성→초기화→재생성·개선 속도 확인은 남아 있다.
[개발팀 공유](../../engineering/NETWORK_LATENCY_IMPROVEMENTS.md)의 인계 절차와
[월별 배포 기록](../logs/2026-10.md#2026-10-10--방-재생성-오류-수정-함수-배포)을 따른다.


## 2026-10-10 — 최초 ready 사전 조회 수정 후보

사용자의 해결·공유 문서 갱신 요청에 따라 공용 명령에서 Map 예약 전 미확정 여부를
판정하도록 수정했다. 최초 ready/failed는 status 없이 전송하고 응답 유실 재시도는
동일 ID/domain 조회·재생을 유지한다. 서버 준비 승인 실패 안내를 로컬 화면 준비와
구분하고, debug 단계·허용 코드만 기록한다. 제품/서버 state contract는 유지한다.

관련34개 PASS, 첫 session 제품 테스트는 통과했으나 별도 작업의 Final Call 에셋 변경으로
mutation FAIL/exit1이었다. 사용자 변경을 보존한 사본 session은 Flutter161·Functions97과
mutation 모두 PASS/exit0, analyze도 PASS/exit0다. 새 FULL 1회와 수정 앱 적용/기존 LP 방
기기별1회 재시험 승인을 요청했다. 아직 수정 앱 실행·서버 배포·commit/push 없음.
[개발팀 공유](../../engineering/NETWORK_LATENCY_IMPROVEMENTS.md#2026-10-10-게임-준비-보고-수정-후보)에
원인·구현·회귀·기기 인계를 추가했다.


### 2026-10-10 — 준비 보고 후보 FULL 및 승인된 기기 재시험

사용자 승인으로 동일 소스 영문 경로 사본의 Node22 PATH
`dart run :mosigame validate --full --json`을 1회 실행: PASS/exit0, 118.156초,
12단계·총1006개 테스트. 원본1470개 해시/Git 상태 변경 없음. 이후 결과 문서만 수정했다.
세 시뮬레이터 설치/실행 exit0. 기존 LP 방에서 iPad 자동 복귀와 ready 즉시 전송,
callable568ms/accepted·준비957ms를 확인했다. 두 휴대폰은 ‘게임 다시 참여’를 각1회
실행했으나 안내 화면에 머물렀고 ready 단계에 도달하지 않았다. 카드 분배/첫 턴 미확인.
휴대폰 복귀 오류가 UI/로그에 드러나지 않는 진단 공백을 확인했으며 실제 오류 원인은
미확정이다. 승인된 횟수 이상 재시험·방 초기화·서버 배포·commit/push는 하지 않았다.
후속 복귀 오류 계측/안내와 추가 재시험 필요. 전체 게임 복구 완료로 표시하지 않는다.
상세 시간·증거·한계는 NETWORK_LATENCY_IMPROVEMENTS.md에 추가했다.

## 2026-10-12 — 방 생성·그룹 탈퇴·초기화 지연 재조사와 설계

사용자 요청에 따라 현재 코드·테스트·canonical 문서·배포 기록·기존 정제 기록을 병행 검토하고
[실행 계획](../ROOM_ACTION_LATENCY_PLAN_20261012.md)을 작성했다. 정상 최초 생성의 resume과
탈퇴/초기화의 status 생략은 이미 구현되어 있어 신규 개선으로 중복 계산하지 않는다.

사용자가 2026-10-11 15:00~17:00 KST와 조회 전용 계정의 두 허용 역할 확인·조회 진행을
승인했다. project0000-ec01e의 관련 서울 callable metadata/고정 단계만 probe1+본조회99건
상한으로 읽었다. 반환1/9건, 고유9건이며 두 조회 PASS/exit0다. 원문·개인정보 없이 ignored
`build/device-test/room-action-plan-20261012/`에 정제 저장했다. SDK 최초 sandbox 실행은
접근 거부(exit1), 승인된 escalation 실행은 성공했다. 운영 데이터 쓰기는 하지 않았다.

leaveRealtimeRoom HTTP200 6건은 동일 revision에서 3건170~184ms, 3건2.82~3.27초였다.
resume은 HTTP200 441/3274ms와 HTTP403 149ms. 생성·초기화·단계 timing은 이 범위에서
미발견이다. metadata는 앱 전체 완료·신규/재생·cold start를 확정하지 않는다.

첫 변경은 leave/transaction 계측과 버전 일치 확인이다. 서버 실행 준비가 긴 군을 설명하면
핵심 함수 minInstances/비용 제한 실험을 우선 선택한다. DB 대기가 크면 close 사전 읽기와
priming 통합 및 create 독립 onboarding/mapping 병행, 앱 cancel이 명령을 막으면 durable
저장을 앞세운 접속 예약 coordinator/만료 continuation 차단을 선택한다.
cleanup 경합/이력 크기·지역 배치도 계측 후 별도 판단한다.

제품 구현·테스트/FULL·배포·실기기 재시험은 하지 않았다. 다른 작업의 Functions 정리·계정
삭제·회귀 변경을 보존했으며 해당 변경을 이번 계획의 검증 결과로 취급하지 않는다.
현재 준비/재참여 미해결과 실기기 검증 상태는 유지한다.

## 2026-10-12 — 정리 Functions 안정성 검토에 따른 계획 보완

사용자가 LP 실기기 검증 채팅의 변경을 재검토하도록 요청했다. 현재 정리 후보에서
connection leaf만 정상으로 돌아오고 player 요약 trigger가 지연된 두 경합을 로컬에서
재현했다. 정리가 최신 room snapshot을 읽어도 leaf를 판정에 사용하지 않아 정상 membership을
제거한다. 현재 controller leaf는 최근 heartbeat인데 요약은 3분 초과인 대기 방 전체가
종료되는 기존 경합도 재현했다. 기존 요약 갱신 reconnect 회귀와 다른 구간이며 운영 발생은 미확인이다.

[성능 계획의 후속 검토](../ROOM_ACTION_LATENCY_PLAN_20261012.md#7-2026-10-12-functions-안정성-검토와-계획-수정)에
참가자·controller 현재 connection의 신원/heartbeat 확인과 callback 재실행 회귀를 정리 후보
배포의 선행 조건으로 반영했다. 정상 create의 DB 호출 수는 바뀌지 않고 deleteAccount는
그룹 탈퇴와 다른 작업이다. 정리 실행 구간의 callable 시간·재실행·처리량을 함께 비교한 뒤
기존 실행 준비/읽기 통합/독립 읽기 병행/앱 취소 대기 후보를 선택한다. TTL 보류는 유지한다.

다른 채팅의 FULL은 최종 PASS(exit0, 12단계)이며 결과 파일을 확인했다. 새 leaf-only 경합은
그 테스트에 없다. 이번 probe 3개는 결함 재현 PASS(exit0)이지 수정 성공이 아니다.
제품 수정·새 FULL·운영 접근·배포는 하지 않았다. 상세 실행 근거는 위 계획과
[월별 검토 기록](../logs/2026-10.md#room-action-function-review-20261012)에 남겼다.


<a id="wait-reduction-integration-20261020"></a>
## 2026-10-20 — 대기 단축 두 항목의 최소 통합

최초 자리 배치의 게임 시작 성공 뒤 퇴장 정리 대상 조회를 남은 착석·줌과 병행한다.
조회는 현재 시작 시도·route·계정·방·접속·게임 문맥에 귀속하고, 실패 시 같은 유효
시도에서만 전환 직전 확인으로 돌아간다. 메뉴·결과 재시작·복구 경로 및 의도된 연출은 유지한다.

초기화는 정확한 옛 접속과 종료 의도를 먼저 고정·저장한 뒤 옛 예약 취소와 서버
close/status를 병행한다. 늦은 옛 등록·취소가 새 접속을 건드리지 않으며, 서버 결과가
미확정이면 원 operation ID·복구 신원을 보존한다. 서버 확인 전 성공 표시·신원 삭제는 금지한다.

구현 계약은 [네트워크·세션 계약](../../engineering/NETWORK_SESSION_CONTRACT.md),
측정 해석은 [로비 지연](../../operations/ROOM_ACTION_LATENCY.md)을 따른다.
방·게임의 공개 API·DB/Rules·서버 권위는 변경하지 않는다.

계측 앱의 최초/메뉴/결과/초기화 본 수집은 각5건이다. 원본 판정 19/20건 통과,
결과 재시작 1건은 첫 제출 이후 다음 라운드 기록 때문에 무효이며 첫 시작 구간을
별도 복원했다. 첫 선택·제출 연결은 15/15건, 초기화의 전체 참가 완료 뒤 새 방
최소30초 유지는 5/5건 확인했다. 각 새 방의 후속 게임 시작까지 5건 모두 확인한 것은 아니다.
R2 영상은 새 방 게임 진행·로비 복귀, S4는 오류 안내 후 게임 진행 재개를 보여주지만
정확한 단절 경합·폰 화면·완전한 복구 계약의 실기기 통과를 뜻하지 않는다.

조회 0.158~0.318초가 5건 모두 연출 안에서 끝났고 전환 시 조회 잔여 대기는 없었다.
취소 4.5~21.5ms와 서버 종료 요청의 병행을 확인했다. 이는 대기 의존성 축소 근거이며
전체 체감 절감량은 미확정이다. 과거 시험의 전체 시간 차이를 원인·절감량으로 단정하지 않는다.

사용자 결정으로 계측 없는 최종 앱의 정상 시작·초기화·새 방 간단 실기기 확인은
최초 방 생성·추방 개선 작업을 마친 뒤 함께 수행한다. 이번 병합의 선행 조건으로
두지 않으며 미실행을 통과로 바꾸지 않는다. G1 공용 경로 실기기 생략·V1 이전 버전
혼합 보류는 유지한다. 기존 타 작업의 미완료 항목은 이 변경으로 완료 처리하지 않는다.

기능 원본은 ea08181, 계측 보존은 e52d781, 상세 평가 보존은 기록 브랜치
codex/wait-reduction의 918228f다. APK·로그·영상은 Git 외 별도 로컬 백업으로 보존한다.
인수인계·계측·상세 CSV/JSON과 수집기는 develop에 포함하지 않는다.
기존 후보25d3ea3의 사용자 승인 FULL은 12단계 PASS/exit0이나 최종 최소 후보의
검증을 대신하지 않는다. 최종 후보의 관련 검사·FULL 결과는 후속 실행 기록으로 갱신한다.

향후 방 생성·추방 성능 작업은 기존 기록에서 재사용 가능한 시작·완료 경계를 먼저
확인하고 누락된 지표만 보완한다. 기존 로그를 일괄 폐기하거나 모든 시험을 다시
수집해야 한다고 가정하지 않는다. 추가 계측·운영 조회·실기기 실행은 별도 범위다.


### 10/20 최종 최소 후보 관련 검증

기존 lock 기준 Prepare/doctor READY, 변경 Dart7개 format(수정0)·analyze(문제0),
관련3파일39 tests와 guarded session suite가 모두 PASS/exit0이다. 각 실행 전후
파일 해시와 Git 상태가 같았다. session은 Flutter29/Functions15 파일을 실행했다.
명령은 `tool/setup_mosigame.ps1 -Prepare`, `dart format --output=none --set-exit-if-changed`
및 변경7파일, `flutter analyze --no-pub` 및 변경7파일,
`flutter test --no-pub test/room_action_fast_path_test.dart test/tablet_start_cleanup_test.dart test/tablet_start_launcher_test.dart`,
`tool/invoke_mosigame.ps1 test session --json`이다. Windows CLI는 guarded 경로로 실행했다.

검증 중 제품 코드를 바꾸지 않았고 이후 갱신은 이 결과를 남기는 작업 문서뿐이다.
최종 FULL은 이 후보에 대한 명시적 승인 대기이며 아직 실행하지 않았다. develop 병합·
push·배포는 하지 않았다. 원 수집·기록 브랜치의 미커밋 문서·이전 후보는 보존했다.


### 10/20 최종 FULL 승인·PASS

사용자가 “FULL 검증 후 병합 진행”을 승인했다. 최종 최소 후보6e07361에서
`powershell.exe -NoProfile -NonInteractive -OutputFormat Text -ExecutionPolicy Bypass -File tool/invoke_mosigame.ps1 validate --full --json`을 실행해
FULL12단계 PASS/exit0, 약 360.05초를 확인했다. 실행 전후 HEAD·branch·
staged/unstaged/untracked 상태가 같았다. 포맷·정적 분석·루트 앱·공용과 네 게임 패키지·
Functions lint/test·작업 트리 보존이 모두 통과했다.

검증 뒤 변경은 이 결과를 남기는 작업 문서3개뿐이며 제품·테스트·환경/설정 파일은
검증한 후보와 같다. 원 수집·기록 브랜치의 미커밋 문서·이전 후보도 보존했다.
비계측 앱 실기기 확인은 방 생성·추방 개선 후로 이관하며 G1 생략·V1 보류를 유지한다.
병합은 최신 develop 재확인 후 진행하고, 원격 push·배포는 별도다.


### 10/20 디벨럽1 결합 검토

앞선 최소 후보 FULL과 구분하여 팀원 디벨럽1b87418f를 포함한 새 후보를 검증했다.
양쪽 시작 전환/로컬 Firebase/취소 병행을 보존하고 관련 session/auth 및 직접 회귀가
PASS/exit0이다. 이번 결합의 최종 FULL은 승인 대기다.
[브랜치 기준·수정·검증·유지한 한계](../DEVELOP1_WAIT_REDUCTION_INTEGRATION_20261020.md).


### 10/20 결합 후보 첫 FULL·회귀 테스트 보완

사용자 승인16480f4의 FULL은 앱 테스트12건에서 FAIL/exit1이다. 번들 의존성 주입과
현재 팀원 UI/패키지 수에 맞는 테스트 절차를 보완했으며 제품은 그대로다. 관련79개·
보완5파일 분석은 PASS/exit0이다. 새 후보 FULL은 skill의 실패 후 재승인 절차를 따른다.
[실패·보완 근거](../DEVELOP1_WAIT_REDUCTION_INTEGRATION_20261020.md#첫-full-실패와-회귀-테스트-보완).


### 10/20 FULL 재승인 결과·Draft PR 전용

최신 사용자 지시는 “다시 실행하고 pr 생성만 해”다.0d48bfb의 FULL 재실행은
12단계 PASS/Functions 마지막1단계 FAIL/exit1(549.46초)이었다. 서버 카탈로그의
옛4종 기대 목록2건만7종으로 보완한 뒤 `npm --prefix functions test`의 build·512개가
모두 PASS/exit0이다. 제품은 그대로고 수정 후 canonical FULL은 미실행이다.
검증 상태를 명시한 develop 대상 Draft PR만 생성하며 병합·자동 병합은 하지 않는다.
[정확한 검증 범위](../DEVELOP1_WAIT_REDUCTION_INTEGRATION_20261020.md).


<a id="server-ready-diagnostics-20261104"></a>
### 2026-11-04 — 배포 앱 준비 실패의 서버 조사·진단 후보

사용자는 분배 직후 휴대폰의 준비 승인 실패/재시도와 태블릿 배경 고착을 보고하고,
배포 앱을 바꾸지 않는 Cloud Functions 수정을 요청했다. 정확한 게임·앱 빌드와
개별 실행의 대응은 미확인이다. 조회용 계정 설정·확인 완료 후 승인된 당일12~14시 KST,
project0000-ec01e의 관련 함수 실행 로그를 총100건 이내로 관찰했다.

고유 요청69건 중 준비 보고40건은 모두 HTTP200, LP 분배 완료19건도 HTTP200이다.
LP 시작9건 중1건은 HTTP400, FC 시작1건은 HTTP200이다. 관련 실행 ERROR와
준비 결과(status/outcome) 기록은 미발견이다. HTTP200은 accepted의 증거가 아니며
staleContext/ignored/dataMissing 또는 앱 내부 승인 처리 실패를 구분하지 못한다.
특정 방·기기와 연결하지 않았고 RTDB·Auth 데이터는 조회하지 않았다.

현재 서버 소스의 준비/분배 관련 기존34개 및 synthetic callable probe3개는 PASS다.
정상 보고로 pause가 해제돼도 별도 complete_dealing 없이 phase가 전환되지 않는
계약을 확인했다. 최초 운영 장애의 원인이나 서버만으로 해결 가능함을 입증한 것은 아니다.

이번 후보는 game_common_recovery_report의 개인정보 없는 결과 계측만 추가한다.
상태/역할·결과 상태·허용 오류 reason/code·처리 시간만 기록하며 신원·카드·요청/응답
본문·오류 메시지/stack은 기록하지 않는다. 기존 응답·오류 객체·준비 검사·진행 계약은
보존한다. 기록 실패도 원래 결과를 바꾸지 않는다. UI·Dart 코드는 수정하지 않는다.

Node22 build와 관련37개 테스트 PASS/exit0. 최초 lint에서 새 helper의 문서·줄 길이12건
FAIL/exit1 후 보완했고 동일 lint PASS/exit0. `dart run :mosigame test session --json`은
manifest/preflight/Flutter/Functions/mutation 모두 PASS/exit0(55.823초)다.
FULL·배포·진단 적용 후 실기기 재현은 미실행이다. 이 후보는 장애 수정 완료가 아니다.
정제 로그와 검증 근거는 ignored `build/server-ready-investigation-2026-11-04/`에 보관한다.


<a id="independent-recovery-20261104"></a>
### 2026-11-04 — 사용자 승인 휴대폰 독립 복구 서버 후보

사용자는 휴대폰 이탈 중 게임 진행 유지, 수신된 준비 실패의 자동 재연결 유도,
태블릿 pause 유지 및 LP 첫 턴 제한 시간을 포함한 서버 변경 방향을 승인했다.
앱/runtime Dart·의존성·보안 규칙은 바꾸지 않았다. 새 protocol2 게임에만 서버 전용
independent-v1 정책을 기록하여 기존 진행 게임에는 종전 규칙을 적용한다.

변경은 recovery-state/game-mutation의 controller-only barrier 및 1회 접속 갱신 유도,
LP complete-dealing의 첫30초 시작, 기존 결과 진단의 reconnectRequested 기록이다.
현재 접속·자격·private context 검사와 중복 요청 원장을 보존한다. 다른 휴대폰의
손패/턴 시간은 그대로이며 태블릿이 끊기면 pause한다. 명시적 퇴장은 기존 최소 인원
규칙을 유지한다. 라운드 변경으로 자동 재연결 한도를 초기화하지 않는다.

검증은 실제 callable + RTDB null/empty-map roundtrip fixture로 시작/ready/분배,
phone 단절·join·늦은 onDisconnect, failed 자동 재연결·응답 재생·반복 방지,
태블릿 failed/resume·타이머 보존, private 부재/옛 자격·접속·게임 거절,
첫 참가자 부재 timeout 및 명시적 퇴장2/3인 시나리오를 포함한다.
7개 gameType의 공통 정책과 기존 protocol2 게임의 종전 barrier도 직접 검사한다.
운영 Firebase 또는 실기기 테스트를 통과한 것으로 해석하지 않는다.

배포 준비 순서(미실행): 새 게임 시작 함수보다 먼저 지원 함수들을 배포한다.
핵심 지원 대상은 game_common_recovery_report, syncRealtimeRoomConnection,
game_common_interruption_on_connection_changed,
game_common_interruption_report_stale_player,
game_common_interruption_report_stale_controller,
game_common_controller_presence_changed, joinRealtimeRoom,
resumeRealtimeControllerRoom, cleanupStaleRealtimeRooms,
game_liars_poker_complete_dealing이다. 종료 시 새 서버 필드 정리까지 일치시키려면
finalizeGameMutation을 사용하는 나머지 게임 명령/leave/exclude 함수도 같은 후보로
갱신한다. 모든 지원 대상 성공 확인 후 liars_poker/final_call/mafia/holdem/yut의
start_game 5개를 갱신한다. 실제 배포 전 index export 기준 최종 선택 목록을 재확인한다.

기존 진행 게임의 정책은 직접 바꾸지 않으며 새 게임에서 확인한다. 실패 보고가
서버에 오지 않는 경우, 앱 실행/네트워크 중단, 실제 배포 빌드에 재연결 경로가 없는
경우는 서버만으로 복구를 보장할 수 없다. 태블릿 분배 완료 요청도 대신 생성하지
않는다. 최초 운영 장애 원인이 확정되거나 모든 오류 UI가 해결된 것은 아니다.

현재 후보의 Functions lint/test와 Project CLI session 결과는 아래 검증 기록에
갱신한다. FULL은 skill에 따른 명시적 승인 대기이며 배포/commit/push는 하지 않았다.
branch develop, HEAD f292f274. 기존 사용자 untracked4개 디렉터리는 보존한다.


#### 현재 후보 관련 검증

Node22에서 `npm --prefix functions run lint` PASS/exit0,
`npm --prefix functions test` build 및568개 PASS/exit0이다.
중간 lint의 LP 줄 길이1건은 줄 분리로 수정 후 재검사했다.
`dart run :mosigame test session --json`은54.246초,5단계 PASS/exit0이다.
Flutter29파일·Functions15파일, manifest/preflight/작업 트리 보존이 통과했다.
실행 전후 HEAD·staged/unstaged/untracked 및 전체 파일 해시가 동일했다.
이후에는 이 검증 결과를 기록하는 문서만 수정했다. `git diff --check` PASS/exit0.
FULL 미실행, 승인 대기. 배포·실기기 검증·commit/push 없음.
증거: ignored build/server-ready-investigation-2026-11-04/ 아래
independent-final-check-{0,1}.log, independent-session.json,
independent-session-progress.log, independent-session-{before,after}.json.


#### 2026-11-04 사용자 승인 FULL 결과

사용자의 “전체검증해” 승인으로 `dart run :mosigame validate --full --json`을
실행했다. 원본 한글 경로에서는 flutter-analyze가 LSP initialize JSON 파싱 오류로
exit255, FULL은 FAIL/exit1(3.348초)이었다. 포맷과 작업 트리 보존은 PASS이며
후속 테스트는 실행되지 않았다. 이는 LOCAL_FIREBASE.md에 기록된 SDK 경로 문제와
같고, 로컬 Flutter 도구가 JSON Content-Length를 바이트 수 대신 문자열 길이로
전송하는 코드도 확인했다. 제품 코드와 SDK는 수정하지 않았다.

동일 HEAD/Git 상태와 모든 tracked/untracked 파일 해시의 영문 임시 사본을 만들고
`dart pub get --offline --enforce-lockfile`로 기존 의존성을 준비했다(PASS/exit0).
실패 단계만 `flutter analyze --no-pub`로 확인하여 PASS/exit0, 문제0건을 얻었다.
후보 변경 없이 같은 전체 검증을 그 경로에서 실행한 결과13/13단계 PASS/exit0,
188.175초다. root Flutter581개, game_kit127개, LP17개, FC28개, Mafia58개,
Holdem32개, Yut8개(Flutter 합851개), Functions568개로 총1,419개가 통과했다.
포맷·분석·Functions lint/build와 작업 트리 보존도 PASS다.

실행 전후 원본과 사본의 HEAD·Git 상태·파일 해시가 모두 같았다.
branch develop/HEAD f292f274, staged 없음, 기존 사용자 untracked4개 디렉터리를
보존했다. 검증 뒤에는 결과 기록용 TASKS/상세/월별 기록3개만 갱신했다.
`git diff --check` PASS/exit0. 앱 코드·SDK·lockfile 변경, commit/push, 운영 접근,
배포는 없으며 실기기 동작 확인은 아직 남아 있다. 운영 장애 해결 완료를 뜻하지 않는다.
증거는 같은 ignored 폴더의 independent-full.json(원본 실패),
independent-full-ascii.json(최종 PASS), 각 progress.log와 before/after.json,
independent-full-ascii-analyze.log 및 prepare.log에 보관한다.


<a id="startup-watchdog-20261105"></a>
### 2026-11-05 — 운영 영향 제한 초기 준비 미보고 보조 복구 후보

사용자는 FC/LP 순서와 관계없이 장애가 발생한다고 설명하고, 배포 서비스의 영향을
최소화하며 추가 복구가 실행되도록 요청했다. 현재 서버 로컬 검사24건(4종 게임 간
12방향×기존/새 protocol 정책)에서는 game 전체 교체·새 식별자·옛 ready 및 종료 이벤트
차단이 통과했다. 실제 운영 DB 초기화 문제를 확정한 것은 아니다. 앱에는10/12의
이전 화면 준비 예산 초기화 수정이 있으나 설치 빌드 포함 여부와11/4 스크립트 배포
완료 여부는 사용자 확인 대기다. 이번 작업에서 운영 접근/배포는 하지 않는다.

추가 서버 후보는 새 LP/FC 시작 당시 접속만 startupRecovery로 추적한다. valid ready
도착 즉시 제외하며90초~5분 사이 최근20초 heartbeat가 정상인 미확인 접속만 기존
재연결 경로로1회 유도한다. failed 보고가 전송되지 못한 초기 준비 장애의 보완이다.
기존 진행 방과 다른 게임·background/offline·교체된 접속/자격은 건드리지 않는다.
시작/완료/보고는 기존 원장·권한/context 검증을 유지한다. 반복 호출/failed 보고와
한도를 공유하고 손패/phase/분배 완료를 생성하지 않는다. 기존1분 스케줄의 조회를
재사용하며10개 동시 transaction 제한과 실패 방 격리, 비식별 건수 로그를 추가했다.

이전 배포 스크립트는 검증된11/4 서버 파일 해시를 확인하도록 고정했다.
새 수정안이 들어간 상태에서 그 명령으로 미검증 후보가 배포되는 것을 막는다.
새 후보 검증 뒤 스케줄 cleanupExpiredGameInterruptions를 포함한 지원 함수와
시작 함수 순서로 별도 명령을 갱신한다. 아직 그 명령을 운영 실행하지 않는다.

앱 코드·의존성·rules 변경은 없다. 기존 사용자 변경을 보존한다.
자동 복구가 기존 앱의 callback 소실이나 이미 승인된 준비 이후 모든 실패를 해결하는
것은 아니다. 운영 배포·실기기 결과가 있어야 실제 해결 여부를 판정한다.


#### 11/5 추가 후보 관련 검증 결과

Node22에서 `npm --prefix functions run lint` PASS/exit0,
`npm --prefix functions test` build 및590개 PASS/exit0이다. 추가22개는 LP/FC 실제
start→무보고→보조 복구→resume/join→ready/분배, 정상 기기·private/타이머 보존,
준비/접속 교체 경합, 구버전·종료·다른 게임/방·만료·background·stale/future heartbeat·
자격/접속 교체·탈락 제외, 스케줄1회 조회/최대10개 동시/실패 격리/비식별 건수를 검사한다.
`dart run :mosigame test session --json`은5단계 PASS/exit0,50.330초다.
실행 전후 HEAD·Git 상태·tracked/untracked 파일 해시 동일이며 결과 문서만 이후 갱신했다.
기존11/4 배포 스크립트는 새 후보에서 의도한 exit1로 운영 호출 전에 중단됨을 dry-run으로
확인했다. `git diff --check` PASS/exit0. branch develop/HEAD f292f274, staged 없음.

증거: ignored build/server-ready-investigation-2026-11-05/의 startup-verified-*.log와
startup-checks-{before,after}.json. 이번 후보 FULL은 명시적 재승인 대기이고 미실행이다.
운영 접근·배포·실기기 확인·commit/push는 하지 않았다. 이전 FULL 결과는 새 후보의
완료 판정을 대신하지 않는다.


<a id="stop-failed-disconnect-20261105"></a>
### 2026-11-05 — 준비 실패 보고의 강제 연결 종료 중단 배포

사용자가 선턴 및 특정 휴대폰의 반복 연결 실패가 최근 Functions 배포 후 심해졌다고
보고했다. 운영 장애의 정확한 최초 원인과 설치 빌드는 미확정이다. 서버의 LP/FC 선턴
재접속을 제한 시간 전후로 실행한 임시 4개 검사는 통과했다. 초기 임시 FC 검사의
캐릭터 중복 fixture와 배열 변환을 바로잡은 뒤 실제 지원 입력으로 재검증했다.

배포 앱과 공통 코드 경로에서는 준비 실패 보고가 정상 연결을 false로 바꿀 수 있고,
재접속 실패 뒤 transportRecovering=true가 남으면 게임 retryRecovery가 재접속
callback을 호출하지 않는다. 임시 Flutter 회귀에서 기대 호출 1회, 실제 0회로
FAIL/exit1을 재현했다. 실제 화면은 GameRecoveryLayer의 session.retry 경로를 사용한다.
이 앱 동작은 기존 코드에 있었으며 최근 서버의 연결 해제가 이 경로를 유발할 수 있다.

서버 수정은 applyRecoveryReport의 failed 처리에서 requestPreparationReconnect 호출을
제거하고 기존 응답 필드 reconnectRequested=false를 유지한다. 휴대폰 독립 진행과
태블릿 pause/ready, 접속·참가 자격·private 검증을 보존한다. LP/FC 선턴이 반복 실패
보고 후 동일 접속에서 ready를 승인받고 손패·턴·연결을 보존하는 회귀 2개를 추가했다.
수정 전 두 회귀 FAIL/exit1, 수정 후 전체 서버 593개 PASS/exit0이다.

`npm --prefix functions run lint`, `npm --prefix functions test`,
`dart run :mosigame test session --json`은 PASS/exit0이다. session은 5단계와
working-tree 보존을 통과했다. 사용자가 전체 검증 후 해당 함수 배포를 명시 승인했다.
영문 임시 사본에서 고정 lockfile/offline 의존성을 준비하고
`dart run :mosigame validate --full --json`을 실행했다. 13단계 PASS/exit0,
136.467초, Flutter 851개와 서버 593개가 통과했다. 검증 중 파일 변경도 없었다.

검증한 사본에서 다음 명령으로 선택 배포했다.

```bash
./functions/node_modules/.bin/firebase deploy --project project0000-ec01e --only functions:game_common_recovery_report --non-interactive
```

서울 리전 Node22 2nd Gen의 Successful update operation 및 Deploy complete,
exit0을 확인했다. 실기기 복구와 최초 준비 실패 원인은 후속 확인 대상이다.
이미 앱 내부의 복구 플래그가 남은 경우를 서버만으로 해제한다고 보장하지 않는다.
startupRecovery 스케줄 후보는 별도이며 이번 배포에 포함하지 않았다. 해당 후보의
운영 활성화는 이 재접속 위험을 해결하기 전까지 보류한다.

작업 전 develop/7c46f74d의 tracked 변경은 없고 사용자 미추적 폴더 4개가 있었다.
수정한 서버 1개·테스트 2개와 결과 문서를 로컬에 보존했으며 이번 작업의 commit/push는
수행하지 않았다. 검증 증거는 ignored build/server-ready-investigation-2026-11-05의
no-forced-disconnect-tests.log, no-forced-disconnect-session.json,
no-forced-disconnect-full.json에 보관했다.


2026-11-05 후속 사용자 확인에서 강제 끊김 중단 배포 후 재접속이 복구됐다고 보고했다.
추가 pending join 후보는 사용자 요청으로 배포를 취소하고 로컬에서도 직전 배포 후보로
되돌렸다. 조사 기록과 후보는 ignored build에 보관했다. 다시하기 후 분배 정체는 별도 조사한다.


<a id="restart-background-investigation-20261105"></a>
### 2026-11-05 — 다시하기 후 휴대폰 배경 정체 조사(미해결)

사용자가 마지막 recovery_report 배포로 재접속이 된다고 확인하여 미배포
pending-join 후보를 철회했다. 관련 5개 파일은 직전 배포 검증 checkout과
byte 비교로 일치하며, joinRealtimeRoom 추가 배포는 하지 않았다. 기존 HEAD의
미배포 startup watchdog까지 운영 전체와 일치한다고 주장하지 않는다.

요청 시각 기준 14:10:22–14:15:22 KST를 조회용 gcloud configuration으로
한정 조회했다(관련 callable 10개, limit100, 결과90, exit0). Firebase CLI의
Node22 경로로 실제 runServiceId를 확인했다. LP start3/complete_dealing3/end1
모두 HTTP200, ready 보고16개 accepted였다. 해당 구간에서 FC 호출은 없었다.
HTTP200만으로 새 변경 commit 여부나 사용자 기기의 렌더링 성공을 확정할 수 없고,
사용자가 보고한 판과의 대응도 아직 확인되지 않았다. 운영 DB는 조회·수정하지 않았다.

합성 참가자로 실제 LP callable의 시작→ready→분배→카드 제출4회→다시하기를
2회 반복한 뒤 종료한 snapshot을 생성했다. 공개/개인 이벤트 동시 도착,
공개 우선, 개인 우선 3가지로 현재 Flutter 소스의 손패5장 수신과 수동 종료를
검증했다. 준비 에셋은 테스트에서 명시적으로 준비 처리했고, 손패 펼치기는
직접 markHandRevealed를 호출했으므로 실기기 연출 재현/통과의 증거는 아니다.
초기 테스트의 종료 잔류는 routeActive=false인 960ms 퇴장 연출의 disposal
프레임 대기였고, 프레임 대기 후 3개 PASS/exit0이었다. 앱 코드는 수정하지 않았다.

- `npm --prefix functions run build`: PASS/exit0.
- `node --test build/server-ready-investigation-2026-11-05/restart-snapshot-probe.mjs`:
  PASS/exit0(합성 snapshot 1개 시나리오).
- `flutter test --no-pub /private/tmp/mosigame-restart-probe_test.dart --reporter expanded`:
  동일 소스 ASCII 검증 checkout에서 PASS/exit0, 3개.
- `npm --prefix functions test`: PASS/exit0, 593개.
- `git diff --check`: PASS/exit0. develop/7c46f74d 유지, 기존 8개 수정 파일과
  사용자 untracked 4개 디렉터리 보존. 새 제품 코드 수정·commit·push·deploy 없음.
- 새 수정 후보가 없어 FULL은 추가 실행하지 않았다. 증상 해결을 선언하지 않는다.

정제한 운영 metadata/log와 합성 재현 evidence는 ignored
`build/server-ready-investigation-2026-11-05/`의 `replay-game-*`, `restart-*`,
`restored-server-tests.log`에 있다. 다음에는 해당 시간/게임과 태블릿 동반 정체
여부를 확인하고, 필요 시 실제 실패 재현 시점의 기기 진단과 서버 처리 결과를
연결해야 한다. 현재 evidence로 강제 연결 끊기나 자동 분배를 추가하지 않는다.


<a id="restart-transition-diagnostics-20261105"></a>
### 2026-11-05 — 분배·종료 결과 진단(배포 완료, 원인 미확정)

사용자는 종료도 되지 않아 태블릿·휴대폰 모두 정체했을 가능성을 전했으나 확실하지
않다고 했다. 동일 소스의 실제 태블릿 `onExitToLobby` 경로에 성공 응답을 주는
격리 테스트를 추가 조사하여 정상/준비 대기 두 경우 모두 화면 종료 PASS/exit0을
확인했다. 성공 callable은 Fake이며 네트워크·실기기 정상 판정은 아니다.

현재 HTTP200 로그로는 이전 작업의 저장 응답 재생과 현재 게임의 실제 분배/종료를
구분할 수 없다. 이를 다음 재현에서 구분할 수 있도록 LP complete_dealing/end_game
두 callable의 성공 결과에만 `liars_poker_transition_result` 진단을 추가했다.
새 함수 export, 앱 코드, DB 읽기/쓰기, API 응답 또는 게임 전이는 변경하지 않는다.
이미 완료한 transaction snapshot에서 고정 action/responseType/status/phase,
requestGameCurrent/paused/contextValid/pendingHands boolean 및 private 인원수와
public-private context 일치 인원수만 기록한다. 방 코드·UID·게임 ID·손패·원문
오류는 기록하지 않는다. snapshot 해석/로깅 실패도 원래 성공 응답을 보존한다.

회귀는 실제 분배→종료→재시작 뒤 옛 분배 명령을 재전송하여, 저장된 성공 응답과
현재 dealing 상태를 구분하면서 새 판을 바꾸지 않는지 확인한다. 이는 멱등 계약을
검증한 것이며 운영 장애가 옛 명령 재생 때문이라고 확정한 증거가 아니다.

- `npm --prefix functions run lint`: 최초 JSDoc/줄 길이 실패를 수정 후 PASS/exit0.
- `npm --prefix functions test`: PASS/exit0, 598개(이전593+진단5).
- `flutter test --no-pub /private/tmp/mosigame-tablet-restart-probe_test.dart --reporter expanded`:
  동일 소스 ASCII checkout에서 PASS/exit0, 2개(정상/준비 대기 종료 경로).
- `git diff --check`: PASS/exit0. develop/7c46f74d, 기존 변경/사용자 untracked 보존.
- 후보 변경: `transition-diagnostics.ts`, LP `complete-dealing.ts`/`end-game.ts`,
  `transition-diagnostics.test.mjs`, 기존 RTDB 회귀 파일에 integration 1개, 조사 문서.
- FULL과 운영 배포는 아직 수행하지 않았다. 승인 시 배포 대상은
  `game_liars_poker_complete_dealing`, `game_liars_poker_end_game` 두 개로 제한한다.
  시작·startup scheduler·join 함수와 기존 재접속 배포는 변경 대상이 아니다.
- 정상 경로와 재시도 응답을 바꾸지 않는 진단 후보다. 장애 수정 완료로 표시하지 않는다.
  FULL은 Skill의 새 최종 후보 승인, 두 함수 배포는 기존 recovery_report 배포 범위
  밖이므로 별도 승인을 요청한다. 승인 후에도 실제 재현 상태 확인이 필요하다.


#### 사용자 승인 후 전체 검증·선택 배포 완료

사용자의 “배포해줘”를 직전 제안한 FULL 후 두 함수 선택 배포 승인으로 받아 실행했다.
기존에 확인된 한글 경로 Flutter 분석 오류를 피하기 위해
`/private/tmp/mosigame-transition-deploy-6435op0r/project00`에 develop/7c46f74d의
동일 tracked 소스와 진단 추가 파일을 복사했다. 총1657개 파일의 SHA256으로
원본/검증본 일치를 확인했다. SDK 수정 없이 기존 Node22와 Flutter SDK를 사용했다.
`flutter pub get --offline --enforce-lockfile`은 PASS/exit0이며 소스 변화가 없었다.

- `dart run :mosigame validate --full --json`: PASS/exit0, 13/13단계,
  198621ms. formatting, Flutter analysis, root와 6개 게임 패키지 테스트,
  Functions lint/tests, working-tree mutation 판정이 모두 PASS다.
- `node functions/node_modules/firebase-tools/lib/bin/firebase.js deploy --project
  project0000-ec01e --only functions:game_liars_poker_complete_dealing,functions:game_liars_poker_end_game
  --non-interactive`: 검증한 checkout에서 PASS/exit0. predeploy eslint/tsc,
  두 함수 Successful update operation과 Deploy complete를 확인했다.
- 배포 runner는 FULL PASS와 원본/검증본의 소스 hash 일치에 실패하면 배포 전에 중단한다.
- `firebase functions:list --project project0000-ec01e --json`: 정제한 두 대상
  metadata의 서울 리전/Node22/gcfv2 유지와 source hash 교체를 확인했다(exit0).
  이전 `e9ecbc6ef8048a14df0fa5aaaa71d0a5131204c0` →
  새 `8e078f4b63fb897bfc68730837dbbb2073a53502`(두 함수 동일).
  확인 시각 2026-11-05 14:54:53 KST.
- 검증·배포 전후 원본1657개 파일 hash 및 `git status --porcelain` 동일을 확인했다.
  develop/7c46f74d 유지, 기존 사용자 untracked4개 디렉터리 보존, commit/push 없음.
  이 확인 이후 배포 결과 기록을 위한 문서4개만 의도적으로 갱신했다.
- 배포 후 실제 게임 호출은 하지 않았다. 시작/join/recovery_report/scheduler와
  Rules/DB migration은 이번 배포 대상이 아니다. 사용자 재현 시각의 진단 로그와
  화면 상태를 연결해야 하며, 정체 장애 해결 완료로 보고하지 않는다.

Evidence: ignored `build/server-ready-investigation-2026-11-05/` 아래
`transition-full.json`, `transition-validation-source.json`, `transition-before-status.txt`,
`transition-deploy.log`, `transition-deploy-before.json`, `transition-deploy-after.json`,
`deploy-transition-diagnostics.py`. 위 후보 절의 승인 대기는 이 후속 기록으로 해소됐다.


<a id="foreground-return-investigation-20261105"></a>
### 2026-11-05 — 다른 앱에서 복귀 후 정체 조사(제품 코드 변경 없음)

사용자가 완전 종료 대신 다른 앱에 잠깐 갔다 돌아와도 멈춘다고 확인했다.
현재 RoomProvider는 paused에서 current connection을 disconnected로 쓰고
transportRecovering=true로 잠근 뒤 resumed에서 retryConnectionRecovery를 실행한다.
복귀 요청의 실패는 catch되어 해당 화면에 남으며, 게임 화면의 retryRecovery는
retrySession/에셋 준비만 호출하고 session.reconnect를 호출하지 않는다.
transportRecovering=true이면 readiness 평가와 ready 전송이 진행되지 않는다.

검증한 동일 소스 checkout에서 기존 격리 probe 한 개를 실행했다.
`flutter test --no-pub /private/tmp/mosigame-phone-reconnect-probe.dart --plain-name
'PROBE retry restarts a failed phone connection recovery' --reporter expanded`는
FAIL/exit1, reconnect 호출 기대1/실제0이었다. 제품 코드 변경 없이 테스트에서만
복구 callback을 먼저 연결한 비교 probe는 PASS/exit0, canSend=true를 확인했다.
이는 최초 복귀 실패가 일어났다는 실기기 증거나 운영 원인 확정이 아니라,
실패 뒤 수동 재시도로 회복하지 못하는 클라이언트 결함의 재현이다.

`node --test build/server-ready-investigation-2026-11-05/foreground-server-probe.mjs`:
PASS/exit0(2개 조건 확인). 정상 join→ready 경로는 같은 membership/자리/손패를
유지하며 새 connected 연결과 accepted를 돌려준다. 응답을 저장하기 전 다시
단절된 pending join을 재전송하면 현재 disconnected 연결의 저장 성공이 돌아오는
기존 서버 경계 사례도 재현했다. 이전 철회한 join 후보는 다시 적용/배포하지 않았다.

기존 ‘Cloud Function만 수정’ 범위에서는 앱이 호출하지 않는 재연결 callback을
서버에서 연결할 수 없다. 앱 복귀·실패 재시도의 실제 연결 복원을 함께 수정할
범위를 확인해야 한다. 최초 복귀 실패의 시각/실제 로그는 아직 확보되지 않았다.
프로젝트에 shorebird.yaml/shorebird_code_push가 있지만 설치된 스토어 바이너리가
Shorebird release 빌드인지 확인되지 않았으므로 무심사 패치 가능을 확정하지 않는다.
공식 문서 https://docs.shorebird.dev/code-push/troubleshooting/ 의 기존 release
바이너리 조건을 확인했다. 이 조사에서는 FULL·production 접근·deploy를 추가
실행하지 않았고, 제품 소스와 사용자 파일을 유지했다.


<a id="pending-join-disconnected-20261105"></a>
### 2026-11-05 — 끊긴 pending join 성공 응답 재사용 방지 후보

다른 앱에 갔다 복귀하는 문제에 대해 사용자는 앱 수정 없이 서버에서 가능한 최소
수정을 승인했다. 앞서 철회했던 후보 전체를 복구하지 않고 joinRealtimeRoom의
저장 응답 분기에만 disconnected 현재 연결 검사와 기존 staleConnection 오류를
추가했다. 추가 지연 계측/거절 사유 로깅은 포함하지 않는다. 동일 active membership,
presenceProtocol=2, 비종료 방에만 적용하고 currentPresence로 같은 transaction의
연결 신원을 검증한다. 클라이언트 기존 복구가 새로운 operationId/최신 seq로 접속을
요청한다. 기존 연결 부활, 강제 퇴장, 손패/게임 초기화, 앱 제품 코드 변경은 없다.

수정 전 단일 회귀는 Missing expected rejection으로 FAIL(1/1 실패)했다.
수정 후 npm --prefix functions test는 PASS/exit0(603개), npm --prefix functions
run lint는 max-len 1건 수정 후 PASS/exit0이다. 정상 응답 유실 replay, 단절 뒤
새 연결/동일 membership·손패·게임 유지, 늦은 old onDisconnect 무효,
closed/terminal/removed/다른 membership 경계를 확인했다. Dart 테스트만 추가하여
기존 RoomService가 aborted/staleConnection에서 새 연결을 요청하고 heartbeat를
새 연결에 쓰는 경로를 검증한다. 앱 lib/packages 제품 코드 변경은 없다.

세션 검증은 동일 소스 ASCII 임시 checkout에서 수행하며 결과를 아래에 기록한다.
현재 전체 검증과 joinRealtimeRoom 배포는 미실행이다. 최초 단절 원인이나 모든
복귀 정체의 해결을 확정하지 않는다. 특히 앱이 재접속 요청을 보내지 않는 경우는
서버 후보 적용 범위 밖이다. 설치된 스토어 바이너리와 소스 일치도 별도 확인이 필요하다.


`dart run :mosigame test session --json`: PASS/exit0, 5/5단계(63.548초).
추가한 기존 앱 복구 회귀를 포함한 Flutter 선택 테스트와 서버 선택 테스트233개가
통과했다. 같은 소스 ASCII checkout의 검증 전후 mutation 검사 PASS이며 원본과
검증본의 소스 hash가 일치했다. 실행 후 차이는 의도한 작업 기록 문서4개뿐이다.
초기 offline pub get은 SDK 캐시 sandbox 권한으로 실패했으며 기존 SDK 캐시 접근
권한으로 재실행해 성공했다. SDK 제품 코드/권한 설정을 수정하지 않았다.

develop/7c46f74d 유지, 기존 수정과 사용자 untracked4개 디렉터리 보존.
이번 제품 수정은 functions/src/room/realtime-room-functions.ts 14줄이며 테스트
2개 파일과 기록 문서4개를 보완했다. commit/push/production 접근/배포 없음.
FULL 승인 전이므로 완료 판정은 보류한다. Evidence는 ignored
build/server-ready-investigation-2026-11-05/pending-join-{baseline,server,lint}.log,
pending-join-session.{json,progress}, pending-join-validation-source.json에 있다.


#### 후속 승인·FULL·join 단일 배포 완료

사용자의 “배포해줘” 승인으로 최종 후보 전체 검증 뒤 joinRealtimeRoom만 배포했다.
`dart run :mosigame validate --full --json`: PASS/exit0, 13/13단계,
186.309초. 동일 소스 ASCII checkout에서 분석/format/앱·게임 테스트/Functions
lint·603개 테스트/working-tree mutation을 모두 통과했다.

`node functions/node_modules/firebase-tools/lib/bin/firebase.js deploy --project
project0000-ec01e --only functions:joinRealtimeRoom --non-interactive`:
검증 checkout에서 predeploy lint/tsc, Successful update operation,
Deploy complete를 확인했다(PASS/exit0). 배포 runner가 FULL 성공과 원본·검증본
1657개 파일 hash 일치를 확인한 뒤 실행했다. 다른 함수·Rules·DB migration 없음.

`firebase functions:list --project project0000-ec01e --json`: 배포 전후 정제한
joinRealtimeRoom metadata 확인 PASS/exit0. asia-northeast3/nodejs22/gcfv2 유지,
source hash e9ecbc6ef8048a14df0fa5aaaa71d0a5131204c0 →
079397f150d3ba5f832d7366f36c005cf32faef3. 확인 시각 2026-11-05 16:22:34 KST.

검증·배포 전후 원본 소스 hash와 git status 동일, develop/7c46f74d 및 기존 사용자
변경 보존. 이후 배포 기록 문서4개만 의도적으로 갱신했다. commit/push 없음.
실기기에서 다른 앱으로 전환·복귀 후 현재 손패/턴 유지 확인은 아직 미실행이며,
모든 앱 복귀 정체의 해결로 보고하지 않는다. 위 FULL/배포 승인 대기는 해소됐다.
Evidence: ignored build/server-ready-investigation-2026-11-05/의
pending-join-full.{json,progress}, pending-join-validation-source.json,
pending-join-deploy.log, pending-join-deploy-{before,after}.json,
pending-join-{full-before,deploy-after}-status.txt, deploy-pending-join.py.


### 2026-11-06 — 앱·서버 동시 개선으로 범위 전환(진단·계획)

사용자는 별도 Firebase 프로젝트를 준비하고, 새 브랜치 codex/app-cloud-update에서
출시 앱의 우회 복구 대신 앱 코드와 Functions의 근본 개선 방향을 요청했다.
[코드 근거·실행 순서·검증 기준](../APP_SERVER_RECOVERY_PLAN_20261106.md)을 작성했다.
확인된 retry 연결 누락을 우선하고 분배 완료/새 게임 경계/종료/서버 복구 정책을
순차 검증한다. 실제 분배 정체 원인은 미확정이며 새 프로젝트 ID는 아직 미제공이다.
이번 작업은 문서만 변경, 제품 코드·운영 접근·배포·테스트 실행 없음.


<a id="foreground-input-20261106"></a>
### 2026-11-06 — 휴대폰 앱 이탈·복귀 입력 잠금 최소 수정 후보

사용자는 게임 진행은 정상이며 iOS/Android의 다른 앱 전환 후 입력 정체를 최우선으로
지정하고 실제 재접속 연결 및 복구/나가기 접근 유지 수정을 승인했다. 자동 복구는 기존
30초 배치 예산 후 종료될 수 있지만, 모든 장애의 최초 원인이 예산 소진으로 확정된
것은 아니다. 확인한 결함은 게임 retryRecovery가 session.reconnect를 호출하지 않아
transportRecovering이 남을 수 있다는 점이다.

수정 전 새 회귀는 reconnect 기대1/실제0으로 FAIL/exit1이었다. 수정 후 공용 retry는
필요한 경우 실제 reconnect를 먼저 기다리고 현재 데이터/화면 준비를 재시작한다.
중복 클릭은 한 Future로 합치며 identity/transport 이벤트의 중복 재구독을 억제한다.
연결 실패는 로컬 오류와 재시도를 남기고 leaving/dispose 이후 완료는 무시한다.
휴대폰 게임 route만 blanket AbsorbPointer를 사용하지 않도록 선택하고 실제 게임
명령의 canSend 검사는 유지한다. 기본 로비 차단은 바꾸지 않는다. guard 복구 실패 때
즉시 재시도 UI를 노출하고 진행 중 나가기 버튼을 활성화했다.

변경 제품 파일: game_session_controller.dart, app_network_guard.dart,
critical_network_guard.dart, network_unavailable_modal.dart,
lib/platform/home/phone/screens/phone_room_waiting.dart.
회귀 파일: game_readiness_contract_test.dart, app_network_guard_test.dart,
test/game_command_response_loss_test.dart. 새 dependency/서버 데이터 계약 변경 없음.

동일 소스 ASCII checkout의 `flutter test --no-pub` 관련3파일: PASS/exit0, 53개.
재접속 중복 합침, 실패 뒤 재시도, 정상 연결 재사용, 오래된 손패 입력 차단,
퇴장 중 늦은 완료 무효, 실패 UI 재시도 후 해제, 복구 중 나가기, 실제 명령 서비스의
복구 전 호출0/복구 후 호출1을 확인했다. `flutter analyze --no-pub` 변경8파일:
PASS/exit0, No issues found. dart format 변경8파일 exit0, git diff --check exit0.
공식 session 결과는 후속 기록하며 최종 후보 FULL은 별도 승인 전까지 미실행이다.

이번 수정은 업데이트할 앱 후보이며 출시 앱에는 아직 적용되지 않았다. Functions는
이번 작업에서 수정/배포하지 않았다. 새 Firebase ID가 아직 없어 실제 Android/iOS
복귀·네트워크 전환·서버 연계 검증은 미실행이다. 전체 증상 해결로 판정하지 않는다.
기존 Functions 수정·배포 기록과 사용자 파일은 보존하며 commit/push/운영 접근 없음.
Evidence: ignored build/foreground-recovery-2026-11-06/의 before.json,
test-source.json, baseline.log, targeted.log, analyze.log 및 session 결과.


후속 공식 검증: `dart run :mosigame test session --json` PASS/exit0,
5/5단계(50.326초). 선택 Flutter/Functions 검사와 working-tree mutation 모두 PASS.
검증본1658개 파일 hash가 전후 동일하며 원본의 이후 차이는 의도한 기록 문서뿐이다.
codex/app-cloud-update / 7c46f74d 유지. 최종 후보 FULL 승인 대기이며 운영 배포 없음.


<a id="startup-session-choice-20261106"></a>
### 2026-11-06 — 로그인 전환·이전 게임 선택·Final Call 결과 순서 후보

사용자는 저장 로그인이 있어도 로그인 화면이 잠깐 보이는 현상을 없애되 인증 검증은
유지하고, 휴대폰·태블릿 모두 로비보다 이전 게임 확인을 먼저 수행한 뒤 복귀 여부를
묻도록 요청했다. 또한 Final Call 태블릿에서 카드 공개 전 팀 탈락 문구가 보이는
문제를 수정하도록 승인했다.

`AuthGate`의 인증·온보딩 구독과 timeout은 유지하고 초기 판정 위젯만 공용 violet
startup surface에서 렌더링한다. `PhoneHome`은 이전 세션 판정 완료 전 로비를 숨기고,
판정 오류를 none으로 바꾸지 않고 재시도를 제공한다. 복귀 거절도 서버 확인 성공 전
prompt를 닫지 않는다. `TabletHome`은 기존 controller 방을 복원해 game status를
분류하되 게임 route를 자동으로 열지 않고, 진행 게임/대기 그룹 복귀 또는 기존 방
종료를 사용자가 선택하게 한다. status 최초값이 3초 안에 오지 않으면 방 연결을
버리지 않고 그룹 복귀 선택으로 진행하며 후속 playing 이벤트가 오면 게임 복귀로
갱신한다.

Final Call의 결과 life row는 teammate가 직접 heart를 잃지 않은 `loss=0`인 경우도
reveal timeline 완료 전 eliminated 문구를 숨긴다. 좌석 plate의 탈락 표시는 그대로다.
서버 함수·persistent data·public API 변경과 production 접근·배포는 없다.

직접 관련 테스트(인증 시작 화면, 휴대폰 판정 gate, 태블릿 복귀 prompt, 공용 prompt,
Final Call 공개 순서) 23개와 변경 파일 정적 분석은 PASS/exit0이다. Node22 격리본에서
`dart run :mosigame test auth --json`은 Flutter82개·Functions38개,
`dart run :mosigame test session --json`은 Flutter230개·Functions233개와 각각
working-tree mutation을 포함해 모두 5/5단계 PASS/exit0이다. FULL은 승인 대기다.


<a id="live-room-retention-liar-ui-20261108"></a>
### 2026-11-08 — live 방 자동 퇴장 제거·LIAR 첫 턴 비활성 후보

사용자 요청으로 연결 단절 경과 시간만으로 자동 퇴장·방 삭제하는
경로를 제거했다. `findGhostPlayers`는 게임/방 종료가 확인된 경우에만
대상을 반환하고, `cleanupDeadline`/`shouldDeleteRoom`은 waiting·seating·playing에
시간 기한을 만들지 않는다. 명시적 자기 퇴장·강퇴·방 종료와 finished
보존 기한은 유지한다. 이전 cleanup queue job은 live signal에서 job만 제거한다.

라이어스 포커는 기존 `LiarsPokerController.canCallLiar` 서버 권한 조건
(`lastPlayPlayerUid != null`)을 UI 색에도 반영했다. 첫 제출 전 선택 카드가 없으면
LIAR 버튼은 grayscale/dark filter와 disabled semantics를 사용하고 터치를 무시한다.
직전 제출이 생기면 같은 controller getter로 즉시 활성화된다.

CI 2개 실패도 함께 보정했다. session frozen manifest에
`phone_home_startup_recovery_test.dart`를 추가했고, AuthGate 프로필 전환 테스트는
약관 복원 비동기 프레임을 명시적으로 pump한다. Functions build와 관련 72개,
선택 Flutter 33개 및 LIAR 추가 흐름 7개는 PASS/exit0. FULL·실기기·배포는
실행하지 않았다.

후속 CI 동일 `flutter test --no-pub`는 587개 PASS/exit0으로 기존
584 PASS/2 FAIL을 해소했다. Project CLI session은 Flutter231개·Functions233개,
auth는 Functions38개를 포함해 각각 5/5단계·mutation PASS/exit0이다.
Functions lint/build과 ASCII 임시 검증본의 변경 Dart 6파일 분석도 PASS/exit0이다.
원본 한글 경로의 분석은 기존 SDK LSP JSON 절단으로 exit255였고,
동일 소스 ASCII 경로에서 `No issues found`를 확인했다. FULL은 승인 대기다.
