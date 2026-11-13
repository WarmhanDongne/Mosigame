// [final_selection.dart] 는 파이널콜 휴대폰의 최종 제출 카드 선택을 손패에 맞추는 파일이다.
//
// - [Package] : 파이널콜
// - [Logic] : 최종 제출이 열리면 가장 높은 조합을 미리 고르고, 손패에 없는 카드를 걸러냄
//
// 즉, 늦게 도착한 손패 때문에 이미 버린 카드를 제출해 서버가 거절하는 일을 막기 위해 필요한 파일이다.

import 'package:game_final_call/shared/models/game_models.dart';

/// 선택한 카드를 누르면 해제합니다. 다른 조합으로 바꿀 때는 새 카드와
/// 같은 색 또는 같은 숫자인 기존 선택만 남겨, 함께 낼 수 있는 카드를
/// 다시 누르지 않아도 되게 합니다.
void toggleFinalCallSelection({
  required Set<String> selected,
  required List<FinalCallCard> hand,
  required String cardId,
}) {
  final tappedIndex = hand.indexWhere((card) => card.id == cardId);
  if (tappedIndex < 0) return;
  if (selected.remove(cardId)) return;

  final tapped = hand[tappedIndex];
  final matchingColor = [
    for (final card in hand)
      if (selected.contains(card.id) && card.color == tapped.color) card.id,
  ];
  final matchingNumber = [
    for (final card in hand)
      if (selected.contains(card.id) && card.value == tapped.value) card.id,
  ];
  selected
    ..clear()
    ..addAll(
      matchingColor.length >= matchingNumber.length
          ? matchingColor
          : matchingNumber,
    )
    ..add(cardId);
}

/// 최종 제출 선택 [selected]를 지금 손패 [hand]에 맞춥니다.
///
/// 공개 진행(phase)과 내 손패는 서로 다른 경로로 도착합니다. 마지막 교체
/// 직후에는 제출 단계가 먼저 오고 바뀐 손패가 뒤에 올 수 있어, 이미 버린
/// 카드가 선택에 남으면 서버가 제출을 거절합니다. 사용자가 아직 선택을 고치지
/// 않았다면 늦게 도착한 손패에도 최고 조합을 다시 맞추고, 직접 고친 뒤에는 현재
/// 손패에 남아 있는 선택만 보존합니다.
int? syncFinalCallSelection({
  required Set<String> selected,
  required List<FinalCallCard> hand,
  required bool submitPhase,
  required int round,
  required int? presetRound,
  required bool preserveUserSelection,
}) {
  if (!submitPhase) {
    selected.clear();
    return null;
  }
  if (hand.isEmpty) {
    selected.clear();
    return null;
  }
  final handIds = {for (final card in hand) card.id};
  selected.removeWhere((cardId) => !handIds.contains(cardId));
  if (presetRound != round || !preserveUserSelection) {
    selected
      ..clear()
      ..addAll(finalCallBestCombination(hand).cardIds);
  }
  return round;
}
