import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/phone/noir_view.dart';
import 'package:game_eleven/shared/noir/noir_motion.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';

import '../support/eleven_test_support.dart';
import 'screen_fixtures.dart';

void main() {
  setUpAll(loadElevenTestFonts);

  Future<void> render(
    WidgetTester tester,
    PhoneCase fixture, {
    Size size = const Size(844, 390),
    double turnProgress = 1,
    double endProgress = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: ElevenNoirColors.table,
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
            turnProgress: turnProgress,
            endProgress: endProgress,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final fixture in phoneCases) {
    testWidgets('${fixture.id} review', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await render(tester, fixture);
      await captureElevenReview(
        tester,
        find.byType(ElevenPhoneNoirView),
        lane: 'lane-a',
        name: fixture.id,
      );
    }, skip: !elevenReviewEnabled);
  }

  for (final outcome in ['lose', 'tie', 'second']) {
    testWidgets('P08-$outcome review', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = p08Variant(outcome);
      await render(tester, fixture);
      await captureElevenReview(
        tester,
        find.byType(ElevenPhoneNoirView),
        lane: 'lane-a',
        name: 'P08-$outcome',
      );
    }, skip: !elevenReviewEnabled);
  }

  for (final id in ['P02', 'P05']) {
    testWidgets('$id-small review', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = phoneCases.firstWhere((item) => item.id == id);
      await render(tester, fixture, size: const Size(667, 375));
      await captureElevenReview(
        tester,
        find.byType(ElevenPhoneNoirView),
        lane: 'lane-a',
        name: '$id-small',
      );
    }, skip: !elevenReviewEnabled);
  }

  testWidgets('P05-unselected review', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = phoneCases.firstWhere((item) => item.id == 'P05');
    await render(
      tester,
      PhoneCase(
        base.id,
        base.public,
        uid: base.uid,
        private: base.private,
        countdownSeconds: base.countdownSeconds,
        text: base.text,
      ),
    );
    await captureElevenReview(
      tester,
      find.byType(ElevenPhoneNoirView),
      lane: 'lane-a',
      name: 'P05-unselected',
    );
  }, skip: !elevenReviewEnabled);

  for (final ms in [0, 700, 2900, 3100]) {
    testWidgets('02_round-$ms review', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = roundMotionCase(ms);
      await render(
        tester,
        fixture,
        turnProgress: ms == 0 || ms == 2900 ? 0 : 1,
      );
      await tester.pump(Duration(milliseconds: ms));
      await captureElevenReview(
        tester,
        find.byType(ElevenPhoneNoirView),
        lane: 'lane-a',
        name: '02_round-${ms.toString().padLeft(5, '0')}',
      );
    }, skip: !elevenReviewEnabled);
  }

  for (final ms in [3700, 3800, 3950, 4050, 4200, 4450]) {
    testWidgets('06_early-end-$ms review', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = phoneCases.firstWhere(
        (item) => item.id == (ms == 3700 ? 'G7' : 'P10'),
      );
      await render(
        tester,
        fixture,
        endProgress: ms == 3700
            ? 0
            : (ms - ElevenGameEndFlowMotion.crownAt.inMilliseconds) /
                  ElevenPhoneEndMotion.total.inMilliseconds,
      );
      await tester.pump(Duration(milliseconds: ms));
      await captureElevenReview(
        tester,
        find.byType(ElevenPhoneNoirView),
        lane: 'lane-a',
        name: '06_early-end-${ms.toString().padLeft(5, '0')}',
      );
    }, skip: !elevenReviewEnabled);
  }
}
