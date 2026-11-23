import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/game_registry.dart';

void main() {
  test('registry exposes ELEVEN as a fixed 2-player game', () {
    final game = const GameRegistry().find('eleven');
    expect(game, isNotNull);
    expect(game!.supportedPlayerCounts, [2]);
    expect(game.leaveFunctionName, 'game_eleven_leave_game');
    expect(game.requiredAssetVersion, 0);
  });
}
