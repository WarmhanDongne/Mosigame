import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/startup/startup_single_flight.dart';

void main() {
  test('시작 준비 재시도는 진행 중인 작업 하나만 공유한다', () async {
    final runner = StartupSingleFlight();
    final firstRun = Completer<void>();
    var calls = 0;

    Future<void> action() async {
      calls += 1;
      await firstRun.future;
    }

    final first = runner.run(action);
    final second = runner.run(action);

    expect(identical(first, second), isTrue);
    expect(runner.isRunning, isTrue);
    expect(calls, 1);

    firstRun.complete();
    await Future.wait([first, second]);
    expect(runner.isRunning, isFalse);

    await runner.run(() async => calls += 1);
    expect(calls, 2);
  });

  test('시작 준비가 실패해도 잠금이 풀려 다음 재시도를 허용한다', () async {
    final runner = StartupSingleFlight();

    await expectLater(
      runner.run(() async => throw StateError('failed')),
      throwsStateError,
    );
    expect(runner.isRunning, isFalse);

    var retried = false;
    await runner.run(() async => retried = true);
    expect(retried, isTrue);
  });
}
