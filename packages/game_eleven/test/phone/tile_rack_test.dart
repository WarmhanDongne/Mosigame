// 레인 A 소유: S4 손패 위젯 테스트(test/widgets_test.dart에서 옮김). 위젯을 바꾸면 함께 고친다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/phone/widgets/tile_rack.dart';

Widget _host(Widget child, {double width = 360}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  testWidgets('tile rack selects only remaining tiles', (tester) async {
    int? selected;
    await tester.pumpWidget(
      _host(
        ElevenTileRack(
          remaining: const [0, 3, 11],
          selected: null,
          enabled: true,
          onSelect: (value) => selected = value,
        ),
        width: 320,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('eleven-tile-5')));
    expect(selected, isNull);
    await tester.tap(find.byKey(const ValueKey('eleven-tile-11')));
    expect(selected, 11);
  });

  testWidgets('rack fits two rows in a short landscape phone area', (
    tester,
  ) async {
    // 작은 가로 휴대폰(약 640x320)의 오른쪽 손패 영역 크기입니다.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 200,
              child: Center(
                child: ElevenTileRack(
                  remaining: const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11],
                  selected: null,
                  enabled: true,
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final first = tester.getRect(find.byKey(const ValueKey('eleven-tile-0')));
    final last = tester.getRect(find.byKey(const ValueKey('eleven-tile-11')));
    expect(last.bottom - first.top, lessThanOrEqualTo(200));
  });

  testWidgets('disabled rack ignores taps', (tester) async {
    int? selected;
    await tester.pumpWidget(
      _host(
        ElevenTileRack(
          remaining: const [0, 3, 11],
          selected: 3,
          enabled: false,
          onSelect: (value) => selected = value,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('eleven-tile-0')));
    expect(selected, isNull);
  });
}
