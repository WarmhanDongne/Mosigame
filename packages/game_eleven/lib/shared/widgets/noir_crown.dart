// [noir_crown.dart] 는 시안 A의 빨간 왕관과 승리 조각을 그리는 공통 위젯이다.
//
// - 왕관 svg(screens.md 2-1): `viewBox 0 0 54 34`, path `M4 30 L8 8 L19 20 L27 3 L35 20 L46 8
//   L50 30 Z`, fill #e23a3a, stroke #141414 3, round. 태블릿 54×34, 휴대폰 76×44.
// - 조각(프로토타입 ⑥ `kESp0–5` 원자료): 10×10, 테두리 2px #141414, 반경 2, 크림 #f7f0e4과
//   경고 빨강 #d42a2f를 번갈아, 왕관 가운데에서 출발해 `ElevenGameEndMotion.sparks` 위치로 퍼진다.
// 움직임(시점·곡선)은 noir_motion.dart의 `ElevenGameEndMotion`·`ElevenPhoneEndMotion`을 쓴다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:game_eleven/shared/noir/noir_motion.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';

// ============================================================

class ElevenNoirCrown extends StatelessWidget {
  const ElevenNoirCrown({super.key, this.size = tabletSize});

  /// 태블릿(T10·T13·T13-B 승자 측) 54×34.
  static const tabletSize = Size(54, 34);

  /// 휴대폰(P10·P11) 76×44.
  static const phoneSize = Size(76, 44);

  /// 왕관 아래 여백: 태블릿 `margin-bottom:-10px`, 휴대폰 `-16px`.
  static const tabletOverlap = -10.0;
  static const phoneOverlap = -16.0;

  final Size size;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: size,
    child: const CustomPaint(painter: _CrownPainter()),
  );
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  static const _viewBox = Size(54, 34);
  static const _stroke = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    // svg 기본 preserveAspectRatio(xMidYMid meet)처럼 비율을 지켜 가운데에 맞춘다.
    final scale = math.min(
      size.width / _viewBox.width,
      size.height / _viewBox.height,
    );
    canvas
      ..translate(
        (size.width - _viewBox.width * scale) / 2,
        (size.height - _viewBox.height * scale) / 2,
      )
      ..scale(scale);
    final path = Path()
      ..moveTo(4, 30)
      ..lineTo(8, 8)
      ..lineTo(19, 20)
      ..lineTo(27, 3)
      ..lineTo(35, 20)
      ..lineTo(46, 8)
      ..lineTo(50, 30)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = ElevenNoirColors.accentRed)
      ..drawPath(
        path,
        Paint()
          ..color = ElevenNoirColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => false;
}

/// 승리 조각 하나입니다. [index] 0–5 순서로 크림·빨강을 번갈아 쓴다.
class ElevenNoirSpark extends StatelessWidget {
  const ElevenNoirSpark({super.key, required this.index});

  static const size = 10.0;
  static const border = ElevenNoirBorder.thin;
  static const radius = 2.0;

  final int index;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: index.isEven ? ElevenNoirColors.cream : ElevenNoirColors.warnRed,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: ElevenNoirColors.ink, width: border),
    ),
  );
}

/// 왕관 가운데에서 퍼지는 조각 6개입니다. [progress]는 조각 연출 0→1
/// (`sparkTravel` 980ms 구간: 처음 `sparkFadeIn` 140ms에 나타나며 출발, 끝에서 사라짐 —
/// kNSp 770→910→1750ms). 동작 줄이기면 이 위젯을 그리지 않는다.
class ElevenNoirSparkBurst extends StatelessWidget {
  const ElevenNoirSparkBurst({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final total = ElevenGameEndMotion.sparkTravel.inMicroseconds;
    final fadeIn = ElevenGameEndMotion.sparkFadeIn.inMicroseconds / total;
    final t = progress.clamp(0.0, 1.0);
    // 0 → fadeIn: 제자리에서 나타남. 이후 이동하며 사라짐(kNSp 키프레임).
    final opacity = t < fadeIn ? t / fadeIn : 1 - (t - fadeIn) / (1 - fadeIn);
    final travel = ElevenGameEndMotion.sparkCurve.transform(t);
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < ElevenGameEndMotion.sparks.length; i++)
            Transform.translate(
              offset: ElevenGameEndMotion.sparks[i].$1 * travel,
              child: Transform.rotate(
                angle:
                    ElevenGameEndMotion.sparks[i].$2 * travel * math.pi / 180,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: ElevenNoirSpark(index: i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
