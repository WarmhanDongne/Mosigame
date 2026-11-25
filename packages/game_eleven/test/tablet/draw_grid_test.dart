// 레인 B 소유: S4 뽑기판 위젯 테스트(test/widgets_test.dart에서 옮김). 위젯을 바꾸면 함께 고친다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';
import 'package:game_eleven/shared/widgets/noir_tile.dart';
import 'package:game_eleven/tablet/widgets/draw_grid.dart';

Widget _host(Widget child, {double width = 360}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  testWidgets(
    'draw grid blocks taken slots and shows numbers only after reveal',
    (tester) async {
      final picks = <int>[];
      const draw = ElevenDrawView(
        purpose: ElevenDrawPurpose.firstPlayer,
        order: ['a', 'b'],
        picks: {'a': 2},
        nextPickerUid: 'b',
      );
      await tester.pumpWidget(
        _host(
          ElevenDrawGrid(
            draw: draw,
            nicknameOf: (uid) => uid == 'a' ? 'Ann' : 'Bo',
            seatByUid: const {'a': 0, 'b': 1},
            enabled: true,
            onPick: picks.add,
          ),
          width: 900,
        ),
      );
      expect(find.text('A'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('eleven-draw-slot-2')));
      await tester.tap(find.byKey(const ValueKey('eleven-draw-slot-5')));
      expect(picks, [5]);
      // 공개 전에는 숫자가 없습니다.
      for (final value in [1, 2, 3, 4, 5, 6, 7, 8, 9]) {
        expect(find.text('$value'), findsNothing);
      }

      const revealed = ElevenDrawView(
        purpose: ElevenDrawPurpose.firstPlayer,
        order: ['a', 'b'],
        picks: {'a': 2, 'b': 5},
        nextPickerUid: null,
        revealed: {'a': 1, 'b': 9},
        winnerUid: 'b',
      );
      await tester.pumpWidget(
        _host(
          ElevenDrawGrid(
            draw: revealed,
            nicknameOf: (uid) => uid == 'a' ? 'Ann' : 'Bo',
            seatByUid: const {'a': 0, 'b': 1},
            enabled: false,
            onPick: picks.add,
          ),
          width: 900,
        ),
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('draw order does not change A and B seat orientation', (
    tester,
  ) async {
    const draw = ElevenDrawView(
      purpose: ElevenDrawPurpose.finalTie,
      order: ['b', 'a'],
      picks: {'a': 2, 'b': 5},
      nextPickerUid: null,
      revealed: {'a': 1, 'b': 9},
      winnerUid: 'b',
    );
    await tester.pumpWidget(
      _host(
        ElevenDrawGrid(
          draw: draw,
          nicknameOf: (uid) => uid,
          seatByUid: const {'a': 0, 'b': 1},
          enabled: false,
          onPick: (_) {},
        ),
        width: 900,
      ),
    );
    final aTile = find.descendant(
      of: find.byKey(const ValueKey('eleven-draw-slot-2')),
      matching: find.byType(ElevenNoirTile),
    );
    final bTile = find.descendant(
      of: find.byKey(const ValueKey('eleven-draw-slot-5')),
      matching: find.byType(ElevenNoirTile),
    );
    expect(tester.widget<ElevenNoirTile>(aTile).numberQuarterTurns, 1);
    expect(tester.widget<ElevenNoirTile>(bTile).numberQuarterTurns, 3);
    expect(tester.widget<ElevenNoirTile>(aTile).state, ElevenTileState.normal);
    expect(tester.widget<ElevenNoirTile>(bTile).state, ElevenTileState.picked);
  });
}
