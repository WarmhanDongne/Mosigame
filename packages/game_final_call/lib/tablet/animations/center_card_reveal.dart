// [tablet_center_card_reveal.dart] 는 파이널콜에서 사용하는 화면 전환과 게임 연출의 진행 시간을 관리하는 파일이다.
//
// - [Package] : 파이널콜
// - [Animation] : 화면 전환과 게임 연출의 진행 시간을 관리함
//
// 즉, 같은 연출을 예측 가능한 순서와 속도로 재생하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_final_call/game_copy.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/widgets/card_view.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';

// ============================================================

/// 중앙 덱에서 한 장이 뒤집히며 오른쪽 공개 카드 자리로 이동합니다.
///
/// 왼쪽의 덱 카드는 고정된 채 남고, 이동 카드는 90도 지점에서 앞면으로
/// 교체됩니다. [AnimatedSwitcher]를 사용하지 않아 이미지 전환 시 페이드가
/// 섞이지 않습니다.
class FinalCallCenterCardReveal extends StatefulWidget {
  const FinalCallCenterCardReveal({
    super.key,
    required this.card,
    this.cardWidth = 92,
    this.gap = 10,
    this.deckCount,
    this.showRevealedCard = true,
  });

  final FinalCallCard? card;
  final double cardWidth;

  /// 덱과 공개 카드 사이 간격입니다.
  final double gap;

  /// 덱에 남은 장수입니다. 덱 카드 오른쪽 위 별 스티커에 표시합니다.
  /// null이면 스티커 없이 두 겹 더미만 그립니다.
  final int? deckCount;
  final bool showRevealedCard;

  @override
  State<FinalCallCenterCardReveal> createState() =>
      _FinalCallCenterCardRevealState();
}

class _FinalCallCenterCardRevealState extends State<FinalCallCenterCardReveal> {
  static const Duration _startDelay = Duration(milliseconds: 400);
  static const Duration _duration = Duration(milliseconds: 680);

  Timer? startTimer;
  bool started = false;

  double get cardHeight => widget.cardWidth * finalCallCardHeightRatio;
  double get travelDistance => widget.cardWidth + widget.gap;

  @override
  void initState() {
    super.initState();
    startTimer = Timer(_startDelay, () {
      if (mounted) setState(() => started = true);
    });
  }

  @override
  void dispose() {
    startTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.cardWidth * 2 + widget.gap,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 애니메이션이 끝난 뒤에도 왼쪽에 그대로 남는 카드 더미입니다.
          Positioned(
            left: 0,
            top: 0,
            child: FinalCallDeckPile(
              cardWidth: widget.cardWidth,
              count: widget.deckCount,
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: AnimatedOpacity(
              opacity: widget.showRevealedCard ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: started ? 1 : 0),
                duration: _duration,
                curve: Curves.easeInOutCubic,
                builder: (context, progress, _) {
                  final showFront = progress >= 0.5;

                  // 앞뒷면이 바뀌는 90도 지점을 기준으로 각도를 다시 펴 줍니다.
                  final rotationY = showFront
                      ? (progress - 1) * math.pi
                      : progress * math.pi;

                  return Transform.translate(
                    offset: Offset(travelDistance * progress, 0),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0016)
                        ..rotateY(rotationY),
                      child: FinalCallCardView(
                        card: widget.card,
                        faceDown: !showFront,
                        width: widget.cardWidth,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // 별 스티커는 뒤집히며 나가는 카드보다 위에 둡니다.
          if (widget.deckCount != null && widget.deckCount! > 0)
            Positioned(
              left:
                  widget.cardWidth -
                  FinalCallDeckPile.stickerInset(widget.cardWidth),
              top: -FinalCallDeckPile.stickerLift(widget.cardWidth),
              child: FinalCallDeckCountSticker(
                count: widget.deckCount!,
                size: FinalCallDeckPile.stickerSize(widget.cardWidth),
              ),
            ),
        ],
      ),
    );
  }
}

/// 가운데 덱 더미입니다. 남은 장수에 따라 겹친 그림자 수가 줄어듭니다.
///
/// 10장 이상은 두 겹, 2~9장은 한 겹, 1장은 카드 한 장, 0장은 점선 빈자리입니다.
class FinalCallDeckPile extends StatelessWidget {
  const FinalCallDeckPile({super.key, required this.cardWidth, this.count});

