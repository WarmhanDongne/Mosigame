import 'package:flutter/material.dart';
import 'package:game_eleven/game_copy.dart';
import 'package:game_eleven/shared/noir/noir_motion.dart';
import 'package:game_eleven/shared/noir/noir_text.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';
import 'package:game_eleven/shared/services/history_mapper.dart';
import 'package:game_eleven/shared/widgets/noir_tile.dart';

/// The controller-only history remains colour-only even after a round ends.
class ElevenHistoryStrip extends StatelessWidget {
  const ElevenHistoryStrip({
    super.key,
    required this.history,
    required this.seatOrder,
    this.animatedRound,
  });

  final List<ElevenHistoryEntry> history;
  final List<String> seatOrder;
  final int? animatedRound;

  @override
  Widget build(BuildContext context) {
    final byRound = {for (final entry in history) entry.round: entry};
    return SizedBox.fromSize(
      size: ElevenNoirSpacing.historyCardRect.size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ElevenNoirColors.creamCard,
          border: Border.all(
            color: ElevenNoirColors.ink,
            width: ElevenNoirBorder.heavy,
          ),
          borderRadius: BorderRadius.circular(ElevenNoirRadius.tabletCard),
          boxShadow: ElevenNoirShadow.card,
        ),
        child: Padding(
          padding: ElevenNoirSpacing.historyCardPadding,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 9,
                height: 19,
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text('A', style: ElevenNoirText.columnHead()),
                      ),
                    ),
                    SizedBox(
                      width: ElevenNoirSpacing.historyRowCenterWidth,
                      child: Center(
                        child: Text(
                          ElevenScreenCopy.historyColumnRound,
                          style: ElevenNoirText.columnHead(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text('B', style: ElevenNoirText.columnHead()),
                      ),
                    ),
                  ],
                ),
              ),
              for (var round = 1; round <= 11; round++)
                Positioned(
                  left: 0,
                  right: 0,
                  top:
                      35 +
                      (round - 1) *
                          (ElevenNoirSpacing.historyRowHeight +
                              ElevenNoirSpacing.historyCardGap),
                  height: ElevenNoirSpacing.historyRowHeight,
                  child: KeyedSubtree(
                    key: ValueKey('eleven-history-$round'),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(
                        'history-motion-$round-${animatedRound == round}',
                      ),
                      tween: Tween(
                        begin: animatedRound == round && byRound[round] != null
                            ? 0
                            : 1,
                        end: 1,
                      ),
                      duration: animatedRound == round
                          ? ElevenHistoryRowMotion.tilesIn
                          : Duration.zero,
                      curve: ElevenHistoryRowMotion.tileCurve,
                      builder: (context, progress, child) => Opacity(
                        opacity: progress.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(
                            ElevenHistoryRowMotion.tileOffsetX * (1 - progress),
                            0,
                          ),
                          child: child,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _cell(
                              byRound[round],
                              seatOrder.isNotEmpty ? seatOrder[0] : '',
                              true,
                            ),
                          ),
                          SizedBox(
                            width: ElevenNoirSpacing.historyRowCenterWidth,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (byRound[round]?.isTie == true)
                                  SizedBox(
                                    height: 38,
                                    child: Stack(
                                      alignment: Alignment.topCenter,
                                      children: [
                                        Text(
                                          ElevenScreenCopy.historyTie,
                                          style: ElevenNoirText.historyTie(),
                                        ),
                                        Positioned(
                                          top: 20,
                                          child: Text(
                                            ElevenScreenCopy.historyTieMark,
                                            style:
                                                ElevenNoirText.historyTieMark(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (byRound[round] case final entry?)
                                  Text(
                                    entry.winnerUid == seatOrder.firstOrNull
                                        ? ElevenScreenCopy.historyWinLeft
                                        : ElevenScreenCopy.historyWinRight,
                                    style: ElevenNoirText.historyResult(),
                                  ),
                                Text(
                                  ElevenScreenCopy.historyRound(round),
                                  style: ElevenNoirText.historyRound(),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _cell(
                              byRound[round],
                              seatOrder.length > 1 ? seatOrder[1] : '',
                              false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(ElevenHistoryEntry? entry, String uid, bool left) {
    final color = entry?.colors[uid];
    final lose = entry != null && !entry.isTie && entry.winnerUid != uid;
    return Center(
      child: Opacity(
        opacity: lose ? ElevenNoirOpacity.lose : 1,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ElevenNoirTile(
              face: color == null
                  ? ElevenTileFace.empty
                  : ElevenTileFace.of(color),
              spec: ElevenTileSpec.historyCell.copyWith(
                shadow: ElevenNoirShadow.historyCell(towardLeft: left),
              ),
              state: color != null && entry!.winnerUid == uid
                  ? ElevenTileState.win
                  : ElevenTileState.normal,
            ),
            if (entry != null && entry.firstUid == uid)
              Positioned(
                left: -10,
                top: -9,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: ElevenNoirColors.red,
                    border: Border.all(
                      color: ElevenNoirColors.ink,
                      width: ElevenNoirBorder.thin,
                    ),
                    borderRadius: BorderRadius.circular(
                      ElevenNoirRadius.firstBadgeInRow,
                    ),
                  ),
                  child: Text(
                    ElevenScreenCopy.firstBadge,
                    style: ElevenNoirText.firstBadge(inHistoryRow: true),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
