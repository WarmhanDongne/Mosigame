// [startup_boot.dart] 는 시작 애니메이션 뒤에서 앱이 쓸 준비를 미리 하는 파일이다.
//
// - [Platform] : 앱 시작
// - [Startup] : Firebase·App Check·구글 SDK·에셋·로그인 상태를 준비함
//
// 즉, 시작 화면이 도는 동안 통신 준비를 끝내 두어 홈까지 한 번에 들어가기 위해
// 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:game_kit/core/diagnostics/crash_reporting.dart';
import 'package:game_kit/core/diagnostics/dev_error_overlay.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/errors/services/user_error_message.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:project00/firebase_bootstrap.dart';
import 'package:project00/game_assets/game_asset_bootstrap.dart';
import 'package:project00/games/game_registry.dart';
import 'package:project00/platform/startup/startup_single_flight.dart';
import 'package:project00/platform/update/app_update_gate.dart';

// ============================================================

/// 앱을 시작하지 못한 까닭입니다.
enum StartupFailure {
  /// 기기가 인터넷에 붙지 못했습니다.
  network,

  /// 서버가 응답하지 않습니다.
  server,
}

//=======================시작 준비==============================
/// 첫 화면을 띄운 뒤 뒤에서 도는 준비 과정입니다.
///
/// 준비가 끝나면 [ready]가 켜지고, 실패하면 [failure]가 채워집니다. 화면은
/// 이 두 값만 보고 그립니다.
///
/// 순서를 지키는 이유:
/// - Firebase 초기화는 다른 모든 것의 전제라 먼저 기다립니다.
/// - App Check는 토큰을 쓰는 호출(로그인 복원)보다 **먼저** 켭니다.
/// - 필수 업데이트를 인증 복원·자동 게스트 로그인보다 **먼저** 확인합니다.
/// - 나머지는 서로 기다릴 필요가 없어 한꺼번에 돌립니다.
class StartupBoot extends ChangeNotifier {
  StartupBoot({
    required this.appLinks,
    Future<bool> Function()? readRequiredUpdate,
  }) : _readRequiredUpdate = readRequiredUpdate ?? readAppUpdateRequired;

  /// 콜드 스타트보다 먼저 만들어 둔 링크 처리 인스턴스입니다.
  final AppLinks appLinks;
  final Future<bool> Function() _readRequiredUpdate;
  final StartupSingleFlight _startFlight = StartupSingleFlight();

  /// 홈까지 들어갈 준비가 끝났는지입니다.
  bool get ready => _ready;
  bool _ready = false;

  /// 인증 화면보다 먼저 확인한 필수 스토어 업데이트 결과입니다.
  bool get updateRequired => _updateRequired;
  bool _updateRequired = false;

  /// 시작하지 못한 까닭입니다. null이면 준비 중이거나 성공입니다.
  StartupFailure? get failure => _failure;
  StartupFailure? _failure;

  /// 앱을 열게 한 이메일 인증 링크입니다.
  Uri? get initialEmailLink => _initialEmailLink;
  Uri? _initialEmailLink;

  /// 미리 읽어 둔 로그인 상태입니다.
  ///
  /// 지금 사용자부터 바로 내보내므로 [AuthGate]가 '로그인 상태 확인' 화면을
  /// 한 번 더 띄우지 않습니다. 제때 못 읽으면 null로 두어 기존 흐름이
  /// 그대로 복원과 시간 초과를 맡습니다.
  Stream<User?>? get userChanges => _userChanges;
  Stream<User?>? _userChanges;

  /// 로그인 상태를 기다리는 최대 시간입니다.
  static const _authWait = Duration(milliseconds: 2500);

  /// 다시 시도할 때 지난 회차의 결과를 버리기 위한 번호입니다.
  int _generation = 0;

  //=======================준비 시작==============================
  Future<void> start() {
    if (_ready) return Future.value();
    return _startFlight.run(_start);
  }

