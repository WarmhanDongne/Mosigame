import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/phone/phone_board.dart';
import 'package:game_final_call/phone/providers/game_stage.dart';
import 'package:game_final_call/phone/screens/game_screen.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/models/game_state.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/shared/providers/session_provider.dart';
import 'package:game_final_call/shared/services/game_service.dart';
import 'package:game_kit/game_flow/phone_game_shell.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/models/game_room_context.dart';

import 'support/firebase_test_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(FirebaseTestCore());
  setUpAll(initializeFirebaseAppsForTest);
  setUp(() {
    FirebaseAuthPlatform.instanceFor(
      app: FirebaseBackend.app,
      pluginConstants: {
        'APP_CURRENT_USER': [
          InternalUserInfo(
            uid: 'phone',
            isAnonymous: false,
            isEmailVerified: true,
          ).encode(),
          <Map<Object?, Object?>>[],
        ],
      },
    );
    expect(FirebaseBackend.auth.currentUser?.uid, 'phone');
  });

  for (final accepted in [true, false]) {
    testWidgets(
      'replacement sends before animation, locks duplicates, accepted=$accepted',
      (tester) async {
        final service = _Service();
        final game = _Controller(service);
        final args = FinalCallSessionArgs(
          roomCode: 'LATENCY',
          uid: 'phone',
          service: service,
          watchPrivateHand: true,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              finalCallSessionProvider(args).overrideWith(() => game),
            ],
            child: MaterialApp(
              home: FinalCallPhoneGame(
                roomCode: 'LATENCY',
                provider: _Room(),
                gameService: service,
                onExitRoom: () async => true,
              ),
            ),
          ),
        );
        // Use the board's real action binding without waiting for unrelated intro assets.
        FinalCallPhoneGameScreen screen() {
          final shell = tester.widget<PhoneGameShell<FinalCallPhoneStage>>(
            find.byType(PhoneGameShell<FinalCallPhoneStage>),
          );
          return (shell.content as RepaintBoundary).child!
              as FinalCallPhoneGameScreen;
        }

        final action = screen().onCompleteTurn('card');
        expect(game.calls, 1);
        await screen().onCompleteTurn('card');
        expect(game.calls, 1);
        game.reply.complete(accepted);
        await tester.pump();
        expect(screen().replacementInProgress, isTrue);
        await tester.pump(const Duration(milliseconds: 459));
        expect(screen().replacementInProgress, isTrue);
        await tester.pump(const Duration(milliseconds: 1));
        await action;
        await tester.pump();
        expect(screen().replacementInProgress, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('다음 턴으로 넘어가면 손패에 남은 카드의 교체 선택도 해제한다', (tester) async {
    final game = await _mountGame(tester);
    game.publishTurn(deadline: ServerClock.nowMillis() + 10000);
    await tester.pump();

    _screen(tester).onSelectedCardChanged('card');
    await tester.pump();
    expect(_screen(tester).selectedCardId, 'card');

    game.publishTurn(
      turnUid: 'other',
      deadline: ServerClock.nowMillis() + 10000,
      revision: 1,
    );
    await tester.pump();
    expect(_screen(tester).selectedCardId, isNull);
    expect(game.hand.single.id, 'card');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('카드 교체 중 턴 시간이 끝나면 서버 응답 전에도 선택을 해제한다', (tester) async {
    ServerClock.debugSetOffset(0);
    addTearDown(ServerClock.stop);
    final game = await _mountGame(tester);
    game.publishTurn(deadline: ServerClock.nowMillis() + 10000);
    await tester.pump();

    _screen(tester).onSelectedCardChanged('card');
    await tester.pump();
    expect(_screen(tester).selectedCardId, 'card');
    final action = _screen(tester).onCompleteTurn('card');
    expect(game.calls, 1);

    ServerClock.debugSetOffset(11000);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_screen(tester).selectedCardId, isNull);
    _screen(tester).onSelectedCardChanged('card');
    await tester.pump();
    expect(_screen(tester).selectedCardId, isNull);
    game.reply.complete(false);
    await tester.pump(const Duration(milliseconds: 210));
    await action;
    await tester.pump();
    expect(_screen(tester).selectedCardId, isNull);
    expect(_screen(tester).replacementInProgress, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

FinalCallPhoneGameScreen _screen(WidgetTester tester) {
  final shell = tester.widget<PhoneGameShell<FinalCallPhoneStage>>(
    find.byType(PhoneGameShell<FinalCallPhoneStage>),
  );
  return (shell.content as RepaintBoundary).child! as FinalCallPhoneGameScreen;
}

Future<_Controller> _mountGame(WidgetTester tester) async {
  final service = _Service();
  final game = _Controller(service);
  final args = FinalCallSessionArgs(
    roomCode: 'LATENCY',
    uid: 'phone',
    service: service,
    watchPrivateHand: true,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [finalCallSessionProvider(args).overrideWith(() => game)],
      child: MaterialApp(
        home: FinalCallPhoneGame(
          roomCode: 'LATENCY',
          provider: _Room(),
          gameService: service,
          onExitRoom: () async => true,
        ),
      ),
    ),
  );
  return game;
}

class _Controller extends FinalCallController {
  _Controller(FinalCallService service)
    : super(roomCode: 'LATENCY', uid: 'phone', service: service);
  final reply = Completer<bool>();
  int calls = 0;
  void publishTurn({
    String turnUid = 'phone',
    required int deadline,
    int revision = 0,
  }) {
    state = state.copyWith(
      loading: false,
      phase: 'playing',
      turnUid: turnUid,
      turnDeadlineAt: deadline,
      revision: revision,
      pendingDrawUid: turnUid == uid ? uid : null,
      pendingDraw: const FinalCallCard(id: 'drawn', color: 'blue', value: 2),
      hand: const [FinalCallCard(id: 'card', color: 'red', value: 3)],
    );
  }

  @override
  FinalCallGameState build() => FinalCallGameState.initial();
  @override
  bool get canCompleteTurn => true;
  @override
  Future<bool> completeTurn(String? replaceCardId) {
    calls++;
    expect(replaceCardId, 'card');
    return reply.future;
  }
}

class _Service extends Fake implements FinalCallService {}

class _Room extends Fake implements GameRoomContext {
  @override
  Stream<bool> watchServerConnection() => const Stream.empty();
}
