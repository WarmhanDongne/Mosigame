// [game_overlay.dart] 게임 중 태블릿 위에
// 규칙·설정 메뉴를 겹쳐 표시하는 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_liars_poker/tablet/widgets/rulebook.dart';
import 'package:game_kit/tablet/widgets/game_settings_dialog.dart';
import 'package:game_liars_poker/tablet/providers/game_stage.dart';
import 'package:game_kit/tablet/widgets/game_menu_overlay.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_kit/models/game_room_context.dart';

// ============================================================

/// 게임 중 사용할 규칙/설정 메뉴를 화면 위에 배치합니다.
class LiarsPokerTabletGameOverlay extends StatelessWidget {
  const LiarsPokerTabletGameOverlay({
    super.key,
    required this.provider,
    required this.stage,
    required this.tableCardValue,
    required this.onRestartGame,
    required this.onEndGame,
  });

  final GameRoomContext provider;
  final LiarsPokerTabletStage stage;

  /// 호환을 위해 유지하는 고정 "TRUTH" 선언값입니다.
  /// 새 규칙 화면에는 표시하지 않습니다.
  final String tableCardValue;
  final VoidCallback onRestartGame;
  final VoidCallback onEndGame;

  @override
  Widget build(BuildContext context) {
    // 분배·결과처럼 전체 화면 연출이 필요한 단계에서는 사이드바를 숨깁니다.
    // 카드 배분 전과 배분 중에는 숨기고, 잔여 카드 연출이 시작되는
    // roundStarting부터 함께 등장시킵니다.
    if (stage == LiarsPokerTabletStage.waiting ||
        stage == LiarsPokerTabletStage.dealing ||
        stage == LiarsPokerTabletStage.result ||
        stage == LiarsPokerTabletStage.finished) {
      return const SizedBox.expand();
    }

    final icons = Assets.games.liarsPoker.images.icons;
    return TabletGameMenuOverlay(
      visible: true,
      roleIcon: icons.iconRole.image(fit: BoxFit.contain),
      settingIcon: icons.iconSetting.image(fit: BoxFit.contain),
      roleDialogBuilder: (_) => LiarsPokerTabletRulebook(provider: provider),
      settingDialogBuilder: (_) => TabletGameSettingsDialog(
        provider: provider,
        onRestartGame: onRestartGame,
        onEndGame: onEndGame,
      ),
    );
  }
}
