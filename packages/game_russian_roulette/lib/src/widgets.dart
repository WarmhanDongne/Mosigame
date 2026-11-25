import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_russian_roulette/src/gun_art.dart';
import 'package:game_russian_roulette/src/theme.dart';
import 'package:game_russian_roulette/src/timing.dart';
import 'package:game_russian_roulette/src/view.dart';

/// 네 언어 문구를 한 줄로 고릅니다.
String rouletteText(String ko, String en, String zhHans, String zhHant) =>
    GameLocale.select(ko: ko, en: en, zhHans: zhHans, zhHant: zhHant);

//=======================위에서 본 리볼버==============================
// 총 그림은 시안(B-Anim) 좌표 그대로 [gun_art.dart]에 있습니다. 원판(r152)
// 안에서 시안은 0.82배로 그리고 총 그림의 x = 85가 회전축입니다. 이 배율이면
// 손잡이 끝과 총구 끝이 원판 가장자리에 닿습니다.
const _gunArtScale = .82 / .64;
const _gunArtPivot = 85.0;

/// 위에서 내려다본 리볼버를 그립니다.
///
/// 원점이 총의 회전축이고, 총구는 +x 방향을 봅니다. 실린더 원판(r152) 안에서는
/// [scale] 0.64입니다.
void paintRouletteGun(Canvas canvas, {double scale = 0.64, bool shot = false}) {
  canvas.save();
  canvas.scale(scale * _gunArtScale);
  canvas.translate(-_gunArtPivot, 0);
  paintRouletteGunTopArt(canvas);
  if (shot) _paintShotLines(canvas);
  canvas.restore();
}

/// 총구 앞에 튀는 붉은 선 세 줄입니다(총 그림 좌표).
void _paintShotLines(Canvas canvas) {
  final flash = Paint()
    ..color = RouletteColors.red
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(const Offset(268, 0), const Offset(304, -14), flash);
  canvas.drawLine(const Offset(268, 0), const Offset(308, 0), flash);
  canvas.drawLine(const Offset(268, 0), const Offset(304, 14), flash);
}

/// 원판 위 총의 자세입니다. 시작 연출에서 옆으로 눕혀 둔 총을 굴려 세울 때 씁니다.
@immutable
class RouletteGunPose {
  const RouletteGunPose({
    this.roll = 0,
    this.shift = 0,
    this.scale = 1,
    this.tilt = 0,
    this.lift = 0,
    this.dust,
  });

  /// 옆으로 눕혀 내려놓은 총입니다. 원판 밖으로 나가지 않게 조금 작게, 가운데로
  /// 옮겨 둡니다.
  static const lying = RouletteGunPose(roll: 90, shift: 37, scale: .94);

  /// 세워 둔(위에서 본) 총입니다.
  static const standing = RouletteGunPose();

  /// 총열을 축으로 굴린 각도(도)입니다. 90이면 옆으로 누움, 0이면 선 모습입니다.
  final double roll;

  /// 손잡이 반대쪽(-y)으로 옮기는 거리(판 px)입니다. 눕힌 총을 가운데 둡니다.
  final double shift;
  final double scale;

  /// 들어 올릴 때 살짝 기우는 각도(도, 시계 방향 +)입니다.
  final double tilt;

  /// 들린 높이(0 → 1)입니다. 높을수록 그림자가 멀어지고 흐려집니다.
  final double lift;

  /// 내려앉을 때 양옆으로 튀는 먼지 자국의 진행(0 → 1)입니다.
  final double? dust;
}

