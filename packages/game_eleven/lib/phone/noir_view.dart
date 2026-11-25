import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown.dart';
import 'package:game_eleven/game_copy.dart';
import 'package:game_eleven/phone/providers/game_stage.dart';
import 'package:game_eleven/phone/widgets/tile_rack.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/models/tiles.dart';
import 'package:game_eleven/shared/noir/noir_motion.dart';
import 'package:game_eleven/shared/noir/noir_text.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';
import 'package:game_eleven/shared/widgets/noir_crown.dart';
import 'package:game_eleven/shared/widgets/noir_dashed_box.dart';
import 'package:game_eleven/shared/widgets/noir_icons.dart';
import 'package:game_eleven/shared/widgets/noir_stage.dart';
import 'package:game_eleven/shared/widgets/noir_tile.dart';

/// The 844×390 design surface, scaled as a whole for smaller landscape phones.
class ElevenPhoneNoirView extends StatelessWidget {
  const ElevenPhoneNoirView({
    super.key,
    required this.game,
    required this.uid,
    required this.screen,
    required this.stage,
    required this.selected,
    required this.submitting,
    required this.onSelect,
    required this.onSubmit,
    required this.onExit,
    required this.onRules,
    this.turnProgress = 1,
    this.selectionProgress = 1,
    this.endProgress = 1,
  });

  final ElevenGameState game;
  final String uid;
  final ElevenPhoneScreen screen;
  final ElevenPhoneStage stage;
  final int? selected;
  final bool submitting;
  final ValueChanged<int> onSelect;
  final VoidCallback onSubmit;
  final VoidCallback onExit;
  final VoidCallback onRules;
  final double turnProgress;
  final double selectionProgress;
  final double endProgress;

