// 휴대폰 phase → 시안 화면 ID(P01–P11, G1–G8) 순수 함수 검사(S5-0b 6).
import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/phone/providers/game_stage.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/services/private_state_mapper.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';

ElevenGameState _game(
  Map<String, Object?> public, {
  Map<String, Object?>? private,
}) => ElevenGameState.initial().copyWith(
  loading: false,
  public: ElevenPublicSnapshot.fromValue({
    'status': 'playing',
    'round': 5,
    'firstUid': 'a',
    'secondUid': 'b',
    ...public,
  }),
  private: ElevenPrivateSnapshot.fromValue(
    private ??
        {
          'tiles': [0, 1, 2, 3],
        },
  ),
);

ElevenPhoneScreen _screen(
  Map<String, Object?> public, {
  String uid = 'a',
  Map<String, Object?>? private,
  int? local,
  bool roundResultRevealed = true,
  bool gameEndRevealed = true,
}) => resolveElevenPhoneScreen(
  _game(public, private: private),
  uid: uid,
  locallySubmittedRound: local,
  roundResultRevealed: roundResultRevealed,
  gameEndRevealed: gameEndRevealed,
);

Map<String, Object?> _draw(
  String purpose, {
  Map<String, int> picks = const {},
  String? next = 'a',
  String? winner,
}) => {
  'purpose': purpose,
  'order': ['a', 'b'],
  'picks': picks,
  'nextPickerUid': ?next,
  if (winner != null) 'revealed': {'a': 7, 'b': 3},
  'winnerUid': ?winner,
};

