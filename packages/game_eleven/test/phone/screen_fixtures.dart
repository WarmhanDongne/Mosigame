import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_eleven/phone/providers/game_stage.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/services/private_state_mapper.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';

class PhoneCase {
  const PhoneCase(
    this.id,
    this.public, {
    this.uid = 'a',
    this.private = const {},
    this.selected,
    this.countdownSeconds,
    this.resultRevealed = true,
    this.endRevealed = true,
    required this.text,
    this.canSubmit = false,
  });

  final String id;
  final Map<String, Object?> public;
  final String uid;
  final Map<String, Object?> private;
  final int? selected;
  final int? countdownSeconds;
  final bool resultRevealed;
  final bool endRevealed;
  final String text;
  final bool canSubmit;

  ElevenGameState get game => ElevenGameState.initial().copyWith(
    loading: false,
    public: ElevenPublicSnapshot.fromValue({
      'status': 'playing',
      'round': 5,
      'firstUid': 'a',
      'secondUid': 'b',
      'players': {
        'a': {
          'uid': 'a',
          'nickname': 'A',
          'seatIndex': 0,
          'characterId': 'bear',
        },
        'b': {
          'uid': 'b',
          'nickname': 'B',
          'seatIndex': 1,
          'characterId': 'bee',
        },
      },
      if (countdownSeconds != null)
        'turnDeadlineAt': ServerClock.nowMillis() + countdownSeconds! * 1000,
      ...public,
    }),
    private: ElevenPrivateSnapshot.fromValue({'tiles': <int>[], ...private}),
  );

  ElevenPhoneScreen get screen => resolveElevenPhoneScreen(
    game,
    uid: uid,
    roundResultRevealed: resultRevealed,
    gameEndRevealed: endRevealed,
  );

  ElevenPhoneStage get stage => resolveElevenPhoneStage(game, uid: uid);
}

const _drawPick = {
  'purpose': 'firstPlayer',
  'order': ['a', 'b'],
  'picks': <String, int>{},
  'nextPickerUid': 'a',
};

const _drawReveal = {
  'purpose': 'firstPlayer',
  'order': ['a', 'b'],
  'picks': {'a': 2, 'b': 4},
  'revealed': {'a': 7, 'b': 3},
  'winnerUid': 'a',
};

