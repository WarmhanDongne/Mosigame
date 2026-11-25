import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/shared/widgets/game_route_exit.dart';
import 'package:game_kit/widgets/game_exit_route.dart';

void main() {
  testWidgets('material game route disables interactive back gestures', (
    tester,
  ) async {
    late NavigatorState navigator;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            navigator = Navigator.of(context);
            return const Scaffold(body: Center(child: Text('lobby')));
          },
        ),
      ),
    );

    late BuildContext gameContext;
    final route = GameExitMaterialPageRoute<void>(
      builder: (context) {
        gameContext = context;
        return const Scaffold(body: Center(child: Text('game')));
      },
    );
    navigator.push(route);
    await tester.pumpAndSettle();

    expect(route.popGestureEnabled, isFalse);
    expect(route.popDisposition, RoutePopDisposition.doNotPop);

    // Android 시스템 뒤로가기와 같은 maybePop은 게임을 닫지 않습니다.
    // doNotPop도 뒤로가기 요청 자체는 처리했으므로 maybePop은 true를 돌려주지만
    // 라우트는 그대로 남습니다.
    expect(await navigator.maybePop(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('game'), findsOneWidget);

    // 게임 내부의 명시적 종료는 뒤로가기 차단과 무관하게
    // 게임 라우트를 닫아야 합니다.
    exitGameRoute(gameContext);
    await tester.pumpAndSettle();
    expect(find.text('lobby'), findsOneWidget);
  });

  for (final instantEntry in [false, true]) {
    testWidgets('game exit covers the old screen then reveals the destination '
        '(${instantEntry ? 'instant' : 'material'} entry)', (tester) async {
      late NavigatorState navigator;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              navigator = Navigator.of(context);
              return const Scaffold(body: Center(child: Text('lobby')));
            },
          ),
        ),
      );

      final PageRoute<void> route = instantEntry
          ? GameExitInstantPageRoute<void>(
              pageBuilder: (_, _, _) =>
                  const Scaffold(body: Center(child: Text('game'))),
            )
          : GameExitMaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Center(child: Text('game'))),
            );
      expect(route.popGestureEnabled, isFalse);
      expect(route.popDisposition, RoutePopDisposition.doNotPop);
      navigator.push(route);
      await tester.pumpAndSettle();
      expect(find.text('game'), findsOneWidget);
      expect(find.byKey(const Key('game-exit-pattern')), findsNothing);

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 155));
      expect(find.byKey(const Key('game-exit-pattern')), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(find.byKey(const Key('game-exit-old-screen')))
            .opacity,
        1,
      );

      await tester.pump(const Duration(milliseconds: 215));
      expect(find.byKey(const Key('game-exit-pattern')), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(find.byKey(const Key('game-exit-old-screen')))
            .opacity,
        0,
      );

      await tester.pumpAndSettle();
      expect(find.text('lobby'), findsOneWidget);
      expect(find.byKey(const Key('game-exit-pattern')), findsNothing);
    });
  }
}
