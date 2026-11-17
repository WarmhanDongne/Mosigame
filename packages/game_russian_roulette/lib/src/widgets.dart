import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_russian_roulette/src/theme.dart';
import 'package:game_russian_roulette/src/timing.dart';
import 'package:game_russian_roulette/src/view.dart';

/// 네 언어 문구를 한 줄로 고릅니다.
String rouletteText(String ko, String en, String zhHans, String zhHant) =>
    GameLocale.select(ko: ko, en: en, zhHans: zhHans, zhHant: zhHant);

//=======================위에서 본 리볼버==============================
/// 위에서 내려다본 리볼버를 그립니다.
///
/// 원점이 총의 회전축이고, 총구는 +x 방향을 봅니다. 시안 좌표(약 -229~263)를
/// 그대로 쓰므로 [scale]로 크기를 맞춥니다. 실린더 원판(r152) 안에서는 0.64입니다.
void paintRouletteGun(Canvas canvas, {double scale = 0.64, bool shot = false}) {
  const ink = RouletteColors.ink;
  const cream = RouletteColors.cream;
  canvas.save();
  canvas.scale(scale);
  canvas.translate(-41, 0);
  final fill = Paint()..color = ink;
  Paint line(double width, {double opacity = 1, Color color = cream}) => Paint()
    ..color = color.withValues(alpha: opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  RRect box(double x, double y, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  final grip = Path()
    ..moveTo(-58, -21)
    ..cubicTo(-90, -25, -130, -34, -156, -36)
    ..cubicTo(-188, -36, -188, 36, -156, 36)
    ..cubicTo(-130, 34, -90, 25, -58, 21)
    ..close();
  canvas.drawPath(grip, fill);
  canvas.drawPath(
    Path()
      ..moveTo(-70, -9)
      ..cubicTo(-105, -13, -135, -19, -166, -18),
    line(2.5, opacity: .5),
  );
  canvas.drawRRect(box(-80, -9, 18, 18, 4), fill);
  canvas.drawRRect(box(-66, -23, 66, 46, 8), fill);
  canvas.drawRRect(box(-48, -6, 28, 12, 6), line(2.5));
  canvas.drawCircle(const Offset(-57, 0), 3, Paint()..color = cream);
  canvas.drawRRect(box(-8, -33, 64, 66, 12), fill);
  canvas.drawRRect(box(-8, -33, 64, 66, 12), line(2.5));
  canvas.drawRRect(box(4, -5.5, 40, 11, 5.5), line(2.5));
  canvas.drawLine(const Offset(8, -20), const Offset(40, -20), line(2.5, opacity: .6));
  canvas.drawLine(const Offset(8, 20), const Offset(40, 20), line(2.5, opacity: .6));
  canvas.drawRRect(box(54, -17, 12, 34, 4), fill);
  canvas.drawRRect(box(64, -12.5, 8, 25, 2), Paint()..color = cream);
  canvas.drawRRect(box(71, -9, 189, 18, 9), fill);
  canvas.drawLine(const Offset(78, -3), const Offset(250, -3), line(2.5, opacity: .5));
  canvas.drawRRect(box(250, -9, 12, 18, 6), Paint()..color = RouletteColors.red);
  if (shot) {
    final flash = line(5, color: RouletteColors.red);
    canvas.drawLine(const Offset(268, 0), const Offset(304, -14), flash);
    canvas.drawLine(const Offset(268, 0), const Offset(308, 0), flash);
    canvas.drawLine(const Offset(268, 0), const Offset(304, 14), flash);
  }
  canvas.restore();
}

/// 크림색 원판 위에 놓인 리볼버입니다. [angle]은 총구 방향(라디안, 0 = 오른쪽,
/// 시계 방향이 +)입니다. 상세 미리보기·구성품에서 씁니다.
class RouletteRevolver extends StatelessWidget {
  const RouletteRevolver({
    super.key,
    this.size = 180,
    this.angle = -math.pi / 4,
    this.disc = true,
  });
  final double size;
  final double angle;
  final bool disc;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _RevolverPainter(angle: angle, disc: disc),
  );
}

class _RevolverPainter extends CustomPainter {
  const _RevolverPainter({required this.angle, required this.disc});
  final double angle;
  final bool disc;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    canvas.translate(size.width / 2, size.height / 2);
    if (disc) {
      canvas.drawCircle(Offset.zero, r, Paint()..color = RouletteColors.track);
      canvas.drawCircle(
        Offset.zero,
        r * 152 / 166,
        Paint()..color = RouletteColors.cream,
      );
    }
    canvas.rotate(angle);
    paintRouletteGun(canvas, scale: (disc ? r * 152 / 166 : r) / 152 * .64);
  }

  @override
  bool shouldRepaint(covariant _RevolverPainter old) =>
      old.angle != angle || old.disc != disc;
}

