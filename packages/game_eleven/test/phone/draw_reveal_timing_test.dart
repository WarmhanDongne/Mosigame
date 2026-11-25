// 하준 실기기 확인(2026-11-25): 뽑기 결과는 태블릿이 카드를 뒤집기 전에 휴대폰에 먼저 보이면 안 된다.
import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/phone/providers/game_stage.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';

ElevenGameState _game(String purpose) => ElevenGameState.initial().copyWith(
  loading: false,
  public: ElevenPublicSnapshot.fromValue({
    'status': 'playing',
    'phase': 'drawReveal',
    'round': purpose == 'finalTie' ? 11 : 1,
    'draw': {
      'purpose': purpose,
      'order': ['a', 'b'],
      'picks': {'a': 0, 'b': 8},
      'revealed': {'a': 7, 'b': 3},
      'winnerUid': 'a',
    },
  }),
);

void main() {
  test('first-player draw result waits for the tablet flip', () {
    final game = _game('firstPlayer');
    for (final uid in ['a', 'b']) {
      expect(
        resolveElevenPhoneScreen(game, uid: uid, drawResultRevealed: false),
        ElevenPhoneScreen.g3DrawPicked,
      );
    }
    expect(
      resolveElevenPhoneScreen(game, uid: 'a'),
      ElevenPhoneScreen.g4DrawResultFirst,
    );
    expect(
      resolveElevenPhoneScreen(game, uid: 'b'),
      ElevenPhoneScreen.g5DrawResultSecond,
    );
  });

  test('final tie draw keeps G8 until the flip, then game end', () {
    final game = _game('finalTie');
    expect(
      resolveElevenPhoneScreen(game, uid: 'a', drawResultRevealed: false),
      ElevenPhoneScreen.g8TieDraw,
    );
    expect(
      resolveElevenPhoneScreen(game, uid: 'a'),
      ElevenPhoneScreen.p10Winner,
    );
  });
}
