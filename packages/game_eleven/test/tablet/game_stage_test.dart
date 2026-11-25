import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/services/history_mapper.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';
import 'package:game_eleven/tablet/providers/game_stage.dart';
import 'package:game_eleven/tablet/tablet_board.dart';

ElevenGameState _game(
  Map<String, Object?> public, {
  List<Object?> history = const [],
}) => ElevenGameState.initial().copyWith(
  loading: false,
  public: ElevenPublicSnapshot.fromValue({
    'status': 'playing',
    'round': 4,
    'firstUid': 'a',
    'secondUid': 'b',
    'players': {
      'a': {'uid': 'a', 'nickname': 'Ann', 'seatIndex': 0},
      'b': {'uid': 'b', 'nickname': 'Bo', 'seatIndex': 1},
    },
    ...public,
  }),
  history: parseElevenHistory(history),
);

Map<String, Object?> _draw(String purpose, {bool revealed = false}) => {
  'purpose': purpose,
  'order': ['a', 'b'],
  'picks': revealed ? {'a': 1, 'b': 2} : {'a': 1},
  'nextPickerUid': revealed ? null : 'b',
  if (revealed) 'revealed': {'a': 7, 'b': 3},
  if (revealed) 'winnerUid': 'a',
};

void main() {
  test('T01–T03 first player draw and T11–T12 final tie draw', () {
    expect(
      resolveElevenTabletStage(
        _game({'phase': 'drawPick', 'draw': _draw('firstPlayer')}),
      ),
      ElevenTabletStage.firstDrawPick,
    );
    expect(
      resolveElevenTabletStage(
        _game({
          'phase': 'drawReveal',
          'draw': _draw('firstPlayer', revealed: true),
        }),
      ),
      ElevenTabletStage.firstDrawReveal,
    );
    expect(
      resolveElevenTabletStage(
        _game({'phase': 'drawPick', 'draw': _draw('finalTie')}),
      ),
      ElevenTabletStage.tieDrawPick,
    );
    expect(
      resolveElevenTabletStage(
        _game({
          'phase': 'drawReveal',
          'draw': _draw('finalTie', revealed: true),
        }),
      ),
      ElevenTabletStage.tieDrawReveal,
    );
  });

  test(
    'T04/T05 submit phases have deadlines; reveal/result complete phase',
    () {
      final first = resolveElevenTabletStage(_game({'phase': 'firstSubmit'}));
      final second = resolveElevenTabletStage(_game({'phase': 'secondSubmit'}));
      final result = resolveElevenTabletStage(_game({'phase': 'roundResult'}));
      expect(first, ElevenTabletStage.firstSubmit);
      expect(second, ElevenTabletStage.secondSubmit);
      expect(result, ElevenTabletStage.roundResult);
      expect(first.hasDeadline && second.hasDeadline, isTrue);
      expect(result.hasDeadline, isFalse);
      expect(result.completesPhase, isTrue);
      expect(ElevenTabletStage.firstDrawReveal.completesPhase, isTrue);
      expect(ElevenTabletStage.firstDrawPick.completesPhase, isFalse);
    },
  );

  test(
    'T07/T08 headline uses controller history of the current round only',
    () {
      final win = _game(
        {'phase': 'roundResult'},
        history: [
          {
            'round': 4,
            'firstUid': 'a',
            'colors': {'a': 'black', 'b': 'white'},
            'winnerUid': 'b',
          },
        ],
      );
      final tie = _game(
        {'phase': 'roundResult'},
        history: [
          {
            'round': 4,
            'firstUid': 'a',
            'colors': {'a': 'black', 'b': 'black'},
            'winnerUid': null,
          },
        ],
      );
      final stale = _game(
        {'phase': 'roundResult'},
        history: [
          {'round': 3, 'firstUid': 'a', 'colors': {}, 'winnerUid': 'a'},
        ],
      );
      expect(
        elevenTabletHeadline(ElevenTabletStage.roundResult, win).$2,
        contains('Bo'),
      );
      expect(
        elevenTabletHeadline(ElevenTabletStage.roundResult, tie).$2,
        isNotEmpty,
      );
      expect(elevenTabletHeadline(ElevenTabletStage.roundResult, stale).$2, '');
    },
  );

  test('T10/T13 natural finish is result; no-winner finish is closing', () {
    final early = _game({
      'status': 'finished',
      'phase': 'finished',
      'winnerUid': 'a',
      'finishReason': 'winner',
      'finishDetail': 'earlyEnd',
      'earlyEnd': {'remainingRounds': 3, 'leaderUid': 'a', 'gap': 4},
    });
    expect(resolveElevenTabletStage(early), ElevenTabletStage.result);
    final (title, subtitle) = elevenTabletHeadline(
      ElevenTabletStage.result,
      early,
    );
    expect(title, contains('Ann'));
    expect(subtitle, isNotEmpty);
    expect(
      resolveElevenTabletStage(
        _game({
          'status': 'finished',
          'phase': 'finished',
          'finishReason': 'insufficientPlayers',
        }),
      ),
      ElevenTabletStage.closing,
    );
  });
}
