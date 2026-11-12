import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/tablet/animations/deck_showcase_shuffle_animation.dart';

class _Face extends StatelessWidget {
  const _Face(this.row, this.index);

  final int row;
  final int index;

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.white);
}

class _HiddenFace extends StatelessWidget {
  const _HiddenFace();

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.red);
}

class _Back extends StatelessWidget {
  const _Back();

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}

Widget _app({
  List<int> rowCounts = const [3, 2],
  int hiddenCardCount = 4,
  Duration hold = DeckShowcaseShuffleAnimation.defaultShowcaseHold,
  VoidCallback? onCompleted,
  bool hiddenFace = false,
}) => MaterialApp(
  home: Scaffold(
    body: DeckShowcaseShuffleAnimation(
      rowCounts: rowCounts,
      hiddenCardCount: hiddenCardCount,
      faceBuilder: (context, row, index) => _Face(row, index),
      hiddenFaceBuilder: hiddenFace
          ? (context, index) => const _HiddenFace()
          : null,
      backBuilder: (context) => const _Back(),
      cardWidth: 120,
      cardAspectRatio: 1.4,
      cardRadius: 8,
      title: 'DECK',
      showcaseHold: hold,
      onCompleted: onCompleted,
    ),
  ),
);

/// 컨트롤러는 시작 뒤 다음 프레임부터 시간을 세므로, 실제 화면처럼 짧은
/// 프레임으로 나눠 시간을 보냅니다.
Future<void> _advance(WidgetTester tester, Duration duration) async {
  const frame = Duration(milliseconds: 50);
  var left = duration;
  while (left > Duration.zero) {
    final step = left < frame ? left : frame;
    await tester.pump(step);
    left -= step;
  }
}

/// 덱 등장을 끝내고 전시·섞기를 시작합니다.
Future<void> _startShowcase(WidgetTester tester) => _advance(
  tester,
  DeckShowcaseShuffleAnimation.entryDuration +
      const Duration(milliseconds: 100),
);

