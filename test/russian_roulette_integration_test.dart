import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/games/game_registry.dart';
import 'package:project00/platform/home/tablet/widgets/detail/game_detail_previews.dart';

void main() {
  test('registry exposes Russian Roulette as a 2-8 player game', () {
    final game = const GameRegistry().find('russian_roulette');
    expect(game, isNotNull);
    expect(game!.supportedPlayerCounts, [2, 3, 4, 5, 6, 7, 8]);
    expect(game.leaveFunctionName, 'game_russian_roulette_leave_game');
  });

  test(
    'detail subtitle contrasts with the red Russian Roulette background',
    () {
      final art = MosiGameArt.russianRoulette;
      expect(art.accent, const Color(0xFFECE3D0));
      expect(art.accent, isNot(art.shelfTheme.ground));
    },
  );

  testWidgets('catalog preview and component board render', (tester) async {
    final preview = buildGamePlayPreview('russian_roulette');
    final parts = buildGameParts('russian_roulette', playerCount: 4);
    expect(preview, isNotNull);
    expect(parts, isNotNull);

    await tester.pumpWidget(
      MaterialApp(home: SizedBox(width: 694, height: 560, child: preview)),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(home: SizedBox(width: 694, height: 560, child: parts)),
    );
    expect(tester.takeException(), isNull);
  });
}
