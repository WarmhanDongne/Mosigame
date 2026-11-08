import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_liars_poker/phone/widgets/liar_accusation.dart';

void main() {
  testWidgets('첫 제출 전 LIAR 버튼은 어둡고 누를 수 없다', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiarAccusation(
            isLandscape: true,
            enabled: false,
            onAccuse: () => calls++,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('liars-poker-action-disabled')),
      findsOneWidget,
    );
    await tester.tap(find.byType(LiarAccusation));
    await tester.pump();
    expect(calls, 0);
  });

  testWidgets('직전 제출이 있는 LIAR 버튼은 정상 입력을 받는다', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiarAccusation(isLandscape: true, onAccuse: () => calls++),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('liars-poker-action-disabled')),
      findsNothing,
    );
    await tester.tap(find.byType(LiarAccusation));
    await tester.pump();
    expect(calls, 1);
  });
}
