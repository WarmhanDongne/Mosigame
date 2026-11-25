import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_balanced_text.dart';

Widget _app({required double width, required String text, double scale = 1}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Center(
          child: SizedBox(
            width: width,
            child: MosiBalancedText(
              text,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
          ),
        ),
      ),
    );

Text _renderedText(WidgetTester tester) => tester.widget<Text>(
  find.descendant(
    of: find.byType(MosiBalancedText),
    matching: find.byType(Text),
  ),
);

void main() {
  testWidgets('넓은 화면에서는 문구를 한 줄 그대로 유지한다', (tester) async {
    const text = '연결을 확인하고 다시 시도해 주세요';
    await tester.pumpWidget(_app(width: 400, text: text));

    expect(_renderedText(tester).data, text);
  });

  testWidgets('좁은 화면에서는 공백 단위의 균형 잡힌 줄로 나눈다', (tester) async {
    const text = '참가자 기기 연결을 확인하고 있어요 잠시 기다려 주세요';
    await tester.pumpWidget(_app(width: 190, text: text));

    final lines = _renderedText(tester).data!.split('\n');
    expect(lines.length, greaterThan(1));
    expect(lines.every((line) => line.trim().runes.length > 2), isTrue);
    expect(lines.join(' '), text);
  });

  testWidgets('글자 크기를 키워도 마지막 한두 글자만 고립시키지 않는다', (tester) async {
    const text = '시간이 끝나면 아무것도 안 하기로 자동 선택돼요';
    await tester.pumpWidget(_app(width: 220, text: text, scale: 1.3));

    final lines = _renderedText(tester).data!.split('\n');
    expect(lines.length, greaterThan(1));
    expect(lines.every((line) => line.trim().runes.length > 2), isTrue);
  });

  testWidgets('의도적으로 넣은 줄바꿈과 공백 없는 이름은 바꾸지 않는다', (tester) async {
    await tester.pumpWidget(_app(width: 80, text: '위 문장\n아래 문장'));
    expect(_renderedText(tester).data, '위 문장\n아래 문장');

    await tester.pumpWidget(_app(width: 40, text: '가나다라마바사아'));
    expect(_renderedText(tester).data, '가나다라마바사아');
  });
}