void main() {
  test('세기 쉽게 한 줄 최대 6장, 줄마다 비슷한 장수로 나눈다', () {
    expect(DeckShowcaseShuffleAnimation.balancedRows(0), isEmpty);
    expect(DeckShowcaseShuffleAnimation.balancedRows(6), [6]);
    expect(DeckShowcaseShuffleAnimation.balancedRows(9), [5, 4]);
    expect(DeckShowcaseShuffleAnimation.balancedRows(12), [6, 6]);
    expect(DeckShowcaseShuffleAnimation.balancedRows(15), [5, 5, 5]);
    expect(DeckShowcaseShuffleAnimation.balancedRows(18), [6, 6, 6]);
  });

  testWidgets('전시 줄만 앞면으로 보이고 남길 카드는 전시 중 숨었다가 섞을 때 돌아온다', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await _startShowcase(tester);
    // 기본 머무름의 한가운데: 모두 공개된 상태입니다.
    await _advance(tester, const Duration(milliseconds: 1300));

    final faces = tester.widgetList<_Face>(find.byType(_Face)).toList();
    expect(faces, hasLength(5));
    expect(
      {for (final face in faces) (face.row, face.index)},
      {(0, 0), (0, 1), (0, 2), (1, 0), (1, 1)},
    );
    expect(find.byType(_Back), findsNWidgets(4));
    expect(find.text('DECK'), findsOneWidget);

    // 전시하지 않는 카드는 전시하는 동안 보이지 않습니다.
    double opacityOf(Element card) =>
        card.findAncestorWidgetOfExactType<Opacity>()!.opacity;
    final backs = find.byType(_Back).evaluate().toList();
    expect(backs.map(opacityOf), everyElement(0));

    // 전시 줄은 화면 가운데를 기준으로 위아래로 고르게 놓입니다.
    final center = tester.getCenter(find.byType(DeckShowcaseShuffleAnimation));
    final tops = [
      for (final face in find.byType(_Face).evaluate())
        tester.getTopLeft(find.byWidget(face.widget)).dy,
    ];
    final bottoms = [
      for (final face in find.byType(_Face).evaluate())
        tester.getBottomLeft(find.byWidget(face.widget)).dy,
    ];
    final top = tops.reduce((a, b) => a < b ? a : b);
    final bottom = bottoms.reduce((a, b) => a > b ? a : b);
    expect(((top + bottom) / 2 - center.dy).abs(), lessThan(8));

    // 다시 모아 섞을 때는 남겨 둔 카드도 덱으로 돌아옵니다.
    await _advance(tester, const Duration(milliseconds: 1600));
    expect(find.byType(_Face), findsNothing);
    expect(find.byType(_Back).evaluate().map(opacityOf), everyElement(1));
    await tester.pumpAndSettle();
  });

  testWidgets('덱은 위에서 떨어지지 않고 가운데에서 은은하게 나타난다', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final center = tester.getCenter(find.byType(DeckShowcaseShuffleAnimation));
    final opacity = tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byType(DeckShowcaseShuffleAnimation),
            matching: find.byType(Opacity),
          ),
        )
        .first
        .opacity;
    expect(opacity, greaterThan(0));
    expect(opacity, lessThan(1));
    // 처음 나타나는 덱은 전시할 카드뿐이며, 합류 카드는 아직 보이지 않습니다.
    for (final back in find.byType(_Back).evaluate()) {
      if (back.findAncestorWidgetOfExactType<Opacity>()!.opacity == 0) {
        continue;
      }
      final box = back.renderObject! as RenderBox;
      final cardCenter = box.localToGlobal(box.size.center(Offset.zero));
      expect((cardCenter - center).distance, lessThan(16));
    }
    await tester.pumpAndSettle();
  });

  testWidgets('머무름이 끝나면 합류 카드가 앞면으로 들어와 전시 카드와 함께 뒷면으로 뒤집힌다', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(hiddenFace: true));
    await _startShowcase(tester);

    // 머무는 동안: 전시 카드만 앞면이고 합류 카드는 아직 없습니다.
    await _advance(tester, const Duration(milliseconds: 1300));
    expect(find.byType(_Face), findsNWidgets(5));
    expect(find.byType(_HiddenFace), findsNothing);

    // 머무름 직후: 합류 카드가 앞면으로 들어와 전시 카드와 함께 보입니다.
    await _advance(tester, const Duration(milliseconds: 1000));
    expect(find.byType(_Face), findsNWidgets(5));
    expect(find.byType(_HiddenFace), findsNWidgets(4));

    // 함께 뒷면으로 뒤집힙니다.
    await _advance(tester, const Duration(milliseconds: 600));
    expect(find.byType(_Face), findsNothing);
    expect(find.byType(_HiddenFace), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('머무는 시간만큼 전체 연출이 길어지고 끝나면 완료를 알린다', (tester) async {
    const hold = Duration(milliseconds: 2400);
    expect(
      DeckShowcaseShuffleAnimation.shuffleDurationFor(hold) -
          DeckShowcaseShuffleAnimation.shuffleDurationFor(
            DeckShowcaseShuffleAnimation.defaultShowcaseHold,
          ),
      hold - DeckShowcaseShuffleAnimation.defaultShowcaseHold,
    );

    var completed = 0;
    await tester.pumpWidget(_app(hold: hold, onCompleted: () => completed++));
    await _startShowcase(tester);
    // 기본 머무름이었다면 이미 뒷면으로 돌아갔을 시점에도 앞면이 남아 있습니다.
    await _advance(tester, const Duration(milliseconds: 2500));
    expect(find.byType(_Face), findsNWidgets(5));

    await _advance(
      tester,
      DeckShowcaseShuffleAnimation.shuffleDurationFor(hold),
    );
    expect(completed, 1);
    expect(find.byType(_Face), findsNothing);
  });

  testWidgets('전시할 카드가 없으면 뒷면 덱만 섞는다', (tester) async {
    await tester.pumpWidget(_app(rowCounts: const [0], hiddenCardCount: 0));
    await _startShowcase(tester);
    await _advance(tester, const Duration(milliseconds: 1300));
    expect(find.byType(_Face), findsNothing);
    expect(find.byType(_Back), findsWidgets);
    expect(find.text('DECK'), findsNothing);
    await tester.pumpAndSettle();
  });
}
