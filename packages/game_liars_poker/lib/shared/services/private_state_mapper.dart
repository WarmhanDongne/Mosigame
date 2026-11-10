// [private_state_mapper.dart] 개인 손패 snapshot을 안정적인 카드 목록으로
// 변환하는 순수 파서입니다. 같은 종류의 카드를 붙이고, 같은 종류 안에서는
// ID 기준으로 고정해 RTDB map 순서와 무관하게 항상 같은 손패를 표시합니다.

import 'package:game_liars_poker/shared/models/game_models.dart';

List<PhoneHandCard> parseLiarsPokerHand(Object? value) {
  final cards = <PhoneHandCard>[];
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.value is! Map) continue;
      final card = PhoneHandCard.fromMap(
        entry.key.toString(),
        Map<Object?, Object?>.from(entry.value as Map),
      );
      if (card != null) cards.add(card);
    }
  }
  cards.sort((left, right) {
    final kindOrder = _cardKindOrder(
      left.cardValue,
    ).compareTo(_cardKindOrder(right.cardValue));
    if (kindOrder != 0) return kindOrder;

    final valueOrder = left.cardValue.compareTo(right.cardValue);
    if (valueOrder != 0) return valueOrder;
    return left.id.compareTo(right.id);
  });
  return cards;
}

int _cardKindOrder(String value) => switch (value) {
  'TRUTH' => 0,
  'LIE' => 1,
  _ => 2,
};