  Future<void> _start() async {
    final generation = ++_generation;
    if (_failure != null) {
      _failure = null;
      notifyListeners();
    }

    // 1. Firebase 네이티브 SDK. 실패하면 앱을 열 수 없습니다.
    try {
      await initializeFirebaseBackend();
    } catch (error, stack) {
      debugPrint('Firebase 초기화 실패: $error\n$stack');
      _fail(generation, error);
      return;
    }
    if (generation != _generation) return;

    // 2. 오류 수집. 이 뒤에 나는 오류는 화면·Crashlytics로 올라갑니다.
    installDevErrorWidgetBuilder();
    await _guard(CrashReporting.initialize, '오류 수집 초기화');
    if (generation != _generation) return;

    // 3. App Check. 토큰을 쓰는 호출보다 먼저 켜야 합니다.
    await _guard(_activateAppCheck, 'Firebase App Check 초기화');
    if (generation != _generation) return;

    // 4. 인증 복원·자동 게스트 로그인보다 필수 업데이트를 먼저 판정합니다.
    // 구버전이면 AuthGate 자체를 만들지 않고 여기서 준비를 끝냅니다.
    _updateRequired = await _checkRequiredUpdate();
    if (generation != _generation) return;
    if (_updateRequired) {
      _ready = true;
      notifyListeners();
      return;
    }

    // 5. 서로 기다릴 필요가 없는 나머지 준비는 한꺼번에 합니다.
    await Future.wait([
      _guard(_loadGameAssets, '게임 에셋 저장소 초기화'),
      _guard(_readInitialEmailLink, '초기 이메일 링크 읽기'),
      _guard(_initializeGoogleSignIn, '구글 로그인 SDK 초기화'),
      _guard(_warmUpAuth, '로그인 상태 확인'),
    ]);
    if (generation != _generation) return;

    // 6. 서버 시각 보정은 계속 도는 작업이라 기다리지 않습니다.
    ServerClock.start();

    _ready = true;
    notifyListeners();
  }

  /// 실패 화면에서 다시 누를 때입니다.
  void retry() {
    if (_ready) return;
    unawaited(start());
  }

  //=======================준비 하나하나==============================
  /// 다운로드 게임 캐시 저장소만 연결합니다. 네트워크는 쓰지 않습니다.
  Future<void> _loadGameAssets() =>
      initializeGameAssets(catalog: const GameRegistry());

  /// 관찰 모드 토큰을 먼저 발급합니다. enforcement는 콘솔에서 단계적으로 켭니다.
  Future<void> _activateAppCheck() async {
    if (FirebaseBackend.isLocal) return;
    await FirebaseAppCheck.instanceFor(app: FirebaseBackend.app).activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }

  Future<void> _readInitialEmailLink() async {
    _initialEmailLink = await appLinks.getInitialLink();
  }

  /// 실패해도 앱은 시작합니다. 구글 로그인만 못 쓰고 나머지는 그대로입니다.
  Future<void> _initializeGoogleSignIn() async {
    if (FirebaseBackend.isLocal) return;
    await GoogleSignIn.instance.initialize(
      clientId: selectedFirebaseOptions.iosClientId,
      serverClientId: selectedGoogleServerClientId,
    );
  }

  /// 업데이트 확인 실패는 기존 계약대로 앱 시작을 막지 않습니다.
  Future<bool> _checkRequiredUpdate() async {
    try {
      return await _readRequiredUpdate();
    } catch (error, stack) {
      CrashReporting.recordError(error, stack, reason: '필수 업데이트 확인');
      return false;
    }
  }

  /// 기기에 저장된 로그인 정보를 미리 복원합니다.
  ///
  /// 제때 못 읽으면 [_userChanges]를 비워 둡니다. 이때 [AuthGate]가 기존처럼
  /// 복원 화면과 시간 초과 안내를 맡습니다.
  Future<void> _warmUpAuth() async {
    final auth = FirebaseBackend.auth;
    try {
      await auth.userChanges().first.timeout(_authWait);
    } on TimeoutException {
      return;
    }
    _userChanges = _seededUserChanges(auth);
  }

  /// 지금 사용자부터 내보내는 로그인 상태 스트림입니다.
  Stream<User?> _seededUserChanges(FirebaseAuth auth) async* {
    yield auth.currentUser;
    yield* auth.userChanges();
  }

  //=======================도우미==============================
  /// 시작을 막지 않는 준비입니다. 실패는 기록만 남깁니다.
  Future<void> _guard(Future<void> Function() step, String reason) async {
    try {
      await step();
    } catch (error, stack) {
      CrashReporting.recordError(error, stack, reason: reason);
    }
  }

  void _fail(int generation, Object error) {
    if (generation != _generation) return;
    _failure = isNetworkError(error)
        ? StartupFailure.network
        : StartupFailure.server;
    notifyListeners();
  }
}
