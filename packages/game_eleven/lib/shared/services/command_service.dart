// [command_service.dart] 는 ELEVEN 서버 명령(callable)을 모아 둔 파일이다.
//
// - [Package] : ELEVEN
// - [Command] : functions/src/eleven/callables.ts의 명령과 1:1 대응
//
// callable 이름은 배포 후 public API다. 서버와 정확히 같게 유지한다.
// `role`·`controllerSessionId`·방 세션 식별자는 GameCommandService가 붙인다.

// ========================[ import ]==========================
import 'package:game_kit/services/game_command_service.dart';

// ============================================================

abstract final class ElevenFunctions {
  static const startGame = 'game_eleven_start_game';
  static const pickDrawTile = 'game_eleven_pick_draw_tile';
  static const submitTile = 'game_eleven_submit_tile';
  static const timeoutTurn = 'game_eleven_timeout_turn';
  static const completePhase = 'game_eleven_complete_phase';
  static const endGame = 'game_eleven_end_game';
  static const leaveGame = 'game_eleven_leave_game';
}

class ElevenCommandService extends GameCommandService {
  ElevenCommandService({super.functions, super.retryPolicy});

  /// 태블릿 진입 때 진행 명령을, 휴대폰 진입 때 제출 명령을 미리 깨웁니다.
  Future<void> warmUpControllerCommands() => warmUpCommands(const [
    ElevenFunctions.pickDrawTile,
    ElevenFunctions.completePhase,
    ElevenFunctions.timeoutTurn,
  ]);

  Future<void> warmUpPlayerCommands() =>
      warmUpCommands(const [ElevenFunctions.submitTile]);

  Future<Map<String, dynamic>> startGame({
    required String roomCode,
    bool restart = false,
  }) => invoke(ElevenFunctions.startGame, {
    'roomCode': roomCode,
    'commandId': commandId('start'),
    if (restart) 'restart': true,
  });

  /// 태블릿 공용 뽑기. 서버는 순서(`nextPickerUid`)와 중복 위치만 검증합니다.
  Future<Map<String, dynamic>> pickDrawTile({
    required String roomCode,
    required String pickerUid,
    required int slotIndex,
  }) => invoke(ElevenFunctions.pickDrawTile, {
    'roomCode': roomCode,
    'pickerUid': pickerUid,
    'slotIndex': slotIndex,
    'commandId': commandId('pick'),
  }, retryTransientFailure: true);

  /// 휴대폰 본인 제출. 응답에는 성공 여부와 revision만 있습니다.
  Future<Map<String, dynamic>> submitTile({
    required String roomCode,
    required int round,
    required int value,
  }) => invoke(ElevenFunctions.submitTile, {
    'roomCode': roomCode,
    'round': round,
    'value': value,
    'commandId': commandId('submit'),
  }, retryTransientFailure: true);

  /// 태블릿(주)과 두 휴대폰(예비)이 마감 뒤 호출합니다. 첫 요청만 반영됩니다.
  Future<Map<String, dynamic>> timeoutTurn({
    required String roomCode,
    required int round,
    required String phase,
  }) => invoke(ElevenFunctions.timeoutTurn, {
    'roomCode': roomCode,
    'round': round,
    'phase': phase,
    'commandId': commandId('timeout'),
  }, retryTransientFailure: true);

  /// 태블릿이 공개·결과 연출을 끝낸 뒤 호출합니다.
  Future<Map<String, dynamic>> completePhase({
    required String roomCode,
    required int revision,
  }) => invoke(ElevenFunctions.completePhase, {
    'roomCode': roomCode,
    'revision': revision,
    'commandId': commandId('phase'),
  }, retryTransientFailure: true);

  Future<Map<String, dynamic>> endGame({required String roomCode}) => invoke(
    ElevenFunctions.endGame,
    {'roomCode': roomCode, 'commandId': commandId('end')},
    retryTransientFailure: true,
  );
}
