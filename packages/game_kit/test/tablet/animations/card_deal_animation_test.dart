import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/tablet/animations/card_deal_animation.dart';

void main() {
  testWidgets('첫 분배는 기다려도 자동 시작하지 않고 탭 이후 한 번 완료된다', (tester) async {
    final key = GlobalKey<CardDealAnimationState>();
    var completed = 0;
    await tester.pumpWidget(_scene(key, () => completed++));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(completed, 0);
    key.currentState!.play();
    key.currentState!.play();
    await tester.pumpAndSettle();
    expect(completed, 1);
    key.currentState!.play();
    await tester.pumpAndSettle();
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('beforeDelay와 afterDelay를 지킨 뒤 서버 완료 콜백을 보낸다', (tester) async {
    final key = GlobalKey<CardDealAnimationState>();
    var completed = 0;
    await tester.pumpWidget(_scene(key, () => completed++, delays: true));
    await tester.pumpAndSettle();
    key.currentState!.play();
    await tester.pump(const Duration(milliseconds: 900));
    expect(completed, 0);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // 마지막 프레임의 부동소수점 경계를 넘겨 afterDelay 타이머를 시작합니다.
    await tester.pump(const Duration(milliseconds: 1));
    expect(completed, 0);
    await tester.pump(const Duration(milliseconds: 999));
    expect(completed, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('지연 중 화면을 떠나면 완료 콜백을 호출하지 않는다', (tester) async {
    final key = GlobalKey<CardDealAnimationState>();
    var completed = 0;
    await tester.pumpWidget(_scene(key, () => completed++, delays: true));
    await tester.pumpAndSettle();
    key.currentState!.play();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    expect(completed, 0);
  });

  testWidgets('분배하지 않는 카드는 덱 옆으로 빠졌다가 분배가 시작되기 전에 사라진다', (tester) async {
    final key = GlobalKey<CardDealAnimationState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardDealAnimation(
            key: key,
            playerCount: 2,
            cardsPerPlayer: 1,
            reserveCardCount: 3,
            duration: const Duration(milliseconds: 1000),
            cardBuilder: (_, _, _) => const ColoredBox(color: Colors.red),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Finder reserved(int index) => find.byKey(ValueKey('reserved-card-$index'));
    double opacity(int index) => tester
        .widget<Opacity>(
          find.descendant(of: reserved(index), matching: find.byType(Opacity)),
        )
        .opacity;
    final centersBefore = [
      for (var index = 0; index < 3; index++) tester.getCenter(reserved(index)),
    ];
    key.currentState!.play();
    await tester.pump();
    final deckCenter = tester.getCenter(find.byType(CardDealAnimation));
    // 분배 카드(빼 둔 카드가 아닌 것)의 중심입니다. 카드 위젯이 const라
    // 위젯이 아니라 요소마다 위치를 읽습니다.
    List<Offset> dealtCenters() => [
      for (final element in find.byType(ColoredBox).evaluate())
        if ((element.widget as ColoredBox).color == Colors.red &&
            !_isReserved(element))
          (element.renderObject! as RenderBox).localToGlobal(
            (element.renderObject! as RenderBox).size.center(Offset.zero),
          ),
    ];
    // 빼 두는 구간(0~16%)이 끝나면 덱 오른쪽에 그대로 보이고, 분배 카드는
    // 아직 한 장도 덱을 떠나지 않았습니다(분배는 36%부터).
    await tester.pump(const Duration(milliseconds: 200));
    for (var index = 0; index < 3; index++) {
      expect(
        tester.getCenter(reserved(index)).dx,
        greaterThan(centersBefore[index].dx),
      );
      expect(opacity(index), 1);
    }
    expect(dealtCenters(), hasLength(2));
    for (final center in dealtCenters()) {
      expect((center - deckCenter).distance, lessThan(12));
    }
    // 다 뺀 뒤 멈춤 구간에서 뺀 카드가 모두 사라지고, 그때까지 분배 카드는
    // 덱을 떠나지 않습니다(멈춤이 끝나기 직전 34%).
    await tester.pump(const Duration(milliseconds: 140));
    for (var index = 0; index < 3; index++) {
      expect(opacity(index), 0);
    }
    for (final center in dealtCenters()) {
      expect((center - deckCenter).distance, lessThan(12));
    }
    // 분배가 끝나기 전에 모두 사라집니다.
    await tester.pump(const Duration(milliseconds: 460));
    for (var index = 0; index < 3; index++) {
      expect(opacity(index), 0);
    }
    await tester.pumpAndSettle();
  });
}

Widget _scene(
  GlobalKey<CardDealAnimationState> key,
  VoidCallback onCompleted, {
  bool delays = false,
}) => MaterialApp(
  home: Scaffold(
    body: CardDealAnimation(
      key: key,
      playerCount: 2,
      cardsPerPlayer: 1,
      duration: const Duration(milliseconds: 200),
      beforeDelay: delays ? const Duration(seconds: 1) : Duration.zero,
      afterDelay: delays ? const Duration(seconds: 1) : Duration.zero,
      cardBuilder: (_, _, _) => const ColoredBox(color: Colors.red),
      onCompleted: onCompleted,
    ),
  ),
);

bool _isReserved(Element element) {
  var reserved = false;
  element.visitAncestorElements((ancestor) {
    final key = ancestor.widget.key;
    if (key is ValueKey<String> && key.value.startsWith('reserved-card-')) {
      reserved = true;
      return false;
    }
    return true;
  });
  return reserved;
}
