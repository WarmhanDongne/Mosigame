import 'dart:async';

import 'package:game_kit/recovery/services/game_progress_command.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/models/timing.dart';
import 'package:game_eleven/tablet/providers/game_stage.dart';

/// Schedules one completion per server revision after its visual phase duration.
/// GameProgressCommand owns transport retries; this clock owns the one-shot timer.
class ElevenTabletPhaseClock {
  ElevenTabletPhaseClock(this.command);

  final GameProgressCommand command;
  Timer? _timer;
  Object? _key;

  void arm(
    ElevenGameState game,
    ElevenTabletStage stage, {
    required bool Function() isCurrent,
    required Future<bool> Function(int revision) send,
    void Function()? onFired,
  }) {
    final pub = game.public;
    final key = stage.completesPhase ? (pub.startedAt, pub.revision) : null;
    if (key == _key) return;
    _key = key;
    _timer?.cancel();
    command.cancel();
    if (key == null) return;
    final revision = pub.revision;
    final wait = stage.isDrawReveal
        ? ElevenTiming.drawReveal
        : ElevenTiming.roundResult;
    _timer = Timer(wait, () {
      if (!isCurrent()) return;
      command.run(key: key, isCurrent: isCurrent, send: () => send(revision));
      onFired?.call();
    });
  }

  void dispose() {
    _timer?.cancel();
    command.dispose();
  }
}
