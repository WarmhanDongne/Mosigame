import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:game_eleven/game_copy.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';
import 'package:game_eleven/shared/models/tiles.dart';
import 'package:game_eleven/shared/widgets/noir_tile.dart';

/// The two fixed hand rows from the phone design. Only the owner's tiles are read.
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

  static const blackRow = [0, 2, 4, 6, 8, 11];
  static const whiteRow = [1, 3, 5, 7, 9];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      width: constraints.hasBoundedWidth
          ? math.min(508, constraints.maxWidth)
          : 508,
      height: constraints.hasBoundedHeight
          ? math.min(190, constraints.maxHeight)
          : 190,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 508,
          height: 190,
          child: Column(
            children: [
              _row(blackRow),
              const SizedBox(height: ElevenNoirSpacing.handRowGap),
              _row(whiteRow),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _row(List<int> values) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < values.length; i++) ...[
        if (i > 0) const SizedBox(width: ElevenNoirSpacing.handTileGap),
        _tile(values[i]),
      ],
    ],
  );

  Widget _tile(int value) {
    final available = remaining.contains(value);
    final tappable = enabled && available;
    final state = !available
        ? ElevenTileState.used
        : selected == value && enabled
        ? ElevenTileState.selected
        : enabled
        ? ElevenTileState.normal
        : ElevenTileState.locked;
    return Semantics(
      button: tappable,
      child: GestureDetector(
        key: ValueKey('eleven-tile-$value'),
        onTap: tappable ? () => onSelect(value) : null,
        child: ElevenNoirTile(
          face: ElevenTileFace.ofValue(value),
          value: value,
          spec: ElevenTileSpec.phoneHand,
          state: state,
          badgeLabel: ElevenScreenCopy.selectedBadge,
          semanticsLabel: ElevenScreenCopy.tileName(
            ElevenTileColor.of(value) == ElevenTileColor.black
                ? ElevenScreenCopy.black
                : ElevenScreenCopy.white,
            value,
          ),
        ),
      ),
    );
  }
}
