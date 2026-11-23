// [tile_face.dart] 는 ELEVEN 타일 한 장을 그리는 공용 위젯이다.
//
// 휴대폰 손패(숫자 표시)와 태블릿 공개 색(숫자 없음)에서 함께 쓴다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_eleven/game_theme.dart';
import 'package:game_eleven/shared/models/tiles.dart';

// ============================================================

class ElevenTileFace extends StatelessWidget {
  const ElevenTileFace({
    super.key,
    required this.color,
    this.value,
    this.size = 56,
    this.selected = false,
    this.dimmed = false,
    this.hidden = false,
  });

  /// null이면 아직 제출되지 않은 빈 자리입니다.
  final ElevenTileColor? color;

  /// null이면 숫자를 그리지 않습니다(공개 정보는 색뿐).
  final int? value;
  final double size;
  final bool selected;
  final bool dimmed;

  /// 공용 뽑기처럼 뒷면을 그립니다.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final background = hidden
        ? ElevenColors.inkMuted
        : switch (color) {
            ElevenTileColor.black => ElevenColors.blackTile,
            ElevenTileColor.white => ElevenColors.whiteTile,
            null => Colors.transparent,
          };
    final foreground = color == ElevenTileColor.white
        ? ElevenColors.blackTile
        : ElevenColors.whiteTile;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: dimmed ? 0.25 : 1,
      child: Container(
        width: size,
        height: size * 1.35,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.14),
          border: Border.all(
            color: selected ? ElevenColors.accent : ElevenColors.inkMuted,
            width: selected ? 3 : 1,
          ),
        ),
        child: value == null || hidden
            ? null
            : Text(
                '$value',
                style: TextStyle(
                  color: foreground,
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
