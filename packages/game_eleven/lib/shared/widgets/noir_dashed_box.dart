// [noir_dashed_box.dart] 는 시안 A의 점선 테두리(`border: Npx dashed #b9ae9c`)를 그리는 공통 위젯이다.
//
// - 휴대폰 대시 상자(P04·P06·P07·P08 “결과는 태블릿에서 확인해요” 등): 높이 56, 반경 16, 3px.
// - 빈 슬롯·빈 전적칸·빈 자리 타일도 같은 그리기([ElevenDashedBorderPainter])를 쓴다.

// ========================[ import ]==========================
import 'package:flutter/widgets.dart';
import 'package:game_eleven/shared/noir/noir_text.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';

// ============================================================

/// 점선 상자입니다. [label]을 주면 screens.md 2-2 대시 상자 글자(15/700 보조색)로 가운데에 씁니다.
class ElevenNoirDashedBox extends StatelessWidget {
  const ElevenNoirDashedBox({
    super.key,
    this.label,
    this.child,
    this.height = ElevenNoirSpacing.dashedBoxHeight,
    this.radius = ElevenNoirRadius.dashedBox,
    this.borderWidth = ElevenNoirBorder.regular,
    this.background,
  }) : assert(label == null || child == null);

  final String? label;
  final Widget? child;
  final double? height;
  final double radius;
  final double borderWidth;
  final Color? background;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: CustomPaint(
      painter: ElevenDashedBorderPainter(
        radius: radius,
        width: borderWidth,
        fill: background,
      ),
      child: Center(
        child:
            child ??
            Text(
              label ?? '',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ElevenNoirText.dashedBox(),
            ),
      ),
    ),
  );
}

/// `Npx dashed #b9ae9c` 테두리. 브라우저 dashed처럼 두께의 약 3배 길이로 끊어 그린다.
class ElevenDashedBorderPainter extends CustomPainter {
  const ElevenDashedBorderPainter({
    required this.radius,
    required this.width,
    this.color = ElevenNoirColors.greyBeige,
    this.fill,
  });

  final double radius;
  final double width;
  final Color color;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    if (fill case final fill?) canvas.drawRRect(outer, Paint()..color = fill);
    final rect = (Offset.zero & size).deflate(width / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final dash = width * 3;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash * 2) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(ElevenDashedBorderPainter oldDelegate) =>
      radius != oldDelegate.radius ||
      width != oldDelegate.width ||
      color != oldDelegate.color ||
      fill != oldDelegate.fill;
}
