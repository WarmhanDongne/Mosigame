// [result.dart] 게임 종료 후 태블릿에
// 최종 우승자 프로필과 다시하기·나가기 버튼을 라이어스 타로 카드 모양으로
// 표시하는 결과 화면 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_liars_poker/shared/widgets/card_face_view.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/core/constants/room_character.dart';
import 'package:game_kit/localization/game_locale.dart';

// ============================================================

/// 게임 종료 후 우승자와 다음 동작을 보여주는 태블릿 결과 화면입니다.
class Result extends StatelessWidget {
  const Result({
    super.key,
    this.onRestartGame,
    this.onExitToLobby,
    this.winnerPlayer,
  });

  final VoidCallback? onRestartGame;
  final VoidCallback? onExitToLobby;
  final PlayerLayoutPlayer? winnerPlayer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: _ResultLayout.canvasWidth,
            height: _ResultLayout.canvasHeight,
            // 결과 글자가 Material 밖에서 밑줄 기본 스타일을 받지 않게 합니다.
            child: Material(
              type: MaterialType.transparency,
              child: _ResultContent(
                winnerPlayer: winnerPlayer,
                onRestartGame: onRestartGame,
                onExitToLobby: onExitToLobby,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 모든 기기에서 같은 비율을 유지하기 위한 결과 화면 기준 크기입니다.
abstract final class _ResultLayout {
  static const double canvasWidth = 1194;
  static const double canvasHeight = 834;
  static const double cardWidth = 430;
  static const double cardHeight = 630;
  static const double cardLeft = (canvasWidth - cardWidth) / 2;
  static const double cardTop = (canvasHeight - cardHeight) / 2;
  static const double actionInset = 60;
  static const double actionBottom = 44;
  static const double buttonWidth = 160;
  static const double buttonHeight = 214;
}

// 라이어스 카드(card_face_view.dart)와 같은 판화 색입니다.
const Color _ink = Color(0xFF17110F);
const Color _bone = Color(0xFFF2EADB);
const Color _paper = Color(0xFFE6D8BC);
const Color _gold = Color(0xFFB9A782);
const Color _truth = Color(0xFF2E6B4E);

class _ResultContent extends StatelessWidget {
  const _ResultContent({
    required this.winnerPlayer,
    required this.onRestartGame,
    required this.onExitToLobby,
  });

  final PlayerLayoutPlayer? winnerPlayer;
  final VoidCallback? onRestartGame;
  final VoidCallback? onExitToLobby;

  @override
  Widget build(BuildContext context) {
    const center = Offset(
      _ResultLayout.canvasWidth / 2,
      _ResultLayout.cardTop + _ResultLayout.cardHeight / 2 + 40,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 우승 카드 뒤로 진실·거짓 카드가 부채꼴로 펼쳐집니다.
        for (final (face, angle, dx) in const [
          (LiarsCardFace.truth, -0.26, -190.0),
          (LiarsCardFace.lie, 0.26, 190.0),
        ])
          Positioned(
            left: center.dx + dx - _FanCard.width / 2,
            top: center.dy - _FanCard.height / 2,
            child: Transform.rotate(
              angle: angle,
              child: _FanCard(face: face),
            ),
          ),
        Positioned(
          top: _ResultLayout.cardTop,
          left: _ResultLayout.cardLeft,
          child: _WinnerCard(player: winnerPlayer),
        ),
        // ---------------------------------------------------------------------------
        // 다시하기·나가기 버튼
        // ---------------------------------------------------------------------------
        Positioned(
          left: _ResultLayout.actionInset,
          right: _ResultLayout.actionInset,
          bottom: _ResultLayout.actionBottom,
          child: _ResultActions(
            onRestartGame: onRestartGame,
            onExitToLobby: onExitToLobby,
          ),
        ),
      ],
    );
  }
}

class _FanCard extends StatelessWidget {
  const _FanCard({required this.face});

  static const double width = 300;
  static const double height = width * liarsCardAspectRatio;

  final LiarsCardFace face;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: LiarsPokerCardView(face: face, rounded: true),
  );
}

/// 카드와 같은 뼈색 테두리 안 먹색 아치 창에 우승자를 보여 줍니다.
class _WinnerCard extends StatelessWidget {
  const _WinnerCard({required this.player});

