# Mosigame 문서 지도

AI는 루트 [`AGENTS.md`](../AGENTS.md) 하나에서 시작합니다. 모든 문서를 미리 읽지 않고
작업에 필요한 활성 문서만 추가로 읽습니다.

## 활성 문서

| 문서 | 역할 |
| --- | --- |
| [`CURRENT_PROJECT.md`](CURRENT_PROJECT.md) | 현재 버전, 게임 공개 계획, 패키지·Functions 기준 |
| [`ENGINEERING_CONTRACT.md`](engineering/ENGINEERING_CONTRACT.md) | 완료 조건, 작업 트리 보호, 승인 경계 |
| [`ARCHITECTURE.md`](engineering/ARCHITECTURE.md) | 앱·게임·서버·데이터 책임과 패키지 구조 |
| [`PROJECT_CLI.md`](engineering/PROJECT_CLI.md) | 검증 명령, 플랫폼 실행 경로, exit code |
| [`CLOUD_FUNCTIONS.md`](engineering/CLOUD_FUNCTIONS.md) | 현재 Functions source inventory와 배포 경계 |
| [`NEW_GAME_GUIDE.md`](engineering/NEW_GAME_GUIDE.md) | 새 게임의 패키지·서버·카탈로그·검증 순서 |
| [`DEVELOPMENT_GUIDE.md`](development/DEVELOPMENT_GUIDE.md) | 개발환경, TEST·local 실행, dependency 준비 |
| [`TEST_AND_RELEASE_GUIDE.md`](operations/TEST_AND_RELEASE_GUIDE.md) | TEST 실기기 검증과 스토어·운영 배포 절차 |
| [`PUSH_NOTIFICATION_RELEASE_GUIDE.md`](operations/PUSH_NOTIFICATION_RELEASE_GUIDE.md) | TEST·운영 푸시 설정, 콘솔 등록과 제한 배포 절차 |
| [`TASKS.md`](planning/TASKS.md) | 현재 작업 상태와 다음 행동 |

## 작업 상세과 과거 증거

다음 자료는 삭제하지 않지만 기본 개발 문맥이 아닙니다.

- `planning/tasks/`: 작업별 완료 조건과 아직 남은 범위
- `planning/logs/`: 날짜별 실행·검증 기록
- 날짜가 붙은 `planning/*.md`: 과거 설계·통합·인수인계
- 날짜가 붙은 `operations/*.md`: 과거 실기기·성능·배포 증거
- `COMPLETED_TASKS.md`: 완료 판정과 당시 한계

과거 문서의 버전, 함수 수, 게임 수, 브랜치와 검증 결과를 현재 상태로 재사용하지 않습니다.
현재 문서가 근거로 연결했을 때만 해당 기록을 확인합니다.

## 참고 자료

- [`GAME_KIT_ADOPTION.md`](engineering/GAME_KIT_ADOPTION.md): 공용 게임 기반의 세부 채택 규칙
- [`PACKAGE_MIGRATION.md`](engineering/PACKAGE_MIGRATION.md): 패키지 전환의 과거 결정과 현재 번들 정책 근거
- [`NETWORK_SESSION_CONTRACT.md`](engineering/NETWORK_SESSION_CONTRACT.md): 인증·세션 상태 전이 변경 시 필요한 상세 계약
- [`FIREBASE_MCP.md`](operations/FIREBASE_MCP.md): 승인된 production RTDB 단일 경로 읽기
- [`FIREBASE_SERVER_LOGS.md`](operations/FIREBASE_SERVER_LOGS.md): 승인 범위의 정제된 서버 로그 읽기
- [`MOSIGAME_SYSTEM_MAP.html`](engineering/MOSIGAME_SYSTEM_MAP.html): 시각적 개발자 운영 Map.
  `jinsung`에서 직접 작업할 때 현재 코드로 갱신

## 더 이상 현재 기준으로 사용하지 않는 자료

- `GAME_PACKAGE_FILE_REFERENCE.md`: 2026-09 시점 자동 추출본으로 현재 패키지와 링크가 다름
- `cloud-functions.tsv`: 과거 67개 목록으로 현재 `functions/src/index.ts`와 다름
- `GAME_CODE_REVIEW_GUIDE.md`: 과거 세 게임 중심 리뷰 순서. 현재 구조는 Architecture 우선
- `STORE_RELEASE_CHECKLIST.md`: 1.0.0 출시 준비 기록. 현재 절차는 Test and release guide 우선
- `DEVELOPMENT_ENVIRONMENT_PLAN.md`: 환경 구축 과정 기록. 현재 절차는 Development guide 우선

이 파일들은 과거 의사결정과 검증 근거 보존을 위해 남깁니다. 새 작업의 source of truth로
사용하지 않습니다.
