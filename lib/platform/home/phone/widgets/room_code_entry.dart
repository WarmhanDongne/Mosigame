// [room_code_entry.dart] 는 방 코드 다섯 칸과 전용 자판, 스캐너 테두리처럼
// 로비와 참여 화면이 함께 쓰는 입력 부품을 모아 둔 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/home/phone/models/room_join_feedback.dart';

// ============================================================

class RoomCodeBoxes extends StatelessWidget {
  const RoomCodeBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.feedback,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final RoomJoinFeedback? feedback;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final code = controller.text.toUpperCase();
    final feedbackColor = switch (feedback?.tone) {
      RoomJoinFeedbackTone.warning => MosiColors.sun,
      RoomJoinFeedbackTone.danger => MosiColors.red,
      null => null,
    };
    return GestureDetector(
      onTap: focusNode.requestFocus,
      child: Stack(
        children: [
          Row(
            children: [
              for (var index = 0; index < 5; index++) ...[
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        // 아직 비어 있는 뒤쪽 칸은 살짝 흐리게 둡니다.
                        color: index <= code.length || !focusNode.hasFocus
                            ? MosiColors.white
                            : const Color(0xE0FFFFFF),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: MosiColors.navy,
                            offset: Offset(4, 4),
                          ),
                        ],
                        border: Border.all(
                          color:
                              feedbackColor ??
                              (focusNode.hasFocus &&
                                      code.length < 5 &&
                                      index == code.length
                                  ? MosiColors.lime
                                  : MosiColors.navy),
                          width:
                              feedbackColor != null ||
                                  (focusNode.hasFocus &&
                                      code.length < 5 &&
                                      index == code.length)
                              ? 3
                              : 2,
                        ),
                      ),
                      child: Text(
                        index < code.length ? code[index] : '',
                        style: MosiFonts.grotesk(
                          color: MosiColors.navy,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
                if (index < 4) const SizedBox(width: 10),
              ],
            ],
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              alwaysIncludeSemantics: true,
              child: TextField(
                enabled: enabled,
                textInputAction: TextInputAction.done,
                controller: controller,
                focusNode: focusNode,
                showCursor: false,
                enableInteractiveSelection: false,
                maxLength: 5,
                textCapitalization: TextCapitalization.characters,
                // 기기 키보드를 띄우지 않습니다(전용 자판 사용). 연결된 실제
                // 키보드 입력은 그대로 받습니다.
                keyboardType: TextInputType.none,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) =>
                        newValue.copyWith(text: newValue.text.toUpperCase()),
                  ),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  labelText: GameLocale.select(
                    ko: '방 코드, 영문과 숫자 다섯 자리',
                    en: 'Room code, five letters or numbers',
                    zhHans: '房间码，五位字母或数字',
                    zhHant: '房間碼，五位字母或數字',
                  ),
                ),
                onSubmitted: (_) => onSubmitted(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 코드 입력을 시작하거나 QR 화면으로 돌아갈 때 전용 자판을 부드럽게 열고
/// 닫습니다. 자판을 단순히 제거하면 본문 높이가 같은 프레임에 튀므로
/// [AnimatedSwitcher]로 아래 영역의 높이를 함께 조정합니다. 열리는 첫
/// 프레임부터 자판을 실제로 hit-test할 수 있어, 손가락을 떼자마자 키를
/// 누르는 경우에도 입력이 누락되지 않습니다.
class RoomCodeKeypadTransition extends StatelessWidget {
  const RoomCodeKeypadTransition({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 닫힘 직후 다음 입력 화면으로 넘어가는 흐름이므로, 자판이 120ms
    // 안에 트리에서 사라지도록 짧게 마무리합니다.
    final duration = MosiMotion.of(context, const Duration(milliseconds: 100));
    return AnimatedSwitcher(
      key: const Key('room-code-keyboard-transition'),
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: <Widget>[
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      child: visible
          ? KeyedSubtree(key: const ValueKey('keyboard-visible'), child: child)
          : const SizedBox.shrink(key: ValueKey('keyboard-hidden')),
    );
  }
}

/// 방 코드 전용 자판입니다. 숫자는 노란 키, 영문 대문자는 흰 키입니다.
class RoomCodeKeypad extends StatelessWidget {
  const RoomCodeKeypad({
    required this.length,
    required this.enabled,
    required this.onKey,
    required this.onBackspace,
  });

  final int length;
  final bool enabled;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  static const _rows = ['1234567890', 'QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      key: const ValueKey('room-code-keyboard'),
      decoration: const BoxDecoration(
        color: MosiColors.navy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(8, 12, 8, bottom > 0 ? bottom + 6 : 26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 한 줄 10키가 꼭 맞는 폭입니다. 큰 화면에서는 너무 넓어지지 않게 둡니다.
          final keyWidth = ((constraints.maxWidth - _gap * 9) / 10).clamp(
            22.0,
            44.0,
          );
          Widget row(List<Widget> keys) => Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (index, key) in keys.indexed) ...[
                  if (index > 0) const SizedBox(width: _gap),
                  key,
                ],
              ],
            ),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        GameLocale.select(
                          ko: '영문 · 숫자만 입력돼요',
                          en: 'Letters and numbers only',
                          zhHans: '仅限字母和数字',
                          zhHant: '僅限字母和數字',
                        ),
                        style: MosiFonts.sans(
                          size: 11,
                          color: const Color(0x99FFFFFF),
                          letterSpacing: .4,
                        ),
                      ),
                    ),
                    Text(
                      '$length / 5',
                      style: MosiFonts.grotesk(
                        size: 12,
                        color: MosiColors.lime,
                      ),
                    ),
                  ],
                ),
              ),
              for (final (index, letters) in _rows.indexed)
                row([
                  for (final character in letters.split(''))
                    _CodeKey(
                      label: character,
                      width: keyWidth,
                      digit: index == 0,
                      onPressed: enabled && length < 5
                          ? () => onKey(character)
                          : null,
                    ),
                  if (index == _rows.length - 1)
                    _CodeKey(
                      width: keyWidth * 2 + _gap,
                      semanticLabel: GameLocale.select(
                        ko: length == 0 ? '키보드 내리기' : '지우기',
                        en: length == 0 ? 'Hide keyboard' : 'Delete',
                        zhHans: length == 0 ? '收起键盘' : '删除',
                        zhHant: length == 0 ? '收起鍵盤' : '刪除',
                      ),
                      icon: length == 0
                          ? Icons.keyboard_hide_rounded
                          : Icons.backspace_outlined,
                      onPressed: enabled ? onBackspace : null,
                    ),
                ]),
            ],
          );
        },
      ),
    );
  }
}

