// [truth_count_hint.dart] 는 라이어스 포커에서 카드를 나눠 주기 전 빈 휴대폰
// 화면에 '태블릿을 봐 주세요!' 안내를 보여 주는 파일이다.
//
// 태블릿에는 이번 판 진실/거짓 카드 장수가 나오는데, 휴대폰만 보고 있으면
// 놓치기 쉽습니다. 실제 태블릿처럼 그린 기기 그림이 위아래로 떠다니며 금빛으로
// 반짝이고, 아래 문구로 진실 카드 수를 꼭 확인하게 합니다.
// 디자인: Claude Design '라이어스 분배 전 진실 카드 확인 안내' A-1 안.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';

// ============================================================

class LiarsPokerTruthCountHint extends StatefulWidget {
  const LiarsPokerTruthCountHint({super.key});

  @override
  State<LiarsPokerTruthCountHint> createState() =>
      _LiarsPokerTruthCountHintState();
}

class _LiarsPokerTruthCountHintState extends State<LiarsPokerTruthCountHint>
    with SingleTickerProviderStateMixin {
  static const _cream = Color(0xFFF2EADB);
  static const _body = Color(0xD1F2EADB); // 크림 82%
  static const _truth = Color(0xFF7FE0A8);
  static const _gold = Color(0xFFFFD98A);
  static const _ink = Color(0xFF17110F);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final title = GameLocale.select(
      ko: '태블릿을 봐 주세요!',
      en: 'Look at the tablet!',
      zhHans: '请看平板！',
      zhHant: '請看平板！',
    );
    final before = GameLocale.select(
      ko: '카드를 나눠 주기 전에\n이번 판 ',
      en: 'Before the cards are dealt,\ncount the ',
      zhHans: '发牌之前，\n请确认本局',
      zhHant: '發牌之前，\n請確認本局',
    );
    final truth = GameLocale.select(
      ko: '진실 카드',
      en: 'truth cards',
      zhHans: '真话牌',
      zhHant: '真話牌',
    );
    final after = GameLocale.select(
      ko: '가 몇 장인지\n',
      en: ' this round.\n',
      zhHans: '有几张\n',
      zhHant: '有幾張\n',
    );
    final check = GameLocale.select(
      ko: '꼭 확인하세요',
      en: "Don't miss it!",
      zhHans: '一定要看清楚',
      zhHant: '一定要看清楚',
    );

    return Semantics(
      liveRegion: true,
      label: '$title ${before.replaceAll('\n', ' ')}$truth'
          '${after.replaceAll('\n', ' ')}$check',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final t = reduceMotion ? 0.0 : _controller.value;
                    // bob: 1.6s 동안 0 → -8 → 0 으로 부드럽게 떠오릅니다.
                    final bob = -8 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));
                    // pulse: 금빛 테두리가 0 → 22px로 번지며 사라집니다.
                    final spread = 22 * t;
                    final alpha = 0.7 * (1 - t);
                    return Transform.translate(
                      offset: Offset(0, bob),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: reduceMotion
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFE2C27E,
                                    ).withValues(alpha: alpha),
                                    spreadRadius: spread,
                                  ),
                                ],
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: const CustomPaint(
                    size: Size(200, 142),
                    painter: _RealTabletPainter(),
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'BlackHanSans',
                    fontSize: 34,
                    height: 1.2,
                    color: _cream,
                    shadows: [Shadow(color: _ink, offset: Offset(0, 3))],
                  ),
                ),
                const SizedBox(height: 18),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.55,
                      color: _body,
                    ),
                    children: [
                      TextSpan(text: before),
                      TextSpan(
                        text: truth,
                        style: const TextStyle(color: _truth),
                      ),
                      TextSpan(text: after),
                      TextSpan(
                        text: check,
                        style: const TextStyle(color: _gold),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 실제 태블릿처럼 금속 몸체·얇은 베젤·카메라·버튼·유리 반사광을 그립니다.
/// 좌표는 200×142 디자인 기준이며 크기에 맞춰 비율로 늘립니다.
class _RealTabletPainter extends CustomPainter {
  const _RealTabletPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 142);

    final buttonPaint = Paint()..color = const Color(0xFF3A3D42);
    // 위쪽 볼륨 버튼 2개, 오른쪽 전원 버튼
    canvas.drawRRect(
      RRect.fromLTRBR(60, 0, 82, 3, const Radius.circular(1.5)),
      buttonPaint,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(88, 0, 110, 3, const Radius.circular(1.5)),
      buttonPaint,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(196, 20, 199, 38, const Radius.circular(1.5)),
      buttonPaint,
    );

    // 아래 그림자
    canvas.drawRRect(
      RRect.fromLTRBR(1.5, 16.5, 198.5, 151.5, const Radius.circular(15)),
      Paint()
        ..color = const Color(0x8C000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // 금속 몸체
    const bodyRect = Rect.fromLTRB(1.5, 2.5, 198.5, 139.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(15)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B5F66), Color(0xFF2C2F34), Color(0xFF16181B)],
          stops: [0, 0.45, 1],
        ).createShader(bodyRect),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(2.5, 3.5, 197.5, 138.5, const Radius.circular(14)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x8C8A8F97),
    );

    // 베젤
    canvas.drawRRect(
      RRect.fromLTRBR(5, 6, 195, 136, const Radius.circular(12)),
      Paint()..color = const Color(0xFF07080A),
    );

    // 꺼진 화면
    const screenRect = Rect.fromLTRB(11, 11, 189, 131);
    final screen = RRect.fromRectAndRadius(
      screenRect,
      const Radius.circular(7),
    );
    canvas.drawRRect(
      screen,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1F26), Color(0xFF0B0C10), Color(0xFF050608)],
          stops: [0, 0.6, 1],
        ).createShader(screenRect),
    );

    // 비스듬한 유리 반사광
    canvas.save();
    canvas.clipRRect(screen);
    final glare = Path()
      ..moveTo(11, 11)
      ..lineTo(97, 11)
      ..lineTo(45, 131)
      ..lineTo(11, 131)
      ..close();
    canvas.drawPath(
      glare,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x29FFFFFF), Color(0x00FFFFFF)],
        ).createShader(const Rect.fromLTRB(11, 11, 97, 131)),
    );
    canvas.restore();

    // 카메라
    canvas.drawCircle(
      const Offset(100, 8.4),
      1.7,
      Paint()..color = const Color(0xFF1E2A3A),
    );
    canvas.drawCircle(
      const Offset(100, 8.4),
      0.7,
      Paint()..color = const Color(0xFF4A6A8A),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RealTabletPainter oldDelegate) => false;
}
