// [startup_splash.dart] 는 앱을 열 때 처음 보이는 시작 화면을 그리는 파일이다.
//
// - [Platform] : 앱 시작
// - [Startup] : 로고가 펼쳐지고 도는 동안 준비를 기다리고, 실패를 알림
//
// 즉, 준비가 끝날 때까지의 시간을 멈춘 화면 대신 로고 움직임으로 채우기 위해
// 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/startup/startup_boot.dart';

// ============================================================

/// 네이티브 시작 화면의 아이콘 바탕색입니다(`mosigame_app_icon.svg`).
const _iconViolet = Color(0xFF5B47E0);

/// 아이콘 안에서 막대가 차지하는 비율입니다(1024 기준 481.28).
const _iconBarRatio = 0.47;

/// 아이콘 모서리 비율입니다(1024 기준 229.07).
const _iconRadiusRatio = 0.2237;

/// 장면이 바뀌는 시각입니다.
const _grow = 500;
const _spinEnd = 1300;
const _wordEnd = 1700;
const _introEnd = 2100;

/// 준비가 늦어질 때 안내가 붙는 시각입니다.
const _waitingAt = Duration(milliseconds: 2500);
const _retryAt = Duration(seconds: 8);

//=======================시작 화면==============================
/// 로고가 화면으로 펼쳐지고 바람개비처럼 도는 시작 화면입니다.
///
/// 첫 프레임은 네이티브 시작 화면(흰 바탕 + 보라 아이콘)과 같은 그림이라
/// 엔진이 바뀌는 순간이 보이지 않습니다.
class StartupSplash extends StatefulWidget {
  const StartupSplash({
    super.key,
    required this.failure,
    required this.onRetry,
    required this.exiting,
    required this.onExitDone,
  });

  /// 시작하지 못한 까닭입니다. null이면 준비 중입니다.
  final StartupFailure? failure;

  /// 다시 시도를 눌렀을 때입니다.
  final VoidCallback onRetry;

  /// 준비가 끝나 화면을 걷어낼 때입니다.
  final bool exiting;

