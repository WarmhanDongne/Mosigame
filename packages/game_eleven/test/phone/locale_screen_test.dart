// D15 후속: 휴대폰 화면이 앱 언어(GameLocale)에 따라 번역 문구로 그려지는지 확인한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/phone/noir_view.dart';
import 'package:game_kit/localization/game_locale.dart';

import '../support/eleven_test_support.dart';
import 'screen_fixtures.dart';

final _hangul = RegExp(r'[가-힣]');

void main() {
  setUpAll(loadElevenTestFonts);
  tearDown(() => GameLocale.current = const Locale('ko'));

  for (final (locale, expected) in [
    (const Locale('en'), 'Pick a tile and submit'),
    (
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      '选一张牌并提交',
    ),
  ]) {
    testWidgets('phone P02 renders in $locale', (tester) async {
      GameLocale.current = locale;
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = phoneCases.firstWhere((c) => c.id == 'P02');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevenPhoneNoirView(
              game: fixture.game,
              uid: fixture.uid,
              screen: fixture.screen,
              stage: fixture.stage,
              selected: fixture.selected,
              submitting: false,
              onSelect: (_) {},
              onSubmit: () {},
              onExit: () {},
              onRules: () {},
            ),
          ),
        ),
      );
      expect(find.text(expected), findsOneWidget);
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where(_hangul.hasMatch)
          .toList();
      expect(texts, isEmpty, reason: '한국어가 남은 문구: $texts');
    });
  }
}
