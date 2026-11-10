// 라이어스의 월넛 테이블 배경을 이미지 없이 캔버스로 그립니다.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 짙은 월넛 판자·나뭇결·긁힘·희미한 컵 자국을 그리는 게임 배경입니다.
///
/// 해상도별 이미지 파일 대신, 태블릿과 휴대폰 크기에 맞춰 같은 결을 다시
/// 계산합니다. 화면을 가로로 돌려도 판자 방향은 실제 테이블처럼 가로를 유지합니다.
class LiarsPokerWoodTableBackground extends StatelessWidget {
  const LiarsPokerWoodTableBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: const _WalnutTablePainter(),
      child: SizedBox.expand(child: child),
    ),
  );
}

class _WalnutTablePainter extends CustomPainter {
  const _WalnutTablePainter();

  static const _base = Color(0xFF351707);
  static const _deep = Color(0xFF140805);
  static const _warm = Color(0xFF895027);
  static const _light = Color(0xFFC07A42);

  @override
  void paint(Canvas canvas, Size size) {
    final surface = Offset.zero & size;
    canvas.drawRect(surface, Paint()..color = _base);

    // 좌측은 그늘지고 우측 가장자리에는 오래 닳은 목재의 따뜻한 반사가 남습니다.
    canvas.drawRect(
      surface,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_deep, Color(0x00140805), Color(0x88542915)],
          stops: [0, .47, 1],
        ).createShader(surface),
    );
    canvas.drawRect(
      surface,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(.92, .18),
          radius: 1.04,
          colors: [_light.withValues(alpha: .28), Colors.transparent],
          stops: const [0, .72],
        ).createShader(surface),
    );

    _paintPlanks(canvas, size);
    _paintGrain(canvas, size);
    _paintKnots(canvas, size);
    _paintScratches(canvas, size);
    _paintVignette(canvas, surface);
  }

  void _paintPlanks(Canvas canvas, Size size) {
    final seams = <double>[.055, .172, .336, .502, .673, .844, .955];
    for (var index = 0; index < seams.length; index++) {
      final y = size.height * seams[index];
      final dark = Paint()
        ..color = _deep.withValues(alpha: index.isEven ? .78 : .58)
        ..strokeWidth = math.max(1.2, size.height * .0032);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), dark);
      canvas.drawLine(
        Offset(0, y + dark.strokeWidth + 1),
        Offset(size.width, y + dark.strokeWidth + 1),
        Paint()
          ..color = _warm.withValues(alpha: .28)
          ..strokeWidth = math.max(.6, size.height * .0011),
      );
    }
  }

  void _paintGrain(Canvas canvas, Size size) {
    final count = (size.height / 11).ceil().clamp(55, 130);
    for (var index = 0; index < count; index++) {
      final phase = index * 1.913;
      final y = ((index * 29.7) % size.height) + 2;
      final amplitude = 1.5 + (index % 5) * .7;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 28) {
        final offset = math.sin(phase + x / (31 + index % 7)) * amplitude;
        path.lineTo(x, y + offset);
      }
      final isLight = index % 4 == 0;
      canvas.drawPath(
        path,
        Paint()
          ..color = (isLight ? _light : _deep).withValues(
            alpha: isLight ? .16 : .24,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = isLight ? .65 : 1.05
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintKnots(Canvas canvas, Size size) {
    final knots = <(Offset, Size)>[
      (
        Offset(size.width * .09, size.height * .23),
        Size(size.width * .07, size.height * .035),
      ),
      (
        Offset(size.width * .17, size.height * .79),
        Size(size.width * .12, size.height * .055),
      ),
      (
        Offset(size.width * .86, size.height * .88),
        Size(size.width * .1, size.height * .043),
      ),
    ];
    for (final knot in knots) {
      for (var ring = 0; ring < 3; ring++) {
        final scale = 1 + ring * .24;
        final rect = Rect.fromCenter(
          center: knot.$1,
          width: knot.$2.width * scale,
          height: knot.$2.height * scale,
        );
        canvas.drawOval(
          rect,
          Paint()
            ..color = _deep.withValues(alpha: .28 - ring * .06)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
    // 사진처럼 오래 놓여 있던 컵의 둥근 자국도 아주 희미하게 남깁니다.
    for (final center in [
      Offset(size.width * .88, size.height * .09),
      Offset(size.width * .09, size.height * .8),
    ]) {
      canvas.drawCircle(
        center,
        math.min(size.width, size.height) * .08,
        Paint()
          ..color = _deep.withValues(alpha: .28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _paintScratches(Canvas canvas, Size size) {
    for (var index = 0; index < 80; index++) {
      final seed = math.sin(index * 19.71) * 43758.5453;
      final fraction = seed - seed.floorToDouble();
      final y = ((index * 67.3) % size.height) + 4;
      final x = (fraction * size.width * .96) - size.width * .04;
      final length = size.width * (.015 + ((index * 17) % 9) * .006);
      final slope = ((index % 5) - 2) * .45;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + length, y + slope),
        Paint()
          ..color = (index.isEven ? _light : _deep).withValues(alpha: .16)
          ..strokeWidth = index % 7 == 0 ? 1.5 : .65
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintVignette(Canvas canvas, Rect surface) {
    canvas.drawRect(
      surface,
      Paint()
        ..shader = RadialGradient(
          radius: 1.12,
          colors: [Colors.transparent, _deep.withValues(alpha: .46)],
          stops: const [.42, 1],
        ).createShader(surface),
    );
  }

  @override
  bool shouldRepaint(covariant _WalnutTablePainter oldDelegate) => false;
}
