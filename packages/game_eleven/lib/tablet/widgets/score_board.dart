// [score_board.dart] 는 태블릿의 두 참가자 패널과 지난 라운드 기록 줄을 그리는 위젯이다.
//
// 공개 정보(점수·선후공·제출 색)와 controller 기록(색·승자)만 쓴다. 숫자는 없다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_eleven/game_copy.dart';
import 'package:game_eleven/game_theme.dart';
import 'package:game_eleven/shared/models/tiles.dart';
import 'package:game_eleven/shared/services/history_mapper.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';
import 'package:game_eleven/shared/widgets/tile_face.dart';

// ============================================================

class ElevenPlayerPanel extends StatelessWidget {
  const ElevenPlayerPanel({
    super.key,
    required this.player,
    required this.score,
    required this.isFirst,
    required this.isSecond,
    required this.isTurn,
    required this.color,
    required this.autoSubmitted,
  });

  final ElevenPlayerView player;
  final int score;
  final bool isFirst;
  final bool isSecond;
  final bool isTurn;

  /// 이번 라운드 제출 색입니다. 제출 전이면 null입니다.
  final ElevenTileColor? color;
  final bool autoSubmitted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTurn ? ElevenColors.accent : ElevenColors.inkMuted,
          width: isTurn ? 3 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            player.nickname,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ElevenColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isFirst
                ? ElevenCopy.first
                : isSecond
                ? ElevenCopy.second
                : '',
            style: const TextStyle(color: ElevenColors.inkMuted, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Text(
            '$score',
            style: const TextStyle(
              color: ElevenColors.ink,
              fontSize: 48,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: color == null
                ? null
                : ElevenTileFace(color: color, size: 56),
          ),
          SizedBox(
            height: 20,
            child: autoSubmitted
                ? Text(
                    ElevenCopy.autoSubmitted,
                    style: const TextStyle(
                      color: ElevenColors.accent,
                      fontSize: 13,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// 지난 라운드 기록입니다. 칸마다 선공 색·후공 색과 승자 표시만 있습니다.
class ElevenHistoryStrip extends StatelessWidget {
  const ElevenHistoryStrip({
    super.key,
    required this.history,
    required this.seatOrder,
  });

  final List<ElevenHistoryEntry> history;

  /// 좌석 순서 uid. 위·아래 줄 순서를 고정합니다.
  final List<String> seatOrder;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final entry in history)
          Padding(
            key: ValueKey('eleven-history-${entry.round}'),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                for (final uid in seatOrder)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: Opacity(
                      opacity: entry.isTie || entry.winnerUid == uid ? 1 : .45,
                      child: ElevenTileFace(color: entry.colors[uid], size: 22),
                    ),
                  ),
                Text(
                  '${entry.round}',
                  style: const TextStyle(
                    color: ElevenColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