//=======================방패==============================
/// 위에서 본, 자리 앞에 세워 둔 방패 모양입니다(시안 viewBox -80 -32 160 64).
Path rouletteShieldTopPath() => Path()
  ..moveTo(-66, 10)
  ..quadraticBezierTo(0, -24, 66, 10)
  ..lineTo(62, 22)
  ..quadraticBezierTo(0, -8, -62, 22)
  ..close();

/// 세워 둔 방패를 원점 기준으로 그립니다. 볼록한 면이 -y(테이블 중앙)를 봅니다.
void paintRouletteShieldTop(
  Canvas canvas, {
  bool hit = false,
  double shadowOpacity = .55,
}) {
  final shape = rouletteShieldTopPath();
  canvas.save();
  canvas.translate(0, -12);
  canvas.scale(1.04, 1);
  canvas.drawPath(
    shape,
    Paint()..color = Colors.black.withValues(alpha: shadowOpacity),
  );
  canvas.restore();
  final base = RRect.fromRectAndRadius(
    const Rect.fromLTWH(-13, 20, 26, 7),
    const Radius.circular(3),
  );
  canvas.drawRRect(base, Paint()..color = RouletteColors.ink);
  canvas.drawRRect(
    base,
    Paint()
      ..color = RouletteColors.cream
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
  canvas.drawPath(shape, Paint()..color = RouletteColors.cream);
  canvas.drawRect(
    const Rect.fromLTWH(-9, -6, 18, 11),
    Paint()..color = RouletteColors.red,
  );
  canvas.drawPath(
    shape,
    Paint()
      ..color = RouletteColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round,
  );
  if (hit) {
    final mark = Paint()
      ..color = RouletteColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(24, -2), 4.5, Paint()..color = RouletteColors.ink);
    canvas.drawLine(const Offset(24, -2), const Offset(16, -9), mark);
    canvas.drawLine(const Offset(24, -2), const Offset(33, -8), mark);
    canvas.drawLine(const Offset(24, -2), const Offset(30, 5), mark);
  }
}

/// 위에서 본 세워 둔 방패 위젯입니다. 가로:세로 = 160:64.
class RouletteShieldTop extends StatelessWidget {
  const RouletteShieldTop({
    super.key,
    this.width = 160,
    this.hit = false,
    this.shadowOpacity = .55,
  });
  final double width;
  final bool hit;
  final double shadowOpacity;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, width * .4),
    painter: _ShieldTopPainter(hit: hit, shadowOpacity: shadowOpacity),
  );
}

class _ShieldTopPainter extends CustomPainter {
  const _ShieldTopPainter({required this.hit, required this.shadowOpacity});
  final bool hit;
  final double shadowOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 160);
    paintRouletteShieldTop(canvas, hit: hit, shadowOpacity: shadowOpacity);
  }

  @override
  bool shouldRepaint(covariant _ShieldTopPainter old) =>
      old.hit != hit || old.shadowOpacity != shadowOpacity;
}

/// 정면에서 본 방패입니다(크림 바탕, 가운데 붉은 띠). [locked]면 흐리게 그립니다.
class RouletteShield extends StatelessWidget {
  const RouletteShield({super.key, this.size = 72, this.locked = false});
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: locked ? .35 : 1,
    child: CustomPaint(
      size: Size(size * 80 / 94, size),
      painter: const _ShieldFrontPainter(),
    ),
  );
}

class _ShieldFrontPainter extends CustomPainter {
  const _ShieldFrontPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 80, size.height / 94);
    final shape = Path()
      ..moveTo(40, 4)
      ..lineTo(74, 14)
      ..lineTo(74, 46)
      ..cubicTo(74, 68, 58, 84, 40, 90)
      ..cubicTo(22, 84, 6, 68, 6, 46)
      ..lineTo(6, 14)
      ..close();
    canvas.drawPath(shape, Paint()..color = RouletteColors.cream);
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawRect(
      const Rect.fromLTWH(33, 0, 14, 94),
      Paint()..color = RouletteColors.red,
    );
    canvas.restore();
    canvas.drawPath(
      shape,
      Paint()
        ..color = RouletteColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 피격 시 한 번 재생되는 방패 충돌 위젯입니다.
class RouletteShieldImpact extends StatelessWidget {
  const RouletteShieldImpact({super.key, this.size = 154});

  final double size;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: RussianRouletteTiming.shieldImpact,
    curve: Curves.easeOut,
    builder: (context, progress, child) {
      final strength = 1 - progress;
      final shake = math.sin(progress * math.pi * 6) * 11 * strength;
      final tilt = math.sin(progress * math.pi * 5) * .09 * strength;
      return Transform.translate(
        offset: Offset(shake, 0),
        child: Transform.rotate(
          angle: tilt,
          child: Transform.scale(
            scale: .72 + Curves.easeOutBack.transform(progress) * .28,
            child: child,
          ),
        ),
      );
    },
    child: RouletteShield(size: size),
  );
}

