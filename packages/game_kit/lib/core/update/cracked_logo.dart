// [cracked_logo.dart] 는 업데이트 안내 화면의 가운데 그림을 그리는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Update] : 낡은 버전을 알리는 '금 간 모시겜 로고'를 그림
//
// 즉, 그림 파일 없이 로고 모양 그대로 "지금 버전이 낡았다"를 보여 주기 위해
// 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

// ============================================================

//=======================금 간 로고==============================
/// 모시겜 로고(둥근 막대 네 개)를 **색만 빼고** 금·깨진 자리를 넣어 그립니다.
///
/// 무너뜨리거나 쓰러뜨리지 않습니다. 자리·크기·둥근 모서리는 로고 그대로 두고
/// 색을 회보라로 바꿔 "낡았다"만 전합니다. 깨진 틈은 [background] 색으로 뚫어
/// 바탕이 보이게 하고, 틈의 **안쪽 두 변에만** 검정 테두리를 남깁니다.
///
/// 그림 파일을 쓰지 않는 이유: 기기 비율·밀도·다크 모드와 무관하게 선 굵기가
/// 유지되고, 업데이트 화면 때문에 큰 webp를 앱에 넣지 않아도 됩니다.
class MosiCrackedLogo extends StatefulWidget {
  const MosiCrackedLogo({
    super.key,
    this.size = 156,
    this.background = MosiColors.violet,
    this.restored = false,
  });

  /// 그림의 가로 크기입니다. 세로는 비율대로 따라갑니다.
  final double size;

  /// 깨진 틈으로 보이는 바탕색입니다. **화면 배경과 같은 색**을 넣어야
  /// 틈이 뚫린 것처럼 보입니다.
  final Color background;

  /// 업데이트가 끝난 뒤 모습입니다. 금·깨짐·느낌표 없이 온전한 로고를
  /// 흰색으로 그리고 반짝임을 더합니다.
  final bool restored;

  /// 로고 원본 좌표(84×84)에 느낌표·부스러기 자리를 더한 그림 상자입니다.
  static const Size _box = Size(128, 114);

  @override
  State<MosiCrackedLogo> createState() => _MosiCrackedLogoState();
}

class _MosiCrackedLogoState extends State<MosiCrackedLogo>
    with TickerProviderStateMixin {
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat(reverse: true);

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _sway.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height =
        widget.size * MosiCrackedLogo._box.height / MosiCrackedLogo._box.width;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_sway, _loop]),
        builder: (context, _) => CustomPaint(
          size: Size(widget.size, height),
          painter: _CrackedLogoPainter(
            background: widget.background,
            restored: widget.restored,
            // -1도 ~ +1도 사이에서 아주 조금 흔들립니다.
            sway: (_sway.value * 2 - 1) * 1.0 * math.pi / 180,
            loop: _loop.value,
          ),
        ),
      ),
    );
  }
}

class _CrackedLogoPainter extends CustomPainter {
  _CrackedLogoPainter({
    required this.background,
    required this.restored,
    required this.sway,
    required this.loop,
  });

  final Color background;
  final bool restored;
  final double sway;
  final double loop;

  /// 색이 빠진 로고입니다.
  static const Color _faded = Color(0xFFA8A2C4);

  /// 로고 막대 네 개입니다(원본 84×84 좌표).
  static const List<Rect> _bars = [
    Rect.fromLTWH(0, 0, 60, 20),
    Rect.fromLTWH(64, 0, 20, 60),
    Rect.fromLTWH(24, 64, 60, 20),
    Rect.fromLTWH(0, 24, 20, 60),
  ];

  static const Radius _corner = Radius.circular(6);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / MosiCrackedLogo._box.width;
    canvas.save();
    canvas.scale(scale);
    // 그림 상자(-16,-20 기준)를 0,0으로 옮겨 로고 원본 좌표를 그대로 씁니다.
    canvas.translate(16, 20);

    // 흔들림은 로고 가운데를 축으로 합니다.
    canvas.save();
    canvas.translate(42, 42);
    canvas.rotate(sway);
    canvas.translate(-42, -42);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = restored ? MosiColors.white : _faded;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..color = MosiColors.ink;

