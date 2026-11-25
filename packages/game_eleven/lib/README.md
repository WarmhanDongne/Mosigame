# ELEVEN 수정 위치

계약: [ELEVEN 게임 계약](../../../docs/engineering/ELEVEN_GAME_CONTRACT.md) ·
작업: [ELEVEN-01](../../../docs/planning/tasks/ELEVEN-01.md#eleven-01)

S4 앱 골격이다. 모든 서버 phase가 실제 화면 단계로 연결되어 있지만, 시각 디자인
(캔버스 T01–T13, P01–P11)·에셋은 아직 반영하지 않았다. 소리는 #221에서 태블릿에 반영했다.

- 게임 등록·기기 연결: `game_eleven.dart`
- 휴대폰 단계(P01–P11) 번역: `phone/providers/game_stage.dart`
- 휴대폰 화면·제출·예비 시간 초과: `phone/phone_board.dart`, `phone/src/board_state.dart`
- 태블릿 단계(T01–T13) 번역: `tablet/providers/game_stage.dart`
- 태블릿 화면·뽑기·`complete_phase`·`timeout_turn`: `tablet/tablet_board.dart`, `tablet/src/board_state.dart`
- 공개·개인·controller 기록 파서: `shared/services/*_mapper.dart`
- 서버 명령/조회: `shared/services/command_service.dart`, `query_service.dart`
- 연출 시간(계약 6절): `shared/models/timing.dart`
- 문구: `game_copy.dart` (zh 문구는 S7에서 확정)
- 소리(태블릿만): 경로 `game_sounds.dart`, 시점 판정 `tablet/src/sound_cues.dart`, 재생·BGM `tablet/src/board_state.dart`,
  음원 `assets/games/eleven/sounds/`(m4a, 새 음원은 Shorebird 패치로 전달되지 않음)

판정·점수·승패는 서버(`functions/src/eleven/`)가 정한다. 휴대폰은 본인 개인 상태만,
태블릿은 공개 상태와 `game/controller/history`만 구독한다.
