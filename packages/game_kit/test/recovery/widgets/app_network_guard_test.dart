// recovery/widgets의 연결 차단·안내 흐름을 실제 서버 없이 검증합니다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_connection_band.dart';
import 'package:game_kit/recovery/widgets/app_network_guard.dart';

void main() {
  testWidgets(
    'game route keeps recovery controls clickable while commands stay guarded',
    (tester) async {
      final connection = StreamController<bool>.broadcast();
      addTearDown(connection.close);
      var exits = 0;
      await _mount(
        tester,
        AppNetworkGuard(
          connectionChanges: connection.stream,
          blockChildInput: false,
          child: Column(
            children: [
              const TextButton(onPressed: null, child: Text('카드 제출')),
              TextButton(onPressed: () => exits++, child: const Text('게임 나가기')),
            ],
          ),
        ),
      );
      connection.add(false);
      await tester.pump();
      expect(_gameInputIsBlocked(tester), false);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '카드 제출'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('게임 나가기'));
      expect(exits, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a locked lobby can still leave through the exit button in the band',
    (tester) async {
      final connection = StreamController<bool>.broadcast();
      addTearDown(connection.close);
      var exits = 0;
      var retries = 0;
      await _mount(
        tester,
        AppNetworkGuard(
          connectionChanges: connection.stream,
          showExitInBand: true,
          exitLabel: '나가기',
          onExit: () => exits++,
          onRetry: () async => retries++,
          noticeDelay: Duration.zero,
          child: const Text('대기실'),
        ),
      );
      final exit = find.byKey(const ValueKey('network-band-exit'));
      expect(exit, findsNothing, reason: 'only while the connection is lost');

      connection.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(MosiConnectionBand), findsOneWidget);
      expect(exit, findsOneWidget);

      await tester.tap(exit);
      await tester.pump();
      expect(exits, 1);
      expect(retries, 0, reason: 'the exit button is not a retry tap');

      // 버튼 밖의 화면과 띠는 계속 재시도입니다.
      await tester.tapAt(tester.getCenter(find.text('대기실')));
      await tester.pump();
      expect(retries, 1);
      expect(exits, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('the band has no exit button unless the screen asks for one', (
    tester,
  ) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        onExit: () {},
        noticeDelay: Duration.zero,
        child: const Text('게임 화면'),
      ),
    );
    connection.add(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(MosiConnectionBand), findsOneWidget);
    expect(find.byKey(const ValueKey('network-band-exit')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'failed recovery retries from anywhere and ignores repeated taps in flight',
    (tester) async {
      final connection = StreamController<bool>.broadcast();
      addTearDown(connection.close);
      final manualRecovery = Completer<void>();
      var attempts = 0;
      await _mount(
        tester,
        AppNetworkGuard(
          connectionChanges: connection.stream,
          onRetry: () async {
            attempts++;
            if (attempts == 1) throw TimeoutException('failed recovery');
            await manualRecovery.future;
          },
          child: const Text('게임 화면'),
        ),
      );
      connection.add(false);
      await tester.pump();
      connection.add(true);
      await tester.pump();
      await tester.pump();
      expect(find.byType(MosiConnectionBand), findsOneWidget);
      expect(find.textContaining('눌러서 다시 시도'), findsOneWidget);
      expect(attempts, 1);
      // 하단 띠가 아닌 잠긴 게임 화면 가운데를 눌러도 같은 복구를 시작합니다.
      await tester.tapAt(tester.getCenter(find.text('게임 화면')));
      await tester.pump();
      expect(attempts, 2);
      expect(find.text('최신 상황을 불러오는 중…'), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.text('게임 화면')));
      await tester.tapAt(tester.getCenter(find.text('게임 화면')));
      await tester.pump();
      expect(attempts, 2, reason: '진행 중인 복구와 동시에 새 요청을 보내지 않는다');
      manualRecovery.complete();
      await tester.pump();
      await tester.pump();
      expect(_gameInputIsBlocked(tester), false);
      expect(find.byType(MosiConnectionBand), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'locked offline screen starts one manual recovery before RTDB reconnects',
    (tester) async {
      final connection = StreamController<bool>.broadcast();
      addTearDown(connection.close);
      final recovery = Completer<void>();
      var attempts = 0;
      await _mount(
        tester,
        AppNetworkGuard(
          connectionChanges: connection.stream,
          onRetry: () {
            attempts++;
            return recovery.future;
          },
          child: const Text('잠긴 게임 화면'),
        ),
      );

      connection.add(false);
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.text('잠긴 게임 화면')));
      await tester.pump();
      expect(attempts, 1);
      expect(
        find.byKey(const ValueKey('network-recovery-tap-surface')),
        findsNothing,
        reason: '복구 진행 중에는 전체 화면 재시도 영역을 제거한다',
      );
      await tester.tapAt(tester.getCenter(find.text('잠긴 게임 화면')));
      await tester.pump();
      expect(attempts, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      recovery.complete();
      await tester.pump();
    },
  );

  testWidgets(
    'recovery band keeps route exit usable during an in-flight retry',
    (tester) async {
      final connection = StreamController<bool>.broadcast();
      addTearDown(connection.close);
      final recovery = Completer<void>();
      var exits = 0;
      await _mount(
        tester,
        AppNetworkGuard(
          connectionChanges: connection.stream,
          onRetry: () => recovery.future,
          blockChildInput: false,
          child: TextButton(
            onPressed: () => exits++,
            child: const Text('게임 나가기'),
          ),
        ),
      );
      connection.add(false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 11));
      connection.add(true);
      await tester.pump();
      expect(find.text('최신 상황을 불러오는 중…'), findsOneWidget);
      await tester.tap(find.text('게임 나가기'));
      expect(exits, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      recovery.complete();
      await tester.pump();
    },
  );

  testWidgets(
    'only foreground navigator route owns recovery notices and retry',
    (tester) async {
      final connection = StreamController<bool>.broadcast();
      var lobbyRetries = 0, gameRetries = 0;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: AppNetworkGuard(
              connectionChanges: connection.stream,
              onRetry: () async {
                lobbyRetries++;
              },
              child: const Text('lobby'),
            ),
          ),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: AppNetworkGuard(
                connectionChanges: connection.stream,
                onRetry: () async {
                  gameRetries++;
                },
                child: const Text('game'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      connection.add(false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 11));
      expect(
        find.byType(MosiConnectionBand, skipOffstage: false),
        findsOneWidget,
      );
      connection.add(true);
      await tester.pump();
      await tester.pump();
      expect(gameRetries, 1);
      expect(lobbyRetries, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await connection.close();
    },
  );
  testWidgets('3초 미만 단절도 화면 터치는 복구만 시도하고 게임 입력은 막는다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    var taps = 0;
    var recoveries = 0;
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        onRetry: () async {
          recoveries++;
        },
        child: TextButton(onPressed: () => taps++, child: const Text('카드 제출')),
      ),
    );
    connection.add(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('카드 제출'), warnIfMissed: false);
    expect(taps, 0);
    expect(find.byType(MosiConnectionBand), findsNothing);
    expect(recoveries, 1, reason: '잠긴 화면의 터치는 수동 복구로만 전달한다');
    connection.add(true);
    await tester.pump();
    // 복구 Future 완료 뒤 예약된 setState를 다음 프레임에 반영합니다.
    await tester.pump();
    expect(_gameInputIsBlocked(tester), isFalse);
    await tester.tap(find.text('카드 제출'));
    expect(recoveries, 2, reason: '새 연결 세대의 최신 상태를 한 번 검증한다');
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('3초 상태 띠, 10초 장기 대기 문구를 표시하며 시간을 초기화하지 않는다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        child: const Text('게임 화면'),
      ),
    );
    connection.add(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('네트워크 연결을 확인하는 중…'), findsOneWidget);
    expect(find.byType(MosiConnectionBand), findsOneWidget);
    connection.add(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    expect(find.byType(MosiConnectionBand), findsOneWidget);
    expect(find.text('네트워크 연결을 기다리는 중…'), findsOneWidget);
    expect(find.text('게임 화면'), findsOneWidget);
    connection.add(true);
    await tester.pump();
    expect(find.byType(MosiConnectionBand), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('연결 신호만 돌아와도 세션 복구가 끝나기 전에는 입력을 풀지 않는다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    final recovery = Completer<void>();
    var taps = 0;
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        onRetry: () => recovery.future,
        child: TextButton(onPressed: () => taps++, child: const Text('CALL')),
      ),
    );
    connection.add(false);
    await tester.pump();
    connection.add(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('최신 상황을 불러오는 중…'), findsOneWidget);
    await tester.tap(find.text('CALL'), warnIfMissed: false);
    expect(taps, 0);
    recovery.complete();
    await tester.pump();
    await tester.pump();
    expect(_gameInputIsBlocked(tester), isFalse);
    await tester.tap(find.text('CALL'));
    expect(taps, 1);
    expect(find.byType(MosiConnectionBand), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('상위 화면은 한 복구 배치만 실행하고 실패 뒤 수동 재시도를 기다린다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    var attempts = 0;
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        onRetry: () async {
          attempts++;
          throw StateError('unknown');
        },
        child: const Text('게임 화면'),
      ),
    );
    connection.add(false);
    await tester.pump();
    connection.add(true);
    await tester.pump();
    expect(attempts, 1);
    await tester.pump(const Duration(seconds: 60));
    expect(attempts, 1);
    expect(_gameInputIsBlocked(tester), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('재단절 전의 늦은 복구 응답은 새 연결의 입력을 풀지 않는다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    final first = Completer<void>();
    final second = Completer<void>();
    var calls = 0;
    var taps = 0;
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        onRetry: () => ++calls == 1 ? first.future : second.future,
        child: TextButton(onPressed: () => taps++, child: const Text('카드 제출')),
      ),
    );
    connection.add(false);
    await tester.pump();
    connection.add(true);
    await tester.pump();
    connection.add(false);
    await tester.pump();
    connection.add(true);
    await tester.pump();
    expect(calls, 1, reason: '진행 중 복구와 동시에 새 요청을 보내지 않는다');
    first.complete();
    await tester.pump();
    await tester.tap(find.text('카드 제출'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 2);
    second.complete();
    await tester.pump();
    await tester.pump();
    expect(_gameInputIsBlocked(tester), isFalse);
    await tester.tap(find.text('카드 제출'));
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('중첩 가드는 복구 요청을 중복하지 않는다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    var outer = 0;
    var inner = 0;
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        onRetry: () async {
          outer++;
        },
        child: AppNetworkGuard(
          connectionChanges: connection.stream,
          onRetry: () async {
            inner++;
          },
          child: const Text('게임 화면'),
        ),
      ),
    );
    connection.add(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('네트워크 연결을 확인하는 중…'), findsOneWidget);
    connection.add(true);
    await tester.pump();
    expect(outer, 1);
    expect(inner, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dispose 이후 늦은 복구 완료가 새 타이머를 만들지 않는다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    final recovery = Completer<void>();
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        onRetry: () => recovery.future,
        child: const Text('게임 화면'),
      ),
    );
    connection.add(false);
    await tester.pump();
    connection.add(true);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    recovery.completeError(StateError('늦은 실패'));
    await tester.pump(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _mount(WidgetTester tester, Widget child) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

bool _gameInputIsBlocked(WidgetTester tester) => tester
    .widgetList<AbsorbPointer>(
      find.descendant(
        of: find.byType(AppNetworkGuard),
        matching: find.byType(AbsorbPointer),
      ),
    )
    .any((pointer) => pointer.absorbing);
