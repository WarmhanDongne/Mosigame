import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown.dart';
import 'package:game_eleven/game_copy.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/models/tiles.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';
import 'package:game_eleven/shared/noir/noir_motion.dart';
import 'package:game_eleven/shared/noir/noir_text.dart';
import 'package:game_eleven/shared/noir/noir_toast_schedule.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';
import 'package:game_eleven/shared/widgets/noir_tile.dart';
import 'package:game_eleven/shared/widgets/noir_toast.dart';
import 'package:game_eleven/shared/widgets/noir_crown.dart';
import 'package:game_eleven/shared/widgets/noir_icons.dart';
import 'package:game_eleven/shared/widgets/noir_stage.dart';
import 'package:game_eleven/tablet/providers/game_stage.dart';
import 'package:game_eleven/tablet/widgets/draw_grid.dart';
import 'package:game_eleven/tablet/widgets/score_board.dart';

class ElevenTabletBoardView extends StatelessWidget {
  const ElevenTabletBoardView({
    super.key,
    required this.game,
    required this.screen,
    required this.onPick,
    required this.onRules,
    required this.onSettings,
    required this.onRestart,
    required this.onHome,
    this.animate = true,
    this.drawRevealed = true,
    this.resultEmphasized = true,
  });

  final ElevenGameState game;
  final ElevenTabletScreen screen;
  final ValueChanged<int> onPick;
  final VoidCallback onRules;
  final VoidCallback onSettings;
  final VoidCallback onRestart;
  final VoidCallback onHome;
  final bool animate;
  final bool drawRevealed;
  final bool resultEmphasized;

  bool get _draw => {
    ElevenTabletScreen.t01DrawStart,
    ElevenTabletScreen.t02DrawSecondPick,
    ElevenTabletScreen.t03DrawReveal,
    ElevenTabletScreen.t11TieDraw,
    ElevenTabletScreen.t12TieReveal,
  }.contains(screen);
  bool get _final =>
      screen == ElevenTabletScreen.t13Final ||
      screen == ElevenTabletScreen.t13bFinalTieDraw;