  final PlayerLayoutPlayer? player;

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    return SizedBox(
      width: _ResultLayout.cardWidth,
      height: _ResultLayout.cardHeight,
      child: CustomPaint(
        painter: const _TarotFramePainter(archColor: _ink, cornerRadius: 22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 70, 56, 64),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  GameLocale.select(
                    ko: '게임 종료',
                    en: 'GAME OVER',
                    zhHans: '游戏结束',
                    zhHant: '遊戲結束',
                  ),
                  maxLines: 1,
                  style: const TextStyle(
                    color: _bone,
                    fontSize: 54,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                    fontFamily: 'Georgia',
                    fontFamilyFallback: ['Times New Roman', 'serif'],
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const SizedBox(
                width: 200,
                height: 16,
                child: CustomPaint(painter: _DividerPainter()),
              ),
              const Spacer(),
              SizedBox(
                width: 236,
                height: 160,
                child: CustomPaint(
                  painter: const _LaurelPainter(),
                  child: Center(
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        color: _bone,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _gold, width: 4),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: player == null
                          ? null
                          : _WinnerProfileImage(
                              characterId: player.characterId,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'WINNER',
                style: TextStyle(
                  color: _gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                  fontFamily: 'Georgia',
                  fontFamilyFallback: ['Times New Roman', 'serif'],
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 46),
                child: player == null
                    ? null
                    : Text(
                        player.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _bone,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const Spacer(),
              Container(width: 130, height: 2, color: _gold),
            ],
          ),
        ),
      ),
    );
  }
}

class _WinnerProfileImage extends StatelessWidget {
  const _WinnerProfileImage({required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      roomCharacterAssetPath(characterId),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({this.onRestartGame, this.onExitToLobby});

  final VoidCallback? onRestartGame;
  final VoidCallback? onExitToLobby;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ResultActionButton(
          action: onRestartGame,
          label: GameLocale.select(
            ko: '다시하기',
            en: 'Play Again',
            zhHans: '再玩一次',
            zhHant: '再玩一次',
          ),
          icon: Icons.refresh_rounded,
          archColor: _truth,
        ),
        _ResultActionButton(
          action: onExitToLobby,
          label: GameLocale.select(
            ko: '나가기',
            en: 'Exit',
            zhHans: '退出',
            zhHant: '退出',
          ),
          icon: Icons.home_rounded,
          archColor: _ink,
        ),
      ],
    );
  }
}

/// 작은 타로 카드 모양 버튼입니다. 누르면 카드가 살짝 내려앉습니다.
class _ResultActionButton extends StatefulWidget {
  const _ResultActionButton({
    required this.action,
    required this.label,
    required this.icon,
    required this.archColor,
  });

  final VoidCallback? action;
  final String label;
  final IconData icon;
  final Color archColor;

  @override
  State<_ResultActionButton> createState() => _ResultActionButtonState();
}

class _ResultActionButtonState extends State<_ResultActionButton> {
  static const _pressDuration = Duration(milliseconds: 115);
  bool _pressed = false;

  bool get _enabled => widget.action != null;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final card = SizedBox(
      width: _ResultLayout.buttonWidth,
      height: _ResultLayout.buttonHeight,
      child: CustomPaint(
        painter: _TarotFramePainter(
          archColor: widget.archColor,
          cornerRadius: 14,
          archBottomInset: 58,
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Icon(widget.icon, color: _bone, size: 64),
                ),
              ),
            ),
            SizedBox(
              height: 58,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        onTap: widget.action,
        child: Opacity(
          opacity: _enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: _pressDuration,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _pressed ? 6 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _pressed ? .3 : .5),
                  blurRadius: _pressed ? 6 : 14,
                  offset: Offset(0, _pressed ? 3 : 9),
                ),
              ],
            ),
            child: card,
          ),
        ),
      ),
    );
  }
}

/// 라이어스 카드의 뼈색 종이 테두리, 모서리 꺾쇠, 아치 창을 그립니다.
class _TarotFramePainter extends CustomPainter {
  const _TarotFramePainter({
    required this.archColor,
    required this.cornerRadius,
    this.archBottomInset,
  });

  final Color archColor;
  final double cornerRadius;