  @override
  Widget build(BuildContext context) {
    final pub = game.public;
    final opponentUid = pub.players.keys.firstWhere(
      (id) => id != uid,
      orElse: () => '',
    );
    final mySeat = pub.players[uid]?.seatIndex ?? 0;
    final opponent = pub.nicknameOf(opponentUid);
    final myScore = pub.scores[uid] ?? 0;
    final theirScore = pub.scores[opponentUid] ?? 0;
    final status = _status(opponent);
    final isEnd =
        screen == ElevenPhoneScreen.p10Winner ||
        screen == ElevenPhoneScreen.p11Loser;
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 844,
            height: 390,
            child: ElevenNoirStage(
              child: Stack(
                children: [
                  _playerChip(
                    mySeat,
                    myScore,
                    theirScore,
                    pub.players[uid]?.characterId ?? '',
                  ),
                  if (!isEnd)
                    _statusChip(
                      status,
                      MediaQuery.disableAnimationsOf(context),
                    ),
                  _menuButton(706, true, ElevenScreenCopy.rules, onRules),
                  _menuButton(772, false, ElevenCopy.toLobby, onExit),
                  if (isEnd)
                    _winner(
                      pub.winnerUid ?? pub.draw?.winnerUid,
                      myScore,
                      theirScore,
                      MediaQuery.disableAnimationsOf(context),
                    )
                  else if (_isGuide)
                    _guide(opponent, myScore, theirScore)
                  else
                    ..._playArea(
                      opponent,
                      MediaQuery.disableAnimationsOf(context),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _isGuide => switch (screen) {
    ElevenPhoneScreen.p01DrawWait ||
    ElevenPhoneScreen.g1DrawMyTurn ||
    ElevenPhoneScreen.g2DrawOtherFirst ||
    ElevenPhoneScreen.g3DrawPicked ||
    ElevenPhoneScreen.g4DrawResultFirst ||
    ElevenPhoneScreen.g5DrawResultSecond ||
    ElevenPhoneScreen.g6RoundResultWait ||
    ElevenPhoneScreen.g7EarlyEnd ||
    ElevenPhoneScreen.g8TieDraw => true,
    _ => false,
  };

  bool get _myTurn => switch (screen) {
    ElevenPhoneScreen.p01DrawWait ||
    ElevenPhoneScreen.g1DrawMyTurn ||
    ElevenPhoneScreen.g4DrawResultFirst ||
    ElevenPhoneScreen.p02FirstChoosing ||
    ElevenPhoneScreen.p05SecondChoosing ||
    ElevenPhoneScreen.p09LastTile => true,
    ElevenPhoneScreen.g8TieDraw => game.public.draw?.nextPickerUid == uid,
    ElevenPhoneScreen.p08RoundResult =>
      game.roundOutcomeFor(uid) == ElevenRoundOutcome.win,
    ElevenPhoneScreen.g7EarlyEnd => true,
    _ => false,
  };

  (String, String) _status(String opponent) {
    final round = game.public.round;
    return switch (screen) {
      ElevenPhoneScreen.p01DrawWait || ElevenPhoneScreen.g1DrawMyTurn => (
        ElevenScreenCopy.tagFirstDraw,
        ElevenScreenCopy.drawMyTurnStatus,
      ),
      ElevenPhoneScreen.g2DrawOtherFirst => (
        ElevenScreenCopy.tagFirstDraw,
        ElevenScreenCopy.drawOtherFirst(opponent),
      ),
      ElevenPhoneScreen.g3DrawPicked => (
        ElevenScreenCopy.tagFirstDraw,
        ElevenScreenCopy.drawPickedWaiting(opponent),
      ),
      ElevenPhoneScreen.g4DrawResultFirst => (
        ElevenScreenCopy.tagFirstDraw,
        ElevenScreenCopy.drawIAmFirst,
      ),
      ElevenPhoneScreen.g5DrawResultSecond => (
        ElevenScreenCopy.tagFirstDraw,
        ElevenScreenCopy.drawOtherIsFirst(opponent),
      ),
      ElevenPhoneScreen.p02FirstChoosing => (
        ElevenScreenCopy.tagFirst(round),
        ElevenScreenCopy.firstChoose,
      ),
      ElevenPhoneScreen.p03SecondPreselect => (
        ElevenScreenCopy.tagSecond(round),
        ElevenScreenCopy.preselectStatus,
      ),
      ElevenPhoneScreen.p04FirstSubmitted => (
        ElevenScreenCopy.tagSecondTurn(round),
        ElevenScreenCopy.opponentChoosing,
      ),
      ElevenPhoneScreen.p05SecondChoosing => (
        ElevenScreenCopy.tagSecond(round),
        ElevenScreenCopy.secondChoose,
      ),
      ElevenPhoneScreen.p06AutoSubmitted => (
        ElevenScreenCopy.tagTimeout(round),
        ElevenScreenCopy.autoSubmittedStatus,
      ),
      ElevenPhoneScreen.p07SecondSubmitted => (
        ElevenScreenCopy.tagWaitingResult(round),
        ElevenScreenCopy.bothSubmitted,
      ),
      ElevenPhoneScreen.p08RoundResult => (
        ElevenScreenCopy.tagRoundResult(round),
        switch (game.roundOutcomeFor(uid)) {
          ElevenRoundOutcome.win => ElevenScreenCopy.roundIWon,
          ElevenRoundOutcome.lose => ElevenScreenCopy.roundOpponentWon,
          ElevenRoundOutcome.tie => ElevenScreenCopy.roundTieStatus,
          null => '',
        },
      ),
      ElevenPhoneScreen.p09LastTile => (
        game.public.firstUid == uid
            ? ElevenScreenCopy.tagFirst(round)
            : ElevenScreenCopy.tagSecond(round),
        ElevenScreenCopy.lastTileStatus,
      ),
      ElevenPhoneScreen.g6RoundResultWait => (
        ElevenScreenCopy.tagRoundResult(round),
        ElevenScreenCopy.resultChecking,
      ),
      ElevenPhoneScreen.g7EarlyEnd => (
        ElevenScreenCopy.tagEarlyEnd,
        ElevenScreenCopy.gameOver,
      ),
      ElevenPhoneScreen.g8TieDraw => (
        ElevenScreenCopy.tagTieDraw,
        game.public.draw?.nextPickerUid == uid
            ? ElevenScreenCopy.myTurn
            : game.public.draw?.picks.containsKey(uid) == true
            ? ElevenScreenCopy.drawPickedWaiting(opponent)
            : ElevenScreenCopy.drawOtherFirst(opponent),
      ),
      _ => ('', ''),
    };
  }

  Widget _card({required double radius, required Widget child, Color? color}) =>
      Container(
        decoration: BoxDecoration(
          color: color ?? ElevenNoirColors.cream,
          border: Border.all(
            color: ElevenNoirColors.ink,
            width: ElevenNoirBorder.regular,
          ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: ElevenNoirShadow.regular,
        ),
        child: child,
      );

  /// 참가자가 고른 캐릭터 얼굴(공용 MosiFace). 캐릭터 정보가 없으면 좌석 글자(A/B)로 대신한다.
  Widget _avatarFace(
    String characterId,
    String seatLetter,
    double size,
    TextStyle letterStyle,
  ) => characterId.isEmpty
      ? Text(seatLetter, style: letterStyle)
      : ClipOval(
          child: MosiFace(characterId: characterId, size: size),
        );

  Widget _playerChip(int seat, int mine, int theirs, String characterId) =>
      Positioned(
        left: 20,
        top: 18,
        height: ElevenNoirSpacing.chipHeight,
        child: _card(
          radius: ElevenNoirRadius.chip,
          child: Padding(
            padding: ElevenNoirSpacing.playerChipPadding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ElevenNoirColors.avatarCream,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ElevenNoirColors.ink,
                      width: ElevenNoirBorder.thin,
                    ),
                  ),
                  child: _avatarFace(
                    characterId,
                    seat == 0 ? 'A' : 'B',
                    34,
                    ElevenNoirText.avatar(),
                  ),
                ),
                const SizedBox(width: ElevenNoirSpacing.playerChipGap),
                Text(ElevenScreenCopy.me, style: ElevenNoirText.topBar()),
                const SizedBox(width: ElevenNoirSpacing.playerChipGap),
                Text('$mine : $theirs', style: ElevenNoirText.topBarScore()),
              ],
            ),
          ),
        ),
      );

  Widget _statusChip((String, String) status, bool reducedMotion) => Positioned(
    left: 174,
    right: 152,
    top: 18,
    height: ElevenNoirSpacing.chipHeight,
    child: Transform.translate(
      offset: Offset(reducedMotion ? 0 : _shakeX, 0),
      child: _card(
        radius: ElevenNoirRadius.chip,
        color: _turnColor,
        child: Padding(
          padding: ElevenNoirSpacing.statusChipPadding,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ElevenNoirColors.ink,
                  borderRadius: BorderRadius.circular(ElevenNoirRadius.tag),
                ),
                child: Text(status.$1, style: ElevenNoirText.tag()),
              ),
              const SizedBox(width: ElevenNoirSpacing.statusChipGap),
              Expanded(
                child: Text(
                  status.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ElevenNoirText.topBar(color: _turnTextColor),
                ),
              ),
              if (stage.canSubmit && game.public.turnDeadlineAt != null)
                GameTurnCountdown(
                  expiresAt: game.public.turnDeadlineAt,
                  builder: (context, remaining) {
                    final seconds = math.max(
                      0,
                      ((remaining?.inMilliseconds ?? 0) + 999) ~/ 1000,
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ElevenNoirColors.ink,
                        borderRadius: BorderRadius.circular(
                          ElevenNoirRadius.timer,
                        ),
                      ),
                      child: Text(
                        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                        style: ElevenNoirText.topBar(
                          color: ElevenNoirColors.cream,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );

  double get _turnColorFraction {
    if (!_myTurn) return 0;
    final elapsed = turnProgress * ElevenTurnMotion.total.inMilliseconds;
    final start = ElevenTurnMotion.creamHold.inMilliseconds;
    final duration = ElevenTurnMotion.colorChange.inMilliseconds;
    final fraction = ((elapsed - start) / duration).clamp(0.0, 1.0);
    return ElevenTurnMotion.colorCurve.transform(fraction);
  }

  Color get _turnColor => Color.lerp(
    ElevenNoirColors.cream,
    ElevenNoirColors.red,
    _turnColorFraction,
  )!;

  Color get _turnTextColor => Color.lerp(
    ElevenNoirColors.ink,
    ElevenNoirColors.cream,
    _turnColorFraction,
  )!;

  double get _shakeX {
    if (turnProgress >= 1 || turnProgress <= 0) return 0;
    final steps = ElevenTurnMotion.shakeOffsets;
    final step =
        (turnProgress *
                ElevenTurnMotion.total.inMilliseconds /
                ElevenTurnMotion.shakeStep.inMilliseconds)
            .floor();
    return step < steps.length ? steps[step] : 0;
  }

  Widget _menuButton(
    double x,
    bool rules,
    String label,
    VoidCallback callback,
  ) => Positioned(
    left: x,
    top: 18,
    width: 52,
    height: 52,
    child: Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: callback,
        child: _card(
          radius: ElevenNoirRadius.phoneButton,
          child: Center(
            child: rules
                ? Text(
                    '?',
                    style: ElevenNoirText.body(22, weight: FontWeight.w900),
                  )
                : const ElevenNoirIcon(ElevenNoirIconKind.exit),
          ),
        ),
      ),
    ),
  );

  List<Widget> _playArea(String opponent, bool reducedMotion) {
    final pub = game.public;
    final submission = game.private.submissionFor(pub.round);
    final locked = !stage.canSelect || submitting;
    final chosen =
        submission?.value ??
        selected ??
        (screen == ElevenPhoneScreen.p09LastTile &&
                game.private.tiles.length == 1
            ? game.private.tiles.single
            : null);
    return [
      Positioned(
        left: 24,
        top: 136,
        child: ElevenTileRack(
          remaining: game.private.tiles,
          selected: chosen,
          enabled: !locked,
          onSelect: onSelect,
        ),
      ),
      Positioned(
        left: 556,
        top: 88,
        width: ElevenNoirSpacing.phonePanelWidth,
        height: 286,
        child: _card(
          radius: ElevenNoirRadius.phonePanel,
          child: _panel(chosen, opponent, reducedMotion),
        ),
      ),
    ];
  }

  Widget _panel(int? chosen, String opponent, bool reducedMotion) {
    final pub = game.public;
    final nextFirstUid = game.currentRoundResult?.winnerUid ?? pub.firstUid;
    final isNextFirst = nextFirstUid == uid;
    final isPreselect = screen == ElevenPhoneScreen.p03SecondPreselect;
    final isChoosing =
        screen == ElevenPhoneScreen.p02FirstChoosing ||
        screen == ElevenPhoneScreen.p05SecondChoosing ||
        screen == ElevenPhoneScreen.p09LastTile;
    final isSubmitted =
        screen == ElevenPhoneScreen.p04FirstSubmitted ||
        screen == ElevenPhoneScreen.p06AutoSubmitted ||
        screen == ElevenPhoneScreen.p07SecondSubmitted;
    final isSecond = screen == ElevenPhoneScreen.p05SecondChoosing;
    final value = chosen;
    final colorName = value == null
        ? ''
        : ElevenTileColor.of(value) == ElevenTileColor.black
        ? ElevenScreenCopy.black
        : ElevenScreenCopy.white;
    final canSubmit =
        stage.canSubmit &&
        !submitting &&
        (selected != null || screen == ElevenPhoneScreen.p09LastTile);
    return Padding(
      padding: const EdgeInsets.all(ElevenNoirSpacing.phonePanelPadding),
      child: Stack(
        children: [
          if (isSecond && pub.currentRound.firstColor != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: ElevenNoirSpacing.summaryRowHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ElevenNoirColors.creamCard,
                  borderRadius: BorderRadius.circular(
                    ElevenNoirRadius.summaryRow,
                  ),
                ),
                child: Padding(
                  padding: ElevenNoirSpacing.summaryRowPadding,
                  child: Row(
                    children: [
                      ElevenNoirTile(
                        face: ElevenTileFace.of(pub.currentRound.firstColor!),
                        spec: ElevenTileSpec.phoneSummaryMini,
                      ),
                      const SizedBox(width: ElevenNoirSpacing.summaryRowGap),
                      Expanded(
                        child: Text(
                          ElevenScreenCopy.firstPlayed(
                            pub.nicknameOf(pub.firstUid),
                            pub.currentRound.firstColor == ElevenTileColor.black
                                ? ElevenScreenCopy.black
                                : ElevenScreenCopy.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ElevenNoirText.panelLabel(
                            color: ElevenNoirColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (isChoosing || isPreselect || isSubmitted)
            Positioned(
              left: 0,
              top: isSecond
                  ? 72
                  : isSubmitted
                  ? 32
                  : 21,
              child: value == null
                  ? const ElevenNoirTile(
                      face: ElevenTileFace.placeholder,
                      spec: ElevenTileSpec.phonePanel,
                    )
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ElevenNoirTile(
                          face: ElevenTileFace.ofValue(value),
                          value: value,
                          spec: screen == ElevenPhoneScreen.p09LastTile
                              ? ElevenTileSpec.phoneLastTile
                              : isSecond
                              ? ElevenTileSpec.phoneSummary
                              : ElevenTileSpec.phonePanel,
                        ),
                        if (isSubmitted)
                          ElevenNoirTiltedBadge(
                            left: screen == ElevenPhoneScreen.p04FirstSubmitted
                                ? ElevenNoirBadgeLayout.tiltedLeftP04
                                : ElevenNoirBadgeLayout.tiltedLeft,
                            label: screen == ElevenPhoneScreen.p06AutoSubmitted
                                ? ElevenScreenCopy.autoSubmittedBadge
                                : ElevenScreenCopy.submittedBadge,
                          ),
                      ],
                    ),
            ),
          if ((isChoosing || isPreselect || isSubmitted) && value != null)
            Positioned(
              left: isSecond ? 82 : 94,
              right: 0,
              top: isSecond
                  ? 88
                  : isSubmitted
                  ? 42
                  : 46,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    screen == ElevenPhoneScreen.p09LastTile
                        ? ElevenScreenCopy.lastTileLabel
                        : screen == ElevenPhoneScreen.p06AutoSubmitted
                        ? ElevenScreenCopy.autoSubmittedLabel
                        : isSubmitted
                        ? ElevenScreenCopy.submittedTileLabel
                        : isPreselect || isSecond
                        ? ElevenScreenCopy.selectedTile
                        : ElevenScreenCopy.confirmTile,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ElevenNoirText.panelLabel(),
                  ),
                  Text(
                    ElevenScreenCopy.tileName(colorName, value),
                    style: ElevenNoirText.panelValue(),
                  ),
                  if (isPreselect || isSubmitted)
                    Text(
                      isPreselect
                          ? ElevenScreenCopy.preselectChangeLater
                          : screen == ElevenPhoneScreen.p06AutoSubmitted
                          ? ElevenScreenCopy.autoSubmittedNote
                          : ElevenScreenCopy.tabletShowsColorOnly(colorName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ElevenNoirText.small(),
                    ),
                ],
              ),
            ),
          if ((isChoosing || isPreselect) && value == null)
            Positioned(
              left: 94,
              right: 0,
              top: 46,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPreselect
                        ? ElevenScreenCopy.preselectPrompt
                        : ElevenScreenCopy.pickTilePrompt,
                    style: ElevenNoirText.panelLabel(),
                  ),
                  Text(
                    ElevenScreenCopy.emptyValue,
                    style: ElevenNoirText.panelValue(),
                  ),
                ],
              ),
            ),
          if (screen == ElevenPhoneScreen.p08RoundResult && pub.round < 11) ...[
            Positioned(
              left: 0,
              top: 30,
              child: Text(
                ElevenScreenCopy.nextRoundSoon,
                style: ElevenNoirText.panelLabel(),
              ),
            ),
            Positioned(
              left: 0,
              top: 57,
              child: Text(
                ElevenScreenCopy.nextRound(pub.round + 1),
                style: ElevenNoirText.nextRound(),
              ),
            ),
            if (game.currentRoundResult != null)
              Positioned(
                left: 0,
                top: 112,
                child: Row(
                  children: [
                    _tag(
                      isNextFirst
                          ? ElevenScreenCopy.firstMark
                          : ElevenScreenCopy.secondMark,
                      color: isNextFirst
                          ? ElevenNoirColors.red
                          : ElevenNoirColors.ink,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isNextFirst
                          ? ElevenScreenCopy.iPlayFirst
                          : ElevenScreenCopy.iPlayAfterOpponent,
                      style: ElevenNoirText.topBar(),
                    ),
                  ],
                ),
              ),
          ],
          if (isChoosing || isPreselect)
            Positioned(
              left: 0,
              right: 0,
              top: isSecond ? 192 : 159,
              height: isSecond ? 52 : 56,
              child: Transform.scale(
                scale: reducedMotion || !canSubmit ? 1 : _buttonScale,
                child: Opacity(
                  opacity: isPreselect
                      ? 1
                      : canSubmit
                      ? _buttonOpacity
                      : ElevenTurnMotion.popStartOpacity,
                  child: _submitButton(canSubmit, isPreselect),
                ),
              ),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 62,
              child: _dashed(
                screen == ElevenPhoneScreen.p08RoundResult
                    ? ElevenScreenCopy.tabletShowingResult
                    : ElevenScreenCopy.resultOnTablet,
              ),
            ),
          if ((isChoosing || isPreselect) && !isSecond)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Text(
                isPreselect
                    ? ElevenScreenCopy.myTurnAfter(opponent)
                    : ElevenScreenCopy.submitIsFinal,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ElevenNoirText.small(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _submitButton(bool enabled, bool preselect) => Semantics(
    button: true,
    enabled: enabled,
    child: GestureDetector(
      key: const ValueKey('eleven-phone-submit'),
      onTap: enabled ? onSubmit : null,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: preselect
              ? ElevenNoirColors.disabledCream
              : ElevenNoirColors.red,
          border: Border.all(
            color: preselect
                ? ElevenNoirColors.greyBeige
                : ElevenNoirColors.ink,
            width: ElevenNoirBorder.regular,
          ),
          borderRadius: BorderRadius.circular(ElevenNoirRadius.phoneButton),
          boxShadow: preselect ? null : ElevenNoirShadow.regular,
        ),
        child: Text(
          preselect ? ElevenScreenCopy.submitLocked : ElevenScreenCopy.submit,
          style: ElevenNoirText.submitButton(locked: preselect),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );

  double get _buttonScale {
    final elapsed =
        selectionProgress * ElevenTurnMotion.popTotal.inMilliseconds;
    final peak = ElevenTurnMotion.popPeakAt.inMilliseconds;
    final start = ElevenTurnMotion.popScaleUpAt.inMilliseconds;
    if (elapsed <= start) return 1;
    if (elapsed <= peak) {
      final fraction = (elapsed - start) / (peak - start);
      return 1 +
          (ElevenTurnMotion.popScale - 1) *
              ElevenTurnMotion.popCurve.transform(fraction);
    }
    final fraction =
        (elapsed - peak) / (ElevenTurnMotion.popTotal.inMilliseconds - peak);
    return ElevenTurnMotion.popScale -
        (ElevenTurnMotion.popScale - 1) * fraction.clamp(0, 1);
  }

  double get _buttonOpacity {
    final elapsed =
        selectionProgress * ElevenTurnMotion.popTotal.inMilliseconds;
    final fade = (elapsed / ElevenTurnMotion.popFadeIn.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    return ElevenTurnMotion.popStartOpacity +
        (1 - ElevenTurnMotion.popStartOpacity) * fade;
  }

  Widget _dashed(String label) => ElevenNoirDashedBox(label: label);

  Widget _tag(String label, {Color color = ElevenNoirColors.ink}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(ElevenNoirRadius.tag),
    ),
    child: Text(label, style: ElevenNoirText.tag()),
  );

  Widget _guide(String opponent, int mine, int theirs) {
    final draw = game.public.draw;
    final myDraw = draw?.revealed[uid];
    final otherUid = game.public.players.keys.firstWhere(
      (id) => id != uid,
      orElse: () => '',
    );
    final otherDraw = draw?.revealed[otherUid];
    final resultFirst = screen == ElevenPhoneScreen.g4DrawResultFirst;
    final resultSecond = screen == ElevenPhoneScreen.g5DrawResultSecond;
    final result = resultFirst || resultSecond;
    final title = switch (screen) {
      ElevenPhoneScreen.g2DrawOtherFirst => ElevenScreenCopy.drawOtherFirst(
        opponent,
      ),
      ElevenPhoneScreen.g3DrawPicked => ElevenScreenCopy.drawPicked,
      ElevenPhoneScreen.g4DrawResultFirst => ElevenScreenCopy.drawIAmFirst,
      ElevenPhoneScreen.g5DrawResultSecond => ElevenScreenCopy.drawOtherIsFirst(
        opponent,
      ),
      ElevenPhoneScreen.g6RoundResultWait =>
        ElevenScreenCopy.checkResultOnTablet,
      ElevenPhoneScreen.g7EarlyEnd => ElevenScreenCopy.earlyEndTitle,
      _ => ElevenScreenCopy.drawOnTablet,
    };
    final body = switch (screen) {
      ElevenPhoneScreen.g2DrawOtherFirst => ElevenScreenCopy.drawAfterOther(
        opponent,
      ),
      ElevenPhoneScreen.g3DrawPicked => ElevenScreenCopy.drawRevealTogether(
        opponent,
      ),
      ElevenPhoneScreen.g4DrawResultFirst
          when myDraw != null && otherDraw != null =>
        ElevenScreenCopy.drawIWon(myDraw, otherDraw),
      ElevenPhoneScreen.g5DrawResultSecond
          when myDraw != null && otherDraw != null =>
        ElevenScreenCopy.drawOtherWon(myDraw, otherDraw, opponent),
      ElevenPhoneScreen.g6RoundResultWait =>
        ElevenScreenCopy.resultShownOnTablet,
      ElevenPhoneScreen.g7EarlyEnd => ElevenScreenCopy.earlyEndReason,
      ElevenPhoneScreen.g8TieDraw => ElevenScreenCopy.finalTie(mine, theirs),
      _ => ElevenScreenCopy.drawPickOne,
    };
    final sub = switch (screen) {
      ElevenPhoneScreen.g3DrawPicked => ElevenScreenCopy.resultOnTablet,
      ElevenPhoneScreen.g4DrawResultFirst => ElevenScreenCopy.drawIPlayFirst,
      ElevenPhoneScreen.g5DrawResultSecond => ElevenScreenCopy.drawIPlayAfter(
        opponent,
      ),
      ElevenPhoneScreen.g6RoundResultWait => ElevenScreenCopy.winnerGoesFirst,
      ElevenPhoneScreen.g7EarlyEnd => ElevenScreenCopy.earlyEndSoon,
      ElevenPhoneScreen.g8TieDraw => ElevenScreenCopy.drawRuleFinal,
      _ => ElevenScreenCopy.drawRuleFirst,
    };
    return Positioned(
      left: 82,
      top: 111,
      width: ElevenNoirSpacing.guideCardSize.width,
      height: ElevenNoirSpacing.guideCardSize.height,
      child: _card(
        radius: ElevenNoirRadius.guideCard,
        child: Padding(
          padding: ElevenNoirSpacing.guideCardPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ElevenNoirText.guideTitle(),
              ),
              const SizedBox(height: ElevenNoirSpacing.guideImageTop),
              SizedBox(
                height: 66,
                child: screen == ElevenPhoneScreen.g7EarlyEnd
                    ? Center(
                        child: Text(
                          '$mine : $theirs',
                          style: ElevenNoirText.earlyEndScore(),
                        ),
                      )
                    : screen == ElevenPhoneScreen.g6RoundResultWait
                    ? _roundColorPair()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (result && myDraw != null)
                            _guideTile(
                              myDraw,
                              win: resultFirst,
                              lose: resultSecond,
                            )
                          else
                            _guideBack(),
                          if (result) ...[
                            const SizedBox(
                              width: ElevenNoirSpacing.guideImageGap,
                            ),
                            Text(
                              ElevenScreenCopy.versus,
                              style: ElevenNoirText.versus(),
                            ),
                            const SizedBox(
                              width: ElevenNoirSpacing.guideImageGap,
                            ),
                            if (otherDraw != null)
                              _guideTile(
                                otherDraw,
                                win: resultSecond,
                                lose: resultFirst,
                              )
                            else
                              _guideBack(),
                          ] else if (screen !=
                              ElevenPhoneScreen.g3DrawPicked) ...[
                            const SizedBox(
                              width: ElevenNoirSpacing.guideImageGap,
                            ),
                            _guideBack(),
                            const SizedBox(
                              width: ElevenNoirSpacing.guideImageGap,
                            ),
                            _guideBack(),
                          ],
                        ],
                      ),
              ),
              const SizedBox(
                height:
                    ElevenNoirSpacing.guideImageBottom +
                    ElevenNoirSpacing.guideBodyTop,
              ),
              Text(
                body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ElevenNoirText.guideBody(),
              ),
              const SizedBox(height: ElevenNoirSpacing.guideSubTop),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ElevenNoirText.guideSub(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// G6: 이번 라운드에 낸 두 타일의 색만(숫자 없음) 보여 준다. 왼쪽이 나, 오른쪽이 상대.
  /// 결과가 공개돼 있으면 이긴 쪽은 빨간 외곽선, 진 쪽은 흐리게(.4). 동점이면 둘 다 그대로.
  Widget _roundColorPair() {
    final pub = game.public;
    final round = pub.currentRound;
    final mineColor = pub.firstUid == uid
        ? round.firstColor
        : round.secondColor;
    final theirColor = pub.firstUid == uid
        ? round.secondColor
        : round.firstColor;
    final outcome = game.roundOutcomeFor(uid);
    Widget tile(ElevenTileColor? color, ElevenRoundOutcome? side) {
      final face = color == null
          ? ElevenTileFace.back
          : ElevenTileFace.of(color);
      final card = ElevenNoirTile(
        face: face,
        spec: ElevenTileSpec.phoneGuideColor,
        state: side == ElevenRoundOutcome.win
            ? ElevenTileState.guideWin
            : ElevenTileState.normal,
      );
      return side == ElevenRoundOutcome.lose
          ? Opacity(
              opacity: ElevenNoirOpacity.guideLoserRoundResult,
              child: card,
            )
          : card;
    }

    final theirOutcome = switch (outcome) {
      ElevenRoundOutcome.win => ElevenRoundOutcome.lose,
      ElevenRoundOutcome.lose => ElevenRoundOutcome.win,
      final other => other,
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        tile(mineColor, outcome),
        const SizedBox(width: ElevenNoirSpacing.guideImageGap),
        Text(ElevenScreenCopy.versus, style: ElevenNoirText.versus(size: 22)),
        const SizedBox(width: ElevenNoirSpacing.guideImageGap),
        tile(theirColor, theirOutcome),
      ],
    );
  }

  Widget _guideBack() => const ElevenNoirTile(
    face: ElevenTileFace.back,
    spec: ElevenTileSpec.phoneGuide,
  );

  Widget _guideTile(int? value, {bool win = false, bool lose = false}) =>
      ElevenNoirTile(
        face: value == null
            ? ElevenTileFace.black
            : ElevenTileFace.ofValue(value),
        value: value,
        spec: ElevenTileSpec.phoneGuide,
        state: win
            ? ElevenTileState.guideWin
            : lose
            ? ElevenTileState.guideLose
            : ElevenTileState.normal,
      );

  Widget _winner(String? winnerUid, int mine, int theirs, bool reducedMotion) {
    final winner = game.public.players[winnerUid];
    final seat = winner?.seatIndex == 1 ? 'B' : 'A';
    final name = winner?.nickname ?? '';
    final total = ElevenPhoneEndMotion.total.inMilliseconds;
    final elapsed = endProgress * total;
    final appear = ElevenPhoneEndMotion.crownDelay.inMilliseconds;
    final fallEnd = appear + ElevenPhoneEndMotion.crownFall.inMilliseconds;
    final upEnd = fallEnd + ElevenPhoneEndMotion.crownBounceUp.inMilliseconds;
    final downEnd = upEnd + ElevenPhoneEndMotion.crownBounceDown.inMilliseconds;
    final crownY = elapsed < fallEnd
        ? ElevenPhoneEndMotion.crownFallFrom *
              (1 -
                  ElevenPhoneEndMotion.curve.transform(
                    ((elapsed - appear) /
                            ElevenPhoneEndMotion.crownFall.inMilliseconds)
                        .clamp(0.0, 1.0),
                  ))
        : elapsed < upEnd
        ? ElevenPhoneEndMotion.crownBounceHeight *
              ElevenPhoneEndMotion.curve.transform(
                ((elapsed - fallEnd) /
                        ElevenPhoneEndMotion.crownBounceUp.inMilliseconds)
                    .clamp(0.0, 1.0),
              )
        : elapsed < downEnd
        ? ElevenPhoneEndMotion.crownBounceHeight *
              (1 -
                  ElevenPhoneEndMotion.curve.transform(
                    ((elapsed - upEnd) /
                            ElevenPhoneEndMotion.crownBounceDown.inMilliseconds)
                        .clamp(0.0, 1.0),
                  ))
        : 0.0;
    final crownOpacity =
        ((elapsed - appear) / ElevenPhoneEndMotion.crownAppear.inMilliseconds)
            .clamp(0.0, 1.0);
    final winnerStart = ElevenPhoneEndMotion.winnerDelay.inMilliseconds;
    final winnerGrowEnd =
        winnerStart + ElevenPhoneEndMotion.winnerGrow.inMilliseconds;
    final winnerSettleEnd =
        winnerGrowEnd + ElevenPhoneEndMotion.winnerSettle.inMilliseconds;
    final winnerGrow =
        ((elapsed - winnerStart) /
                ElevenPhoneEndMotion.winnerGrow.inMilliseconds)
            .clamp(0.0, 1.0);
    final winnerSettle =
        ((elapsed - winnerGrowEnd) /
                ElevenPhoneEndMotion.winnerSettle.inMilliseconds)
            .clamp(0.0, 1.0);
    final winnerScale = elapsed < winnerGrowEnd
        ? ElevenPhoneEndMotion.winnerFrom +
              (ElevenPhoneEndMotion.winnerPeak -
                      ElevenPhoneEndMotion.winnerFrom) *
                  ElevenPhoneEndMotion.curve.transform(winnerGrow)
        : elapsed < winnerSettleEnd
        ? ElevenPhoneEndMotion.winnerPeak +
              (1 - ElevenPhoneEndMotion.winnerPeak) *
                  ElevenPhoneEndMotion.curve.transform(winnerSettle)
        : 1.0;
    return Positioned(
      left: 174,
      top: 103,
      width: 496,
      height: 267,
      child: Column(
        children: [
          SizedBox(
            width: 496,
            height: 160,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 210,
                  top:
                      36 -
                      ElevenNoirCrown.phoneSize.height -
                      ElevenNoirCrown.phoneOverlap,
                  child: Transform.translate(
                    offset: Offset(0, reducedMotion ? 0 : crownY),
                    child: Opacity(
                      opacity: crownOpacity,
                      child: Semantics(
                        label: ElevenScreenCopy.crown,
                        child: const ElevenNoirCrown(
                          size: ElevenNoirCrown.phoneSize,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 190,
                  top: 36,
                  child: Container(
                    width: 116,
                    height: 116,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ElevenNoirColors.red,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ElevenNoirColors.ink,
                        width: ElevenNoirBorder.heavy,
                      ),
                      boxShadow: ElevenNoirShadow.regular,
                    ),
                    child: Container(
                      width: 86,
                      height: 86,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ElevenNoirColors.cream,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ElevenNoirColors.ink,
                          width: ElevenNoirBorder.regular,
                        ),
                      ),
                      child: _avatarFace(
                        winner?.characterId ?? '',
                        seat,
                        80,
                        ElevenNoirText.winnerAvatar(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 400,
            child: Text(
              name,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: ElevenNoirText.winnerName(),
            ),
          ),
          Transform.scale(
            scale: reducedMotion ? 1 : winnerScale,
            child: Opacity(
              opacity: winnerGrow,
              child: Text(
                ElevenScreenCopy.winnerLabel,
                style: ElevenNoirText.winnerLabel(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            ElevenScreenCopy.finalNote(mine, theirs),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ElevenNoirText.endNote(),
          ),
        ],
      ),
    );
  }
}
