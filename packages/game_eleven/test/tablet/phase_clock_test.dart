import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/services/game_progress_command.dart';
import 'package:game_eleven/shared/models/timing.dart';
import 'package:game_eleven/tablet/providers/game_stage.dart';
import 'package:game_eleven/tablet/src/phase_clock.dart';

import 'screen_fixtures.dart';

void main() {
  testWidgets('draw reveal sends complete_phase once after 4.7 seconds', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final clock = ElevenTabletPhaseClock(_RecordingProgressCommand());
    addTearDown(clock.dispose);
    final game = tabletFixture(ElevenTabletScreen.t03DrawReveal);
    var calls = 0;
    var fired = 0;
    int? sentRevision;
    Future<bool> send(int revision) async {
      sentRevision = revision;
      calls++;
      return true;
    }

    clock.arm(
      game,
      ElevenTabletStage.firstDrawReveal,
      isCurrent: () => true,
      send: send,
      onFired: () => fired++,
    );
    await tester.pump(
      ElevenTiming.drawReveal - const Duration(milliseconds: 1),
    );
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();
    expect(fired, 1);
    expect(calls, 1);
    expect(sentRevision, game.public.revision);
    clock.arm(
      game,
      ElevenTabletStage.firstDrawReveal,
      isCurrent: () => true,
      send: send,
    );
    await tester.pump(ElevenTiming.drawReveal);
    expect(calls, 1);
  });

  testWidgets('stale result does not complete its old phase', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final clock = ElevenTabletPhaseClock(_RecordingProgressCommand());
    addTearDown(clock.dispose);
    final game = tabletFixture(ElevenTabletScreen.t07RoundWin);
    var calls = 0;
    clock.arm(
      game,
      ElevenTabletStage.roundResult,
      isCurrent: () => false,
      send: (_) async {
        calls++;
        return true;
      },
    );
    await tester.pump(ElevenTiming.roundResult);
    expect(calls, 0);
  });
}

class _RecordingProgressCommand extends GameProgressCommand {
  @override
  void run({
    required Object key,
    required bool Function() isCurrent,
    required Future<bool> Function() send,
    bool Function()? canAttempt,
    Map<String, Map<String, dynamic>>? capturedCommands,
  }) {
    if (isCurrent()) {
      unawaited(send());
    }
  }
}