  /// 아치 아래에 글자를 놓을 종이 여백입니다. null이면 위아래가 같습니다.
  final double? archBottomInset;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(cornerRadius),
    );
    canvas.drawRRect(outer, Paint()..color = _paper);
    canvas.drawRRect(outer.deflate(1.5), _stroke(_gold, 3));
    final innerInset = w * .03;
    canvas.drawRRect(
      outer.deflate(innerInset),
      _stroke(_ink.withValues(alpha: .55), 1.4),
    );

    final side = w * .1;
    final top = h * .075;
    final bottom = h - (archBottomInset ?? top);
    final curve = (w - side * 2) * .36;
    final arch = Path()
      ..moveTo(side, bottom - curve)
      ..lineTo(side, top + curve)
      ..quadraticBezierTo(side, top, w / 2, top)
      ..quadraticBezierTo(w - side, top, w - side, top + curve)
      ..lineTo(w - side, bottom - curve)
      ..quadraticBezierTo(w - side, bottom, w / 2, bottom)
      ..quadraticBezierTo(side, bottom, side, bottom - curve)
      ..close();
    if (archBottomInset != null) {
      // 글자 자리를 남기도록 아래쪽은 둥근 사각형으로 마무리합니다.
      arch
        ..reset()
        ..moveTo(side, bottom)
        ..lineTo(side, top + curve)
        ..quadraticBezierTo(side, top, w / 2, top)
        ..quadraticBezierTo(w - side, top, w - side, top + curve)
        ..lineTo(w - side, bottom)
        ..close();
    }
    canvas.save();
    canvas.clipPath(arch);
    canvas.drawPath(arch, Paint()..color = archColor);
    final engraving = _stroke(_bone.withValues(alpha: .1), 1);
    for (var y = top + 12; y < bottom; y += 12) {
      canvas.drawLine(Offset(side, y), Offset(w - side, y - 4), engraving);
    }
    canvas.restore();
    canvas.drawPath(arch, _stroke(_ink, 2.6));

    final marks = _stroke(_ink.withValues(alpha: .7), 2);
    final mark = w * .05;
    final inset = w * .065;
    for (final (x, y, sx, sy) in [
      (inset, inset, 1.0, 1.0),
      (w - inset, inset, -1.0, 1.0),
      (inset, h - inset, 1.0, -1.0),
      (w - inset, h - inset, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(x, y), Offset(x + mark * sx, y), marks);
      canvas.drawLine(Offset(x, y), Offset(x, y + mark * sy), marks);
    }
  }

  @override
  bool shouldRepaint(covariant _TarotFramePainter oldDelegate) =>
      oldDelegate.archColor != archColor ||
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.archBottomInset != archBottomInset;
}

/// 제목 아래 금색 선과 마름모 장식입니다.
class _DividerPainter extends CustomPainter {
  const _DividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final cx = size.width / 2;
    final line = _stroke(_gold, 2);
    canvas.drawLine(Offset(0, cy), Offset(cx - 22, cy), line);
    canvas.drawLine(Offset(cx + 22, cy), Offset(size.width, cy), line);
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy - 8)
        ..lineTo(cx + 8, cy)
        ..lineTo(cx, cy + 8)
        ..lineTo(cx - 8, cy)
        ..close(),
      Paint()..color = _gold,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 프로필 양옆을 감싸는 금색 월계수입니다.
class _LaurelPainter extends CustomPainter {
  const _LaurelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final leaf = Paint()..color = _gold;
    final stem = _stroke(_gold, 4)..strokeCap = StrokeCap.round;
    for (final side in const [-1.0, 1.0]) {
      final x0 = size.width / 2 + side * (size.width / 2 - 14);
      final bottom = Offset(x0 + side * -6, size.height - 6);
      final topPoint = Offset(size.width / 2 + side * 70, 8);
      canvas.drawPath(
        Path()
          ..moveTo(bottom.dx, bottom.dy)
          ..quadraticBezierTo(
            x0 + side * 10,
            size.height * .4,
            topPoint.dx,
            topPoint.dy,
          ),
        stem,
      );
      for (var i = 0; i < 4; i++) {
        final t = (i + .5) / 4;
        final y = bottom.dy + (topPoint.dy - bottom.dy) * t;
        final x = x0 + side * (6 - 4 * (t - .5) * (t - .5) * 16) - side * 2;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(side * (-.6 + t * .9));
        canvas.drawOval(
          Rect.fromCenter(center: Offset(side * -9, 0), width: 14, height: 28),
          leaf,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeJoin = StrokeJoin.round;
