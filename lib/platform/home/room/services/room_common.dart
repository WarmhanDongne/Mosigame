export 'package:project00/platform/home/room/models/room_data.dart';
export 'package:project00/platform/home/room/models/room_device.dart';
export 'package:project00/platform/home/room/models/room_player.dart';
export 'package:game_kit/core/error/room_command_exception.dart';

abstract final class RoomLimits {
  static const int defaultMaxPlayers = 8;
}

/// 로컬에 저장된 플레이어 세션으로 무엇을 복원할 수 있는지입니다.
///
/// `bool`이 아니라 종류를 돌려주는 이유: 진행 중 게임은 자동 복귀하고 대기실은
/// 복귀 여부를 물어야 하므로, 화면이 두 흐름을 구분해야 합니다.
enum RestorableSession {
  /// 복원할 것이 없습니다. 저장 세션을 지워야 합니다.
  none,

  /// 대기실로 돌아갈 수 있습니다.
  waitingRoom,

  /// 진행 중인 게임으로 돌아갈 수 있습니다.
  activeGame,
}

/// 로컬에 저장된 플레이어 세션을 복원해도 되는 서버 상태인지 판정합니다.
///
/// 단순히 플레이어 노드가 남아 있다는 이유만으로 복원하면 종료된 게임의 잔여
/// 데이터에 계속 재진입할 수 있습니다. 대기실은 활성 플레이어와 대기 상태를,
/// 진행 중 게임은 선택된 게임 ID와 실제 public playing 상태를 모두 요구합니다.
RestorableSession restorablePlayerSession({
  required bool playerExists,
  required String? playerStatus,
  required String? roomStatus,
  required String? selectedGameId,
  required String? gameStatus,
  required bool privateGameDataExists,
}) {
  // 초기 스키마의 참가자 노드는 status가 없습니다. 서버 join 정책과 RoomPlayer
  // 모델처럼 누락은 active로 호환하되, 명시적인 inactive 값은 복원을 막습니다.
  if (!playerExists || (playerStatus != null && playerStatus != 'active')) {
    return RestorableSession.none;
  }
  if (roomStatus == 'closed' || roomStatus == 'finished') {
    return RestorableSession.none;
  }

  // 방 상태가 다시 waiting/seating으로 전환됐다면 이전 게임의 finished 데이터는
  // 낡은 잔여값입니다. 방의 권위 상태를 우선해 기존 참가자 복구를 허용합니다.
  if (roomStatus == 'waiting' || roomStatus == 'seating') {
    return RestorableSession.waitingRoom;
  }

  if (gameStatus == 'playing') {
    final canRestoreGame =
        selectedGameId != null &&
        selectedGameId.trim().isNotEmpty &&
        privateGameDataExists;
    return canRestoreGame
        ? RestorableSession.activeGame
        : RestorableSession.none;
  }

  return RestorableSession.none;
}