//=======================프로필==============================
const _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// 네모난 프로필 칸입니다. 탈락자는 [gray], 방금 맞은 사람은 [crossed]로 그립니다.
class RouletteProfile extends StatelessWidget {
  const RouletteProfile({
    super.key,
    required this.characterId,
    this.size = 80,
    this.gray = false,
    this.crossed = false,
    this.crossProgress = 1,
    this.background = RouletteColors.cream,
  });

  final String? characterId;
  final double size;
  final bool gray;
  final bool crossed;

  /// X를 긋는 진행(0 → 1). 앞 절반에 첫 줄, 뒤 절반에 둘째 줄을 긋습니다.
  final double crossProgress;
  final Color background;

  @override
  Widget build(BuildContext context) {
    Widget face = Container(
      width: size,
      height: size,
      color: background,
      alignment: Alignment.center,
      child: MosiFace(characterId: characterId, size: size * .92),
    );
    if (gray) {
      face = Opacity(
        opacity: .45,
        child: ColorFiltered(colorFilter: _greyscale, child: face),
      );
    }
    if (!crossed) return SizedBox.square(dimension: size, child: face);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          face,
          Positioned.fill(
            child: CustomPaint(painter: _CrossPainter(crossProgress)),
          ),
        ],
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = RouletteColors.red
      ..strokeWidth = size.width * .085
      ..strokeCap = StrokeCap.square;
    final m = size.width * .08;
    final first = (progress * 2).clamp(0.0, 1.0);
    final second = (progress * 2 - 1).clamp(0.0, 1.0);
    final a = Offset(m, m);
    final b = Offset(size.width - m, size.height - m);
    final c = Offset(size.width - m, m);
    final d = Offset(m, size.height - m);
    if (first > 0) canvas.drawLine(a, Offset.lerp(a, b, first)!, p);
    if (second > 0) canvas.drawLine(c, Offset.lerp(c, d, second)!, p);
  }

  @override
  bool shouldRepaint(covariant _CrossPainter old) => old.progress != progress;
}

/// 예전 둥근 아바타입니다. 다른 화면 호환용으로 남겨 둡니다.
class RouletteAvatar extends StatelessWidget {
  const RouletteAvatar({
    super.key,
    required this.player,
    this.target = false,
    this.action,
    this.size = 64,
  });
  final RoulettePlayerView player;
  final bool target;
  final RouletteAction? action;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    color: target ? RouletteColors.red : RouletteColors.cream,
    child: RouletteProfile(
      characterId: player.characterId,
      size: size,
      gray: !player.alive,
    ),
  );
}

//=======================행동 아이콘·이름==============================
IconData rouletteActionIcon(RouletteAction action) => switch (action) {
  RouletteAction.spin => Icons.rotate_right,
  RouletteAction.shield => Icons.shield,
  RouletteAction.none => Icons.remove_circle_outline,
};

String rouletteActionShort(RouletteAction action) => switch (action) {
  RouletteAction.spin => rouletteText('돌리기', 'Spin', '转动', '轉動'),
  RouletteAction.shield => rouletteText('방패', 'Shield', '护盾', '護盾'),
  RouletteAction.none => rouletteText('안 함', 'Pass', '不行动', '不行動'),
};

/// 행동 칩(돌리기 빨강 · 방패 크림 · 안 함 먹색)입니다.
class RouletteActionChip extends StatelessWidget {
  const RouletteActionChip({super.key, required this.action, this.size = 17});
  final RouletteAction action;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (action) {
      RouletteAction.spin => (RouletteColors.red, RouletteColors.cream),
      RouletteAction.shield => (RouletteColors.cream, RouletteColors.ink),
      RouletteAction.none => (RouletteColors.ink, RouletteColors.cream),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        border: action == RouletteAction.none
            ? Border.all(color: RouletteColors.cream, width: 1.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(rouletteActionIcon(action), color: fg, size: size + 1),
          const SizedBox(width: 6),
          Text(rouletteActionShort(action), style: RouletteType.display(size, fg)),
        ],
      ),
    );
  }
}