  final double cardWidth;
  final int? count;

  /// 별 스티커 지름입니다(카드 폭 104 기준 58).
  static double stickerSize(double cardWidth) => cardWidth * 58 / 104;

  /// 스티커 중심을 덱 오른쪽 위 모서리에 걸칩니다. 왼쪽 위 좌표 계산용입니다.
  static double stickerInset(double cardWidth) =>
      stickerSize(cardWidth) - cardWidth * 18 / 104;

  /// 스티커가 카드 위로 올라오는 높이입니다. 위 차례 알약에 닿지 않게
  /// 조금만 올립니다.
  static double stickerLift(double cardWidth) => cardWidth * 6 / 104;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    final unit = cardWidth / 104;
    final height = cardWidth * finalCallCardHeightRatio;
    if (count != null && count <= 0) {
      return Semantics(
        label: FinalCallCopy.deckCount(0),
        child: CustomPaint(
          size: Size(cardWidth, height),
          painter: _EmptyDeckPainter(unit: unit),
          child: SizedBox(
            width: cardWidth,
            height: height,
            child: Center(
              child: Text(
                '0',
                style: finalCallPopText(
                  44 * unit,
                  color: FinalCallColors.ink.withValues(alpha: .55),
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final layers = count == null || count >= 10
        ? 2
        : count >= 2
        ? 1
        : 0;
    final step = cardWidth * 4 / 92;
    return Semantics(
      label: count == null ? null : FinalCallCopy.deckCount(count),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardWidth * 14 / 92),
          boxShadow: [
            if (layers >= 2)
              BoxShadow(
                color: FinalCallColors.violetDeep,
                offset: Offset(step * 2, step * 2),
              ),
            if (layers >= 1)
              BoxShadow(color: FinalCallColors.ink, offset: Offset(step, step)),
          ],
        ),
        child: FinalCallCardView(faceDown: true, width: cardWidth),
      ),
    );
  }
}

/// 덱 카드 오른쪽 위에 붙는 별 스티커입니다. 5장 이하면 빨강으로 바뀝니다.
class FinalCallDeckCountSticker extends StatelessWidget {
  const FinalCallDeckCountSticker({
    super.key,
    required this.count,
    required this.size,
  });

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final low = count <= 5;
    final unit = size / 58;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _StarStickerPainter(
            color: low ? FinalCallColors.red : FinalCallColors.yellow,
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(size * .2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$count',
                  style: finalCallPopText(
                    (count >= 10 ? 22 : 26) * unit,
                    color: low ? Colors.white : FinalCallColors.ink,
                    height: 1,
                    shadows: low ? finalCallPopOutline(2 * unit) : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 꼭짓점 12개 별 모양에 아래쪽 잉크 그림자를 깝니다.
class _StarStickerPainter extends CustomPainter {
  const _StarStickerPainter({required this.color});

  final Color color;

  Path _star(Size size, Offset shift) {
    final center = size.center(Offset.zero) + shift;
    final outer = size.shortestSide / 2;
    final inner = outer * .76;
    final path = Path();
    for (var i = 0; i < 24; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = i * math.pi / 12;
      final point =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 58;
    canvas.drawPath(
      _star(size, Offset(0, 3 * unit)),
      Paint()..color = FinalCallColors.ink,
    );
    final star = _star(size, Offset.zero);
    canvas.drawPath(star, Paint()..color = color);
    canvas.drawPath(
      star,
      Paint()
        ..color = FinalCallColors.ink
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(1.5, 3 * unit),
    );
  }

  @override
  bool shouldRepaint(_StarStickerPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 덱을 다 쓰면 남는 점선 빈자리입니다.
class _EmptyDeckPainter extends CustomPainter {
  const _EmptyDeckPainter({required this.unit});

  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(1.5, 4 * unit);
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(stroke / 2),
      Radius.circular(16 * unit),
    );
    final paint = Paint()
      ..color = FinalCallColors.ink.withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final dash = 10 * unit;
    final gap = 7 * unit;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EmptyDeckPainter oldDelegate) => oldDelegate.unit != unit;
}