  @override
  Widget build(BuildContext context) {
    final pub = game.public;
    final seats = pub.seatedPlayers;
    final motionEnabled =
        animate && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final showDraw = _draw && pub.draw != null;
    final centerRect = showDraw
        ? ElevenNoirSpacing.drawCardRect
        : ElevenNoirSpacing.historyCardRect;
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 1194,
        height: 834,
        child: Stack(
          children: [
            const Positioned.fill(child: ElevenNoirStage()),
            for (var seat = 0; seat < seats.length && seat < 2; seat++)
              Positioned(
                left: _final
                    ? seat == 0
                          ? 0
                          : 874
                    : seat == 0
                    ? 12
                    : 862,
                top: 37,
                child: RotatedBox(
                  quarterTurns: seat == 0 ? 1 : 3,
                  child: SizedBox.fromSize(
                    size: ElevenNoirSpacing.tabletSideSize,
                    child: _side(context, seats[seat].uid, seat),
                  ),
                ),
              ),
            if (!_final)
              AnimatedPositioned(
                left: centerRect.left,
                top: centerRect.top,
                width: centerRect.width,
                height: centerRect.height,
                duration: motionEnabled
                    ? ElevenDrawMotion.boardMorph
                    : Duration.zero,
                curve: ElevenCurves.ease,
                child: AnimatedSwitcher(
                  duration: animate
                      ? ElevenDrawMotion.boardFade
                      : Duration.zero,
                  child: FittedBox(
                    key: ValueKey(showDraw ? 'draw-board' : 'history-board'),
                    fit: BoxFit.fill,
                    child: SizedBox.fromSize(
                      size: centerRect.size,
                      child: showDraw
                          ? ElevenDrawGrid(
                              draw: pub.draw!,
                              nicknameOf: pub.nicknameOf,
                              seatByUid: {
                                for (final player in seats)
                                  player.uid: player.seatIndex,
                              },
                              enabled:
                                  screen == ElevenTabletScreen.t01DrawStart ||
                                  screen ==
                                      ElevenTabletScreen.t02DrawSecondPick ||
                                  screen == ElevenTabletScreen.t11TieDraw,
                              revealFaces: drawRevealed,
                              animate: motionEnabled,
                              onPick: onPick,
                            )
                          : ElevenHistoryStrip(
                              // 이번 라운드 행은 결과 단계에서 아직 채우지 않는다. 서버는
                              // 판정과 동시에 기록하지만, 시안·MotionKit 7은 새 라운드가 시작될
                              // 때 직전 라운드 행을 채운다(카드 결과 공개보다 먼저 보이지 않게).
                              history: [
                                for (final entry in game.history)
                                  if (pub.status != 'playing' ||
                                      pub.phase != 'roundResult' ||
                                      entry.round != pub.round)
                                    entry,
                              ],
                              seatOrder: [for (final p in seats) p.uid],
                              animatedRound:
                                  motionEnabled &&
                                      screen == ElevenTabletScreen.t09RoundIntro
                                  ? pub.round - 1
                                  : null,
                            ),
                    ),
                  ),
                ),
              ),
            if (_final) ..._finalWidgets(seats.map((p) => p.uid).toList()),
            if (screen == ElevenTabletScreen.closing)
              Center(
                child: ElevenToastText(text: ElevenScreenCopy.pillGameOver),
              ),
            if (screen != ElevenTabletScreen.connecting &&
                screen != ElevenTabletScreen.closing &&
                !_final)
              Positioned.fromRect(
                rect: ElevenNoirSpacing.toastRect,
                child: _BoardToast(
                  // 화면 내용이 바뀔 때만 다시 재생한다. revision은 복구·준비 상태 같은
                  // 화면과 무관한 서버 쓰기에도 오르므로 키에 넣지 않는다(다시하기 직후
                  // “타일 선택”이 두 번 나오던 원인).
                  key: ValueKey(
                    'eleven-toast-${pub.startedAt}-${pub.phase}-${pub.round}-${pub.draw?.picks.length}-${screen.id}',
                  ),
                  playKey: (
                    pub.startedAt,
                    pub.phase,
                    pub.round,
                    pub.draw?.picks.length,
                    screen.id,
                  ),
                  steps: _toastSteps(),
                  secondSteps: _secondToastSteps(),
                  delay: switch (screen) {
                    ElevenTabletScreen.t03DrawReveal ||
                    ElevenTabletScreen.t12TieReveal =>
                      ElevenDrawMotion.revealToastAt,
                    ElevenTabletScreen.t07RoundWin ||
                    ElevenTabletScreen.t08RoundTie =>
                      ElevenRoundFlowMotion.toastAt,
                    // 뽑기 카드 9장이 딜된 뒤 첫 “타일 선택”(프로토타입 ① kDt2).
                    ElevenTabletScreen.t01DrawStart =>
                      ElevenDrawMotion.pickToastAt,
                    _ => Duration.zero,
                  },
                  animate: animate,
                ),
              ),
            Positioned(
              right: ElevenNoirSpacing.menuInset,
              top: ElevenNoirSpacing.menuInset,
              child: Row(
                children: [
                  _menuButton(true, ElevenScreenCopy.menuRules, onRules),
                  const SizedBox(width: ElevenNoirSpacing.menuGap),
                  _menuButton(false, ElevenScreenCopy.menuSettings, onSettings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _side(BuildContext context, String uid, int seat) {
    final pub = game.public;
    final motionEnabled =
        animate && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final draw = pub.draw;
    final picked = draw?.picks.containsKey(uid) ?? false;
    final value = draw?.revealed[uid];
    final isWinner =
        (screen == ElevenTabletScreen.t03DrawReveal ||
            screen == ElevenTabletScreen.t12TieReveal)
        ? draw?.winnerUid == uid
        : pub.winnerUid == uid;
    final isResult = {
      ElevenTabletScreen.t07RoundWin,
      ElevenTabletScreen.t08RoundTie,
    }.contains(screen);
    final currentResult = game.currentRoundResult;
    final currentHistory = game.lastHistory?.round == pub.round
        ? game.lastHistory
        : null;
    final resultWinner = currentResult?.winnerUid ?? currentHistory?.winnerUid;
    final resultTie = currentResult?.isTie ?? currentHistory?.isTie ?? false;
    final isTurn = _draw
        ? screen == ElevenTabletScreen.t03DrawReveal
              ? draw?.winnerUid == uid
              : draw?.nextPickerUid == uid
        : pub.turnUid == uid;
    final auto = pub.currentRound.autoSubmitted.contains(uid);
    String pill;
    if (_final || screen == ElevenTabletScreen.t12TieReveal) {
      pill = isWinner ? ElevenScreenCopy.pillWin : ElevenScreenCopy.pillLose;
    } else if (screen == ElevenTabletScreen.t10EarlyEnd ||
        screen == ElevenTabletScreen.closing) {
      pill = ElevenScreenCopy.pillGameOver;
    } else if (isResult) {
      pill = resultTie
          ? ElevenScreenCopy.pillTie
          : resultWinner == uid
          ? ElevenScreenCopy.pillWin
          : ElevenScreenCopy.pillLose;
    } else if (screen == ElevenTabletScreen.t06AutoSubmitted ||
        (!_draw && auto)) {
      pill = ElevenScreenCopy.pillAutoSubmitted;
    } else if (_draw && picked && value == null) {
      pill = ElevenScreenCopy.pillPicked;
    } else if (!_draw && _submitted(uid)) {
      pill = ElevenScreenCopy.pillSubmitted;
    } else {
      pill = isTurn
          ? ElevenScreenCopy.pillMyTurn
          : ElevenScreenCopy.pillOpponentTurn;
    }
    final active =
        pill == ElevenScreenCopy.pillMyTurn ||
        pill == ElevenScreenCopy.pillWin ||
        pill == ElevenScreenCopy.pillTie ||
        (screen == ElevenTabletScreen.t10EarlyEnd && isWinner);
    final color = active
        ? ElevenNoirColors.red
        : pill == ElevenScreenCopy.pillAutoSubmitted && auto
        ? ElevenNoirColors.warnRed
        : ElevenNoirColors.cream;
    final tileColor = _draw && value != null
        ? ElevenTileColor.of(value)
        : _roundColor(uid);
    final face = _draw
        ? value != null && drawRevealed
              ? ElevenTileFace.ofValue(value)
              : picked
              ? ElevenTileFace.back
              : ElevenTileFace.empty
        : tileColor == null
        ? ElevenTileFace.empty
        : ElevenTileFace.of(tileColor);
    final pillWidget = Container(
      height: _final
          ? 68
          : screen == ElevenTabletScreen.t09RoundIntro ||
                screen == ElevenTabletScreen.t10EarlyEnd
          ? 76
          : ElevenNoirSpacing.pillHeight,
      padding: ElevenNoirSpacing.pillPadding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(
          color: ElevenNoirColors.ink,
          width: ElevenNoirBorder.regular,
        ),
        borderRadius: BorderRadius.circular(ElevenNoirRadius.pill),
        boxShadow: ElevenNoirShadow.regular,
      ),
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          pill,
          style: ElevenNoirText.pill(
            size: screen == ElevenTabletScreen.t10EarlyEnd ? 28 : 26,
            color: active || color == ElevenNoirColors.warnRed
                ? ElevenNoirColors.cream
                : ElevenNoirColors.ink,
          ),
        ),
      ),
    );
    if (_final) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: motionEnabled ? 0 : 1, end: 1),
              duration: motionEnabled
                  ? (isWinner
                        ? ElevenGameEndMotion.winPill
                        : ElevenGameEndMotion.losePillSink)
                  : Duration.zero,
              curve: isWinner
                  ? ElevenGameEndMotion.winPillCurve
                  : ElevenGameEndMotion.losePillCurve,
              builder: (context, progress, child) => Opacity(
                opacity: isWinner
                    ? 1
                    : 1 -
                          (1 - ElevenGameEndMotion.losePillBrightness) *
                              progress,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    isWinner ? 0 : ElevenGameEndMotion.losePillSinkY * progress,
                  ),
                  child: Transform.scale(
                    scale: isWinner
                        ? ElevenGameEndMotion.winPillFrom +
                              (1 - ElevenGameEndMotion.winPillFrom) * progress
                        : 1,
                    child: child,
                  ),
                ),
              ),
              child: pillWidget,
            ),
            if (isWinner)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: motionEnabled ? 0 : 1, end: 1),
                duration: motionEnabled
                    ? ElevenGameEndFlowMotion.crownAt -
                          ElevenGameEndFlowMotion.finalScreenAt +
                          ElevenGameEndMotion.sparkDelay +
                          ElevenGameEndMotion.sparkTravel
                    : Duration.zero,
                builder: (context, progress, child) {
                  final total =
                      ElevenGameEndFlowMotion.crownAt -
                      ElevenGameEndFlowMotion.finalScreenAt +
                      ElevenGameEndMotion.sparkDelay +
                      ElevenGameEndMotion.sparkTravel;
                  final elapsed = total.inMicroseconds * progress;
                  final delay =
                      (ElevenGameEndFlowMotion.crownAt -
                              ElevenGameEndFlowMotion.finalScreenAt)
                          .inMicroseconds;
                  final fall =
                      ((elapsed - delay) /
                              ElevenGameEndMotion.crownFall.inMicroseconds)
                          .clamp(0.0, 1.0);
                  final eased = ElevenGameEndMotion.crownFallCurve.transform(
                    fall,
                  );
                  final sparkProgress =
                      (elapsed -
                          delay -
                          ElevenGameEndMotion.sparkDelay.inMicroseconds) /
                      ElevenGameEndMotion.sparkTravel.inMicroseconds;
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: motionEnabled
                            ? ((elapsed - delay) /
                                      ElevenGameEndMotion
                                          .crownAppear
                                          .inMicroseconds)
                                  .clamp(0.0, 1.0)
                            : 1,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            ElevenGameEndMotion.crownFallFrom * (1 - eased),
                          ),
                          child: child,
                        ),
                      ),
                      if (motionEnabled &&
                          sparkProgress > 0 &&
                          sparkProgress < 1)
                        ElevenNoirSparkBurst(progress: sparkProgress),
                    ],
                  );
                },
                child: const ElevenNoirCrown(),
              ),
          ],
        ),
      );
    }
    if (screen == ElevenTabletScreen.t10EarlyEnd) {
      return Stack(
        children: [
          Positioned(left: 301.5, top: seat == 0 ? 30 : 46, child: pillWidget),
          Positioned(
            left: 462,
            top: seat == 0 ? 138 : 154,
            width: ElevenNoirSpacing.scoreWidth,
            child: Column(
              children: [
                Text(
                  ElevenScreenCopy.scoreLabel,
                  style: ElevenNoirText.tabletScoreLabel(),
                ),
                Text(
                  '${pub.scores[uid] ?? 0}',
                  style: ElevenNoirText.tabletScore(),
                ),
              ],
            ),
          ),
          if (isWinner)
            const Positioned(left: 353, top: 266, child: ElevenNoirCrown()),
        ],
      );
    }
    final intro = screen == ElevenTabletScreen.t09RoundIntro;
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: intro ? 23 : 28,
          width: ElevenNoirSpacing.tabletSideSize.width,
          child: Center(child: pillWidget),
        ),
        if (!_draw) Positioned(left: 200, top: 102, child: _timeBar(uid)),
        Positioned(
          left: 318,
          top: intro ? 131 : 126,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(
              'slot-$uid-${pub.currentRound.round}-${tileColor?.name}',
            ),
            tween: Tween(
              begin: motionEnabled && !_draw && tileColor != null ? 0 : 1,
              end: 1,
            ),
            duration: motionEnabled && !_draw && tileColor != null
                ? ElevenDealMotion.duration
                : Duration.zero,
            curve: ElevenDealMotion.curve,
            builder: (context, progress, child) => Transform.translate(
              offset: Offset(0, (1 - progress) * ElevenDealMotion.offsetY),
              child: Transform.rotate(
                angle:
                    (1 - progress) *
                    ElevenDealMotion.startDegrees *
                    math.pi /
                    180,
                child: child,
              ),
            ),
            child: AnimatedOpacity(
              opacity:
                  isResult &&
                      resultEmphasized &&
                      resultWinner != null &&
                      resultWinner != uid
                  ? ElevenResultMotion.loseBrightness
                  : 1,
              duration: motionEnabled
                  ? ElevenResultMotion.emphasis
                  : Duration.zero,
              child: AnimatedScale(
                scale: isResult && resultEmphasized && resultWinner == uid
                    ? ElevenResultMotion.winScale
                    : 1,
                duration: motionEnabled
                    ? ElevenResultMotion.emphasis
                    : Duration.zero,
                curve: ElevenResultMotion.winCurve,
                child: ElevenNoirTile(
                  face: face,
                  value: _draw && drawRevealed ? value : null,
                  spec: _draw
                      ? ElevenTileSpec.tabletDrawSlot
                      : ElevenTileSpec.tabletSlot,
                  state: isResult && resultEmphasized && resultWinner == uid
                      ? ElevenTileState.win
                      : ElevenTileState.normal,
                ),
              ),
            ),
          ),
        ),
        if (!_draw || pub.draw?.purpose != ElevenDrawPurpose.firstPlayer)
          Positioned(
            left: 482,
            top: intro ? 154 : 149,
            width: ElevenNoirSpacing.scoreWidth,
            child: Column(
              children: [
                Text(
                  ElevenScreenCopy.scoreLabel,
                  style: ElevenNoirText.tabletScoreLabel(),
                ),
                // 시안 `.score`: 숫자 옆에 `+1`이 6px 간격으로 세로 가운데 붙고, 둘을 묶어
                // 가운데 정렬한다. “11 +1”처럼 칸(116)보다 넓으면 살짝 줄인다.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        key: ValueKey(
                          'score-$uid-${pub.scores[uid] ?? 0}-$resultEmphasized',
                        ),
                        tween: Tween(
                          begin:
                              motionEnabled &&
                                  resultEmphasized &&
                                  isResult &&
                                  resultWinner == uid &&
                                  (pub.scores[uid] ?? 0) > 0
                              ? (pub.scores[uid] ?? 0) - 1.0
                              : (pub.scores[uid] ?? 0).toDouble(),
                          end: (pub.scores[uid] ?? 0).toDouble(),
                        ),
                        duration: motionEnabled && isResult
                            ? ElevenScoreMotion.counter
                            : Duration.zero,
                        curve: ElevenScoreMotion.counterCurve,
                        builder: (context, score, child) => Text(
                          '${score.round()}',
                          style: ElevenNoirText.tabletScore(),
                        ),
                      ),
                      if (isResult &&
                          resultEmphasized &&
                          (resultTie || resultWinner == uid)) ...[
                        const SizedBox(width: ElevenNoirSpacing.scorePlusGap),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: motionEnabled ? 0 : 1, end: 1),
                          duration: motionEnabled
                              ? ElevenScoreMotion.plusEnter
                              : Duration.zero,
                          curve: ElevenScoreMotion.plusCurve,
                          builder: (context, progress, child) =>
                              Transform.translate(
                                offset: Offset(
                                  0,
                                  ElevenScoreMotion.plusEnterOffsetY *
                                      (1 - progress),
                                ),
                                child: Opacity(opacity: progress, child: child),
                              ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: ElevenNoirColors.accentRed,
                              border: Border.all(
                                color: ElevenNoirColors.ink,
                                width: ElevenNoirBorder.thin,
                              ),
                              borderRadius: BorderRadius.circular(
                                ElevenNoirRadius.plusBadge,
                              ),
                            ),
                            child: Text(
                              ElevenScreenCopy.scoreDelta(
                                resultTie
                                    ? 0
                                    : resultWinner == uid
                                    ? 1
                                    : 0,
                              ),
                              style: ElevenNoirText.plusBadge(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  bool _submitted(String uid) {
    final pub = game.public;
    return (pub.firstUid == uid && pub.currentRound.firstColor != null) ||
        (pub.secondUid == uid && pub.currentRound.secondColor != null);
  }

  ElevenTileColor? _roundColor(String uid) {
    final pub = game.public;
    if (pub.firstUid == uid) return pub.currentRound.firstColor;
    if (pub.secondUid == uid) return pub.currentRound.secondColor;
    return null;
  }

  Widget _timeBar(String uid) {
    final pub = game.public;
    if (pub.turnUid != uid || pub.turnDeadlineAt == null) {
      return const SizedBox(height: 16);
    }
    return GameTurnCountdown(
      expiresAt: pub.turnDeadlineAt,
      builder: (context, remaining) {
        final left = remaining ?? Duration.zero;
        final fraction = (left.inMilliseconds / 60000).clamp(0.0, 1.0);
        return Semantics(
          label: ElevenScreenCopy.timeBarSemantics((fraction * 100).round()),
          child: Container(
            width: ElevenNoirSpacing.timeBarSize.width,
            height: ElevenNoirSpacing.timeBarSize.height,
            decoration: BoxDecoration(
              color: ElevenNoirColors.ink,
              borderRadius: BorderRadius.circular(ElevenNoirRadius.timeBar),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: ElevenNoirSpacing.timeBarSize.width * fraction,
                decoration: BoxDecoration(
                  color: ElevenTimeBarMotion.colorFor(left),
                  borderRadius: BorderRadius.circular(
                    ElevenNoirRadius.timeBarFill,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<ElevenToastStep> _toastSteps() {
    final pub = game.public;
    return switch (screen) {
      ElevenTabletScreen.t01DrawStart ||
      ElevenTabletScreen.t02DrawSecondPick => ElevenToastSchedule.pickTile(),
      ElevenTabletScreen.t03DrawReveal => ElevenToastSchedule.revealNumbers(),
      ElevenTabletScreen.t04FirstChoosing when pub.round == 1 =>
        ElevenToastSchedule.firstRound(),
      ElevenTabletScreen.t05SecondChoosing => ElevenToastSchedule.submitted(),
      ElevenTabletScreen.t06AutoSubmitted =>
        ElevenToastSchedule.autoSubmitted(),
      ElevenTabletScreen.t07RoundWin => ElevenToastSchedule.roundWinner(
        pub.nicknameOf(
          game.currentRoundResult?.winnerUid ??
              (game.lastHistory?.round == pub.round
                  ? game.lastHistory?.winnerUid
                  : null),
        ),
      ),
      ElevenTabletScreen.t08RoundTie => ElevenToastSchedule.roundTie(),
      ElevenTabletScreen.t09RoundIntro => ElevenToastSchedule.roundIntro(
        pub.round,
        pub.nicknameOf(pub.firstUid),
      ),
      ElevenTabletScreen.t10EarlyEnd => ElevenToastSchedule.earlyEnd(
        pub.nicknameOf(pub.winnerUid),
      ),
      ElevenTabletScreen.t11TieDraw => ElevenToastSchedule.tieDrawStart(),
      ElevenTabletScreen.t12TieReveal => ElevenToastSchedule.revealTiles(),
      _ => const [],
    };
  }

  List<ElevenToastStep> _secondToastSteps() {
    final pub = game.public;
    return switch (screen) {
      ElevenTabletScreen.t03DrawReveal => ElevenToastSchedule.firstPlayer(
        pub.nicknameOf(pub.draw?.winnerUid),
      ),
      ElevenTabletScreen.t12TieReveal => ElevenToastSchedule.tieDrawWinner(
        pub.nicknameOf(pub.draw?.winnerUid),
      ),
      _ => const [],
    };
  }

  List<Widget> _finalWidgets(List<String> seats) {
    final pub = game.public;
    final tie = screen == ElevenTabletScreen.t13bFinalTieDraw;
    return [
      Positioned(
        left: 357,
        top: 96,
        width: 480,
        child: Column(
          children: [
            Text(
              tie
                  ? ElevenScreenCopy.finalWinnerLabel
                  : ElevenScreenCopy.finalScoreLabel,
              style: ElevenNoirText.finalLabel(),
            ),
            Text(
              tie
                  ? pub.nicknameOf(pub.winnerUid)
                  : seats.map((uid) => '${pub.scores[uid] ?? 0}').join(' : '),
              style: tie
                  ? ElevenNoirText.finalName()
                  : ElevenNoirText.finalNumber(),
            ),
          ],
        ),
      ),
      Positioned.fromRect(
        rect: ElevenNoirSpacing.finalButtonsRect,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _finalButton(
              ElevenScreenCopy.restart,
              ElevenNoirColors.warnRed,
              onRestart,
            ),
            const SizedBox(height: ElevenNoirSpacing.finalButtonsGap),
            _finalButton(ElevenScreenCopy.home, ElevenNoirColors.ink, onHome),
            const SizedBox(height: ElevenNoirSpacing.finalButtonsGap),
            Text(
              ElevenScreenCopy.resultStays,
              style: ElevenNoirText.note(size: 13),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _finalButton(String label, Color color, VoidCallback onTap) =>
      SizedBox(
        width: 240,
        height: 68,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            border: Border.all(
              color: ElevenNoirColors.ink,
              width: ElevenNoirBorder.regular,
            ),
            borderRadius: BorderRadius.circular(ElevenNoirRadius.tabletButton),
            boxShadow: ElevenNoirShadow.raised,
          ),
          child: TextButton(
            onPressed: onTap,
            child: Text(label, style: ElevenNoirText.tabletButton()),
          ),
        ),
      );

  Widget _menuButton(bool book, String label, VoidCallback onTap) => SizedBox(
    width: ElevenNoirSpacing.menuButtonSize,
    height: ElevenNoirSpacing.menuButtonSize,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: ElevenNoirColors.cream,
        border: Border.all(
          color: ElevenNoirColors.ink,
          width: ElevenNoirBorder.regular,
        ),
        borderRadius: BorderRadius.circular(ElevenNoirRadius.menuButton),
        boxShadow: ElevenNoirShadow.regular,
      ),
      child: IconButton(
        tooltip: label,
        onPressed: onTap,
        icon: ElevenNoirIcon.tablet(
          book ? ElevenNoirIconKind.rules : ElevenNoirIconKind.settings,
        ),
      ),
    ),
  );
}

class _BoardToast extends StatefulWidget {
  const _BoardToast({
    super.key,
    required this.playKey,
    required this.steps,
    required this.secondSteps,
    required this.delay,
    required this.animate,
  });
  final Object playKey;
  final List<ElevenToastStep> steps;
  final List<ElevenToastStep> secondSteps;
  final Duration delay;
  final bool animate;
  @override
  State<_BoardToast> createState() => _BoardToastState();
}

class _BoardToastState extends State<_BoardToast> {
  Timer? _firstTimer;
  Timer? _secondTimer;
  bool _first = false;
  bool _second = false;
  @override
  void initState() {
    super.initState();
    _first = widget.animate && widget.delay == Duration.zero;
    if (widget.animate && widget.delay > Duration.zero) {
      _firstTimer = Timer(widget.delay, () {
        if (mounted) setState(() => _first = true);
      });
    }
    if (widget.animate && widget.secondSteps.isNotEmpty) {
      _secondTimer = Timer(ElevenDrawMotion.resultToastAt, () {
        if (mounted) setState(() => _second = true);
      });
    }
  }

  @override
  void dispose() {
    _firstTimer?.cancel();
    _secondTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (_first)
        ElevenToastSequence(steps: widget.steps, playKey: (widget.playKey, 1)),
      if (_second)
        ElevenToastSequence(
          steps: widget.secondSteps,
          playKey: (widget.playKey, 2),
        ),
    ],
  );
}