const phoneCases = <PhoneCase>[
  PhoneCase('P01', {'phase': 'drawPick'}, text: '태블릿에서 카드를 뽑아요'),
  PhoneCase(
    'P02',
    {
      'phase': 'firstSubmit',
      'scores': {'a': 2, 'b': 1},
    },
    private: {
      'tiles': [0, 2, 6, 11, 5, 7, 9],
    },
    selected: 6,
    countdownSeconds: 42,
    text: '타일을 고르고 제출하세요',
    canSubmit: true,
  ),
  PhoneCase(
    'P03',
    {
      'phase': 'firstSubmit',
      'scores': {'a': 2, 'b': 1},
    },
    uid: 'b',
    private: {
      'tiles': [0, 4, 6, 8, 11, 3, 7],
    },
    selected: 7,
    text: '상대가 고르는 중 · 미리 골라두세요',
  ),
  PhoneCase(
    'P04',
    {
      'phase': 'secondSubmit',
      'scores': {'a': 2, 'b': 1},
      'currentRound': {'round': 5, 'firstColor': 'black'},
    },
    private: {
      'tiles': [0, 2, 11, 5, 7, 9],
      'submission': {'round': 5, 'value': 6, 'auto': false},
    },
    text: '상대가 고르는 중이에요',
  ),
  PhoneCase(
    'P05',
    {
      'phase': 'secondSubmit',
      'scores': {'a': 2, 'b': 1},
      'currentRound': {'round': 5, 'firstColor': 'black'},
    },
    uid: 'b',
    private: {
      'tiles': [0, 4, 6, 8, 11, 3, 7],
    },
    selected: 7,
    countdownSeconds: 58,
    text: '내 차례예요 · 타일을 고르고 제출하세요',
    canSubmit: true,
  ),
  PhoneCase(
    'P06',
    {
      'phase': 'secondSubmit',
      'scores': {'a': 2, 'b': 1},
    },
    uid: 'b',
    private: {
      'tiles': [4, 6, 8, 11, 3, 7],
      'submission': {'round': 5, 'value': 0, 'auto': true},
    },
    text: '시간이 지나 타일이 자동으로 제출됐어요',
  ),
  PhoneCase(
    'P07',
    {
      'phase': 'secondSubmit',
      'scores': {'a': 2, 'b': 1},
    },
    uid: 'b',
    private: {
      'tiles': [0, 4, 6, 8, 11, 3],
      'submission': {'round': 5, 'value': 7, 'auto': false},
    },
    text: '두 사람 모두 냈어요',
  ),
  PhoneCase(
    'P08',
    {
      'phase': 'roundResult',
      'scores': {'a': 3, 'b': 1},
      'lastRoundResult': {'round': 5, 'winnerUid': 'a'},
    },
    private: {
      'tiles': [0, 2, 11, 5, 7, 9],
    },
    text: '내가 이겼어요! +1',
  ),
  PhoneCase(
    'P09',
    {
      'phase': 'firstSubmit',
      'round': 11,
      'scores': {'a': 4, 'b': 5},
    },
    private: {
      'tiles': [11],
    },
    selected: 11,
    countdownSeconds: 51,
    text: '마지막 타일이에요 · 제출 버튼을 눌러 주세요',
    canSubmit: true,
  ),
  PhoneCase('P10', {
    'status': 'finished',
    'phase': 'finished',
    'scores': {'a': 6, 'b': 2},
    'winnerUid': 'a',
    'finishReason': 'winner',
    'finishDetail': 'earlyEnd',
  }, text: 'WINNER'),
  PhoneCase(
    'P11',
    {
      'status': 'finished',
      'phase': 'finished',
      'scores': {'a': 6, 'b': 2},
      'winnerUid': 'a',
      'finishReason': 'winner',
      'finishDetail': 'earlyEnd',
    },
    uid: 'b',
    text: 'WINNER',
  ),
  PhoneCase('G1', {
    'phase': 'drawPick',
    'draw': _drawPick,
  }, text: '태블릿에서 카드를 뽑아요'),
  PhoneCase(
    'G2',
    {'phase': 'drawPick', 'draw': _drawPick},
    uid: 'b',
    text: 'A가 먼저 뽑고 있어요',
  ),
  PhoneCase('G3', {
    'phase': 'drawPick',
    'draw': {
      'purpose': 'firstPlayer',
      'order': ['a', 'b'],
      'picks': {'a': 2},
      'nextPickerUid': 'b',
    },
  }, text: '뽑았어요'),
  PhoneCase('G4', {
    'phase': 'drawReveal',
    'draw': _drawReveal,
  }, text: '7 vs 3 · 더 큰 숫자를 뽑았어요'),
  PhoneCase(
    'G5',
    {'phase': 'drawReveal', 'draw': _drawReveal},
    uid: 'b',
    text: '3 vs 7 · A가 더 큰 숫자를 뽑았어요',
  ),
  PhoneCase(
    'G6',
    {
      'phase': 'roundResult',
      'scores': {'a': 3, 'b': 1},
      'currentRound': {
        'round': 5,
        'firstColor': 'black',
        'secondColor': 'white',
      },
      'lastRoundResult': {'round': 5, 'winnerUid': 'a'},
    },
    resultRevealed: false,
    text: '태블릿에서 결과를 확인해요',
  ),
  PhoneCase(
    'G7',
    {
      'status': 'finished',
      'phase': 'finished',
      'scores': {'a': 6, 'b': 2},
      'winnerUid': 'a',
      'finishReason': 'winner',
      'finishDetail': 'earlyEnd',
    },
    endRevealed: false,
    text: '게임이 일찍 끝났어요',
  ),
  PhoneCase('G8', {
    'phase': 'drawPick',
    'scores': {'a': 5, 'b': 5},
    'draw': {
      'purpose': 'finalTie',
      'order': ['a', 'b'],
      'picks': <String, int>{},
      'nextPickerUid': 'a',
    },
  }, text: '최종 점수가 5 : 5 동점이에요'),
];

/// P08 result variants, including a tie that preserves B as the next first player.
PhoneCase p08Variant(String variant) {
  assert(variant == 'lose' || variant == 'tie' || variant == 'second');
  final base = phoneCases.firstWhere((item) => item.id == 'P08');
  return PhoneCase(
    'P08',
    {
      ...base.public,
      if (variant == 'second') ...{'firstUid': 'b', 'secondUid': 'a'},
      'lastRoundResult': {'round': 5, if (variant == 'lose') 'winnerUid': 'b'},
    },
    private: base.private,
    text: '',
  );
}

/// Prototype ② starts at round one with the full, unused hand on both phones.
PhoneCase roundMotionCase(int milliseconds) {
  final secondTurn = milliseconds >= 2900;
  return PhoneCase(
    secondTurn ? 'P05' : 'P02',
    {
      'phase': secondTurn ? 'secondSubmit' : 'firstSubmit',
      'round': 1,
      'turnUid': secondTurn ? 'b' : 'a',
      'scores': {'a': 0, 'b': 0},
      if (secondTurn) 'currentRound': {'round': 1, 'firstColor': 'black'},
    },
    uid: secondTurn ? 'b' : 'a',
    private: {
      'tiles': [0, 2, 4, 6, 8, 11, 1, 3, 5, 7, 9],
    },
    selected: secondTurn ? 7 : null,
    countdownSeconds: secondTurn ? 58 : 42,
    text: secondTurn ? '내 차례예요 · 타일을 고르고 제출하세요' : '타일을 고르고 제출하세요',
    canSubmit: secondTurn,
  );
}
