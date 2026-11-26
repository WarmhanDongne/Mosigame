import 'package:flutter/material.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/recovery/widgets/critical_network_guard.dart';
import 'package:game_kit/shared/widgets/game_route_exit.dart';
import 'package:game_kit/template_game.dart';
import 'package:game_kit/tutorial/game_tutorial.dart';
import 'package:game_russian_roulette/src/phone.dart';
import 'package:game_russian_roulette/src/service.dart';
import 'package:game_russian_roulette/src/tablet.dart';
import 'package:game_russian_roulette/src/tutorial.dart';

class RussianRouletteGame extends TemplateGame {
  const RussianRouletteGame();

  static const _layoutChairImage = AssetImage(
    'assets/games/russian_roulette/images/layout_chair.png',
    package: 'game_russian_roulette',
  );

  /// 자리 배치(게임 진입) 화면의 원탁입니다. 디자인의 '테이블 · 의자' 원탁:
  /// 어두운 테두리에 실린더 홈 6개, 붉은 펠트, 크림 선.
  static const _layoutTableImage = AssetImage(
    'assets/games/russian_roulette/images/layout_table.png',
    package: 'game_russian_roulette',
  );

  @override
  String get id => 'russian_roulette';

  @override
  String get title => GameLocale.select(
    ko: '러시안 룰렛',
    en: 'Russian Roulette',
    zhHans: '俄罗斯轮盘',
    zhHant: '俄羅斯輪盤',
  );

  @override
  int? get fixedPlayerCount => null;

  @override
  List<int>? get supportedPlayerCounts => const [2, 3, 4, 5, 6, 7, 8];

  @override
  String get leaveFunctionName => 'game_russian_roulette_leave_game';

  @override
  PhoneGameOrientation get phoneOrientation =>
      PhoneGameOrientation.portraitOnly;

  @override
  Color get tableColor => const Color(0xFFB3201F);

  @override
  ImageProvider? get tableBackgroundImage => null;

  @override
  ImageProvider get layoutTableImage => _layoutTableImage;

  @override
  ImageProvider get layoutChairImage => _layoutChairImage;

  @override
  bool get usesDoorEntrance => true;

  @override
  GameTutorial get tutorial => const RussianRouletteTutorial();

  @override
  Future<void> startGame(String roomCode, {Map<String, Object?>? options}) =>
      RussianRouletteService().command.startGame(roomCode);

  @override
  Stream<String?> watchStatus(String roomCode) => RussianRouletteService().query
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
      onExit: () => exitGameRoute(context),
      child: RussianRoulettePhoneScreen(
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
      onExit: () => exitGameRoute(context),
      child: RussianRouletteTabletScreen(
        roomCode: roomCode,
        provider: provider,
        playerLayout: playerLayout,
      ),
    ),
  );
}
