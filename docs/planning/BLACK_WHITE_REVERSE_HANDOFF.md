# 흑과 백 리버스 작업 인계

## 2026-11-23 · S0 기준선

| 항목 | 내용 |
| --- | --- |
| 제품 원본 | [노션 PRD·개발 계획](https://app.notion.com/p/42009716f87e8146b627c41eb0d45e21), [Claude 시안](https://claude.ai/artifact/EfLY27nxoLMiWVnXzFWomp#page-dcb81aee8d83) |
| 추적 | [GitHub Issue #201](https://github.com/WarmhanDongne/Mosigame/issues/201), [작업 목록](TASKS.md), [S0 화면 매핑·기준선](tasks/BWR-S0.md) |
| 작업 브랜치 | `feature/black-and-white-ui`; 원본 작업 트리에 기존 미커밋 변경이 있어 분리된 복제본에서 작업했다. 원본 변경은 보존했다. |
| 원격 관계 | S0 시작 당시 GitHub 기능 브랜치는 develop 대비 43커밋 뒤·1커밋 앞. 이후 S0 문서 커밋이 추가되었다. 최신 develop 미반영. 작업 재개 시 다시 비교한다. |
| Firebase | 기존 기능 브랜치 `.firebaserc` default `project0000-ec01e`(운영), TEST `ban-pick-simulator`. 이 단계에서 Firebase 명령/배포 없음. |
| 검증 | `dart run :mosigame validate --full --json` → shell exit 1, Flutter SDK cache 쓰기 거부로 검사 시작 전 환경 BLOCKED. 테스트 PASS/FAIL 판정 불가. |
| 작업 결과 | BWR-S0~S9 등록, T01–T13/P01–P11 결정 매핑 작성. 게임명과 영구 `gameId`는 `eleven`으로 확정(2026-11-23). |

### 다음 작업자가 먼저 확인할 것

1. 원본 저장소의 `git status --short --branch`와 HEAD를 재확인하고 사용자 변경을 stash/reset/checkout하지 않는다.
2. 원격 기능 브랜치의 최신 상태와 develop을 다시 비교한다. 충돌 가능성을 확인한 후 안전한 환경에서 병합/동기화한다. 원본 사용자 변경은 보존한다.
3. SDK 쓰기가 가능한 환경에서 최신 develop 포함 후보의 `dart run :mosigame validate --full`을 실행하고 실제 status/exit code, 검사 전후 working tree를 기록한다. 위 BLOCKED 결과를 PASS로 전환하지 않는다.
4. 게임명·`gameId`는 `eleven`이다. 최신 develop 기준선과 FULL 검증을 기록해 S0 완료를 판정한 뒤 S1 계약 문서를 시작한다.

S8의 TEST Functions 배포, S9의 운영 배포·카탈로그·스토어 변경은 각각 해당 단계의 승인과 결과 기록에 따른다.
