import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/services/history_mapper.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';
import 'package:game_eleven/tablet/providers/game_stage.dart';

ElevenGameState tabletFixture(
  ElevenTabletScreen screen, {
  String? prototype,
  int elapsedMs = 0,
}) {
  final firstRoundPrototype = {
    '01_draw',
    '02_round',
    '03_timeout',
    '04_result',
    '05_result-tie',
  }.contains(prototype);
  final firstRound = prototype == null
      ? screen == ElevenTabletScreen.t04FirstChoosing
      : firstRoundPrototype;
  final round =
      prototype == '07_final11' ||
          screen == ElevenTabletScreen.t11TieDraw ||
          screen == ElevenTabletScreen.t12TieReveal ||
          screen == ElevenTabletScreen.t13bFinalTieDraw
      ? 11
      : firstRound
      ? (screen == ElevenTabletScreen.t09RoundIntro ? 2 : 1)
      : screen == ElevenTabletScreen.t09RoundIntro
      ? 6
      : screen == ElevenTabletScreen.t10EarlyEnd
      ? 10
      : 5;
  final historyCount = prototype == '07_final11'
      ? 10
      : firstRound
      ? (screen == ElevenTabletScreen.t09RoundIntro ? 1 : 0)
      : screen == ElevenTabletScreen.t09RoundIntro
      ? 5
      : screen == ElevenTabletScreen.t10EarlyEnd
      ? 9
      : screen == ElevenTabletScreen.t01DrawStart ||
            screen == ElevenTabletScreen.t02DrawSecondPick ||
            screen == ElevenTabletScreen.t03DrawReveal
      ? 0
      : 4;
  final scores = prototype == '07_final11'
      ? elapsedMs >= 1400
            ? {'a': 7, 'b': 4}
            : {'a': 6, 'b': 4}
      : firstRound
      ? prototype == '04_result' && elapsedMs >= 1400
            ? {'a': 1, 'b': 0}
            : {'a': 0, 'b': 0}
      : screen == ElevenTabletScreen.t13Final ||
            screen == ElevenTabletScreen.t10EarlyEnd
      ? {'a': 6, 'b': 2}
      : screen == ElevenTabletScreen.t11TieDraw ||
            screen == ElevenTabletScreen.t12TieReveal ||
            screen == ElevenTabletScreen.t13bFinalTieDraw
      ? {'a': 5, 'b': 5}
      : screen == ElevenTabletScreen.t07RoundWin ||
            screen == ElevenTabletScreen.t09RoundIntro
      ? {'a': 3, 'b': 1}
      : {'a': 2, 'b': 1};
  final draw = <String, Object?>{
    'purpose':
        screen == ElevenTabletScreen.t11TieDraw ||
            screen == ElevenTabletScreen.t12TieReveal ||
            screen == ElevenTabletScreen.t13bFinalTieDraw
        ? 'finalTie'
        : 'firstPlayer',
    'order':
        screen == ElevenTabletScreen.t11TieDraw ||
            screen == ElevenTabletScreen.t12TieReveal ||
            screen == ElevenTabletScreen.t13bFinalTieDraw
        ? ['b', 'a']
        : ['a', 'b'],
    'picks': switch (screen) {
      ElevenTabletScreen.t01DrawStart ||
      ElevenTabletScreen.t11TieDraw => <String, int>{},
      ElevenTabletScreen.t02DrawSecondPick => {'a': 4},
      ElevenTabletScreen.t12TieReveal ||
      ElevenTabletScreen.t13bFinalTieDraw => {'a': 8, 'b': 2},
      _ => {'a': 4, 'b': 8},
    },
    'nextPickerUid': screen == ElevenTabletScreen.t01DrawStart
        ? 'a'
        : screen == ElevenTabletScreen.t11TieDraw
        ? 'b'
        : screen == ElevenTabletScreen.t03DrawReveal ||
              screen == ElevenTabletScreen.t12TieReveal
        ? null
        : 'b',
    if (screen == ElevenTabletScreen.t03DrawReveal ||
        screen == ElevenTabletScreen.t12TieReveal)
      'revealed': screen == ElevenTabletScreen.t12TieReveal
          ? {'a': 4, 'b': 9}
          : {'a': 7, 'b': 3},
    if (screen == ElevenTabletScreen.t03DrawReveal ||
        screen == ElevenTabletScreen.t12TieReveal)
      'winnerUid': screen == ElevenTabletScreen.t12TieReveal ? 'b' : 'a',
  };
  final drawScreen = {
    ElevenTabletScreen.t01DrawStart,
    ElevenTabletScreen.t02DrawSecondPick,
    ElevenTabletScreen.t03DrawReveal,
    ElevenTabletScreen.t11TieDraw,
    ElevenTabletScreen.t12TieReveal,
  }.contains(screen);
  final resultScreen = {
    ElevenTabletScreen.t07RoundWin,
    ElevenTabletScreen.t08RoundTie,
  }.contains(screen);
  final finalScreen = {
    ElevenTabletScreen.t10EarlyEnd,
    ElevenTabletScreen.t13Final,
    ElevenTabletScreen.t13bFinalTieDraw,
  }.contains(screen);
  final phase = switch (screen) {
    ElevenTabletScreen.t01DrawStart ||
    ElevenTabletScreen.t02DrawSecondPick ||
    ElevenTabletScreen.t11TieDraw => 'drawPick',
    ElevenTabletScreen.t03DrawReveal ||
    ElevenTabletScreen.t12TieReveal => 'drawReveal',
    ElevenTabletScreen.t05SecondChoosing ||
    ElevenTabletScreen.t06AutoSubmitted => 'secondSubmit',
    ElevenTabletScreen.t07RoundWin ||
    ElevenTabletScreen.t08RoundTie => 'roundResult',
    _ => 'firstSubmit',
  };
  return ElevenGameState.initial().copyWith(
    loading: false,
    public: ElevenPublicSnapshot.fromValue({
      'status': finalScreen ? 'finished' : 'playing',
      'phase': phase,
      'revision': 5,
      'round': round,
      'players': {
        'a': {'uid': 'a', 'nickname': 'Ann', 'seatIndex': 0},
        'b': {'uid': 'b', 'nickname': 'Bo', 'seatIndex': 1},
      },
      'scores': scores,
      'firstUid': screen == ElevenTabletScreen.t11TieDraw ? 'b' : 'a',
      'secondUid': screen == ElevenTabletScreen.t11TieDraw ? 'a' : 'b',
      'turnUid':
          screen == ElevenTabletScreen.t04FirstChoosing ||
              screen == ElevenTabletScreen.t09RoundIntro
          ? 'a'
          : screen == ElevenTabletScreen.t05SecondChoosing
          ? 'b'
          : screen == ElevenTabletScreen.t11TieDraw
          ? 'b'
          : null,
      'turnDeadlineAt':
          DateTime.now().millisecondsSinceEpoch +
          (prototype == '03_timeout'
              ? (2200 - elapsedMs).clamp(0, 2200).toInt()
              : screen == ElevenTabletScreen.t05SecondChoosing
              ? 42000
              : 48000),
      'currentRound': {
        'round': round,
        'firstColor':
            screen == ElevenTabletScreen.t04FirstChoosing ||
                screen == ElevenTabletScreen.t09RoundIntro
            ? null
            : 'black',
        'secondColor':
            resultScreen || screen == ElevenTabletScreen.t06AutoSubmitted
            ? screen == ElevenTabletScreen.t06AutoSubmitted
                  ? 'black'
                  : 'white'
            : null,
        if (screen == ElevenTabletScreen.t06AutoSubmitted)
          'autoSubmitted': {'b': true},
      },
      if (drawScreen) 'draw': draw,
      if (resultScreen)
        'lastRoundResult': {
          'round': round,
          if (screen == ElevenTabletScreen.t07RoundWin) 'winnerUid': 'a',
        },
      if (finalScreen)
        'winnerUid': screen == ElevenTabletScreen.t13bFinalTieDraw ? 'b' : 'a',
      if (finalScreen) 'finishReason': 'winner',
      if (finalScreen)
        'finishDetail': screen == ElevenTabletScreen.t13bFinalTieDraw
            ? 'tieDraw'
            : 'earlyEnd',
    }),
    history: parseElevenHistory(
      [
        {
          'round': 1,
          'firstUid': 'a',
          if (prototype != '05_result-tie') 'winnerUid': 'a',
          'colors': prototype == '05_result-tie'
              ? {'a': 'black', 'b': 'black'}
              : {'a': 'black', 'b': 'white'},
        },
        {
          'round': 2,
          'firstUid': 'a',
          'winnerUid': 'b',
          'colors': {'a': 'white', 'b': 'white'},
        },
        {
          'round': 3,
          'firstUid': 'b',
          'colors': {'a': 'white', 'b': 'white'},
        },
        {
          'round': 4,
          'firstUid': 'b',
          'winnerUid': 'a',
          'colors': {'a': 'black', 'b': 'black'},
        },
        {
          'round': 5,
          'firstUid': 'a',
          'winnerUid': 'a',
          'colors': {'a': 'black', 'b': 'white'},
        },
        {
          'round': 6,
          'firstUid': 'a',
          'winnerUid': 'a',
          'colors': {'a': 'white', 'b': 'black'},
        },
        {
          'round': 7,
          'firstUid': 'a',
          'winnerUid': 'b',
          'colors': {'a': 'black', 'b': 'black'},
        },
        {
          'round': 8,
          'firstUid': 'b',
          'winnerUid': 'a',
          'colors': {'a': 'white', 'b': 'black'},
        },
        {
          'round': 9,
          'firstUid': 'a',
          'winnerUid': 'a',
          'colors': {'a': 'black', 'b': 'white'},
        },
        {
          'round': 10,
          'firstUid': 'b',
          'winnerUid': 'b',
          'colors': {'a': 'white', 'b': 'black'},
        },
        {
          'round': 11,
          'firstUid': 'a',
          'winnerUid': 'a',
          'colors': {'a': 'black', 'b': 'white'},
        },
      ].take(historyCount).toList(),
    ),
  );
}
