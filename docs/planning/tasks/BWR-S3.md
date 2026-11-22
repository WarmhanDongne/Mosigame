# BWR-S3

서버 상태 전이·명령

[작업 목록](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md) · [노션 단계별 계획](https://app.notion.com/p/42009716f87e8146b627c41eb0d45e21) · [GitHub Issue #201](https://github.com/WarmhanDongne/Mosigame/issues/201)

## 범위와 선행 조건

S1 승인 계약으로 시작·뽑기·제출·timeout·다음 단계·종료 명령과 권한, transaction, commandId, revision, 복구 adapter, rules를 구현한다.

## 완료 조건과 검증

에뮬레이터에서 권한·중복 명령·시간 초과 경합·비공개 경계·재접속, Functions lint/build를 검증한다. 이 단계에서 배포하지 않는다.

2026-11-23 등록. 현재 분류·상태·다음 행동은 [TASKS.md](../TASKS.md)에서만 관리한다. 착수 시 실제 코드와 노션의 최신 결정을 대조하고 구현 근거·실행 명령·exit code를 이 파일과 [인계 문서](../BLACK_WHITE_REVERSE_HANDOFF.md)에 추가한다.