    if (restored) {
      for (final bar in _bars) {
        final rrect = RRect.fromRectAndRadius(bar, _corner);
        canvas
          ..drawRRect(rrect, fill)
          ..drawRRect(rrect, line);
      }
      canvas.restore();
      _paintSparkles(canvas);
      canvas.restore();
      return;
    }

    // 위쪽 막대는 가운데서 갈라져 오른쪽 조각이 조금 어긋나 있습니다.
    _bar(canvas, const Rect.fromLTWH(0, 0, 27, 20), fill, line);
    canvas.save();
    canvas.translate(46, 10);
    canvas.rotate(4 * math.pi / 180);
    canvas.translate(-46, -10);
    _bar(canvas, const Rect.fromLTWH(33, 0, 27, 20), fill, line);
    canvas.restore();
    _bar(canvas, _bars[1], fill, line);
    _bar(canvas, _bars[2], fill, line);
    _bar(canvas, _bars[3], fill, line);

    // 깨져 떨어진 자리입니다. 바탕색으로 뚫고 안쪽 두 변만 선을 남깁니다.
    _chip(canvas, const [Offset(0, 32), Offset(13, 43), Offset(0, 54)]);
    _chip(canvas, const [Offset(84, 18), Offset(70, 30), Offset(84, 42)]);
    _chip(canvas, const [Offset(58, 64), Offset(68, 76), Offset(78, 64)]);
    _chip(canvas, const [Offset(24, 84), Offset(33, 72), Offset(40, 84)]);

    // 금입니다.
    _crack(canvas, const Offset(76, 46), const [
      Offset(-6, 6),
      Offset(6, 7),
      Offset(-5, 7),
    ]);
    _crack(canvas, const Offset(48, 84), const [
      Offset(6, -8),
      Offset(-5, -7),
    ]);
    _crack(canvas, const Offset(14, 24), const [
      Offset(5, 8),
      Offset(-5, 7),
    ], width: 2.4);
    // 갈라진 자리에서 번쩍이는 짧은 금입니다.
    final blink = 0.35 + 0.65 * (0.5 - 0.5 * math.cos(loop * 2 * math.pi));
    _crack(
      canvas,
      const Offset(30, 20),
      const [Offset(-3, 6)],
      width: 2.2,
      opacity: blink,
    );
    _crack(
      canvas,
      const Offset(38, 20),
      const [Offset(3, 6)],
      width: 2.2,
      opacity: blink,
    );

    canvas.restore();

