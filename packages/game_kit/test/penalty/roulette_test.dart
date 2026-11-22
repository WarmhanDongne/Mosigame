// 룰렛의 회전 속도와 서버 결과 반영을 함께 검증합니다.
// 실제 서버·사운드 없이 손가락으로 원판을 휙 돌리고, 화면이 쓰는 회전 각도를 측정합니다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/penalty/roulette.dart';

void main() {
  for (final result in RouletteResult.values) {
    testWidgets('휙 돌린 속도로 돌다가 가속 없이 천천히 감속해 ${result.name} 칸에 멈춘다', (
      tester,
    ) async {
      final prepared = Completer<RouletteResult?>();
      final results = <RouletteResult>[];
      await _mountRoulette(tester, prepared: prepared, onResult: results.add);
      await _flick(tester);

      final waitingSpeed = await _sampleSpeed(tester);
      // Ticker의 첫 프레임은 테스트 pump 경계에서 일부 잘릴 수 있습니다.
      expect(waitingSpeed, closeTo(PenaltyRoulette.maxSpinSpeed, 0.8));
      expect(results, isEmpty);

      prepared.complete(result);
      await tester.pump();
      await tester.pump();

      var previousSpeed = waitingSpeed;
      for (var frame = 0; frame < 125; frame++) {
        final speed = await _sampleSpeed(tester);
        expect(
          speed,
          lessThanOrEqualTo(previousSpeed + 0.05),
          reason: '서버 응답 직후부터 정지까지 다시 가속하면 안 됩니다: $frame',
        );
        previousSpeed = speed;
        // 최소 감속이 4초이므로 3초 시점에도 천천히 움직이며 결과는 아직 없습니다.
        if (frame == 59) {
          expect(speed, greaterThan(0.01));
          expect(speed, lessThan(waitingSpeed * 0.3));
          expect(results, isEmpty);
        }
      }
      expect(previousSpeed, closeTo(0, 0.001));
      expect(results, [result]);

      // 포인터(위쪽) 아래의 칸도 서버 결과와 같아야 합니다.
      final wheel = tester.widget<RouletteWheel>(find.byType(RouletteWheel));
      final count = wheel.sections.length;
      final slot = 2 * math.pi / count;
      final turn = 2 * math.pi;
      final landed = (((-wheel.angle.value) % turn + turn) % turn / slot)
          .floor();
      expect(wheel.sections[landed], result == RouletteResult.eliminated);

      await tester.pump(const Duration(seconds: 1));
      expect(results, [result]);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('서버 응답이 늦어도 먼저 회전하고 결과 수신 후에만 멈춘다', (tester) async {
    final prepared = Completer<RouletteResult?>();
    final results = <RouletteResult>[];
    await _mountRoulette(tester, prepared: prepared, onResult: results.add);
    await _flick(tester);

    // 원본 위젯은 실제 Stopwatch로 서버 대기 시간을 잽니다. 최소 감속 시간(4초)
    // 분기를 검증하려고 이 한 사례는 실제로 응답을 6초 넘게 지연시킵니다.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 6100)),
    );
    await tester.pump(const Duration(seconds: 5));
    final waitingSpeed = await _sampleSpeed(tester);
    expect(waitingSpeed, closeTo(PenaltyRoulette.maxSpinSpeed, 0.8));
    expect(results, isEmpty);

    prepared.complete(RouletteResult.safe);
    await tester.pump();
    await tester.pump();
    var previousSpeed = waitingSpeed;
    for (var frame = 0; frame < 85; frame++) {
      final speed = await _sampleSpeed(tester);
      expect(speed, lessThanOrEqualTo(previousSpeed + 0.05));
      previousSpeed = speed;
      if (frame < 75) expect(results, isEmpty);
    }
    expect(previousSpeed, closeTo(0, 0.001));
    expect(results, [RouletteResult.safe]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('서버 결과가 없으면 임의 결과를 보내지 않고 다시 돌릴 수 있다', (tester) async {
    final prepared = Completer<RouletteResult?>();
    final results = <RouletteResult>[];
    await _mountRoulette(tester, prepared: prepared, onResult: results.add);
    await _flick(tester);
    prepared.complete(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 250));

    expect(await _sampleSpeed(tester), closeTo(0, 0.001));
    expect(results, isEmpty);
    final pointerGuard = tester.widget<IgnorePointer>(
      find
          .ancestor(of: _wheelFinder(), matching: find.byType(IgnorePointer))
          .first,
    );
    expect(pointerGuard.ignoring, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('살살 놓으면 돌지 않고 더 세게 돌리라고 안내한다', (tester) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final prepared = Completer<RouletteResult?>();
    var asked = false;
    await _mountRoulette(
      tester,
      prepared: prepared,
      onResult: (_) {},
      onPrepare: () => asked = true,
    );
    final rect = tester.getRect(_wheelFinder());
    final gesture = await tester.startGesture(_topOfWheel(rect));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(2, 0));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await tester.pump();

    expect(asked, isFalse);
    expect(find.text('조금 더 세게 휙 돌려요'), findsOneWidget);
    expect(haptics, contains('HapticFeedbackType.selectionClick'));
    expect(haptics.last, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('유효한 플릭과 탈락 결과에 단계별 촉각 피드백을 보낸다', (tester) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final prepared = Completer<RouletteResult?>();
    await _mountRoulette(tester, prepared: prepared, onResult: (_) {});

    await _flick(tester);
    expect(haptics, contains('HapticFeedbackType.selectionClick'));
    expect(haptics, contains('HapticFeedbackType.mediumImpact'));

    prepared.complete(RouletteResult.eliminated);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(haptics, contains('HapticFeedbackType.heavyImpact'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('돌리기 전에는 끌어서 돌리라는 안내가 보이고 끄는 동안 숨는다', (tester) async {
    final prepared = Completer<RouletteResult?>();
    await _mountRoulette(tester, prepared: prepared, onResult: (_) {});
    expect(find.byKey(const Key('roulette-drag-hint')), findsOneWidget);

    final rect = tester.getRect(_wheelFinder());
    final gesture = await tester.startGesture(_topOfWheel(rect));
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(find.byKey(const Key('roulette-drag-hint')), findsNothing);

    await gesture.up();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _mountRoulette(
  WidgetTester tester, {
  required Completer<RouletteResult?> prepared,
  required ValueChanged<RouletteResult> onResult,
  VoidCallback? onPrepare,
}) async {
  tester.view.physicalSize = const Size(1300, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PenaltyRoulette(
          attemptCount: 0,
          onPrepareResult: () {
            onPrepare?.call();
            return prepared.future;
          },
          onResult: onResult,
        ),
      ),
    ),
  );
  // 전구·안내 연출은 계속 반복되므로 안정화까지 기다리지 않습니다.
  await tester.pump();
}

Finder _wheelFinder() => find.byWidgetPredicate(
  (widget) => widget is GestureDetector && widget.onPanStart != null,
);

/// 원판 위쪽(포인터 바로 아래) 칸 위의 한 점입니다.
Offset _topOfWheel(Rect rect) =>
    rect.center + Offset(0, -rect.shortestSide * .3);

/// 원판 위쪽을 잡고 오른쪽으로 세게 휙 밀어 시계 방향으로 돌립니다.
Future<void> _flick(WidgetTester tester) async {
  final rect = tester.getRect(_wheelFinder());
  await tester.flingFrom(_topOfWheel(rect), const Offset(120, 0), 12000);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
}

double _angle(WidgetTester tester) =>
    tester.widget<RouletteWheel>(find.byType(RouletteWheel)).angle.value;

Future<double> _sampleSpeed(WidgetTester tester) async {
  final before = _angle(tester);
  await tester.pump(const Duration(milliseconds: 50));
  final delta = (_angle(tester) - before) % (2 * math.pi);
  return delta / 0.05;
}
