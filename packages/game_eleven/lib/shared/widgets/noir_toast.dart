// [noir_toast.dart] 는 ELEVEN 태블릿 중앙 토스트를 그리는 공통 위젯이다.
//
// - [Package] : ELEVEN
// - [Widget] : 72/900 크림(또는 강조 빨강) 글자 + 12px 잉크 외곽 획 + `0 8px 0` 그림자
//
// 시간·움직임: docs/design/eleven/motion.md MotionKit 칸 1(결정 1) — 아래에서 8px
// 떠오르며 0.2초 등장 → 문구별 유지 → 0.2초 투명도 퇴장. 여러 단계는 0.2초 공백.
// 상태가 바뀔 때 한 번만 재생하고(같은 [ElevenToastSequence.playKey]면 다시 재생하지
// 않음), 동작 줄이기 설정이면 이동 없이 투명도만 바꾼다. [animate]가 false(재접속 등)면
// 애니메이션 없이 최종 상태(마지막 단계 퇴장 뒤 = 아무것도 없음)로 둔다.

// ========================[ import ]==========================
import 'package:flutter/widgets.dart';
import 'package:game_eleven/shared/noir/noir_motion.dart';
import 'package:game_eleven/shared/noir/noir_text.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';

// ============================================================

/// 토스트 한 단계입니다.
@immutable
class ElevenToastStep {
  const ElevenToastStep({
    required this.text,
    required this.hold,
    this.accent = false,
  });

  /// 줄바꿈은 `\n`(T09 “6라운드\nA 선공”, T10 “승자\nA”).
  final String text;
  final ElevenToastHold hold;

  /// true면 `cToastOn`(강조 빨강 #e23a3a), false면 크림.
  final bool accent;

  @override
  bool operator ==(Object other) =>
      other is ElevenToastStep &&
      text == other.text &&
      hold == other.hold &&
      accent == other.accent;

  @override
  int get hashCode => Object.hash(text, hold, accent);
}

/// 한 단계 안에서의 표시 값(투명도·세로 이동)입니다. 테스트와 위젯이 같은 계산을 씁니다.
@immutable
class ElevenToastFrame {
  const ElevenToastFrame({
    required this.stepIndex,
    required this.opacity,
    required this.offsetY,
  });

  /// 보이는 단계. 공백·끝이면 null.
  final int? stepIndex;
  final double opacity;
  final double offsetY;

  static const hidden = ElevenToastFrame(
    stepIndex: null,
    opacity: 0,
    offsetY: 0,
  );

  /// [elapsed] 시점의 표시 값을 계산합니다.
  static ElevenToastFrame at(
    List<ElevenToastStep> steps,
    Duration elapsed, {
    bool reduceMotion = false,
  }) {
    var cursor = Duration.zero;
    for (var i = 0; i < steps.length; i++) {
      final hold = steps[i].hold.duration;
      final enterEnd = cursor + ElevenToastMotion.enter;
      final holdEnd = enterEnd + hold;
      final exitEnd = holdEnd + ElevenToastMotion.exit;
      if (elapsed < cursor) return hidden;
      if (elapsed < enterEnd) {
        final t = ElevenToastMotion.enterCurve.transform(
          _ratio(elapsed - cursor, ElevenToastMotion.enter),
        );
        return ElevenToastFrame(
          stepIndex: i,
          opacity: t,
          offsetY: reduceMotion ? 0 : ElevenToastMotion.enterOffsetY * (1 - t),
        );
      }
      if (elapsed < holdEnd) {
        return ElevenToastFrame(stepIndex: i, opacity: 1, offsetY: 0);
      }
      if (elapsed < exitEnd) {
        final t = ElevenToastMotion.exitCurve.transform(
          _ratio(elapsed - holdEnd, ElevenToastMotion.exit),
        );
        return ElevenToastFrame(stepIndex: i, opacity: 1 - t, offsetY: 0);
      }
      cursor = exitEnd + ElevenToastMotion.gap;
    }
    return hidden;
  }

  static double _ratio(Duration part, Duration whole) =>
      (part.inMicroseconds / whole.inMicroseconds).clamp(0.0, 1.0);
}

/// 중앙 토스트 묶음을 한 번 재생합니다. 태블릿 토스트 영역(1040×278)에 놓습니다.
class ElevenToastSequence extends StatefulWidget {
  const ElevenToastSequence({
    super.key,
    required this.steps,
    required this.playKey,
    this.animate = true,
    this.onFinished,
  });

  final List<ElevenToastStep> steps;

  /// 이 값이 바뀔 때만 처음부터 다시 재생합니다(예: phase·round·revision 조합).
  final Object playKey;

  /// false면 재생하지 않고 최종 상태(숨김)로 둡니다. 재접속 복원에 씁니다.
  final bool animate;
  final VoidCallback? onFinished;

  @override
  State<ElevenToastSequence> createState() => _ElevenToastSequenceState();
}

class _ElevenToastSequenceState extends State<ElevenToastSequence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addListener(() => setState(() {}))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinished?.call();
    });

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(ElevenToastSequence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playKey != widget.playKey) _start();
  }

  void _start() {
    _controller.duration = ElevenToastMotion.sequence([
      for (final step in widget.steps) step.hold,
    ]);
    if (widget.animate && widget.steps.isNotEmpty) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _controller.duration ?? Duration.zero;
    final frame = ElevenToastFrame.at(
      widget.steps,
      total * _controller.value,
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    );
    final index = frame.stepIndex;
    if (index == null || frame.opacity <= 0) return const SizedBox.shrink();
    final step = widget.steps[index];
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        label: step.text.replaceAll('\n', ' '),
        child: Opacity(
          opacity: frame.opacity,
          child: Transform.translate(
            offset: Offset(0, frame.offsetY),
            child: Center(
              child: ElevenToastText(text: step.text, accent: step.accent),
            ),
          ),
        ),
      ),
    );
  }
}

/// 토스트 글자 모양만 그립니다(움직임 없음). 기준 PNG의 정지 상태 비교에도 씁니다.
class ElevenToastText extends StatelessWidget {
  const ElevenToastText({super.key, required this.text, this.accent = false});

  final String text;
  final bool accent;

  /// `-webkit-text-stroke:12px` — 획이 글자 가장자리 양쪽으로 6px씩 그려진다.
  static const _strokeWidth = 12.0;

  /// `text-shadow:0 8px 0 #141414`.
  static const _shadowOffset = Offset(0, 8);

  @override
  Widget build(BuildContext context) {
    final fill = ElevenNoirText.toast(
      color: accent ? ElevenNoirColors.accentRed : ElevenNoirColors.cream,
    );
    // paint-order:stroke fill — 획 위에 채움을 그린다. 그림자는 획 모양 아래에 둔다.
    final stroke = fill.copyWith(
      color: null,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..color = ElevenNoirColors.ink,
      shadows: const [
        Shadow(color: ElevenNoirColors.ink, offset: _shadowOffset),
      ],
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text, textAlign: TextAlign.center, softWrap: false, style: stroke),
        Text(text, textAlign: TextAlign.center, softWrap: false, style: fill),
      ],
    );
  }
}
