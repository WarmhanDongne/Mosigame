// [shorebird_patch_screen.dart] 는 여러 게임이 함께 사용하는 Shorebird 패치 확인과 진입 차단 흐름을 관리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Patch] : Shorebird 패치 확인과 진입 차단 흐름을 관리함
//
// 즉, 앱 시작 전에 필요한 코드 업데이트를 안전하게 적용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_kit/core/update/cracked_logo.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

// ============================================================

//=======================Shorebird 패치 화면==============================
/// 업데이트를 받거나 업데이트를 안내하는 동안 보여 주는 화면입니다.
///
/// 로비와 같은 차림입니다. 보라 바탕, Do Hyeon 제목, 검정 테두리와 네이비
/// 그림자가 있는 라임 버튼. 가운데 그림은 **금 간 모시겜 로고**([MosiCrackedLogo])를
/// 코드로 그립니다. 예전에는 재접속 화면(크림 바탕·연보라 원)을 감싸 썼는데,
/// 새 로비와 색·질감이 따로 놀아 이 화면만의 차림으로 분리했습니다.
///
/// 쓰이는 곳 세 군데입니다.
/// - `ShorebirdPatchGate`의 받는 중: 기다림 점을 보여 주고, 오래 걸리면
///   건너뛰기 버튼이 나타납니다.
/// - `ShorebirdPatchGate`의 받기 완료: [restored]를 켜 온전한 로고를 보여 줍니다.
/// - `AppUpdateGate`: 스토어로 보내는 안내입니다. 버튼이 바로 보입니다.
class ShorebirdPatchScreen extends StatefulWidget {
  const ShorebirdPatchScreen({
    super.key,
    this.title = '업데이트를 받는 중',
    this.message = '잠시만 기다려 주세요',
    this.buttonDelay = defaultButtonDelay,
    this.buttonLabel = '나중에 하기',
    this.onSkip,
    this.restored = false,
  });

  /// 가운데 큰 문구입니다.
  final String title;

  /// 그 아래 작은 문구입니다.
  final String message;

  /// 이 시간이 지나도 끝나지 않으면 기다림 표시가 버튼으로 바뀝니다.
  final Duration buttonDelay;

  /// 시간이 지난 뒤 나타나는 버튼 문구입니다.
  final String buttonLabel;

  /// 그 버튼을 눌렀을 때입니다. null이면 버튼을 보여 주지 않습니다.
  final VoidCallback? onSkip;

  /// 업데이트를 마친 상태입니다. 금·깨짐 없는 온전한 로고를 보여 줍니다.
  final bool restored;

  /// 기다림 표시가 버튼으로 바뀌기까지의 기본 시간입니다.
  static const Duration defaultButtonDelay = Duration(seconds: 10);

  @override
  State<ShorebirdPatchScreen> createState() => _ShorebirdPatchScreenState();
}

class _ShorebirdPatchScreenState extends State<ShorebirdPatchScreen> {
  bool _showsButton = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant ShorebirdPatchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 같은 자리에서 문구와 대기 시간만 바꿔 다시 쓰는 경우(받는 중 → 완료)가
    // 있습니다. 이전 시계를 그대로 두면 새 시간이 무시됩니다.
    if (oldWidget.buttonDelay != widget.buttonDelay ||
        (oldWidget.onSkip == null) != (widget.onSkip == null)) {
      _showsButton = false;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.onSkip == null) return;
    if (widget.buttonDelay == Duration.zero) {
      _showsButton = true;
      return;
    }
    _timer = Timer(widget.buttonDelay, () {
      if (mounted) setState(() => _showsButton = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MosiColors.violet,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final unit = constraints.biggest.shortestSide;
            // 태블릿 가로에서도 글자가 폭을 따라 과하게 커지지 않게 짧은 변을
            // 기준으로 잡습니다.
            final artWidth = (unit * 0.52).clamp(150.0, 230.0);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: unit * 0.07),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MosiCrackedLogo(
                        size: artWidth,
                        background: MosiColors.violet,
                        restored: widget.restored,
                      ),
                      SizedBox(height: unit * 0.045),
                      Text(
                        widget.title.localized,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily:
                              'packages/${MosiFonts.package}/${MosiFonts.logo}',
                          color: MosiColors.white,
                          fontSize: (unit * 0.085).clamp(26.0, 34.0),
                          height: 1.25,
                        ),
                      ),
                      SizedBox(height: unit * 0.025),
                      Text(
                        widget.message.localized,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: MosiColors.white.withValues(alpha: 0.84),
                          fontSize: (unit * 0.04).clamp(13.0, 16.0),
                          fontWeight: FontWeight.w700,
                          height: 1.55,
                        ),
                      ),
                      SizedBox(height: unit * 0.075),
                      _buildAction(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAction() {
    if (widget.onSkip != null && _showsButton) {
      return MosiButton(
        label: widget.buttonLabel,
        onPressed: widget.onSkip,
        expand: true,
      );
    }
    // 아직 기다리는 중입니다. 라임 점 세 개만 조용히 튑니다.
    return const _WaitingDots();
  }
}

//=======================기다림 점==============================
/// 라임 점 세 개가 차례로 튀는 기다림 표시입니다.
class _WaitingDots extends StatefulWidget {
  const _WaitingDots();

  @override
  State<_WaitingDots> createState() => _WaitingDotsState();
}

class _WaitingDotsState extends State<_WaitingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final t = (_controller.value + 1 - index * 0.14) % 1;
              final lift = t < 0.35 ? Curves.easeOut.transform(t / 0.35) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Transform.translate(
                  offset: Offset(0, -6 * lift),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: MosiColors.lime.withValues(
                        alpha: 0.55 + 0.45 * lift,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
