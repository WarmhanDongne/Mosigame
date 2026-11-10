// 라이어스 포커 카드 앞·뒷면을 벡터 위젯으로 그립니다.

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';

/// 카드 한 장의 종류입니다. [back]은 공개되지 않은 카드입니다.
enum LiarsCardFace {
  truth('TRUTH'),
  lie('LIE'),
  back('');

  const LiarsCardFace(this.value);

  final String value;

  static LiarsCardFace fromValue(String value) => switch (value.toUpperCase()) {
    'TRUTH' => truth,
    'LIE' => lie,
    _ => back,
  };

  String get label => switch (this) {
    truth => GameLocale.select(
      ko: '진실 카드',
      en: 'Truth card',
      zhHans: '真话牌',
      zhHant: '真話牌',
    ),
    lie => GameLocale.select(
      ko: '거짓 카드',
      en: 'Lie card',
      zhHans: '谎言牌',
      zhHant: '謊言牌',
    ),
    back => GameLocale.select(
      ko: '카드 뒷면',
      en: 'Card back',
      zhHans: '卡牌背面',
      zhHant: '卡牌背面',
    ),
  };

  String get corner => switch (this) {
    truth => 'O',
    lie => '×',
    back => '',
  };
}

/// 첨부된 타로 시안의 200×320 비율입니다.
const Size liarsCardDesignSize = Size(200, 320);

/// 카드 높이 ÷ 너비입니다.
const double liarsCardAspectRatio = 320 / 200;
const Color _ink = Color(0xFF17110F);
const Color _bone = Color(0xFFF2EADB);
const Color _paper = Color(0xFFE6D8BC);
const Color _gold = Color(0xFFB9A782);
const Color _truth = Color(0xFF2E6B4E);
const Color _lie = Color(0xFFB8262B);

/// 고정 타로 비율(5 : 8)로 진실·거짓 카드 또는 뒷면을 표시합니다.
///
/// 외부 이미지가 아니라 벡터로 그려서 휴대폰 손패·태블릿 공개·룰북·결과
/// 화면에서 같은 디자인을 선명하게 공유합니다.
class LiarsPokerCardView extends StatelessWidget {
  const LiarsPokerCardView({
    super.key,
    required this.face,
    this.width,
    this.height,
    this.rounded = false,
  });

  final LiarsCardFace face;
  final double? width;
  final double? height;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: face.label,
      excludeSemantics: true,
      child: SizedBox(
        width: width ?? (height == null ? null : height! / 1.6),
        height: height ?? (width == null ? null : width! * 1.6),
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox.fromSize(
            size: liarsCardDesignSize,
            child: CustomPaint(
              painter: _TarotCardPainter(face: face, rounded: rounded),
            ),
          ),
        ),
      ),
    );
  }
}

/// 모든 제출은 진실 카드라고 주장한다는 고정 규칙을 안내하는 배지입니다.
class LiarsPokerClaimBadge extends StatelessWidget {
  const LiarsPokerClaimBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = GameLocale.select(
      ko: '진실을 주장',
      en: 'CLAIM TRUTH',
      zhHans: '宣称真话',
      zhHant: '宣稱真話',
    );
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 14,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: _truth,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _bone.withValues(alpha: .7)),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8)],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _bone,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 12 : 16,
        ),
      ),
    );
  }
}

class _TarotCardPainter extends CustomPainter {
  const _TarotCardPainter({required this.face, required this.rounded});

