import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/shared/noir/noir_motion.dart';
import 'package:game_eleven/shared/noir/noir_toast_schedule.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';
import 'package:game_eleven/shared/widgets/noir_toast.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/tablet/providers/game_stage.dart';
import 'package:game_eleven/tablet/widgets/noir_board.dart';

import '../support/eleven_test_support.dart';
import 'screen_fixtures.dart';

const _surface = ValueKey('tablet-review-surface');

Widget _host(
  ElevenTabletScreen screen, {
  bool animate = true,
  bool drawRevealed = true,
  bool showLastToast = false,
  String? prototype,
  int elapsedMs = 0,
}) {
  final game = tabletFixture(
    screen,
    prototype: prototype,
    elapsedMs: elapsedMs,
  );
  final lastToast = showLastToast ? _lastToast(screen, game) : null;
  return MaterialApp(
    home: RepaintBoundary(
      key: _surface,
      child: Scaffold(
        body: Stack(
          children: [
            ElevenTabletBoardView(
              key: ValueKey('review-board-$animate'),
              game: game,
              screen: screen,
              animate: animate,
              drawRevealed: drawRevealed,
              resultEmphasized:
                  !{'04_result', '05_result-tie'}.contains(prototype) ||
                  elapsedMs >= 800,
              onPick: (_) {},
              onRules: () {},
              onSettings: () {},
              onRestart: () {},
              onHome: () {},
            ),
            if (lastToast != null)
              Positioned.fromRect(
                rect: ElevenNoirSpacing.toastRect,
                child: Center(
                  child: ElevenToastText(
                    text: lastToast.text,
                    accent: lastToast.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

ElevenToastStep? _lastToast(ElevenTabletScreen screen, ElevenGameState game) {
  final pub = game.public;
  final steps = switch (screen) {
    ElevenTabletScreen.t01DrawStart ||
    ElevenTabletScreen.t02DrawSecondPick => ElevenToastSchedule.pickTile(),
    ElevenTabletScreen.t03DrawReveal => ElevenToastSchedule.firstPlayer(
      pub.nicknameOf(pub.draw?.winnerUid),
    ),
    ElevenTabletScreen.t04FirstChoosing => ElevenToastSchedule.firstRound(),
    ElevenTabletScreen.t05SecondChoosing => ElevenToastSchedule.submitted(),
    ElevenTabletScreen.t06AutoSubmitted => ElevenToastSchedule.autoSubmitted(),
    ElevenTabletScreen.t07RoundWin => ElevenToastSchedule.roundWinner(
      pub.nicknameOf(game.currentRoundResult?.winnerUid),
    ),
    ElevenTabletScreen.t08RoundTie => ElevenToastSchedule.roundTie(),
    ElevenTabletScreen.t09RoundIntro => ElevenToastSchedule.roundIntro(
      pub.round,
      pub.nicknameOf(pub.firstUid),
    ),
    ElevenTabletScreen.t10EarlyEnd => ElevenToastSchedule.earlyEnd(
      pub.nicknameOf(pub.winnerUid),
    ),
    ElevenTabletScreen.t11TieDraw => ElevenToastSchedule.tieDrawStart(),
    ElevenTabletScreen.t12TieReveal => ElevenToastSchedule.tieDrawWinner(
      pub.nicknameOf(pub.draw?.winnerUid),
    ),
    _ => <ElevenToastStep>[],
  };
  return steps.isEmpty ? null : steps.last;
}

void _size(WidgetTester tester) {
  tester.view.physicalSize = const Size(1194, 834);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _capture(WidgetTester tester, String name) => captureElevenReview(
  tester,
  find.byKey(_surface),
  lane: 'lane-b',
  name: name,
);

void main() {
  setUpAll(() async {
    Directory('review_out/lane-b').createSync(recursive: true);
    await loadElevenTestFonts();
  });

  testWidgets('14 tablet screens and toast hold frames', (tester) async {
    _size(tester);
    for (final screen in ElevenTabletScreen.values.where((s) => s.id != null)) {
      final id = screen.id!;
      await tester.pumpWidget(
        _host(screen, animate: false, showLastToast: true),
      );
      await _capture(tester, id);
      if (screen == ElevenTabletScreen.t13Final ||
          screen == ElevenTabletScreen.t13bFinalTieDraw) {
        continue;
      }
      await tester.pumpWidget(_host(screen, animate: false));
      await _capture(tester, '$id--base');
      await tester.pumpWidget(_host(screen));
      final delayedReveal =
          screen == ElevenTabletScreen.t03DrawReveal ||
          screen == ElevenTabletScreen.t12TieReveal;
      if (delayedReveal) {
        await tester.pump(ElevenDrawMotion.revealToastAt);
        await tester.pump(const Duration(milliseconds: 350));
      } else {
        await tester.pump(const Duration(milliseconds: 650));
      }
      await _capture(tester, '$id--toast1');
      if (screen == ElevenTabletScreen.t03DrawReveal ||
          screen == ElevenTabletScreen.t10EarlyEnd ||
          screen == ElevenTabletScreen.t11TieDraw ||
          screen == ElevenTabletScreen.t12TieReveal) {
        if (delayedReveal) {
          await tester.pump(const Duration(milliseconds: 1450));
          await tester.pump(const Duration(milliseconds: 450));
        } else {
          await tester.pump(
            screen == ElevenTabletScreen.t11TieDraw
                ? const Duration(milliseconds: 1000)
                : const Duration(milliseconds: 1900),
          );
        }
        await _capture(tester, '$id--toast2');
      }
      if (screen == ElevenTabletScreen.t11TieDraw) {
        await tester.pump(const Duration(milliseconds: 1400));
        await _capture(tester, '$id--toast3');
      }
    }
  }, skip: !elevenReviewEnabled);

  final prototypes = <String, (List<int>, ElevenTabletScreen Function(int))>{
    '01_draw': (
      [
        0,
        470,
        2000,
        3400,
        4000,
        5000,
        5550,
        6100,
        6900,
        7450,
        7900,
        9700,
        10099,
        10800,
        11300,
      ],
      (ms) => ms < 5000
          ? ElevenTabletScreen.t01DrawStart
          : ms < 6100
          ? ElevenTabletScreen.t02DrawSecondPick
          : ms < 9700
          ? ElevenTabletScreen.t03DrawReveal
          : ElevenTabletScreen.t04FirstChoosing,
    ),
    '02_round': (
      [
        0,
        700,
        1200,
        1800,
        2050,
        2600,
        2900,
        3100,
        3400,
        3700,
        3900,
        4600,
        4850,
        5050,
        5500,
      ],
      (ms) => ms < 2600
          ? ElevenTabletScreen.t04FirstChoosing
          : ElevenTabletScreen.t05SecondChoosing,
    ),
    '03_timeout': (
      [0, 2000, 2100, 2200, 2300, 2400, 3000, 3200, 3300, 3400],
      (ms) => ms < 2200
          ? ElevenTabletScreen.t05SecondChoosing
          : ElevenTabletScreen.t06AutoSubmitted,
    ),
    '04_result': (
      [
        0,
        300,
        800,
        1100,
        1400,
        1750,
        2700,
        3200,
        3450,
        3700,
        3940,
        4200,
        4400,
        4900,
        5100,
      ],
      (ms) => ms < 3200
          ? ElevenTabletScreen.t07RoundWin
          : ElevenTabletScreen.t09RoundIntro,
    ),
    '05_result-tie': (
      [
        0,
        300,
        800,
        1400,
        1600,
        2500,
        2700,
        3200,
        3450,
        3700,
        3940,
        4200,
        4400,
        4900,
        5100,
      ],
      (ms) => ms < 3200
          ? ElevenTabletScreen.t08RoundTie
          : ElevenTabletScreen.t09RoundIntro,
    ),
    '06_early-end': (
      [
        0,
        200,
        1000,
        1200,
        1400,
        1600,
        3100,
        3300,
        3700,
        3800,
        3950,
        4050,
        4200,
        4300,
        4450,
      ],
      (ms) => ms < 3300
          ? ElevenTabletScreen.t10EarlyEnd
          : ElevenTabletScreen.t13Final,
    ),
    '07_final11': (
      [
        0,
        400,
        550,
        1000,
        1200,
        1400,
        1600,
        3100,
        3300,
        3700,
        3950,
        4050,
        4200,
        4300,
        4450,
      ],
      (ms) => ms < 3300
          ? ElevenTabletScreen.t07RoundWin
          : ElevenTabletScreen.t13Final,
    ),
    '08_tie-draw': (
      [
        0,
        680,
        1400,
        2600,
        3401,
        4000,
        5000,
        5550,
        6100,
        6900,
        7600,
        7901,
        9700,
        10100,
        10700,
      ],
      (ms) => ms < 5000
          ? ElevenTabletScreen.t11TieDraw
          : ms < 9700
          ? ElevenTabletScreen.t12TieReveal
          : ElevenTabletScreen.t13bFinalTieDraw,
    ),
  };

  testWidgets('eight prototype tablet frame timelines', (tester) async {
    _size(tester);
    for (final entry in prototypes.entries) {
      var lastMs = 0;
      for (final ms in entry.value.$1) {
        final screen = entry.value.$2(ms);
        if (ms > lastMs) {
          await tester.pump(Duration(milliseconds: ms - lastMs));
        }
        await tester.pumpWidget(
          _host(screen, prototype: entry.key, elapsedMs: ms),
        );
        await _capture(tester, '${entry.key}-${ms.toString().padLeft(5, '0')}');
        lastMs = ms;
      }
    }
  }, skip: !elevenReviewEnabled);
}
