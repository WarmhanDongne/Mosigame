import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/update/app_update_gate.dart';

Widget _app({
  required Future<int?> Function() minimum,
  required Future<int?> Function() current,
  Future<void> Function()? openStore,
}) => MaterialApp(
  builder: (context, child) => AppUpdateGate(
    readMinimumBuild: minimum,
    readCurrentBuild: current,
    openStore: openStore,
    child: child!,
  ),
  home: const Scaffold(body: Text('lobby')),
);

void main() {
  test('플랫폼별 최소 빌드 번호를 읽고 잘못된 값은 무시한다', () {
    const data = {
      'minBuild': {'android': 8, 'ios': 9},
    };
    expect(appUpdateMinimumBuild(data, TargetPlatform.android), 8);
    expect(appUpdateMinimumBuild(data, TargetPlatform.iOS), 9);
    expect(appUpdateMinimumBuild(data, TargetPlatform.macOS), isNull);
    expect(appUpdateMinimumBuild(null, TargetPlatform.android), isNull);
    expect(
      appUpdateMinimumBuild(const {'minBuild': 8}, TargetPlatform.android),
      isNull,
    );
    expect(
      appUpdateMinimumBuild(const {
        'minBuild': {'android': '8'},
      }, TargetPlatform.android),
      isNull,
    );
  });

  test('현재 빌드가 최소 빌드보다 낮을 때만 업데이트가 필요하다', () {
    expect(isAppUpdateRequired(currentBuild: 7, minimumBuild: 8), isTrue);
    expect(isAppUpdateRequired(currentBuild: 8, minimumBuild: 8), isFalse);
    expect(isAppUpdateRequired(currentBuild: 9, minimumBuild: 8), isFalse);
    expect(isAppUpdateRequired(currentBuild: null, minimumBuild: 8), isFalse);
    expect(isAppUpdateRequired(currentBuild: 7, minimumBuild: null), isFalse);
  });

  testWidgets('최소 빌드보다 낮으면 업데이트 화면을 덮고 스토어를 연다', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _app(
        minimum: () async => 8,
        current: () async => 7,
        openStore: () async => opened += 1,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('lobby'), findsNothing);
    expect(find.text('업데이트가 필요해요'), findsOneWidget);

    await tester.tap(find.text('업데이트하기'));
    await tester.pump();
    expect(opened, 1);
    // 스토어에서 돌아와도 업데이트 전에는 화면이 그대로 남습니다.
    expect(find.text('업데이트가 필요해요'), findsOneWidget);
  });

  testWidgets('최신 빌드이거나 확인에 실패하면 앱을 막지 않는다', (tester) async {
    await tester.pumpWidget(
      _app(minimum: () async => 8, current: () async => 8),
    );
    await tester.pump();
    expect(find.text('lobby'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        minimum: () async => throw StateError('offline'),
        current: () async => 7,
      ),
    );
    await tester.pump();
    expect(find.text('lobby'), findsOneWidget);
    expect(find.text('업데이트가 필요해요'), findsNothing);
  });

  testWidgets('앱으로 돌아올 때 다시 확인한다', (tester) async {
    int? minimum;
    await tester.pumpWidget(
      _app(minimum: () async => minimum, current: () async => 7),
    );
    await tester.pump();
    expect(find.text('lobby'), findsOneWidget);

    minimum = 8;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('업데이트가 필요해요'), findsOneWidget);
  });
}