  /// 걷어내는 움직임이 끝났을 때입니다.
  final VoidCallback onExitDone;

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _introEnd),
  )..forward();

  /// 준비가 늦어질 때 90도씩 이어 도는 움직임입니다.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  Timer? _waitingTimer;
  Timer? _retryTimer;
  bool _waitingShown = false;
  bool _retryShown = false;

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener(_onIntroDone);
    _exit.addStatusListener(_onExitDone);
    _waitingTimer = Timer(_waitingAt, () {
      if (mounted) setState(() => _waitingShown = true);
    });
    _retryTimer = Timer(_retryAt, () {
      if (mounted) setState(() => _retryShown = true);
    });
    if (widget.exiting) _startExit();
  }

  /// 걷어내기는 인트로가 끝난 뒤에 시작합니다.
  ///
  /// 준비가 아주 빨리 끝나도 로고가 펼쳐지다 만 채로 사라지지 않게 합니다.
  /// 도는 중이면 멈추지 않고 돌면서 사라집니다.
  void _startExit() {
    if (_exit.isAnimating || _exit.isCompleted) return;
    if (!_intro.isCompleted) return;
    _exit.forward();
  }

  @override
  void didUpdateWidget(covariant StartupSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exiting && !oldWidget.exiting) _startExit();
    // 실패 화면에서는 돌리지 않습니다. 멈춘 상태라는 것을 보여 줍니다.
    if (widget.failure != null && _spin.isAnimating) _spin.stop();
    if (widget.failure == null &&
        oldWidget.failure != null &&
        _intro.isCompleted) {
      _spin.repeat();
    }
  }

  void _onIntroDone(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (widget.exiting) {
      _startExit();
      return;
    }
    if (widget.failure != null) return;
    _spin.repeat();
  }

  void _onExitDone(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onExitDone();
  }

  @override
  void dispose() {
    _waitingTimer?.cancel();
    _retryTimer?.cancel();
    _intro.dispose();
    _spin.dispose();
    _exit.dispose();
    super.dispose();
  }

  /// 네이티브 시작 화면이 아이콘을 그리는 크기입니다.
  double get _startSize => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => 120,
    _ => 48,
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final unit = math.min(width, height);
      final logo = (unit * 0.36).clamp(120.0, 220.0);
      return AnimatedBuilder(
        animation: Listenable.merge([_intro, _spin, _exit]),
        builder: (context, _) {
          final exit = Curves.easeIn.transform(_exit.value);
          return Opacity(
            opacity: 1 - exit,
            child: Stack(
              children: [
                // 네이티브 시작 화면과 같은 흰 바탕입니다.
                const Positioned.fill(child: ColoredBox(color: Colors.white)),
                _tile(width, height),
                _logo(logo, exit),
                _below(logo, height, exit),
              ],
            ),
          );
        },
      );
    },
  );

  /// 아이콘이 화면으로 펼쳐집니다. 검은 겹침 없이 이 사각형이 곧 배경이 됩니다.
  Widget _tile(double width, double height) {
    final t = Curves.easeInOutCubic.transform(
      (_intro.value * _introEnd / _grow).clamp(0.0, 1.0),
    );
    final start = _startSize;
    return Center(
      child: Container(
        width: start + (width - start) * t,
        height: start + (height - start) * t,
        decoration: BoxDecoration(
          color: Color.lerp(_iconViolet, MosiColors.violet, t),
          borderRadius: BorderRadius.circular(
            start * _iconRadiusRatio * (1 - t),
          ),
        ),
      ),
    );
  }

  /// 로고 막대 넷입니다. 펼쳐지며 커지고, 그다음 90도씩 돕니다.
  Widget _logo(double logo, double exit) {
    final elapsed = _intro.value * _introEnd;
    final growT = Curves.easeInOutCubic.transform(
      (elapsed / _grow).clamp(0.0, 1.0),
    );
    final startScale = _startSize * _iconBarRatio / logo;
    final scale = startScale + (1 - startScale) * growT;
    final spinT = Curves.easeOut.transform(
      ((elapsed - _grow) / (_spinEnd - _grow)).clamp(0.0, 1.0),
    );
    // 90도마다 같은 모양이라 이어 돌아도 끊겨 보이지 않습니다.
    // repeat()을 멈춰도 마지막 값이 남아 각도가 튀지 않습니다.
    final loopT = const Cubic(
      0.45,
      0.05,
      0.3,
      1,
    ).transform((_spin.value / 0.8).clamp(0.0, 1.0));
    return Center(
      child: Transform.translate(
        offset: Offset(0, -24 * exit),
        child: Transform.scale(
          scale: scale * (1 - 0.06 * exit),
          child: Transform.rotate(
            angle: (spinT + loopT) * math.pi / 2,
            child: CustomPaint(
              size: Size.square(logo),
              painter: const _LogoBarsPainter(),
            ),
          ),
        ),
      ),
    );
  }

  /// 로고 아래 칸입니다. 워드마크·한 줄 설명·안내·실패 문구가 여기 들어갑니다.
  Widget _below(double logo, double height, double exit) {
    final elapsed = _intro.value * _introEnd;
    final failure = widget.failure;
    return Positioned(
      left: 0,
      right: 0,
      top: height / 2 + logo / 2 + logo * 0.24,
      bottom: 0,
      child: Transform.translate(
        offset: Offset(0, -24 * exit),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: failure != null
                  ? _failureBlock(failure)
                  : _introBlock(elapsed, logo),
            ),
          ),
        ),
      ),
    );
  }

  Widget _introBlock(double elapsed, double logo) {
    final wordT = Curves.easeOut.transform(
      ((elapsed - _spinEnd) / (_wordEnd - _spinEnd)).clamp(0.0, 1.0),
    );
    final tagT = Curves.easeOut.transform(
      ((elapsed - _wordEnd) / (_introEnd - _wordEnd)).clamp(0.0, 1.0),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: wordT,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - wordT)),
            child: SvgPicture.asset(
              'assets/images/logo/mosigame_wordmark_dark.svg',
              width: logo * 1.2,
              semanticsLabel: '모시겜',
            ),
          ),
        ),
        const SizedBox(height: 14),
        Opacity(
          opacity: tagT * 0.82,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - tagT)),
            child: Text(
              _text(
                ko: '태블릿과 휴대폰으로 함께',
                en: 'Tablet and phones, together',
                zhHans: '平板和手机，一起玩',
                zhHant: '平板和手機，一起玩',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MosiColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        // 2.5초가 지나도 준비가 안 끝나면 그때 한 줄만 붙입니다.
        AnimatedOpacity(
          opacity: _waitingShown ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: Text(
            _text(
              ko: '서버에 연결하는 중…',
              en: 'Connecting to the server…',
              zhHans: '正在连接服务器…',
              zhHant: '正在連線伺服器…',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MosiColors.white.withValues(alpha: 0.72),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 8초가 지나면 기다리는 것 말고 할 수 있는 일을 줍니다.
        if (_retryShown)
          MosiButton(
            label: _text(
              ko: '다시 시도',
              en: 'Try again',
              zhHans: '重试',
              zhHant: '重試',
            ),
            expand: true,
            onPressed: widget.onRetry,
          ),
      ],
    );
  }

  Widget _failureBlock(StartupFailure failure) {
    final (title, message) = switch (failure) {
      StartupFailure.network => (
        _text(
          ko: '인터넷에 연결할 수 없어요',
          en: 'No internet connection',
          zhHans: '无法连接到网络',
          zhHant: '無法連線到網路',
        ),
        _text(
          ko: 'Wi-Fi나 데이터가 켜져 있는지 확인한 뒤 다시 시도해 주세요.',
          en: 'Check your Wi-Fi or mobile data, then try again.',
          zhHans: '请确认已开启 Wi-Fi 或移动数据后重试。',
          zhHant: '請確認已開啟 Wi-Fi 或行動數據後重試。',
        ),
      ),
      StartupFailure.server => (
        _text(
          ko: '지금은 서버에 연결할 수 없어요',
          en: 'Can’t reach the server right now',
          zhHans: '目前无法连接服务器',
          zhHant: '目前無法連線伺服器',
        ),
        _text(
          ko: '잠시 뒤에 다시 시도해 주세요. 점검 중일 수 있어요.',
          en: 'Please try again shortly. It may be under maintenance.',
          zhHans: '请稍后再试，可能正在维护。',
          zhHant: '請稍後再試，可能正在維護。',
        ),
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'packages/${MosiFonts.package}/${MosiFonts.logo}',
            color: MosiColors.white,
            fontSize: 26,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MosiColors.white.withValues(alpha: 0.84),
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 28),
        MosiButton(
          label: _text(
            ko: '다시 시도',
            en: 'Try again',
            zhHans: '重试',
            zhHant: '重試',
          ),
          expand: true,
          onPressed: widget.onRetry,
        ),
      ],
    );
  }

  /// 아직 사용자가 고른 언어를 읽기 전이라 기기 언어를 씁니다.
  String _text({
    required String ko,
    required String en,
    String? zhHans,
    String? zhHant,
  }) {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return GameLocale.selectFor(
      locale,
      ko: ko,
      en: en,
      zhHans: zhHans ?? en,
      zhHant: zhHant ?? zhHans ?? en,
    );
  }
}

//=======================로고 막대==============================
/// 모시겜 로고의 둥근 막대 넷입니다(원본 84×84 좌표).
///
/// 그림 파일을 쓰지 않는 이유: 첫 프레임이 네이티브 시작 화면과 정확히 같아야
/// 하는데, 파일을 읽어 그리면 한 프레임 비어 보일 수 있습니다.
class _LogoBarsPainter extends CustomPainter {
  const _LogoBarsPainter();

  static const _bars = [
    Rect.fromLTWH(0, 0, 60, 20),
    Rect.fromLTWH(64, 0, 20, 60),
    Rect.fromLTWH(24, 64, 60, 20),
    Rect.fromLTWH(0, 24, 20, 60),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 84);
    final paint = Paint()..color = MosiColors.white;
    for (final bar in _bars) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(6)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LogoBarsPainter oldDelegate) => false;
}
