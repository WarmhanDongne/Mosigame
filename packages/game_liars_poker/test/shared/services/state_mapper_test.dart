import 'package:flutter_test/flutter_test.dart';
import 'package:game_liars_poker/shared/services/private_state_mapper.dart';
import 'package:game_liars_poker/shared/services/public_state_mapper.dart';

void main() {
  test('공개 플레이어와 마지막 제출 카드를 서버 값에서 변환한다', () {
    final players = parseLiarsPokerPlayers({
      'u1': {'nickname': '민호', 'seatIndex': 2, 'remainingCardCount': 3},
    });
    final lastPlay = LiarsPokerLastPlaySnapshot.fromValue({
      'playId': 'play-1',
      'playerUid': 'u1',
      'revealed': true,
      'cardCount': 2,
      'actualRanks': ['truth', 'LIE'],
    });

    expect(players['u1']?.nickname, '민호');
    expect(players['u1']?.seatIndex, 2);
    expect(lastPlay.playId, 'play-1');
    expect(lastPlay.actualCardValues, ['TRUTH', 'LIE']);
  });

  test('개인 손패는 잘못된 카드를 제외하고 같은 종류끼리 정렬한다', () {
    final hand = parseLiarsPokerHand({
      'd': {'rank': 'lie'},
      'invalid': {'id': 'x'},
      'c': {'rank': 'truth'},
      'b': {'rank': 'lie'},
      'a': {'rank': 'truth'},
    });

    expect(hand.map((card) => card.id), ['a', 'c', 'b', 'd']);
    expect(hand.map((card) => card.cardValue), [
      'TRUTH',
      'TRUTH',
      'LIE',
      'LIE',
    ]);
  });
}
