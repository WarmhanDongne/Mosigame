// [noir_stage.dart] 는 시안 A의 테이블 배경(`.stage`)을 그리는 공통 위젯이다.
//
// `.stage` = 바탕 #262524 + `repeating-linear-gradient(135deg,rgba(255,255,255,.035) 0 2px,
// transparent 2px 14px)` 사선 무늬(screens.md 1-1 주의: 점무늬는 사선 무늬로 덮어써졌다).
// 휴대폰·태블릿 화면 맨 아래에 깐다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';

// ============================================================

class ElevenNoirStage extends StatelessWidget {
  const ElevenNoirStage({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _StagePainter(),
    child: child ?? const SizedBox.expand(),
  );
}

class _StagePainter extends CustomPainter {
  const _StagePainter();

  /// 줄 두께 2px, 반복 간격 14px(그라디언트 축 방향).
  static const _line = 2.0;
  static const _period = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = ElevenNoirColors.table,
    );
    // 135deg 축은 오른쪽 아래를 향하므로 줄은 그와 수직인 `/` 방향이다.
    // 축 방향 간격 p는 가로 간격 p·√2에 해당한다.
    final step = _period * math.sqrt2;
    final width = _line * math.sqrt2;
    final paint = Paint()..color = ElevenNoirColors.stageStripe;
    final span = size.width + size.height;
    for (var x = 0.0; x < span + step; x += step) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + width, 0)
        ..lineTo(x + width - size.height, size.height)
        ..lineTo(x - size.height, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StagePainter oldDelegate) => false;
}