void main() {
  test('every screen id is unique and covers P01–P11, G1–G8', () {
    final ids = [for (final s in ElevenPhoneScreen.values) ?s.id];
    expect(ids.toSet().length, ids.length);
    expect(ids.toSet(), {
      for (var i = 1; i <= 11; i++) 'P${i.toString().padLeft(2, '0')}',
      for (var i = 1; i <= 8; i++) 'G$i',
    });
  });

  test('loading and no-winner finish have no screen', () {
    expect(
      resolveElevenPhoneScreen(ElevenGameState.initial(), uid: 'a'),
      ElevenPhoneScreen.connecting,
    );
    expect(
      _screen({'status': 'finished', 'finishReason': 'manual'}),
      ElevenPhoneScreen.closing,
    );
  });

  group('first player draw', () {
    test('P01 when draw data has not arrived', () {
      expect(_screen({'phase': 'drawPick'}), ElevenPhoneScreen.p01DrawWait);
    });

    test('G1 my turn, G2 other picks first, G3 picked and waiting', () {
      final first = {'phase': 'drawPick', 'draw': _draw('firstPlayer')};
      expect(_screen(first), ElevenPhoneScreen.g1DrawMyTurn);
      expect(_screen(first, uid: 'b'), ElevenPhoneScreen.g2DrawOtherFirst);
      final afterA = {
        'phase': 'drawPick',
        'draw': _draw('firstPlayer', picks: {'a': 4}, next: 'b'),
      };
      expect(_screen(afterA), ElevenPhoneScreen.g3DrawPicked);
      expect(_screen(afterA, uid: 'b'), ElevenPhoneScreen.g1DrawMyTurn);
    });

    test('G4 / G5 after reveal by draw winner', () {
      final reveal = {
        'phase': 'drawReveal',
        'draw': _draw(
          'firstPlayer',
          picks: {'a': 4, 'b': 8},
          next: null,
          winner: 'a',
        ),
      };
      expect(_screen(reveal), ElevenPhoneScreen.g4DrawResultFirst);
      expect(_screen(reveal, uid: 'b'), ElevenPhoneScreen.g5DrawResultSecond);
    });
  });

  group('final tie draw', () {
    test('G8 while picking, game end right after reveal (prototype 8)', () {
      final pick = {'phase': 'drawPick', 'draw': _draw('finalTie', next: 'b')};
      expect(_screen(pick), ElevenPhoneScreen.g8TieDraw);
      expect(_screen(pick, uid: 'b'), ElevenPhoneScreen.g8TieDraw);
      final reveal = {
        'phase': 'drawReveal',
        'draw': _draw(
          'finalTie',
          picks: {'a': 0, 'b': 8},
          next: null,
          winner: 'b',
        ),
      };
      expect(_screen(reveal), ElevenPhoneScreen.p11Loser);
      expect(_screen(reveal, uid: 'b'), ElevenPhoneScreen.p10Winner);
    });
  });

  group('round', () {
    test('P02 first choosing, P03 second preselect', () {
      expect(
        _screen({'phase': 'firstSubmit'}),
        ElevenPhoneScreen.p02FirstChoosing,
      );
      expect(
        _screen({'phase': 'firstSubmit'}, uid: 'b'),
        ElevenPhoneScreen.p03SecondPreselect,
      );
    });

    test('P04 first submitted, P05 second choosing, P07 second submitted', () {
      final second = {'phase': 'secondSubmit'};
      expect(
        _screen(
          second,
          private: {
            'tiles': [0, 1],
            'submission': {'round': 5, 'value': 2, 'auto': false},
          },
        ),
        ElevenPhoneScreen.p04FirstSubmitted,
      );
      expect(_screen(second, uid: 'b'), ElevenPhoneScreen.p05SecondChoosing);
      expect(
        _screen(second, uid: 'b', local: 5),
        ElevenPhoneScreen.p07SecondSubmitted,
      );
    });

    test('P06 when my submission was automatic', () {
      final auto = {
        'tiles': [1, 2],
        'submission': {'round': 5, 'value': 0, 'auto': true},
      };
      expect(
        _screen({'phase': 'secondSubmit'}, private: auto),
        ElevenPhoneScreen.p06AutoSubmitted,
      );
      expect(
        _screen({'phase': 'secondSubmit'}, uid: 'b', private: auto),
        ElevenPhoneScreen.p06AutoSubmitted,
      );
    });

    test('P09 only when the last tile can be submitted', () {
      final one = {
        'tiles': [11],
      };
      expect(
        _screen({'phase': 'firstSubmit', 'round': 11}, private: one),
        ElevenPhoneScreen.p09LastTile,
      );
      expect(
        _screen({'phase': 'secondSubmit', 'round': 11}, uid: 'b', private: one),
        ElevenPhoneScreen.p09LastTile,
      );
      // 후공 미리 선택은 제출할 수 없으므로 P03.
      expect(
        _screen({'phase': 'firstSubmit', 'round': 11}, uid: 'b', private: one),
        ElevenPhoneScreen.p03SecondPreselect,
      );
    });

    test('G6 before the result is revealed, P08 after (prototype 4)', () {
      final result = {
        'phase': 'roundResult',
        'lastRoundResult': {'round': 5, 'winnerUid': 'a'},
      };
      expect(_screen(result), ElevenPhoneScreen.p08RoundResult);
      expect(
        _screen(result, roundResultRevealed: false),
        ElevenPhoneScreen.g6RoundResultWait,
      );
      // 지난 라운드 결과만 있으면 아직 공개 전이다.
      expect(
        _screen({
          'phase': 'roundResult',
          'lastRoundResult': {'round': 4, 'winnerUid': 'a'},
        }),
        ElevenPhoneScreen.g6RoundResultWait,
      );
      // 동점(winnerUid 없음)도 P08이다.
      expect(
        _screen({
          'phase': 'roundResult',
          'lastRoundResult': {'round': 5},
        }),
        ElevenPhoneScreen.p08RoundResult,
      );
    });
  });

  group('game end', () {
    Map<String, Object?> finished(String detail, String winner) => {
      'status': 'finished',
      'phase': 'finished',
      'winnerUid': winner,
      'finishReason': 'winner',
      'finishDetail': detail,
    };

    test('P10 winner, P11 loser for every finish detail', () {
      for (final detail in ['earlyEnd', 'allRounds', 'tieDraw']) {
        expect(_screen(finished(detail, 'a')), ElevenPhoneScreen.p10Winner);
        expect(
          _screen(finished(detail, 'a'), uid: 'b'),
          ElevenPhoneScreen.p11Loser,
        );
      }
    });

    test('G7 only for early end before the final screen (prototype 6)', () {
      expect(
        _screen(finished('earlyEnd', 'a'), gameEndRevealed: false),
        ElevenPhoneScreen.g7EarlyEnd,
      );
      expect(
        _screen(finished('allRounds', 'a'), gameEndRevealed: false),
        ElevenPhoneScreen.p10Winner,
      );
    });
  });
}
