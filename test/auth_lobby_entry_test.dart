import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Firebase가 함께 설치한 플랫폼의 공식 테스트 초기화 도구만 사용합니다.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/core/constants/room_character.dart';
import 'package:project00/platform/auth/legal/signup_terms.dart';
import 'package:project00/platform/auth/models/onboarding_state.dart';
import 'package:project00/platform/auth/screens/login_screen.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/widgets/auth_gate.dart';
import 'package:project00/platform/home/home.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/phone/screens/phone_room_nickname.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/firebase_test_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(_FirebaseCore());
  setUpAll(initializeFirebaseAppsForTest);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final reducedMotion in [false, true]) {
    testWidgets('로그아웃은 홈 퇴장 후 로그인 화면을 유지한다 (동작 줄이기=$reducedMotion)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final users = StreamController<User?>();
      final onboarding = _Onboarding();
      final auth = _AutoGuestService();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              disableAnimations: reducedMotion,
            ),
            child: AuthGate(
              userChanges: users.stream,
              onboardingService: onboarding,
              authService: auth,
            ),
          ),
        ),
      );
      users.add(_User());
      await tester.pump();
      onboarding.states.add(
        const UserOnboarding(
          uid: 'test',
          status: OnboardingStatus.complete,
          provider: OnboardingProvider.emailLink,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(Home), findsOneWidget);
      users.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Home), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('automatic-guest-sign-in')),
        findsNothing,
      );
      expect(auth.calls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      addTearDown(users.close);
      addTearDown(onboarding.states.close);
    });
  }

  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('로그인→가입→취소는 $size에서 route·로고를 유지하고 입력을 복원한다', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final observer = _Observer();
      await tester.pumpWidget(
        MaterialApp(navigatorObservers: [observer], home: const LoginScreen()),
      );
      await tester.enterText(find.byType(TextField).first, 'sample');
      await tester.enterText(find.byType(TextField).last, 'sample-password');
      final logo = tester.element(find.byType(MosiLogo).first);
      final scaffold = tester.element(find.byType(Scaffold));
      final bounds = tester.getRect(find.byType(MosiLogo).first);
      await tester.tap(find.widgetWithText(MosiButton, '회원가입'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(observer.pushes, 1);
      expect(tester.element(find.byType(Scaffold)), same(scaffold));
      expect(tester.element(find.byType(MosiLogo).first), same(logo));
      expect(tester.getRect(find.byType(MosiLogo).first), bounds);
      // 새 가입은 약관 동의부터 받고, 동의하면 같은 화면에서 이메일 단계로 넘어갑니다.
      expect(find.text('모시겜을 시작하기 전에\n약관을 확인해 주세요'), findsOneWidget);
      expect(find.text('인증 메일 보내기'), findsNothing);
      // 화면 전환이 끝나야 약관 행을 누를 수 있습니다.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('terms-all')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('terms-continue')));
      await tester.tap(find.byKey(const ValueKey('terms-continue')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(observer.pushes, 1);
      expect(tester.element(find.byType(MosiLogo).first), same(logo));
      expect(find.text('계정 만들고 인증하기'), findsOneWidget);
      expect(find.text('비밀번호 재입력'), findsNWidgets(2));
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('회원가입을 중단할까요?'), findsOneWidget);
      await tester.tap(find.text('중단하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(RegisterScreen), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'sample',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'sample-password',
      );
      expect(observer.pushes, 2); // 앱 route와 명시적 중단 확인 모달만.
      expect(tester.element(find.byType(Scaffold)), same(scaffold));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('서버 가입 단계가 비밀번호→프로필로 바뀌어도 인증 바탕은 유지한다', (tester) async {
    // 이메일 가입은 첫 단계에서 약관에 동의해 기기에 남아 있습니다.
    await SignupConsentStore().save(
      const SignupConsents(age14: true, terms: true, privacy: true),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final users = StreamController<User?>();
    final onboarding = _Onboarding();
    final observer = _Observer();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: AuthGate(
          userChanges: users.stream,
          onboardingService: onboarding,
        ),
      ),
    );
    users.add(_User());
    await tester.pump();
    onboarding.states.add(
      const UserOnboarding(
        uid: 'test',
        status: OnboardingStatus.settingPassword,
        provider: OnboardingProvider.emailLink,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final scaffold = tester.element(find.byType(Scaffold));
    final logo = tester.element(find.byType(MosiLogo));
    expect(find.text('비밀번호 재입력'), findsNWidgets(2)); // 라벨과 입력 힌트.
    onboarding.states.add(
      const UserOnboarding(
        uid: 'test',
        status: OnboardingStatus.settingProfile,
        provider: OnboardingProvider.emailLink,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    // ProfileSetupScreen이 최초 프레임에서 약관 동의 상태를
    // 비동기로 복원한 다음 프레임에 완료 버튼을 그립니다.
    await tester.pump();
    expect(find.text('가입 완료'), findsOneWidget);
    expect(observer.pushes, 1);
    expect(tester.element(find.byType(Scaffold)), same(scaffold));
    expect(tester.element(find.byType(MosiLogo)), same(logo));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    addTearDown(users.close);
    addTearDown(onboarding.states.close);
  });

  testWidgets('인증 대기 화면이 퇴장 중이어도 지난 타이머가 로그인 상태를 지우지 않는다', (tester) async {
    final users = StreamController<User?>();
    final auth = _AutoGuestService();
    var timeouts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          userChanges: users.stream,
          onboardingService: _Onboarding(),
          authService: auth,
          onAuthRestoreTimeout: () => timeouts++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 7900));
    users.add(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(timeouts, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('automatic-guest-sign-in')), findsNothing);
    expect(auth.calls, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    addTearDown(users.close);
  });

  testWidgets('입장 중 중복 요청을 막고 서버 거절을 버튼 바로 위에 표시한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _RoomService();
    final provider = _RoomProvider(service);
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneRoomNickname(roomCode: 'ABCDE', provider: provider),
      ),
    );
    await tester.pump();
    expect(find.widgetWithText(MosiButton, '수정'), findsNothing);
    await tester.enterText(find.byType(TextField), '방전용닉네임');
    final button = find.widgetWithText(MosiButton, '입장하기');
    await tester.tap(button);
    await tester.pump();
    expect(service.calls, 1);
    expect(service.sentNickname, '방전용닉네임');
    expect(
      roomCharacters.map((character) => character.id),
      contains(service.sentCharacterId),
    );
    expect(find.text('입장하는 중…'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is MosiButton && widget.label == '입장하기',
      ),
    );
    expect(service.calls, 1);
    service.response.completeError(
      FirebaseFunctionsException(
        code: 'invalid-argument',
        message: '올바른 캐릭터를 선택해주세요.',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final error = find.text('올바른 캐릭터를 선택해주세요.');
    expect(error, findsOneWidget);
    final errorRect = tester.getRect(error);
    final buttonRect = tester.getRect(find.widgetWithText(MosiButton, '입장하기'));
    expect(errorRect.top, greaterThan(0));
    expect(errorRect.bottom, lessThan(buttonRect.top));
    expect(buttonRect.bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('8개 캐릭터가 기존 4열 GUI로 스크롤 없이 한 화면에 보인다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _RoomProvider(_RoomService());
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneRoomNickname(roomCode: 'ABCDE', provider: provider),
      ),
    );
    await tester.pump();

    expect(roomCharacters, hasLength(8));
    for (final character in roomCharacters) {
      expect(find.text(character.localizedLabel), findsOneWidget);
    }
    final scrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          widget.axisDirection == AxisDirection.down &&
          widget.physics is! NeverScrollableScrollPhysics,
    );
    expect(scrollable, findsOneWidget);
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      0,
    );
    expect(find.widgetWithText(MosiButton, '입장하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('선택 직후 캐릭터가 선점되면 최신 목록으로 바꾸어 한 번 재시도한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _RoomService()..characterConflictFailures = 1;
    final provider = _RoomProvider(service);
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneRoomNickname(roomCode: 'ABCDE', provider: provider),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '방전용닉네임');

    await tester.tap(find.widgetWithText(MosiButton, '입장하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(provider.previewRefreshes, 1);
    expect(service.calls, 2);
    expect(service.sentCharacterIds, hasLength(2));
    expect(service.sentCharacterIds[1], isNot(service.sentCharacterIds[0]));
    expect(find.text('이미 선택된 캐릭터입니다.'), findsNothing);

    service.response.completeError(
      FirebaseFunctionsException(code: 'unavailable', message: '연결 실패'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('서버에서 캐릭터 충돌이 연속되어도 거절된 후보를 제외하고 계속 입장한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _RoomService()..characterConflictFailures = 2;
    final provider = _RoomProvider(service);
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneRoomNickname(roomCode: 'ABCDE', provider: provider),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '방전용닉네임');

    await tester.tap(find.widgetWithText(MosiButton, '입장하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(provider.previewRefreshes, 2);
    expect(service.calls, 3);
    expect(service.sentCharacterIds.toSet(), hasLength(3));
    expect(find.text('이미 선택된 캐릭터입니다.'), findsNothing);

    service.response.completeError(
      FirebaseFunctionsException(code: 'unavailable', message: '연결 실패'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('입장 직전 미리보기에서 캐릭터 선점을 확인해도 빈 캐릭터로 계속 입장한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _RoomService();
    final provider = _RoomProvider(service);
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneRoomNickname(roomCode: 'ABCDE', provider: provider),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '방전용닉네임');

    final selectedFace = tester.widget<MosiFace>(
      find
          .byWidgetPredicate(
            (widget) => widget is MosiFace && widget.size == 60,
          )
          .first,
    );
    final takenCharacterId = selectedFace.characterId!;
    provider.players = [
      RoomPlayer(
        uid: 'other',
        nickname: '다른참가자',
        characterId: takenCharacterId,
        isConnected: true,
        seatIndex: -1,
        role: 'player',
        status: 'active',
        penaltyAttemptCount: 0,
      ),
    ];

    await tester.tap(find.widgetWithText(MosiButton, '입장하기'));
    await tester.pump();

    expect(service.calls, 1);
    expect(service.sentCharacterId, isNot(takenCharacterId));
    expect(find.text('이미 선택된 캐릭터입니다.'), findsNothing);

    service.response.completeError(
      FirebaseFunctionsException(code: 'unavailable', message: '연결 실패'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('모든 캐릭터가 점유되면 서버 요청 없이 사용 불가를 안내한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _RoomService();
    final provider = _RoomProvider(service);
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneRoomNickname(roomCode: 'ABCDE', provider: provider),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '방전용닉네임');
    provider.players = [
      for (final (index, character) in roomCharacters.indexed)
        RoomPlayer(
          uid: 'other-$index',
          nickname: '참가자$index',
          characterId: character.id,
          isConnected: true,
          seatIndex: -1,
          role: 'player',
          status: 'active',
          penaltyAttemptCount: 0,
        ),
    ];

    await tester.tap(find.widgetWithText(MosiButton, '입장하기'));
    await tester.pump();

    expect(service.calls, 0);
    expect(find.text('사용할 수 있는 캐릭터가 없습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('방 입장 닉네임으로 나를 사용할 수 없다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _RoomService();
    final provider = _RoomProvider(service);
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneRoomNickname(roomCode: 'ABCDE', provider: provider),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '나');
    await tester.tap(find.widgetWithText(MosiButton, '입장하기'));
    await tester.pump();

    expect(service.calls, 0);
    expect(find.text('닉네임으로 “나”는 사용할 수 없어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('참가자 미리보기가 늦어도 서버 검증을 위해 입장할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _RoomService();
    final provider = _RoomProvider(service, previewReadyOnListen: false);
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneRoomNickname(roomCode: 'ABCDE', provider: provider),
      ),
    );
    await tester.pump();

    expect(find.text('참가자 확인 중…'), findsOneWidget);
    expect(
      tester
          .widget<MosiButton>(find.widgetWithText(MosiButton, '입장하기'))
          .onPressed,
      isNotNull,
    );

    provider.completePreview();
    await tester.pump();

    expect(find.text('참가자 확인 중…'), findsNothing);
    expect(
      tester
          .widget<MosiButton>(find.widgetWithText(MosiButton, '입장하기'))
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
}

class _Observer extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

class _AutoGuestService extends FirebaseAuthService {
  int calls = 0;

  @override
  Future<void> signInAsGuest() {
    calls++;
    return Completer<void>().future;
  }
}

class _FirebaseCore extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async {
    final apps = await super.initializeCore();
    apps.single.options.storageBucket = 'test.appspot.com';
    return apps;
  }

  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async {
    final app = await super.initializeApp(appName, initializeAppRequest);
    app.options.storageBucket = 'test.appspot.com';
    return app;
  }
}

class _User implements User {
  @override
  bool get isAnonymous => false;
  @override
  bool get emailVerified => true;
  @override
  String get uid => 'test';
  @override
  String? get email => 'test@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Onboarding extends OnboardingService {
  final states = StreamController<UserOnboarding?>();
  @override
  Stream<UserOnboarding?> watch(String uid) => states.stream;
}

class _RoomProvider extends RoomProvider {
  _RoomProvider(this.service, {this.previewReadyOnListen = true})
    : super(service: service, gameService: _GameService());

  final _RoomService service;
  final bool previewReadyOnListen;
  int previewRefreshes = 0;

  @override
  void listenRoomPreview(String roomCode) {
    if (previewReadyOnListen) roomPreviewReady = true;
  }

  void completePreview([List<RoomPlayer> value = const []]) {
    players = value;
    roomPreviewReady = true;
    notifyListeners();
  }

  @override
  Future<bool> refreshRoomPreview(String roomCode) async {
    previewRefreshes++;
    players = [
      RoomPlayer(
        uid: 'other',
        nickname: '다른참가자',
        characterId: service.sentCharacterIds.first,
        isConnected: true,
        seatIndex: -1,
        role: 'player',
        status: 'active',
        penaltyAttemptCount: 0,
      ),
    ];
    roomPreviewReady = true;
    notifyListeners();
    return true;
  }

  @override
  void stopRoomPreview() {
    roomPreviewReady = false;
  }
}

class _RoomService implements RoomService {
  int calls = 0;
  String? sentNickname;
  String? sentCharacterId;
  final List<String> sentCharacterIds = [];
  int characterConflictFailures = 0;
  final response = Completer<void>();
  @override
  Future<void> joinRoom(
    String code,
    String nickname, {
    required String characterId,
    bool preserveProfile = false,
  }) {
    calls++;
    sentNickname = nickname;
    sentCharacterId = characterId;
    sentCharacterIds.add(characterId);
    if (calls <= characterConflictFailures) {
      return Future.error(
        FirebaseFunctionsException(
          code: 'already-exists',
          message: '이미 선택된 캐릭터입니다.',
        ),
      );
    }
    return response.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GameService implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
