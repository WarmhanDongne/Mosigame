import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_eleven/game_eleven.dart';
import 'package:game_eleven/phone/widgets/tile_rack.dart';
import 'package:game_eleven/shared/services/command_service.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';
import 'package:game_eleven/tablet/widgets/draw_grid.dart';

Widget _host(Widget child, {double width = 360}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  test('entrypoint exposes a fixed 2-player game with server names', () {
    const game = ElevenGame();
    expect(game.id, 'eleven');
    expect(game.fixedPlayerCount, 2);
    expect(game.supportedPlayerCounts, [2]);
    expect(game.leaveFunctionName, 'game_eleven_leave_game');
    // 노션 개발 계획: 휴대폰은 시안의 가로 플레이 화면.
    expect(game.phoneOrientation, PhoneGameOrientation.landscapeOnly);
    expect(ElevenFunctions.submitTile, 'game_eleven_submit_tile');
    expect(ElevenFunctions.timeoutTurn, 'game_eleven_timeout_turn');
    expect(ElevenFunctions.completePhase, 'game_eleven_complete_phase');
    expect(ElevenFunctions.pickDrawTile, 'game_eleven_pick_draw_tile');
    expect(ElevenFunctions.startGame, 'game_eleven_start_game');
    expect(ElevenFunctions.endGame, 'game_eleven_end_game');
  });

  testWidgets('tile rack selects only remaining tiles', (tester) async {
    int? selected;
    await tester.pumpWidget(
      _host(
        ElevenTileRack(
          remaining: const [0, 3, 11],
          selected: null,
          enabled: true,
          onSelect: (value) => selected = value,
        ),
        width: 320,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('eleven-tile-5')));
    expect(selected, isNull);
    await tester.tap(find.byKey(const ValueKey('eleven-tile-11')));
    expect(selected, 11);
  });

  testWidgets('rack fits two rows in a short landscape phone area', (
    tester,
  ) async {
    // 작은 가로 휴대폰(약 640x320)의 오른쪽 손패 영역 크기입니다.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 200,
              child: Center(
                child: ElevenTileRack(
                  remaining: const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11],
                  selected: null,
                  enabled: true,
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final first = tester.getRect(find.byKey(const ValueKey('eleven-tile-0')));
    final last = tester.getRect(find.byKey(const ValueKey('eleven-tile-11')));
    expect(last.bottom - first.top, lessThanOrEqualTo(200));
  });

  testWidgets('disabled rack ignores taps', (tester) async {
    int? selected;
    await tester.pumpWidget(
      _host(
        ElevenTileRack(
          remaining: const [0, 3, 11],
          selected: 3,
          enabled: false,
          onSelect: (value) => selected = value,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('eleven-tile-0')));
    expect(selected, isNull);
  });

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
            enabled: true,
            onPick: picks.add,
          ),
          width: 900,
        ),
      );
      expect(find.text('Ann'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('eleven-draw-slot-2')));
      await tester.tap(find.byKey(const ValueKey('eleven-draw-slot-5')));
      expect(picks, [5]);
      // 공개 전에는 숫자가 없습니다.
      for (final value in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11]) {
        expect(find.text('$value'), findsNothing);
      }

      const revealed = ElevenDrawView(
        purpose: ElevenDrawPurpose.firstPlayer,
        order: ['a', 'b'],
        picks: {'a': 2, 'b': 5},
        nextPickerUid: null,
        revealed: {'a': 9, 'b': 11},
        winnerUid: 'b',
      );
      await tester.pumpWidget(
        _host(
          ElevenDrawGrid(
            draw: revealed,
            nicknameOf: (uid) => uid == 'a' ? 'Ann' : 'Bo',
            enabled: false,
            onPick: picks.add,
          ),
          width: 900,
        ),
      );
      expect(find.text('9'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
