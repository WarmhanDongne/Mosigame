import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_eleven/game_copy.dart';
import 'package:game_eleven/shared/models/tiles.dart';
import 'package:game_eleven/shared/noir/noir_motion.dart';
import 'package:game_eleven/shared/noir/noir_text.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';
import 'package:game_eleven/shared/widgets/noir_tile.dart';

/// Nine public cards. Only a revealed draw may supply a number to a tile.
class ElevenDrawGrid extends StatelessWidget {
  const ElevenDrawGrid({
    super.key,
    required this.draw,
    required this.nicknameOf,
    required this.seatByUid,
    required this.enabled,
    required this.onPick,
    this.revealFaces = true,
    this.animate = false,
  });

  final ElevenDrawView draw;
  final String Function(String uid) nicknameOf;
  final Map<String, int> seatByUid;
  final bool enabled;
  final ValueChanged<int> onPick;
  final bool revealFaces;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final picked = {
      for (final entry in draw.picks.entries) entry.value: entry.key,
    };
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SizedBox(
      width: ElevenNoirSpacing.drawCardRect.width,
      height: ElevenNoirSpacing.drawCardRect.height,
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
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: animate ? 0 : 1, end: 1),
          duration: animate ? ElevenDrawMotion.dealAll : Duration.zero,
          curve: ElevenCurves.linear,
          builder: (context, dealProgress, child) => GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            padding: ElevenNoirSpacing.drawCardPadding,
            crossAxisCount: 3,
            childAspectRatio: 1,
            children: [
              for (var slot = 0; slot < elevenDrawSlotCount; slot++)
                Center(
                  child: GestureDetector(
                    key: ValueKey('eleven-draw-slot-$slot'),
                    onTap: enabled && draw.canPick(slot)
                        ? () => onPick(slot)
                        : null,
                    child: _DrawCard(
                      slot: slot,
                      uid: picked[slot],
                      winnerUid: draw.winnerUid,
                      seat: seatByUid[picked[slot]] ?? -1,
                      value: revealFaces ? draw.revealed[picked[slot]] : null,
                      dim: picked[slot] == null && draw.revealed.isNotEmpty,
                      nickname: picked[slot] == null
                          ? ''
                          : nicknameOf(picked[slot]!),
                      animate: animate,
                      reduceMotion: reduceMotion,
                      dealProgress: dealProgress,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawCard extends StatelessWidget {
  const _DrawCard({
    required this.slot,
    required this.uid,
    required this.winnerUid,
    required this.seat,
    required this.value,
    required this.dim,
    required this.nickname,
    required this.animate,
    required this.reduceMotion,
    required this.dealProgress,
  });
  final int slot;
  final String? uid;
  final String? winnerUid;
  final int seat;
  final int? value;
  final bool dim;
  final String nickname;
  final bool animate;
  final bool reduceMotion;
  final double dealProgress;

  @override
  Widget build(BuildContext context) {
    final elapsed = ElevenDrawMotion.dealAll.inMicroseconds * dealProgress;
    final started = ElevenDrawMotion.dealStagger.inMicroseconds * slot;
    final cardDuration = ElevenDrawMotion.dealCard.inMicroseconds;
    final deal = !animate || reduceMotion
        ? 1.0
        : ((elapsed - started) / cardDuration).clamp(0.0, 1.0);
    final dealScale =
        ElevenDrawMotion.dealFromScale +
        (1 - ElevenDrawMotion.dealFromScale) * deal;
    final dealY = ElevenDrawMotion.dealFromY * (1 - deal);
    final mode = value != null
        ? 'flip'
        : uid != null
        ? 'pick'
        : 'idle';
    final duration = !animate || reduceMotion
        ? Duration.zero
        : mode == 'flip'
        ? ElevenFlipMotion.duration
        : mode == 'pick'
        ? ElevenDrawMotion.pickLift +
              ElevenDrawMotion.pickHold +
              ElevenDrawMotion.pickLeave
        : Duration.zero;
    return Transform.translate(
      offset: Offset(0, dealY),
      child: Transform.scale(
        scale: dealScale,
        child: TweenAnimationBuilder<double>(
          key: ValueKey('draw-motion-$slot-$mode'),
          tween: Tween(begin: animate && mode != 'idle' ? 0 : 1, end: 1),
          duration: duration,
          curve: ElevenCurves.ease,
          builder: (context, progress, child) {
            final flip = mode == 'flip' && animate && !reduceMotion;
            final picking = mode == 'pick' && animate && !reduceMotion;
            final showValue = value != null && (!flip || progress >= 0.5);
            final xScale = flip
                ? math.cos(math.pi * progress).abs().clamp(0.001, 1.0)
                : 1.0;
            final lift = flip
                ? -ElevenFlipMotion.lift * math.sin(math.pi * progress)
                : picking
                ? ElevenDrawMotion.pickLiftY * math.sin(math.pi * progress)
                : 0.0;
            final pickScale = picking
                ? 1 +
                      (ElevenDrawMotion.pickScale - 1) *
                          math.sin(math.pi * progress)
                : 1.0;
            return Transform.translate(
              offset: Offset(0, lift),
              child: Transform.scale(
                scaleX: xScale * pickScale,
                scaleY: pickScale,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ElevenNoirTile(
                      face: showValue
                          ? ElevenTileFace.ofValue(value!)
                          : ElevenTileFace.back,
                      spec: ElevenTileSpec.drawCard,
                      value: showValue ? value : null,
                      numberQuarterTurns: seat == 0 ? 1 : 3,
                      state: dim
                          ? ElevenTileState.dim
                          : uid != null && (value == null || winnerUid == uid)
                          ? ElevenTileState.picked
                          : ElevenTileState.normal,
                      semanticsLabel: uid == null
                          ? ElevenScreenCopy.drawCardBack
                          : value == null
                          ? ElevenScreenCopy.drawCardPicked(nickname)
                          : ElevenScreenCopy.drawCardRevealed(nickname, value!),
                    ),
                    if (uid != null)
                      Positioned(
                        left: seat == 0 ? -12 : null,
                        right: seat == 0 ? null : -12,
                        top: -12,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: ElevenNoirColors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ElevenNoirColors.ink,
                              width: ElevenNoirBorder.regular,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              seat == 0 ? 'A' : 'B',
                              style: ElevenNoirText.seatMark(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
