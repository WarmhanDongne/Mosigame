import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/game_copy.dart';
import 'package:game_eleven/phone/noir_view.dart';
import 'package:game_eleven/shared/noir/noir_motion.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';
import 'package:game_eleven/shared/widgets/noir_crown.dart';
import 'package:game_eleven/shared/widgets/noir_stage.dart';
import 'package:game_eleven/shared/widgets/noir_tile.dart';

import '../support/eleven_test_support.dart';
import 'screen_fixtures.dart';

void main() {
  setUpAll(loadElevenTestFonts);

  test('submitted values are absent from remaining tiles', () {
    for (final id in ['P04', 'P06', 'P07']) {
      final game = phoneCases.firstWhere((fixture) => fixture.id == id).game;
      final submitted = game.private.submissionFor(game.public.round);
      expect(submitted, isNotNull, reason: id);
      expect(game.private.tiles, isNot(contains(submitted!.value)), reason: id);
    }
  });

  for (final fixture in phoneCases) {
    testWidgets('${fixture.id} renders from public/private snapshots', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var submits = 0;
      var rulesOpened = 0;
      expect(fixture.screen.id, fixture.id);
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
              onSubmit: () => submits++,
              onExit: () {},
              onRules: () => rulesOpened++,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ElevenNoirStage), findsOneWidget);
      expect(find.text(fixture.text), findsWidgets);
      if (fixture.id == 'P01') {
        expect(find.text('0 : 0'), findsOneWidget);
        await tester.tap(find.text('?'));
        expect(rulesOpened, 1);
      }
      if (fixture.id == 'P05') expect(find.text('1 : 2'), findsOneWidget);
      if (fixture.id == 'P08') expect(find.text('3 : 1'), findsOneWidget);
      if (fixture.id == 'P10') {
        expect(find.text('6 : 2'), findsOneWidget);
        expect(find.byType(ElevenNoirCrown), findsOneWidget);
      }
      if (fixture.id == 'P11') {
        expect(find.text('2 : 6'), findsOneWidget);
        expect(find.byType(ElevenNoirCrown), findsOneWidget);
      }
      if (fixture.id.startsWith('G') &&
          int.parse(fixture.id.substring(1)) <= 5) {
        expect(find.text('0 : 0'), findsOneWidget);
      }
      if (fixture.countdownSeconds != null) {
        expect(
          find.textContaining(RegExp(r'^[0-9]+:[0-9]{2}$')),
          findsOneWidget,
        );
      }
      if (fixture.canSubmit) {
        await tester.tap(find.byKey(const ValueKey('eleven-phone-submit')));
        expect(submits, 1);
      } else if (fixture.id == 'P03') {
        await tester.tap(find.byKey(const ValueKey('eleven-phone-submit')));
        expect(submits, 0);
      }
      if (fixture.id == 'P06') {
        expect(fixture.game.private.tiles.contains(0), isFalse);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ElevenNoirTile &&
                widget.spec == ElevenTileSpec.phonePanel &&
                widget.value == 0,
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ElevenNoirTile &&
                widget.spec == ElevenTileSpec.phoneHand &&
                widget.value == 0 &&
                widget.state == ElevenTileState.used,
          ),
          findsOneWidget,
        );
      }
      if (fixture.id == 'G6') {
        expect(
          find.byWidgetPredicate(
            (widget) => widget is ElevenNoirTile && widget.value != null,
          ),
          findsNothing,
        );
      }
      if (fixture.id == 'P05') {
        // The opponent's public submission has color only; the summary tile
        // must never receive a number.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ElevenNoirTile &&
                widget.spec.size == const Size(22, 30) &&
                widget.value != null,
          ),
          findsNothing,
        );
      }
    });
  }

  for (final variant in ['lose', 'tie', 'second']) {
    testWidgets('P08 $variant shows outcome and next turn', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = p08Variant(variant);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevenPhoneNoirView(
              game: fixture.game,
              uid: fixture.uid,
              screen: fixture.screen,
              stage: fixture.stage,
              selected: null,
              submitting: false,
              onSelect: (_) {},
              onSubmit: () {},
              onExit: () {},
              onRules: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final status = variant == 'lose'
          ? ElevenScreenCopy.roundOpponentWon
          : ElevenScreenCopy.roundTieStatus;
      expect(find.text(status), findsOneWidget);
      expect(
        find
            .ancestor(of: find.text(status), matching: find.byType(Container))
            .evaluate()
            .map((element) => element.widget)
            .whereType<Container>()
            .any(
              (container) =>
                  container.decoration is BoxDecoration &&
                  (container.decoration! as BoxDecoration).color ==
                      ElevenNoirColors.cream,
            ),
        isTrue,
      );
      final second = variant != 'tie';
      expect(
        find.text(
          second ? ElevenScreenCopy.secondMark : ElevenScreenCopy.firstMark,
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          second
              ? ElevenScreenCopy.iPlayAfterOpponent
              : ElevenScreenCopy.iPlayFirst,
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'P02 before local selection has an empty preview and locked submit',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final base = phoneCases.firstWhere((fixture) => fixture.id == 'P02');
      var submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevenPhoneNoirView(
              game: base.game,
              uid: base.uid,
              screen: base.screen,
              stage: base.stage,
              selected: null,
              submitting: false,
              onSelect: (_) {},
              onSubmit: () => submitted = true,
              onExit: () {},
              onRules: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ElevenNoirTile &&
              widget.spec == ElevenTileSpec.phonePanel &&
              widget.face == ElevenTileFace.placeholder,
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('eleven-phone-submit')));
      expect(submitted, isFalse);
    },
  );

  for (final id in ['P02', 'P05', 'P03']) {
    testWidgets('$id submit button keeps its stage-specific appearance', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final base = phoneCases.firstWhere((fixture) => fixture.id == id);
      final preselect = id == 'P03';
      var submissions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevenPhoneNoirView(
              game: base.game,
              uid: base.uid,
              screen: base.screen,
              stage: base.stage,
              selected: preselect ? base.selected : null,
              submitting: false,
              onSelect: (_) {},
              onSubmit: () => submissions++,
              onExit: () {},
              onRules: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final button = find.byKey(const ValueKey('eleven-phone-submit'));
      final gesture = tester.widget<GestureDetector>(button);
      expect(gesture.onTap, isNull);
      final decoration =
          (gesture.child! as Container).decoration! as BoxDecoration;
      expect(
        decoration.color,
        preselect ? ElevenNoirColors.disabledCream : ElevenNoirColors.red,
      );
      expect(
        decoration.border!.top.color,
        preselect ? ElevenNoirColors.greyBeige : ElevenNoirColors.ink,
      );
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: button, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, preselect ? 1 : ElevenTurnMotion.popStartOpacity);
      await tester.tap(button);
      expect(submissions, 0);
    });
  }

  testWidgets('P02 selection restores opacity and pops submit button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = phoneCases.firstWhere((item) => item.id == 'P02');
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
            selectionProgress:
                ElevenTurnMotion.popPeakAt.inMilliseconds /
                ElevenTurnMotion.popTotal.inMilliseconds,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final button = find.byKey(const ValueKey('eleven-phone-submit'));
    expect(tester.widget<GestureDetector>(button).onTap, isNotNull);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: button, matching: find.byType(Opacity)).first,
          )
          .opacity,
      1,
    );
    expect(
      tester
          .widget<Transform>(
            find.ancestor(of: button, matching: find.byType(Transform)).first,
          )
          .transform
          .storage[0],
      closeTo(ElevenTurnMotion.popScale, 0.001),
    );
  });

  testWidgets('small landscape and long opponent name do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(667, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = phoneCases.firstWhere((item) => item.id == 'P03');
    final fixture = PhoneCase(
      base.id,
      {
        ...base.public,
        'players': {
          'a': {'uid': 'a', 'nickname': '아주길고긴닉네임열두글자이상', 'seatIndex': 0},
          'b': {'uid': 'b', 'nickname': '상대방닉네임도아주길게작성', 'seatIndex': 1},
        },
      },
      uid: base.uid,
      selected: base.selected,
      text: base.text,
    );
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
    expect(tester.takeException(), isNull);
  });
}
