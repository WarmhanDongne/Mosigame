import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/shared/widgets/noir_tile.dart';
import 'package:game_eleven/tablet/providers/game_stage.dart';
import 'package:game_eleven/tablet/widgets/noir_board.dart';

import 'screen_fixtures.dart';

Widget host(
  ElevenTabletScreen screen, {
  ValueChanged<int>? onPick,
  VoidCallback? onRules,
  VoidCallback? onSettings,
  VoidCallback? onRestart,
  VoidCallback? onHome,
}) => MaterialApp(
  home: Scaffold(
    body: ElevenTabletBoardView(
      game: tabletFixture(screen),
      screen: screen,
      onPick: onPick ?? (_) {},
      onRules: onRules ?? () {},
      onSettings: onSettings ?? () {},
      onRestart: onRestart ?? () {},
      onHome: onHome ?? () {},
      animate: false,
    ),
  ),
);

void main() {
  testWidgets('T01–T13 and T13-B render at tablet size', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final screen in ElevenTabletScreen.values.where((s) => s.id != null)) {
      await tester.pumpWidget(host(screen));
      expect(tester.takeException(), isNull, reason: screen.id);
    }
  });

  testWidgets(
    'draw accepts only available cards 0–8 and reveals only public numbers',
    (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final picked = <int>[];
      await tester.pumpWidget(
        host(ElevenTabletScreen.t02DrawSecondPick, onPick: picked.add),
      );
      await tester.tap(find.byKey(const ValueKey('eleven-draw-slot-4')));
      await tester.tap(find.byKey(const ValueKey('eleven-draw-slot-8')));
      expect(picked, [8]);
      expect(find.text('7'), findsNothing);
      await tester.pumpWidget(host(ElevenTabletScreen.t03DrawReveal));
      expect(find.text('7'), findsNWidgets(2));
      expect(find.text('3'), findsNWidgets(2));
    },
  );

  testWidgets(
    'history has eleven rows with win, lose and tie while hiding tile values',
    (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(host(ElevenTabletScreen.t07RoundWin));
      for (var round = 1; round <= 11; round++) {
        expect(find.byKey(ValueKey('eleven-history-$round')), findsOneWidget);
      }
      expect(find.text('◀ 승'), findsWidgets);
      expect(find.text('승 ▶'), findsOneWidget);
      expect(find.text('동점'), findsWidgets);
      expect(find.text('='), findsOneWidget);
      // The last controller history entry belongs to round 4, while the
      // displayed result belongs to round 5. It must not override the result.
      expect(find.text('승리'), findsOneWidget);
      expect(find.text('패배'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('+0'), findsNothing);
      await tester.pumpWidget(host(ElevenTabletScreen.t08RoundTie));
      expect(find.text('+0'), findsNWidgets(2));
      expect(
        find.byWidgetPredicate((w) => w is ElevenNoirTile && w.value != null),
        findsNothing,
      );
    },
  );

  testWidgets('final actions and menu buttons call their callbacks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var restart = 0;
    var home = 0;
    var rules = 0;
    var settings = 0;
    await tester.pumpWidget(
      host(
        ElevenTabletScreen.t13Final,
        onRules: () => rules++,
        onSettings: () => settings++,
        onRestart: () => restart++,
        onHome: () => home++,
      ),
    );
    await tester.tap(find.text('다시하기'));
    await tester.tap(find.text('HOME'));
    await tester.tap(find.byTooltip('게임 규칙 열기'));
    await tester.tap(find.byTooltip('게임 설정 열기'));
    expect((restart, home), (1, 1));
    expect((rules, settings), (1, 1));
    await tester.pumpWidget(host(ElevenTabletScreen.t13bFinalTieDraw));
    expect(find.text('Bo'), findsOneWidget);
    expect(find.text('승리'), findsOneWidget);
    expect(find.text('패배'), findsOneWidget);
  });
}
