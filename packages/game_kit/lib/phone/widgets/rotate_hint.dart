// [rotate_hint.dart] 는 가로로만 하는 게임(예: 파이널콜)에서 첫 카드를
// 나눠 주기 전 빈 화면에 '휴대폰을 가로로 돌려 주세요' 안내를 보여 주는 파일이다.
//
// 게임 화면은 이미 가로로 고정돼 있어서, 휴대폰을 세로로 들고 있으면 화면이
// 옆으로 누워 보입니다. 세로로 서 있던 휴대폰이 가로로 눕는 그림을 반복해
// 보여 주어 손에 든 휴대폰을 돌리게 합니다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';

// ============================================================

class PhoneRotateLandscapeHint extends StatefulWidget {
  const PhoneRotateLandscapeHint({
    super.key,
    this.color = Colors.white,
    this.accent = const Color(0xFFFFC93C),
  });

  /// 글자와 휴대폰 테두리 색입니다.
  final Color color;

  /// 회전 화살표와 화면 속 강조 색입니다.
  final Color accent;

  @override
  State<PhoneRotateLandscapeHint> createState() =>
      _PhoneRotateLandscapeHintState();
}

class _PhoneRotateLandscapeHintState extends State<PhoneRotateLandscapeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
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
      ko: '휴대폰을 가로로 돌려 주세요',
      en: 'Turn your phone sideways',
      zhHans: '请把手机横过来',
      zhHant: '請把手機橫過來',
    );
    final subtitle = GameLocale.select(
      ko: '이 게임은 가로 화면으로 해요. 곧 카드를 나눠 줘요.',
      en: 'This game is played in landscape. Cards are coming soon.',
      zhHans: '这个游戏用横屏进行，马上就要发牌了。',
      zhHant: '這個遊戲用橫向畫面進行，馬上就要發牌了。',
    );
    final shadow = [
      Shadow(color: Colors.black.withValues(alpha: .55), blurRadius: 10),
    ];
    return Semantics(
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 132,
              child: reduceMotion
                  ? CustomPaint(
                      painter: _RotatingPhonePainter(
                        t: .75,
                        color: widget.color,
                        accent: widget.accent,
                      ),
                    )
                  : AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        painter: _RotatingPhonePainter(
                          t: _controller.value,
                          color: widget.color,
                          accent: widget.accent,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                shadows: shadow,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.color.withValues(alpha: .8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: shadow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 세로로 서 있던 휴대폰이 가로로 눕고, 둘레에 돌아가는 화살표가 그려집니다.
///
/// 0 → 0.2: 세로로 서 있음 · 0.2 → 0.55: 시계 방향으로 90° 눕기 ·
/// 0.55 → 0.85: 가로로 멈춤(화면이 반짝) · 0.85 → 1: 흐려지며 처음으로
class _RotatingPhonePainter extends CustomPainter {
  const _RotatingPhonePainter({
    required this.t,
    required this.color,
    required this.accent,
  });

  final double t;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final unit = size.shortestSide / 132;
    final turn = Curves.easeInOutCubic.transform(
      ((t - .2) / .35).clamp(0.0, 1.0),
    );
    final fade = t < .85 ? 1.0 : 1 - (t - .85) / .15;
    final landed = t >= .55 && t < .85;

    // 돌아가는 방향 화살표(휴대폰 둘레의 호)
    final arc = Paint()
      ..color = accent.withValues(alpha: .9 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * unit
      ..strokeCap = StrokeCap.round;
    const start = -math.pi * .78;
    const sweep = math.pi * .52;
    final radius = 58 * unit;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      start,
      sweep,
      false,
      arc,
    );
    final end = start + sweep;
    final tip = c + Offset(math.cos(end), math.sin(end)) * radius;
    final along = Offset(-math.sin(end), math.cos(end));
    final across = Offset(math.cos(end), math.sin(end));
    final head = Path()
      ..moveTo(tip.dx + along.dx * 9 * unit, tip.dy + along.dy * 9 * unit)
      ..lineTo(
        tip.dx - along.dx * 4 * unit + across.dx * 8 * unit,
        tip.dy - along.dy * 4 * unit + across.dy * 8 * unit,
      )
      ..lineTo(
        tip.dx - along.dx * 4 * unit - across.dx * 8 * unit,
        tip.dy - along.dy * 4 * unit - across.dy * 8 * unit,
      )
      ..close();
    canvas.drawPath(head, Paint()..color = accent.withValues(alpha: .9 * fade));

    // 휴대폰: 세로(폭 46 × 높이 82)에서 90° 돌아 가로로 눕습니다.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(turn * math.pi / 2);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 46 * unit, height: 82 * unit),
      Radius.circular(9 * unit),
    );
    canvas.drawRRect(
      body,
      Paint()..color = Colors.black.withValues(alpha: .35 * fade),
    );
    final screen = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 36 * unit, height: 64 * unit),
      Radius.circular(4 * unit),
    );
    canvas.drawRRect(
      screen,
      Paint()
        ..color = (landed ? accent : color).withValues(
          alpha: (landed ? .55 : .18) * fade,
        ),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = color.withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * unit,
    );
    // 노치(세로일 때 위쪽)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -35 * unit),
          width: 14 * unit,
          height: 4 * unit,
        ),
        Radius.circular(2 * unit),
      ),
      Paint()..color = color.withValues(alpha: fade),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RotatingPhonePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.color != color ||
      oldDelegate.accent != accent;
}