/// 원판(r152) 위에 [pose]대로 놓인 리볼버를 그림자와 함께 그립니다.
///
/// 캔버스는 원판 가운데로 옮겨 총구 방향([aim])으로 돌려 둔 상태여야 합니다.
/// 그림자는 총 방향과 상관없이 판의 오른쪽 아래로 떨어집니다.
void paintRouletteGunOnDisc(
  Canvas canvas, {
  required double aim,
  RouletteGunPose pose = RouletteGunPose.standing,
  bool shot = false,
}) {
  final roll = pose.roll * math.pi / 180;
  final side = math.sin(roll);
  final top = math.max(0.0, math.cos(roll));
  // 옆모습은 굴러가며 납작해지다 사라지고, 윗모습은 점점 넓어지며 나타납니다.
  final sideOpacity = ((pose.roll.abs() - 6) / 24).clamp(0.0, 1.0);
  final topOpacity = ((62 - pose.roll) / 26).clamp(0.0, 1.0);

  void place(Canvas c) {
    c.translate(0, -pose.shift);
    c.scale(pose.scale);
    c.rotate(pose.tilt * math.pi / 180);
    c.scale(.64 * _gunArtScale);
    c.translate(-_gunArtPivot, 0);
  }

  void body(Canvas c, {required bool shade}) {
    void layer(
      double scaleY,
      double opacity,
      double brightness,
      void Function(Canvas) art,
    ) {
      if (opacity <= 0 || scaleY.abs() < .005) return;
      c.save();
      c.scale(1, scaleY);
      final dim = shade && (opacity < 1 || brightness < 1);
      if (dim) {
        c.saveLayer(
          null,
          Paint()
            ..color = Color.fromRGBO(0, 0, 0, opacity)
            ..colorFilter = ColorFilter.matrix(<double>[
              brightness, 0, 0, 0, 0, //
              0, brightness, 0, 0, 0, //
              0, 0, brightness, 0, 0, //
              0, 0, 0, 1, 0,
            ]),
        );
      }
      art(c);
      if (dim) c.restore();
      c.restore();
    }

    layer(side, sideOpacity, .55 + .45 * side.abs(), paintRouletteGunSideArt);
    layer(top, topOpacity, .7 + .3 * top, paintRouletteGunTopArt);
  }

  // 판에 닿은 짙은 그림자와 넓게 퍼진 그림자를 겹칩니다. 들리면 멀어지고 흐려집니다.
  final h = pose.lift.clamp(0.0, 1.0);
  final shadows = <(double, double, double, double)>[
    (1, 1, .5 + h, .35 - .15 * h),
    (5 + 11 * h, 8 + 16 * h, 6 + 10 * h, .25 + .03 * h),
  ];
  final cosA = math.cos(aim);
  final sinA = math.sin(aim);
  for (final (dx, dy, blur, alpha) in shadows) {
    canvas.save();
    // 판 기준 (dx, dy)를 돌려 둔 캔버스 기준으로 바꿉니다.
    canvas.translate(dx * cosA + dy * sinA, -dx * sinA + dy * cosA);
    canvas.saveLayer(
      Rect.fromCircle(center: Offset.zero, radius: 240),
      Paint()
        ..imageFilter = ui.ImageFilter.blur(sigmaX: blur / 2, sigmaY: blur / 2)
        ..colorFilter = ColorFilter.mode(
          Color.fromRGBO(0, 0, 0, alpha),
          BlendMode.srcIn,
        ),
    );
    place(canvas);
    body(canvas, shade: false);
    canvas.restore();
    canvas.restore();
  }

  canvas.save();
  place(canvas);
  body(canvas, shade: true);
  final dust = pose.dust;
  if (dust != null && dust >= 0 && dust < 1) _paintDust(canvas, dust);
  if (shot) _paintShotLines(canvas);
  canvas.restore();
}

/// 내려앉는 순간 총 양옆으로 짧게 퍼지는 먼지 자국입니다(총 그림 좌표).
void _paintDust(Canvas canvas, double t) {
  final opacity = t < .25
      ? .75 * Curves.easeOut.transform(t / .25)
      : .75 * (1 - Curves.easeOut.transform((t - .25) / .75));
  final spread = .85 + .85 * Curves.easeOut.transform(t);
  final paint = Paint()
    ..color = RouletteColors.ink.withValues(alpha: .4 * opacity)
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round;
  const marks = <(double, double, double)>[
    (-78, 24, 9),
    (-50, 19, 7),
    (42, 30, 9),
    (70, 30, 8),
    (150, 13, 7),
    (215, 12, 6),
  ];
  for (final (x, y, length) in marks) {
    for (final sign in const [-1.0, 1.0]) {
      final dx = x < 0 ? -3 * sign : 3 * sign;
      canvas.drawLine(
        Offset(x, sign * y * spread),
        Offset(x + dx, sign * (y + length) * spread),
        paint,
      );
    }
  }
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
