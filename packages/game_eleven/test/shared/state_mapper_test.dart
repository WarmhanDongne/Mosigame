import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/shared/models/tiles.dart';
import 'package:game_eleven/shared/services/history_mapper.dart';
import 'package:game_eleven/shared/services/private_state_mapper.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';

void main() {
  group('tile colors', () {
    test('black is 0,2,4,6,8,11 and white is 1,3,5,7,9 (contract 2)', () {
      expect(elevenTiles, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11]);
      expect(
        elevenTiles.where(
          (v) => ElevenTileColor.of(v) == ElevenTileColor.black,
        ),
        [0, 2, 4, 6, 8, 11],
      );
      expect(
        elevenTiles.where(
          (v) => ElevenTileColor.of(v) == ElevenTileColor.white,
        ),
        [1, 3, 5, 7, 9],
      );
    });
  });

  group('public snapshot', () {
    test('parses the server createElevenGame shape with an array order', () {
      final snapshot = ElevenPublicSnapshot.fromValue({
        'gameType': 'eleven',
        'status': 'playing',
        'phase': 'drawPick',
        'revision': 0,
        'round': 1,
        'players': {
          'b': {
            'uid': 'b',
            'nickname': 'B',
            'characterId': 'c2',
            'seatIndex': 1,
            'status': 'alive',
          },
          'a': {
            'uid': 'a',
            'nickname': 'A',
            'characterId': 'c1',
            'seatIndex': 0,
            'status': 'alive',
          },
        },
        'scores': {'a': 0, 'b': 0},
        'currentRound': {'round': 1},
        'draw': {
          'purpose': 'firstPlayer',
          'order': ['b', 'a'],
          'nextPickerUid': 'b',
        },
        'startedAt': 1000,
      });
      expect(snapshot.phase, 'drawPick');
      expect(snapshot.seatedPlayers.map((p) => p.uid), ['a', 'b']);
      expect(snapshot.draw!.purpose, ElevenDrawPurpose.firstPlayer);
      expect(snapshot.draw!.order, ['b', 'a']);
      expect(snapshot.draw!.picks, isEmpty);
      expect(snapshot.draw!.revealed, isEmpty);
      expect(snapshot.turnUid, isNull);
      expect(snapshot.startedAt, 1000);
    });

    test('reads RTDB map-shaped arrays, colors, auto flags and early end', () {
      final snapshot = ElevenPublicSnapshot.fromValue({
        'status': 'finished',
        'phase': 'finished',
        'round': 7,
        'revision': 30,
        'draw': {
          'purpose': 'finalTie',
          'order': {'1': 'a', '0': 'b'},
          'picks': {'a': 3, 'b': 9},
          'revealed': {'a': 11, 'b': 0},
          'winnerUid': 'a',
        },
        'currentRound': {
          'round': 7,
          'firstColor': 'white',
          'secondColor': 'black',
          'autoSubmitted': {'b': true},
        },
        'winnerUid': 'a',
        'finishReason': 'winner',
        'finishDetail': 'earlyEnd',
        'earlyEnd': {'remainingRounds': 4, 'leaderUid': 'a', 'gap': 5},
      });
      expect(snapshot.isFinished, isTrue);
      expect(snapshot.draw!.order, ['b', 'a']);
      expect(snapshot.draw!.isTaken(3), isTrue);
      expect(snapshot.draw!.isTaken(4), isFalse);
      expect(snapshot.currentRound.firstColor, ElevenTileColor.white);
      expect(snapshot.currentRound.secondColor, ElevenTileColor.black);
      expect(snapshot.currentRound.autoSubmitted, {'b'});
      expect(snapshot.earlyEnd!.gap, 5);
      expect(snapshot.finishDetail, 'earlyEnd');
    });

    test('equal values compare equal so the screen does not rebuild', () {
      Map<String, Object?> raw() => {
        'status': 'playing',
        'phase': 'firstSubmit',
        'round': 2,
        'revision': 5,
        'scores': {'a': 1, 'b': 0},
        'currentRound': {'round': 2, 'autoSubmitted': <String, Object?>{}},
      };
      expect(
        ElevenPublicSnapshot.fromValue(raw()),
        ElevenPublicSnapshot.fromValue(raw()),
      );
      expect(
        ElevenPublicSnapshot.fromValue(raw()).hashCode,
        ElevenPublicSnapshot.fromValue(raw()).hashCode,
      );
    });

    test('non-map values fall back to the waiting snapshot', () {
      final snapshot = ElevenPublicSnapshot.fromValue(null);
      expect(snapshot.status, 'waiting');
      expect(snapshot.draw, isNull);
    });
  });

  group('private snapshot', () {
    test('missing tiles mean no tiles left and used tiles are derived', () {
      final snapshot = ElevenPrivateSnapshot.fromValue({
        'submission': {'round': 11, 'value': 4, 'auto': false},
      });
      expect(snapshot.tiles, isEmpty);
      expect(snapshot.usedTiles, elevenTiles.toSet());
      expect(snapshot.submissionFor(11)!.value, 4);
      expect(snapshot.submissionFor(10), isNull);
    });

    test('sorts tiles, ignores invalid values and reads auto submission', () {
      final snapshot = ElevenPrivateSnapshot.fromValue({
        'tiles': [11, 3, 10, 0],
        'submission': {'round': 2, 'value': 5, 'auto': true},
      });
      expect(snapshot.tiles, [0, 3, 11]);
      expect(snapshot.submission!.auto, isTrue);
    });
  });

  group('controller history', () {
    test('keeps colors and winner only, sorted by round', () {
      final history = parseElevenHistory([
        {
          'round': 2,
          'firstUid': 'b',
          'colors': {'a': 'black', 'b': 'white'},
          'winnerUid': null,
        },
        {
          'round': 1,
          'firstUid': 'a',
          'colors': {'a': 'white', 'b': 'black'},
          'winnerUid': 'b',
          'autoSubmitted': {'a': true},
        },
        'garbage',
      ]);
      expect(history.map((e) => e.round), [1, 2]);
      expect(history.first.winnerUid, 'b');
      expect(history.first.autoSubmitted, {'a'});
      expect(history.last.isTie, isTrue);
      expect(history.last.colors['b'], ElevenTileColor.white);
    });

    test('null history (RTDB empty array) is an empty list', () {
      expect(parseElevenHistory(null), isEmpty);
    });
  });
}
