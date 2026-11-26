import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/core/layout/app_system_ui.dart';
import 'package:game_kit/core/layout/device_layout.dart';
import 'package:game_kit/core/sound/providers/sound_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/app.dart';
import 'package:project00/platform/startup/startup_boot.dart';
import 'package:project00/platform/startup/startup_splash.dart';
import 'package:provider/provider.dart';

void main() async {
  // 1. Flutter 프레임워크 코어와 네이티브 엔진 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();
  // 링크 처리 인스턴스 생성. 콜드 스타트 보다 먼저 생성. 이메일 인증 링크 기능도 수행
  final appLinks = AppLinks();
  final soundProvider = SoundProvider();
  final boot = StartupBoot(appLinks: appLinks);

  //=======================[ 시작 화면을 먼저 띄웁니다 ]==============================
  // Firebase·App Check·구글 SDK를 기다린 뒤에 그리면 그동안 네이티브 시작
  // 화면에서 멈춰 보입니다. 첫 프레임을 먼저 그리고 준비는 뒤에서 합니다.
  // 시작 화면은 Firebase를 쓰지 않으므로 초기화 전에 그려도 안전합니다.
  runApp(
    StartupShell(
      boot: boot,
      soundProvider: soundProvider,
      emailLinks: appLinks.uriLinkStream,
    ),
  );

  //=======================[ iOS scene 연결 이후 초기 방향 ]==============================
  // 플랫폼 기본 방향입니다. runApp 전이나 첫 화면 initState에서 적용하면 iOS
  // scene이 아직 없어 요청이 사라집니다. 기기 판별은 DeviceLayout 한 곳에서
  // 합니다(게임 종료 후 방향 복원과 같은 기준을 써야 로비 방향이 어긋나지 않습니다).
  _InitialOrientationApplier().start();

  unawaited(boot.start());
}

//=======================[ 시작 화면과 앱 사이 ]==============================
/// 준비가 끝날 때까지 시작 화면을 덮어 두고, 끝나면 걷어내며 앱을 보여 줍니다.
///
/// 앱 본체는 준비가 끝난 뒤에 만듭니다. Firebase 초기화 전에 [AuthGate]가
/// 붙으면 로그인 스트림을 먼저 열어 버리기 때문입니다.
class StartupShell extends StatefulWidget {
  const StartupShell({
    super.key,
    required this.boot,
    required this.soundProvider,
    required this.emailLinks,
  });

  final StartupBoot boot;
  final SoundProvider soundProvider;
  final Stream<Uri> emailLinks;

  @override
  State<StartupShell> createState() => _StartupShellState();
}

class _StartupShellState extends State<StartupShell> {
  /// 걷어내는 움직임까지 끝났는지입니다. 그 전까지는 앱 위에 덮여 있습니다.
  bool _splashGone = false;
  bool _soundStarted = false;

  @override
  void initState() {
    super.initState();
    widget.boot.addListener(_onBootChanged);
  }

  @override
  void dispose() {
    widget.boot.removeListener(_onBootChanged);
    super.dispose();
  }

  void _onBootChanged() {
    if (widget.boot.ready && !_soundStarted) {
      _soundStarted = true;
      // 네이티브 오디오 플러그인이 첫 화면 렌더링을 막지 않도록 앱이 올라온
      // 뒤에 사운드를 초기화합니다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(widget.soundProvider.initialize());
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final boot = widget.boot;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (boot.ready)
            ProviderScope(
              child: ChangeNotifierProvider.value(
                value: widget.soundProvider,
                child: App(
                  userChanges: boot.userChanges,
                  emailLinks: widget.emailLinks,
                  initialEmailLink: boot.initialEmailLink,
                  initialUpdateRequired: boot.updateRequired,
                  initialUpdateCheckCompleted: true,
                ),
              ),
            ),
          if (!_splashGone)
            StartupSplash(
              failure: boot.failure,
              onRetry: boot.retry,
              exiting: boot.ready,
              onExitDone: () => setState(() => _splashGone = true),
            ),
        ],
      ),
    );
  }
}

class _InitialOrientationApplier with WidgetsBindingObserver {
  bool _completed = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _applyIfReady(WidgetsBinding.instance.lifecycleState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyIfReady(WidgetsBinding.instance.lifecycleState);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _applyIfReady(state);
  }

  @override
  void didChangeMetrics() {
    _applyIfReady(WidgetsBinding.instance.lifecycleState);
  }

  void _applyIfReady(AppLifecycleState? state) {
    if (_completed || state != AppLifecycleState.resumed) return;
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final view = dispatcher.implicitView ?? dispatcher.views.firstOrNull;
    if (view == null || view.physicalSize.isEmpty) return;
    final isTablet = DeviceLayout.isTabletDevice();
    _completed = true;
    WidgetsBinding.instance.removeObserver(this);

    // scene 연결 전 요청이 남아 있어도 활성 scene에는 반드시 다시 전달합니다.
    AppOrientation.invalidate();
    if (isTablet) {
      // 첫 Flutter frame 전에 태블릿 viewport를 전체 화면으로 확정합니다.
      // 이후 로비→자리 배치에서 시스템 UI가 바뀌지 않아 요소가 재배치되지 않습니다.
      unawaited(AppSystemUi.enterTabletPlatformFullscreen());
    }
    unawaited(
      isTablet
          ? defaultTargetPlatform == TargetPlatform.iOS
                ? AppOrientation.allowPlatformRotation()
                : AppOrientation.lockPlatformLandscape()
          : AppOrientation.lockPlatformPortrait(),
    );
  }
}
