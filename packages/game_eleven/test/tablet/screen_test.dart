// 태블릿 phase → 시안 화면 ID(T01–T13, T13-B) 순수 함수 검사(S5-0b 6).
import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/services/history_mapper.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';
import 'package:game_eleven/tablet/providers/game_stage.dart';

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
    ...public,
  }),
  history: parseElevenHistory(history),
);

ElevenTabletScreen _screen(
  Map<String, Object?> public, {
  List<Object?> history = const [],
  bool roundIntroActive = false,
  bool roundResultRevealed = true,
  bool gameEndRevealed = true,
}) => resolveElevenTabletScreen(
  _game(public, history: history),
  roundIntroActive: roundIntroActive,
  roundResultRevealed: roundResultRevealed,
  gameEndRevealed: gameEndRevealed,
);

Map<String, Object?> _draw(String purpose, Map<String, int> picks) => {
  'purpose': purpose,
  'order': ['a', 'b'],
  'picks': picks,
  'nextPickerUid': picks.isEmpty ? 'a' : 'b',
};

void main() {
  test('every screen id is unique and covers T01–T13 and T13-B', () {
    final ids = [for (final s in ElevenTabletScreen.values) ?s.id];
    expect(ids.toSet().length, ids.length);
    expect(ids.toSet(), {
      for (var i = 1; i <= 13; i++) 'T${i.toString().padLeft(2, '0')}',
      'T13-B',
    });
  });

  test('T01 no picks, T02 one pick (slot 8 is valid), T03 reveal', () {
    expect(
      _screen({'phase': 'drawPick', 'draw': _draw('firstPlayer', {})}),
      ElevenTabletScreen.t01DrawStart,
    );
    expect(
      _screen({
        'phase': 'drawPick',
        'draw': _draw('firstPlayer', {'a': 8}),
      }),
      ElevenTabletScreen.t02DrawSecondPick,
    );
    expect(
      _screen({
        'phase': 'drawReveal',
        'draw': _draw('firstPlayer', {'a': 8, 'b': 0}),
      }),
      ElevenTabletScreen.t03DrawReveal,
    );
  });

  test('T11 / T12 final tie draw', () {
    expect(
      _screen({
        'phase': 'drawPick',
        'draw': _draw('finalTie', {'b': 3}),
      }),
      ElevenTabletScreen.t11TieDraw,
    );
    expect(
      _screen({
        'phase': 'drawReveal',
        'draw': _draw('finalTie', {'a': 2, 'b': 3}),
      }),
      ElevenTabletScreen.t12TieReveal,
    );
  });

  test('T04 first choosing, T09 round intro only after round 1', () {
    expect(
      _screen({'phase': 'firstSubmit'}),
      ElevenTabletScreen.t04FirstChoosing,
    );
    expect(
      _screen({'phase': 'firstSubmit'}, roundIntroActive: true),
      ElevenTabletScreen.t09RoundIntro,
    );
    expect(
      _screen({'phase': 'firstSubmit', 'round': 1}, roundIntroActive: true),
      ElevenTabletScreen.t04FirstChoosing,
    );
  });

  test('T05 second choosing, T06 when the first player timed out', () {
    expect(
      _screen({'phase': 'secondSubmit'}),
      ElevenTabletScreen.t05SecondChoosing,
    );
    expect(
      _screen({
        'phase': 'secondSubmit',
        'currentRound': {
          'round': 4,
          'autoSubmitted': {'a': true},
        },
      }),
      ElevenTabletScreen.t06AutoSubmitted,
    );
  });

  test('T07 win / T08 tie from lastRoundResult, history as fallback', () {
    expect(
      _screen({
        'phase': 'roundResult',
        'lastRoundResult': {'round': 4, 'winnerUid': 'a'},
      }),
      ElevenTabletScreen.t07RoundWin,
    );
    expect(
      _screen({
        'phase': 'roundResult',
        'lastRoundResult': {'round': 4},
      }),
      ElevenTabletScreen.t08RoundTie,
    );
    expect(
      _screen(
        {'phase': 'roundResult'},
        history: [
          {'round': 4, 'firstUid': 'a', 'winnerUid': null},
        ],
      ),
      ElevenTabletScreen.t08RoundTie,
    );
    expect(
      _screen(
        {'phase': 'roundResult'},
        history: [
          {'round': 4, 'firstUid': 'a', 'winnerUid': 'b'},
        ],
      ),
      ElevenTabletScreen.t07RoundWin,
    );
  });

  test('T06 before revealing a round that ended by timeout', () {
    final timedOut = {
      'phase': 'roundResult',
      'currentRound': {
        'round': 4,
        'autoSubmitted': {'b': true},
      },
      'lastRoundResult': {'round': 4, 'winnerUid': 'a'},
    };
    expect(
      _screen(timedOut, roundResultRevealed: false),
      ElevenTabletScreen.t06AutoSubmitted,
    );
    expect(_screen(timedOut), ElevenTabletScreen.t07RoundWin);
  });

  test('T10 early end, T13 final, T13-B tie draw final', () {
    Map<String, Object?> finished(String detail) => {
      'status': 'finished',
      'phase': 'finished',
      'winnerUid': 'a',
      'finishReason': 'winner',
      'finishDetail': detail,
    };
    expect(
      _screen(finished('earlyEnd'), gameEndRevealed: false),
      ElevenTabletScreen.t10EarlyEnd,
    );
    expect(_screen(finished('earlyEnd')), ElevenTabletScreen.t13Final);
    expect(_screen(finished('allRounds')), ElevenTabletScreen.t13Final);
    expect(
      _screen(finished('allRounds'), gameEndRevealed: false),
      ElevenTabletScreen.t13Final,
    );
    expect(_screen(finished('tieDraw')), ElevenTabletScreen.t13bFinalTieDraw);
    expect(
      _screen({'status': 'finished', 'finishReason': 'insufficientPlayers'}),
      ElevenTabletScreen.closing,
    );
  });
}
