// [tile_rack.dart] 는 휴대폰 본인 손패 11칸을 그리는 위젯이다.
//
// 사용한 타일은 전체 집합 − 남은 타일로 계산해 흐리게 표시한다(계약 4.2).

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_eleven/shared/models/tiles.dart';
import 'package:game_eleven/shared/widgets/tile_face.dart';

// ============================================================

class ElevenTileRack extends StatelessWidget {
  const ElevenTileRack({
    super.key,
    required this.remaining,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final List<int> remaining;
  final int? selected;
  final bool enabled;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 6장씩 두 줄. 가로 휴대폰은 높이가 먼저 모자라므로 폭·높이 중 작은 쪽에 맞춥니다.
        final byWidth = (constraints.maxWidth - 5 * 8) / 6;
        final byHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - 10) / (2 * 1.35)
            : byWidth;
        final size = (byWidth < byHeight ? byWidth : byHeight).clamp(
          28.0,
          64.0,
        );
        return Wrap(
          spacing: 8,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final value in elevenTiles)
              _RackTile(
                key: ValueKey('eleven-tile-$value'),
                value: value,
                size: size,
                available: remaining.contains(value),
                selected: selected == value,
                enabled: enabled,
                onSelect: onSelect,
              ),
          ],
        );
      },
    );
  }
}

class _RackTile extends StatelessWidget {
  const _RackTile({
    super.key,
    required this.value,
    required this.size,
    required this.available,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final int value;
  final double size;
  final bool available;
  final bool selected;
  final bool enabled;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final tappable = enabled && available;
    return Semantics(
      button: tappable,
      selected: selected,
      label: '$value',
      child: GestureDetector(
        onTap: tappable ? () => onSelect(value) : null,
        child: ElevenTileFace(
          color: ElevenTileColor.of(value),
          value: value,
          size: size,
          selected: selected,
          dimmed: !available,
        ),
      ),
    );
  }
}
