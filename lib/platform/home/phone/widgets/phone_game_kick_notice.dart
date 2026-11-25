import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

/// 게임 중 강퇴된 휴대폰을 덮고 로비 복귀를 안내하는 전용 화면입니다.
class PhoneGameKickNotice extends StatefulWidget {
  const PhoneGameKickNotice({
    super.key,
    required this.onReturnToLobby,
    this.countdownDuration = const Duration(seconds: 5),
  });

  final VoidCallback onReturnToLobby;
  final Duration countdownDuration;

  @override
  State<PhoneGameKickNotice> createState() => _PhoneGameKickNoticeState();
}

class _PhoneGameKickNoticeState extends State<PhoneGameKickNotice>
    with TickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final AnimationController _door = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: widget.countdownDuration,
  )..addStatusListener(_handleCountdownStatus);

  bool _started = false;
  bool _finished = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(HapticFeedback.mediumImpact());

    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion) {
      _reveal.value = 1;
      _door.value = 1;
    } else {
      unawaited(_reveal.forward());
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_finished) unawaited(_door.forward());
        }),
      );
    }
    unawaited(_countdown.forward());
  }

  void _handleCountdownStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _countdown.stop();
    widget.onReturnToLobby();
  }

  @override
  void dispose() {
    _countdown
      ..removeStatusListener(_handleCountdownStatus)
      ..dispose();
    _door.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('phone-game-kick-notice'),
    type: MaterialType.transparency,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: AnimatedBuilder(
        animation: Listenable.merge([_reveal, _door, _countdown]),
        builder: (context, _) {
          final seconds = math.max(
            1,
            (widget.countdownDuration.inMilliseconds *
                    (1 - _countdown.value) /
                    Duration.millisecondsPerSecond)
                .ceil(),
          );
          return ClipPath(
            clipper: _KickRevealClipper(_reveal.value),
            child: ColoredBox(
              color: _navy,
              child: CustomPaint(
                painter: const _KickPatternPainter(),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: SizedBox(
                                  width: math.min(
                                    360,
                                    math.max(240, constraints.maxWidth - 44),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _KickDoor(progress: _door.value),
                                      const SizedBox(height: 30),
                                      MosiBalancedText(
                                        GameLocale.select(
                                          ko: '게임에서 나왔어요',
                                          en: 'You left the game',
                                          zhHans: '你已离开游戏',
                                          zhHant: '你已離開遊戲',
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        style: MosiFonts.sans(
                                          size: 30,
                                          weight: FontWeight.w900,
                                          color: Colors.white,
                                          height: 1.15,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        GameLocale.select(
                                          ko: '방장이 이 게임에서 내보냈어요',
                                          en: 'The host removed you from this game',
                                          zhHans: '房主已将你移出本局游戏',
                                          zhHant: '房主已將你移出本局遊戲',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: MosiFonts.sans(
                                          size: 15,
                                          weight: FontWeight.w600,
                                          color: const Color(0xFFC8C1EC),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 390),
                            child: _KickLobbyButton(
                              progress: 1 - _countdown.value,
                              onPressed: _finish,
                            ),
                          ),
                          const SizedBox(height: 14),
                          MosiBalancedText(
                            GameLocale.select(
                              ko: '$seconds초 뒤 자동으로 이동해요',
                              en: 'Moving automatically in $seconds seconds',
                              zhHans: '$seconds 秒后自动返回',
                              zhHant: '$seconds 秒後自動返回',
                            ),
                            key: const Key('phone-game-kick-countdown'),
                            textAlign: TextAlign.center,
                            style: MosiFonts.sans(
                              size: 13,
                              weight: FontWeight.w600,
                              color: const Color(0xFFA9A2CC),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _KickLobbyButton extends StatelessWidget {
  const _KickLobbyButton({required this.progress, required this.onPressed});

  final double progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 58,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Material(
          color: _sun,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: _ink, width: 3),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('phone-game-kick-lobby-button'),
            onTap: onPressed,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: const ColoredBox(color: Color(0x241E1840)),
                  ),
                ),
                Center(
                  child: Text(
                    GameLocale.select(
                      ko: '로비로 가기',
                      en: 'Go to lobby',
                      zhHans: '返回大厅',
                      zhHant: '返回大廳',
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: MosiFonts.sans(
                      size: 17,
                      weight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _KickDoor extends StatelessWidget {
  const _KickDoor({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    height: 186,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          top: -54,
          child: Opacity(
            opacity: Curves.easeOut.transform(progress),
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x38FFD54A), Color(0x00FFD54A)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -9,
          child: Container(
            width: 142,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0x800B0920),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Container(
          width: 124,
          height: 166,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _sun,
            border: Border.all(color: const Color(0xFF0B0920), width: 5),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(18),
              bottom: Radius.circular(5),
            ),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF6D6), Color(0xFFFFD54A)],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(10),
                bottom: Radius.circular(2),
              ),
            ),
            child: Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0015)
                ..rotateY(-1.25 * Curves.easeOutBack.transform(progress)),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF5B4BC4),
                  border: Border.all(color: const Color(0xFF0B0920), width: 3),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9),
                    bottom: Radius.circular(2),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 12,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0x730B0920),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 82,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _sun,
                          shape: BoxShape.circle,
                          border: Border.all(color: _ink, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _KickRevealClipper extends CustomClipper<Path> {
  const _KickRevealClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final radius = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    return Path()..addOval(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: radius * Curves.easeOutCubic.transform(progress),
      ),
    );
  }

  @override
  bool shouldReclip(_KickRevealClipper oldClipper) =>
      oldClipper.progress != progress;
}

class _KickPatternPainter extends CustomPainter {
  const _KickPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x12FFFFFF);
    for (double y = 8; y < size.height; y += 16) {
      for (double x = 8; x < size.width; x += 16) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_KickPatternPainter oldDelegate) => false;
}

const _navy = Color(0xFF1E1840);
const _ink = Color(0xFF0B0920);
const _sun = Color(0xFFFFD54A);
