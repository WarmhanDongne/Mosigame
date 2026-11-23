// [draw_grid.dart] 는 태블릿 공용 타일 뽑기(T01–T03, T11–T12) 11칸을 그리는 위젯이다.
//
// 공개 전 배치는 서버에만 있다. 고른 칸에는 고른 사람 이름만, 공개 뒤에만 숫자를 그린다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_eleven/game_theme.dart';
import 'package:game_eleven/shared/models/tiles.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';
import 'package:game_eleven/shared/widgets/tile_face.dart';

// ============================================================

class ElevenDrawGrid extends StatelessWidget {
  const ElevenDrawGrid({
    super.key,
    required this.draw,
    required this.nicknameOf,
    required this.enabled,
    required this.onPick,
  });

  final ElevenDrawView draw;
  final String Function(String uid) nicknameOf;
  final bool enabled;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final pickerBySlot = {
      for (final entry in draw.picks.entries) entry.value: entry.key,
    };
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      alignment: WrapAlignment.center,
      children: [
        for (var slot = 0; slot < elevenDrawSlotCount; slot++)
          _DrawSlot(
            key: ValueKey('eleven-draw-slot-$slot'),
            pickerName: switch (pickerBySlot[slot]) {
              final uid? => nicknameOf(uid),
              null => null,
            },
            revealed: switch (pickerBySlot[slot]) {
              final uid? => draw.revealed[uid],
              null => null,
            },
            enabled: enabled && !draw.isTaken(slot),
            onTap: () => onPick(slot),
          ),
      ],
    );
  }
}

class _DrawSlot extends StatelessWidget {
  const _DrawSlot({
    super.key,
    required this.pickerName,
    required this.revealed,
    required this.enabled,
    required this.onTap,
  });

  final String? pickerName;
  final int? revealed;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = revealed;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevenTileFace(
            color: value == null ? null : ElevenTileColor.of(value),
            value: value,
            hidden: value == null,
            selected: pickerName != null,
            size: 64,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 80,
            child: Text(
              pickerName ?? '',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ElevenColors.ink, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
