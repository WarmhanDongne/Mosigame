// 파이널콜 첫 진입의 가로 회전 안내가 손패 준비와 다음 라운드에서 사라지는지 검증합니다.
// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/phone/phone_board.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/models/game_state.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/shared/providers/session_provider.dart';
import 'package:game_final_call/shared/services/game_service.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/phone/widgets/rotate_hint.dart';

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
  });

  testWidgets('첫 분배 전만 가로 회전 안내를 보여 준다', (tester) async {
    final game = await _mountGame(tester);
    expect(find.byType(PhoneRotateLandscapeHint), findsOneWidget);
    expect(find.text('휴대폰을 가로로 돌려 주세요'), findsOneWidget);

    game.publish(
      round: 1,
      phase: 'playing',
      hand: const [FinalCallCard(id: 'card', color: 'red', value: 3)],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PhoneRotateLandscapeHint), findsNothing);

    game.publish(round: 2, phase: 'dealing', hand: const []);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PhoneRotateLandscapeHint), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('모션 감소 설정에서도 정적인 가로 회전 안내를 제공한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: PhoneRotateLandscapeHint()),
        ),
      ),
    );

    expect(find.text('휴대폰을 가로로 돌려 주세요'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PhoneRotateLandscapeHint),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(find.byType(CustomPaint), findsWidgets);
  });
}

Future<_Controller> _mountGame(WidgetTester tester) async {
  final service = _Service();
  final game = _Controller(service);
  final args = FinalCallSessionArgs(
    roomCode: 'ROTATE',
    uid: 'phone',
    service: service,
    watchPrivateHand: true,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [finalCallSessionProvider(args).overrideWith(() => game)],
      child: MaterialApp(
        home: FinalCallPhoneGame(
          roomCode: 'ROTATE',
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
    : super(roomCode: 'ROTATE', uid: 'phone', service: service);

  @override
  FinalCallGameState build() => FinalCallGameState.initial();

  void publish({
    required int round,
    required String phase,
    required List<FinalCallCard> hand,
  }) {
    state = state.copyWith(
      loading: false,
      round: round,
      phase: phase,
      hand: hand,
    );
  }
}

class _Service extends Fake implements FinalCallService {}

class _Room extends Fake implements GameRoomContext {
  @override
  Stream<bool> watchServerConnection() => const Stream.empty();
}