  final LiarsCardFace face;
  final bool rounded;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / liarsCardDesignSize.width,
      size.height / liarsCardDesignSize.height,
    );

    final outer = RRect.fromRectAndRadius(
      const Rect.fromLTWH(1, 1, 198, 318),
      Radius.circular(rounded ? 14 : 7),
    );
    canvas.drawRRect(outer, _fill(_paper));
    canvas.drawRRect(outer, _stroke(_gold, 2));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 7, 186, 306),
        Radius.circular(rounded ? 10 : 4),
      ),
      _stroke(_ink.withValues(alpha: .55), 1.2),
    );

    final arch = _archPath();
    canvas.save();
    canvas.clipPath(arch);
    if (face == LiarsCardFace.back) {
      _paintBack(canvas);
    } else {
      _paintFront(canvas, face == LiarsCardFace.truth);
    }
    canvas.restore();
    canvas.drawPath(arch, _stroke(_ink, 2.4));
    _paintCornerMarks(canvas);
    _paintPaperGrain(canvas);
    canvas.restore();
  }

  Path _archPath() => Path()
    ..moveTo(20, 238)
    ..lineTo(20, 82)
    ..quadraticBezierTo(20, 24, 100, 24)
    ..quadraticBezierTo(180, 24, 180, 82)
    ..lineTo(180, 238)
    ..quadraticBezierTo(180, 296, 100, 296)
    ..quadraticBezierTo(20, 296, 20, 238)
    ..close();

  void _paintFront(Canvas canvas, bool truth) {
    final color = truth ? _truth : _lie;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 200, 320), _fill(color));
    canvas.drawCircle(
      const Offset(100, 160),
      120,
      _fill(_ink.withValues(alpha: .12)),
    );
    if (truth) {
      canvas.drawCircle(const Offset(100, 160), 49, _stroke(_bone, 20));
      canvas.drawCircle(
        const Offset(100, 160),
        30,
        _stroke(_ink.withValues(alpha: .18), 2),
      );
    } else {
      final cross = _stroke(_bone, 20)..strokeCap = StrokeCap.square;
      canvas.drawLine(const Offset(62, 122), const Offset(138, 198), cross);
      canvas.drawLine(const Offset(138, 122), const Offset(62, 198), cross);
    }
    _paintEngraving(canvas);
  }

  void _paintBack(Canvas canvas) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, 200, 320), _fill(_ink));
    final top = Path()
      ..moveTo(20, 24)
      ..lineTo(96, 24)
      ..lineTo(20, 150)
      ..close();
    final bottom = Path()
      ..moveTo(180, 120)
      ..lineTo(180, 300)
      ..lineTo(90, 300)
      ..close();
    canvas.drawPath(top, _fill(const Color(0xFF2E2926)));
    canvas.drawPath(bottom, _fill(const Color(0xFF221C19)));

    // 시안의 얼굴 좌표는 카드 중심(100, 160)이 원점입니다.
    canvas.save();
    canvas.translate(100, 160);
    _paintCollar(canvas);
    _paintFace(canvas);
    canvas.restore();
    _paintEngraving(canvas);
  }

  void _paintCollar(Canvas canvas) {
    const collarColor = Color(0xFF3E3834);
    final collar = Path()
      ..moveTo(-70, 70)
      ..lineTo(-30, 40)
      ..lineTo(-8, 92)
      ..lineTo(10, 44)
      ..lineTo(40, 96)
      ..lineTo(52, 42)
      ..lineTo(90, 74)
      ..lineTo(80, 140)
      ..lineTo(-80, 140)
      ..close();
    canvas.drawPath(collar, _fill(collarColor));
    final folds = Path()
      ..moveTo(-46, 64)
      ..lineTo(-24, 52)
      ..lineTo(-14, 100)
      ..close()
      ..moveTo(30, 60)
      ..lineTo(46, 104)
      ..lineTo(56, 58)
      ..close();
    canvas.drawPath(
      folds,
      _fill(const Color(0xFF5A524C).withValues(alpha: .8)),
    );
  }

  void _paintFace(Canvas canvas) {
    const mouthColor = Color(0xFF3E3834);
    final head = Path()
      ..moveTo(-46, -56)
      ..cubicTo(-40, -92, 40, -92, 46, -56)
      ..cubicTo(54, -10, 40, 40, 0, 58)
      ..cubicTo(-40, 40, -54, -10, -46, -56)
      ..close();
    canvas.drawPath(head, _fill(_bone));
    final shadowHalf = Path()
      ..moveTo(0, -84)
      ..cubicTo(34, -84, 44, -70, 46, -56)
      ..cubicTo(54, -10, 40, 40, 0, 58)
      ..cubicTo(10, 30, -10, -20, 6, -50)
      ..cubicTo(12, -62, 4, -76, 0, -84)
      ..close();
    canvas.drawPath(shadowHalf, _fill(_ink));

    canvas.drawCircle(const Offset(-20, -22), 10, _stroke(_ink, 5));
    final cross = _stroke(_bone, 5)..strokeCap = StrokeCap.square;
    canvas.drawLine(const Offset(12, -32), const Offset(32, -12), cross);
    canvas.drawLine(const Offset(32, -32), const Offset(12, -12), cross);

    final mouth = Path()
      ..moveTo(-30, 8)
      ..quadraticBezierTo(0, 40, 36, 4)
      ..quadraticBezierTo(30, 30, 0, 34)
      ..quadraticBezierTo(-22, 30, -30, 8)
      ..close();
    canvas.drawPath(mouth, _fill(mouthColor));
    final teeth = _stroke(_ink, 1.6);
    for (final (from, to) in const [
      (Offset(-24, 12), Offset(-20, 22)),
      (Offset(-14, 16), Offset(-12, 27)),
      (Offset(-4, 18), Offset(-3, 30)),
      (Offset(6, 18), Offset(6, 30)),
      (Offset(16, 15), Offset(15, 27)),
      (Offset(26, 10), Offset(23, 21)),
    ]) {
      canvas.drawLine(from, to, teeth);
    }
    canvas.drawPath(
      Path()
        ..moveTo(-30, 8)
        ..quadraticBezierTo(0, 40, 36, 4),
      _stroke(_ink, 2.6),
    );
    canvas.drawPath(
      Path()
        ..moveTo(36, 4)
        ..quadraticBezierTo(42, -2, 46, -10),
      _stroke(_bone, 2),
    );
  }

  void _paintCornerMarks(Canvas canvas) {
    final paint = _stroke(_ink.withValues(alpha: .58), 1.4);
    for (final offset in const [
      Offset(14, 24),
      Offset(186, 24),
      Offset(14, 296),
      Offset(186, 296),
    ]) {
      final sx = offset.dx < 100 ? 1.0 : -1.0;
      final sy = offset.dy < 100 ? 1.0 : -1.0;
      canvas.drawLine(offset, offset + Offset(10 * sx, 0), paint);
      canvas.drawLine(offset, offset + Offset(0, 10 * sy), paint);
    }
  }

  void _paintEngraving(Canvas canvas) {
    final paint = _stroke(_bone.withValues(alpha: .16), 1);
    for (var y = 36.0; y < 290; y += 11) {
      canvas.drawLine(Offset(27, y), Offset(173, y - 4), paint);
    }
    final shade = _fill(_ink.withValues(alpha: .16));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 200, 18), shade);
    canvas.drawRect(const Rect.fromLTWH(0, 302, 200, 18), shade);
  }

  void _paintPaperGrain(Canvas canvas) {
    final paint = _stroke(_gold.withValues(alpha: .28), .55);
    for (var y = 12.0; y < 308; y += 13) {
      canvas.drawLine(Offset(9, y), Offset(15, y + 1), paint);
      canvas.drawLine(Offset(185, y + 1), Offset(191, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TarotCardPainter oldDelegate) =>
      oldDelegate.face != face || oldDelegate.rounded != rounded;
}

Paint _fill(Color color) => Paint()..color = color;

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeJoin = StrokeJoin.round;
