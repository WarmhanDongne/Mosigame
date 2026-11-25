// [noir_icons.dart] 는 시안 A의 선 아이콘(나가기·규칙 책·설정 톱니)을 그리는 공통 위젯이다.
//
// 시안 svg는 선 아이콘이다: 휴대폰 나가기 22×22 stroke 2.6, 태블릿 메뉴 34×34 stroke 2.4,
// 색 #141414(screens.md 2-1·2-2). 측정 자료에 경로 원문이 없어 같은 크기·굵기로 다시 그렸다.
// 아이콘 글꼴을 쓰지 않으므로 테스트 스크린샷에서도 그대로 보인다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';

// ============================================================

enum ElevenNoirIconKind {
  /// 휴대폰 나가기(오른쪽 문틀 + 왼쪽 화살표).
  exit,

  /// 태블릿 “게임 규칙 열기”(펼친 책).
  rules,

  /// 태블릿 “게임 설정 열기”(톱니).
  settings,
}

class ElevenNoirIcon extends StatelessWidget {
  const ElevenNoirIcon(
    this.kind, {
    super.key,
    this.size = ElevenNoirIconSpec.phoneSize,
    this.strokeWidth = ElevenNoirIconSpec.phoneStroke,
    this.color = ElevenNoirColors.ink,
  });

  /// 태블릿 메뉴 아이콘(34×34, stroke 2.4).
  const ElevenNoirIcon.tablet(this.kind, {super.key})
    : size = ElevenNoirIconSpec.tabletSize,
      strokeWidth = ElevenNoirIconSpec.tabletStroke,
      color = ElevenNoirColors.ink;

  final ElevenNoirIconKind kind;
  final double size;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _IconPainter(kind, strokeWidth, color)),
  );
}

class _IconPainter extends CustomPainter {
  const _IconPainter(this.kind, this.strokeWidth, this.color);

  final ElevenNoirIconKind kind;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 24 단위 격자로 그린 뒤 크기에 맞춘다(svg viewBox 0 0 24 24와 같은 방식).
    final scale = size.width / 24;
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (kind) {
      case ElevenNoirIconKind.exit:
        canvas.drawPath(
          Path()
            ..moveTo(14, 4)
            ..lineTo(19, 4)
            ..lineTo(19, 20)
            ..lineTo(14, 20),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(15, 12)
            ..lineTo(5, 12)
            ..moveTo(9, 8)
            ..lineTo(5, 12)
            ..lineTo(9, 16),
          paint,
        );
      case ElevenNoirIconKind.rules:
        canvas.drawPath(
          Path()
            ..moveTo(12, 6)
            ..quadraticBezierTo(8, 4, 3, 5)
            ..lineTo(3, 19)
            ..quadraticBezierTo(8, 18, 12, 20)
            ..quadraticBezierTo(16, 18, 21, 19)
            ..lineTo(21, 5)
            ..quadraticBezierTo(16, 4, 12, 6)
            ..lineTo(12, 20),
          paint,
        );
      case ElevenNoirIconKind.settings:
        canvas.drawCircle(const Offset(12, 12), 3, paint);
        final teeth = Path();
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          teeth
            ..moveTo(12 + 6.5 * math.cos(a), 12 + 6.5 * math.sin(a))
            ..lineTo(12 + 9 * math.cos(a), 12 + 9 * math.sin(a));
        }
        canvas
          ..drawPath(teeth, paint)
          ..drawCircle(const Offset(12, 12), 6.5, paint);
    }
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      kind != oldDelegate.kind ||
      strokeWidth != oldDelegate.strokeWidth ||
      color != oldDelegate.color;
}
