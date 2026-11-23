// game_eleven.dart: ELEVEN 등록 정보와 두 기기의 board를 연결합니다.
//
// - [Package] : ELEVEN (기획명 '흑과 백 리버스')
// - [GameEntry] : 게임 패키지를 플랫폼에 연결하는 진입 계약을 구현함
//
// 계약: docs/engineering/ELEVEN_GAME_CONTRACT.md · 작업: ELEVEN-01 S4

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/recovery/widgets/critical_network_guard.dart';
import 'package:game_kit/template_game.dart';
import 'package:game_eleven/game_copy.dart';
import 'package:game_eleven/game_theme.dart';
import 'package:game_eleven/phone/phone_board.dart';
import 'package:game_eleven/shared/services/command_service.dart';
import 'package:game_eleven/shared/services/game_service.dart';
import 'package:game_eleven/tablet/tablet_board.dart';

// ============================================================

class ElevenGame extends TemplateGame {
  const ElevenGame();

  @override
  String get id => 'eleven';

  @override
  String get title => ElevenCopy.title;

  /// 정확히 2명. 서버도 다른 인원은 시작을 거절합니다(계약 1절).
  @override
  int? get fixedPlayerCount => 2;

  @override
  String get leaveFunctionName => ElevenFunctions.leaveGame;

  /// 노션 개발 계획: 휴대폰은 시안의 가로 플레이 화면(목업 비율 약 2:1).
  /// 플랫폼 대기 화면이 이 값으로 [AppOrientation.applyPhoneGame]을 호출합니다.
  @override
  PhoneGameOrientation get phoneOrientation =>
      PhoneGameOrientation.landscapeOnly;

  @override
  Color get tableColor => ElevenColors.table;

  @override
  ImageProvider? get tableBackgroundImage => null;

  @override
  Future<void> startGame(String roomCode, {Map<String, Object?>? options}) =>
      ElevenService().command.startGame(roomCode: roomCode);

  @override
  Stream<String?> watchStatus(String roomCode) => ElevenService().query
      .watchStatus(roomCode)
      .map((event) => event.snapshot.value as String?);

  @override
  Widget buildPhoneScreen({
    required String roomCode,
    required GameRoomContext provider,
    required Future<bool> Function() onExitRoom,
  }) => Builder(
    builder: (context) => CriticalNetworkGuard(
      provider: provider,
      onExit: () => Navigator.of(context).maybePop(),
      child: ElevenPhoneGame(
        roomCode: roomCode,
        provider: provider,
        onExitRoom: onExitRoom,
      ),
    ),
  );

  @override
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required GameRoomContext provider,
    required String roomCode,
  }) => Builder(
    builder: (context) => CriticalNetworkGuard(
      provider: provider,
      exitLabel: GameLocale.select(
        ko: '대기실로',
        en: 'To lobby',
        zhHans: '返回大厅',
        zhHant: '返回大廳',
      ),
      onExit: () => Navigator.of(context).maybePop(),
      child: ElevenTabletGame(roomCode: roomCode, provider: provider),
    ),
  );
}