/// 누르면 아래 그림자만큼 내려앉는 자판 키입니다. [label]이 없으면 지우기 키입니다.
class _CodeKey extends StatefulWidget {
  const _CodeKey({
    required this.width,
    required this.onPressed,
    this.label,
    this.digit = false,
    this.semanticLabel,
    this.icon,
  });

  final String? label;
  final double width;
  final bool digit;
  final String? semanticLabel;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  State<_CodeKey> createState() => _CodeKeyState();
}

class _CodeKeyState extends State<_CodeKey> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value || !mounted) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final (face, shade, ink) = label == null
        ? (MosiColors.ink2, MosiColors.navyDeepest, MosiColors.white)
        : widget.digit
        ? (MosiColors.sun, const Color(0xFF9C8C1E), MosiColors.navy)
        : (MosiColors.white, MosiColors.lilac, MosiColors.navy);
    final enabled = widget.onPressed != null;
    final depth = _down ? 0.0 : 3.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapCancel: () => _setDown(false),
        onTapUp: (_) => _setDown(false),
        onTap: widget.onPressed,
        child: SizedBox(
          width: widget.width,
          height: 49,
          child: Opacity(
            // 다섯 글자를 다 넣으면 글자 키는 흐려지고 지우기만 남습니다.
            opacity: enabled || label == null ? 1 : .55,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 60),
              margin: EdgeInsets.only(top: 3 - depth, bottom: depth),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: face,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: shade, offset: Offset(0, depth))],
              ),
              child: label == null
                  ? Icon(
                      widget.icon ?? Icons.backspace_outlined,
                      size: 20,
                      color: MosiColors.white,
                    )
                  : Text(label, style: MosiFonts.grotesk(size: 18, color: ink)),
            ),
          ),
        ),
      ),
    );
  }
}

class InlineJoinFeedback extends StatelessWidget {
  const InlineJoinFeedback({required this.feedback});

  final RoomJoinFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final danger = feedback.tone == RoomJoinFeedbackTone.danger;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFFE4E8) : const Color(0xFFFFF3C4),
          border: Border.all(color: MosiColors.navy, width: 1.5),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          feedback.message,
          textAlign: TextAlign.center,
          style: MosiFonts.sans(
            size: 12,
            weight: FontWeight.w700,
            color: danger ? MosiColors.red : MosiColors.navy,
          ),
        ),
      ),
    );
  }
}

class ScannerFrame extends StatelessWidget {
  const ScannerFrame();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(38),
      child: CustomPaint(painter: __ScannerFramePainter()),
    );
  }
}

class __ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MosiColors.lime
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(10, size.height / 2),
      Offset(size.width - 10, size.height / 2),
      Paint()
        ..color = MosiColors.lime.withValues(alpha: .45)
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawLine(
      Offset(10, size.height / 2),
      Offset(size.width - 10, size.height / 2),
      Paint()
        ..color = MosiColors.lime
        ..strokeWidth = 2,
    );
    const line = 28.0;
    final paths = <Path>[
      Path()
        ..moveTo(0, line)
        ..lineTo(0, 0)
        ..lineTo(line, 0),
      Path()
        ..moveTo(size.width - line, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, line),
      Path()
        ..moveTo(0, size.height - line)
        ..lineTo(0, size.height)
        ..lineTo(line, size.height),
      Path()
        ..moveTo(size.width - line, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - line),
    ];
    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