    _paintCrumbs(canvas);
    _paintBang(canvas);
    canvas.restore();
  }

  void _bar(Canvas canvas, Rect rect, Paint fill, Paint line) {
    final rrect = RRect.fromRectAndRadius(rect, _corner);
    canvas
      ..drawRRect(rrect, fill)
      ..drawRRect(rrect, line);
  }

  /// 깨진 틈 하나입니다. [points]는 막대 겉면 → 안쪽 → 겉면 순서입니다.
  ///
  /// 바탕색 삼각형을 겉면 **바깥으로 6 더 밀어** 그려서 막대 테두리 선 끝이
  /// 남지 않게 덮고, 그 다음 안쪽 두 변만 다시 그립니다.
  void _chip(Canvas canvas, List<Offset> points) {
    final inner = points[1];
    Offset pushed(Offset point) {
      final delta = point - inner;
      final length = delta.distance == 0 ? 1.0 : delta.distance;
      return point + delta / length * 6;
    }

    final cover = Path()
      ..moveTo(pushed(points[0]).dx, pushed(points[0]).dy)
      ..lineTo(inner.dx, inner.dy)
      ..lineTo(pushed(points[2]).dx, pushed(points[2]).dy)
      ..close();
    canvas.drawPath(cover, Paint()..color = background);

    final edge = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(inner.dx, inner.dy)
      ..lineTo(points[2].dx, points[2].dy);
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = MosiColors.ink,
    );
  }

  /// 꺾인 금 하나입니다. [steps]는 이어 그릴 상대 좌표입니다.
  void _crack(
    Canvas canvas,
    Offset start,
    List<Offset> steps, {
    double width = 2.6,
    double opacity = 1,
  }) {
    final path = Path()..moveTo(start.dx, start.dy);
    var cursor = start;
    for (final step in steps) {
      cursor += step;
      path.lineTo(cursor.dx, cursor.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = MosiColors.ink.withValues(alpha: opacity),
    );
  }

  /// 깨진 자리에서 떨어지는 부스러기입니다.
  void _paintCrumbs(Canvas canvas) {
    const starts = [Offset(36, 24), Offset(78, 62), Offset(20, 70)];
    const delays = [0.0, 0.4, 0.72];
    for (var i = 0; i < starts.length; i++) {
      final t = (loop + 1 - delays[i]) % 1;
      // 떨어지는 동안만 보입니다.
      final opacity = t < 0.18 ? t / 0.18 : (1 - (t - 0.18) / 0.82);
      if (opacity <= 0.02) continue;
      final offset = starts[i] + Offset(4 * t, 26 * t);
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(t * 50 * math.pi / 180);
      final crumb = Path()
        ..moveTo(0, 0)
        ..lineTo(4.6, 1.4)
        ..lineTo(3.2, 6)
        ..lineTo(-1, 4.4)
        ..close();
      canvas
        ..drawPath(
          crumb,
          Paint()..color = _faded.withValues(alpha: opacity.clamp(0, 1) * 0.9),
        )
        ..drawPath(
          crumb,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = MosiColors.ink.withValues(
              alpha: opacity.clamp(0, 1) * 0.9,
            ),
        );
      canvas.restore();
    }
  }

  /// 오른쪽 위 노랑 느낌표입니다.
  void _paintBang(Canvas canvas) {
    final bob = math.sin(loop * 2 * math.pi) * 4;
    canvas.save();
    canvas.translate(94, 2 + bob);
    canvas.rotate(math.sin(loop * 2 * math.pi) * 5 * math.pi / 180);
    canvas
      ..drawCircle(Offset.zero, 13, Paint()..color = MosiColors.sun)
      ..drawCircle(
        Offset.zero,
        13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = MosiColors.ink,
      )
      ..drawLine(
        const Offset(0, -6.5),
        const Offset(0, 1),
        Paint()
          ..strokeWidth = 3.3
          ..strokeCap = StrokeCap.round
          ..color = MosiColors.ink,
      )
      ..drawCircle(const Offset(0, 4.8), 1.8, Paint()..color = MosiColors.ink);
    canvas.restore();
  }

  /// 업데이트를 마친 로고 주변 반짝임입니다.
  void _paintSparkles(Canvas canvas) {
    const spots = [
      (Offset(-8, 6), 7.0, MosiColors.sun),
      (Offset(92, 2), 6.0, MosiColors.lime),
      (Offset(80, 76), 5.0, MosiColors.white),
    ];
    for (var i = 0; i < spots.length; i++) {
      final (center, radius, color) = spots[i];
      final t = (loop + i * 0.3) % 1;
      final grow = 0.75 + 0.4 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));
      final r = radius * grow;
      final star = Path()
        ..moveTo(center.dx, center.dy - r)
        ..lineTo(center.dx + r * 0.32, center.dy - r * 0.32)
        ..lineTo(center.dx + r, center.dy)
        ..lineTo(center.dx + r * 0.32, center.dy + r * 0.32)
        ..lineTo(center.dx, center.dy + r)
        ..lineTo(center.dx - r * 0.32, center.dy + r * 0.32)
        ..lineTo(center.dx - r, center.dy)
        ..lineTo(center.dx - r * 0.32, center.dy - r * 0.32)
        ..close();
      canvas
        ..drawPath(star, Paint()..color = color)
        ..drawPath(
          star,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = MosiColors.ink,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _CrackedLogoPainter old) =>
      old.sway != sway ||
      old.loop != loop ||
      old.restored != restored ||
      old.background != background;
}
