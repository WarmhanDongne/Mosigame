import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';
import 'package:game_eleven/tablet/providers/game_stage.dart';
import 'package:game_eleven/tablet/src/sound_cues.dart';

ElevenPublicSnapshot _snapshot(Map<String, Object?> value) =>
    ElevenPublicSnapshot.fromValue({
      'status': 'playing',
      'round': 1,
      'startedAt': 1000,
      'players': {
        'a': {'uid': 'a', 'nickname': 'Ann', 'seatIndex': 0},
        'b': {'uid': 'b', 'nickname': 'Bo', 'seatIndex': 1},
      },
      ...value,
    });

Map<String, Object?> _draw(Map<String, int> picks) => {
  'purpose': 'firstPlayer',
  'order': ['a', 'b'],
  'picks': picks,
  'nextPickerUid': picks.isEmpty ? 'a' : 'b',
};

List<ElevenTabletSoundCue> _cues(
  ElevenPublicSnapshot? previous,
  ElevenPublicSnapshot next,
  ElevenTabletStage stage,
) => resolveElevenTabletSoundCues(previous: previous, next: next, stage: stage);

void main() {
  final freshDraw = _snapshot({'phase': 'drawPick', 'draw': _draw({})});

  test('a freshly started game plays the intro once', () {
    expect(_cues(null, freshDraw, ElevenTabletStage.firstDrawPick), [
      ElevenTabletSoundCue.intro,
    ]);
    expect(
      _cues(freshDraw, freshDraw, ElevenTabletStage.firstDrawPick),
      isEmpty,
    );
  });

  test('joining a game already in progress stays silent', () {
    final midRound = _snapshot({
      'phase': 'secondSubmit',
      'round': 4,
      'currentRound': {'round': 4, 'firstColor': 'black'},
    });
    expect(_cues(null, midRound, ElevenTabletStage.secondSubmit), isEmpty);
  });

  test('restarting (new startedAt) plays the intro again', () {
    final finished = _snapshot({'status': 'finished', 'phase': 'finished'});
    final restarted = _snapshot({
      'phase': 'drawPick',
      'startedAt': 2000,
      'draw': _draw({}),
    });
    expect(_cues(finished, restarted, ElevenTabletStage.firstDrawPick), [
      ElevenTabletSoundCue.intro,
    ]);
  });

  test('a draw pick places a tile', () {
    final picked = _snapshot({
      'phase': 'drawPick',
      'draw': _draw({'a': 3}),
    });
    expect(_cues(freshDraw, picked, ElevenTabletStage.firstDrawPick), [
      ElevenTabletSoundCue.place,
    ]);
  });

  test('first and second submissions place a tile', () {
    final waiting = _snapshot({
      'phase': 'firstSubmit',
      'currentRound': {'round': 1},
    });
    final first = _snapshot({
      'phase': 'secondSubmit',
      'currentRound': {'round': 1, 'firstColor': 'black'},
    });
    final second = _snapshot({
      'phase': 'roundResult',
      'currentRound': {
        'round': 1,
        'firstColor': 'black',
        'secondColor': 'white',
      },
    });
    expect(_cues(waiting, first, ElevenTabletStage.secondSubmit), [
      ElevenTabletSoundCue.place,
    ]);
    expect(_cues(first, second, ElevenTabletStage.roundResult), [
      ElevenTabletSoundCue.place,
    ]);
  });

  test('moving to a new round does not place a tile', () {
    final result = _snapshot({
      'phase': 'roundResult',
      'currentRound': {
        'round': 1,
        'firstColor': 'black',
        'secondColor': 'white',
      },
    });
    final nextRound = _snapshot({
      'phase': 'firstSubmit',
      'round': 2,
      'currentRound': {'round': 2},
    });
    expect(_cues(result, nextRound, ElevenTabletStage.firstSubmit), isEmpty);
  });
}
