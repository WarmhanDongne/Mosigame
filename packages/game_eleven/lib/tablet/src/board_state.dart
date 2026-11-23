// 태블릿 세션 수명·연출 타이머·진행 명령을 맡는 내부 구현입니다.
// board와 같은 Dart library의 part로 유지해 private 상태를 외부에 노출하지 않습니다.
part of '../tablet_board.dart';

class _ElevenTabletGameState extends ConsumerState<ElevenTabletGame> {
  late final ElevenService _service = widget.service ?? ElevenService();
  ElevenSessionArgs? _args;
  ProviderSubscription<ElevenGameState>? _subscription;
  String? _initializationError;
  bool _reportedReady = false;

  /// 공개·결과 연출이 끝난 뒤 보내는 `complete_phase`.
  final GameProgressCommand _phaseCommand = GameProgressCommand();

  /// 마감 뒤 보내는 `timeout_turn`(태블릿이 주 호출).
  final GameProgressCommand _timeoutCommand = GameProgressCommand();
  Timer? _phaseTimer;
  Object? _phaseKey;
  Timer? _timeoutTimer;
  Object? _timeoutKey;

  /// T09 새 라운드 안내를 보여 주는 라운드입니다. 입력·deadline을 막지 않습니다.
  int? _introRound;
  int? _lastSubmitRound;
  Timer? _introTimer;
  Timer? _closingTimer;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseBackend.auth.currentUser?.uid;
    if (uid == null) {
      _initializationError = GameFlowCopy.authenticationRequired;
      return;
    }
    final args = ElevenSessionArgs(
      roomCode: widget.roomCode,
      uid: uid,
      service: _service,
      isController: true,
    );
    _args = args;
    _subscription = ref.listenManual(
      elevenSessionProvider(args),
      (_, next) => _handleState(next),
    );
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _timeoutTimer?.cancel();
    _introTimer?.cancel();
    _closingTimer?.cancel();
    _phaseCommand.dispose();
    _timeoutCommand.dispose();
    _subscription?.close();
    super.dispose();
  }

  ElevenController get _controller =>
      ref.read(elevenSessionProvider(_args!).notifier);

  ElevenGameState get _game => ref.read(elevenSessionProvider(_args!));

  void _handleState(ElevenGameState game) {
    if (!mounted) return;
    final stage = resolveElevenTabletStage(game);
    // 승부 없이 끝나면(퇴장·수동 종료·인원 부족) 안내 뒤 게임 화면을 닫고
    // 기존 방으로 돌아갑니다(노션 기기별 UX '종료 후', D13). 정상 승부 결과는 유지합니다.
    if (stage == ElevenTabletStage.closing) {
      _closingTimer ??= Timer(ElevenTiming.closingRouteDelay, () {
        if (mounted) exitGameRoute(context);
      });
    } else {
      _closingTimer?.cancel();
      _closingTimer = null;
    }
    _armPhaseCompletion(game, stage);
    _armTimeout(game, stage);
    _armRoundIntro(game, stage);
  }

  // ---------------------------------------------------------------------------
  // 연출 완료 → complete_phase
  // ---------------------------------------------------------------------------
  void _armPhaseCompletion(ElevenGameState game, ElevenTabletStage stage) {
    final pub = game.public;
    final key = stage.completesPhase ? (pub.startedAt, pub.revision) : null;
    if (key == _phaseKey) return;
    _phaseKey = key;
    _phaseTimer?.cancel();
    _phaseCommand.cancel();
    if (key == null) return;
    final revision = pub.revision;
    final wait = stage.isDrawReveal
        ? ElevenTiming.drawReveal
        : ElevenTiming.roundResult;
    bool isCurrent() =>
        mounted &&
        _game.public.revision == revision &&
        resolveElevenTabletStage(_game).completesPhase;
    _phaseTimer = Timer(wait, () {
      if (!isCurrent()) return;
      _phaseCommand.run(
        key: key,
        isCurrent: isCurrent,
        send: () => _controller.sendCompletePhase(revision),
      );
      if (mounted) setState(() {});
    });
  }

  // ---------------------------------------------------------------------------
  // 마감 → timeout_turn (주 호출, 마감 약 1초 뒤)
  // ---------------------------------------------------------------------------
  void _armTimeout(ElevenGameState game, ElevenTabletStage stage) {
    final pub = game.public;
    final deadline = pub.turnDeadlineAt;
    final key = stage.hasDeadline && deadline != null
        ? (pub.startedAt, pub.round, pub.phase)
        : null;
    if (key == _timeoutKey) return;
    _timeoutKey = key;
    _timeoutTimer?.cancel();
    _timeoutCommand.cancel();
    if (key == null) return;
    final round = pub.round;
    final phase = pub.phase;
    bool isCurrent() =>
        mounted &&
        !_game.isFinished &&
        _game.public.round == round &&
        _game.public.phase == phase;
    final wait =
        ServerClock.remainingUntil(deadline!) +
        ElevenTiming.controllerTimeoutGrace;
    _timeoutTimer = Timer(wait, () {
      if (!isCurrent()) return;
      _timeoutCommand.run(
        key: key,
        isCurrent: isCurrent,
        send: () => _controller.sendTimeout(round: round, phase: phase),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // T09 새 라운드 안내 (겹침 표시)
  // ---------------------------------------------------------------------------
  void _armRoundIntro(ElevenGameState game, ElevenTabletStage stage) {
    if (stage != ElevenTabletStage.firstSubmit) return;
    final round = game.public.round;
    if (_lastSubmitRound == round) return;
    _lastSubmitRound = round;
    _introTimer?.cancel();
    setState(() => _introRound = round);
    _introTimer = Timer(ElevenTiming.roundIntro, () {
      if (mounted) setState(() => _introRound = null);
    });
  }

  void _retryProgress() {
    if (_phaseCommand.needsRetry) _phaseCommand.retry();
    if (_timeoutCommand.needsRetry) _timeoutCommand.retry();
    if (_game.errorMessage != null) {
      unawaited(_controller.retryLastCommand());
    }
  }

  Future<void> _openSettings() async {
    await showDialog<void>(
      context: context,
      builder: (_) => TabletGameSettingsDialog(
        provider: widget.provider,
        onRestartGame: () => unawaited(_controller.restartGame()),
        onEndGame: () => unawaited(_endAndExit()),
      ),
    );
  }

  Future<void> _endAndExit() async {
    if (!_game.isFinished) {
      final ended = await _controller.endGame();
      if (!ended) return;
    }
    if (mounted) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final error = _initializationError;
    if (error != null || _args == null) {
      return Scaffold(
        backgroundColor: ElevenColors.background,
        body: Center(
          child: Text(
            error ?? GameFlowCopy.gameOpenFailed,
            style: const TextStyle(color: ElevenColors.ink),
          ),
        ),
      );
    }
    final game = ref.watch(elevenSessionProvider(_args!));
    final controller = _controller;
    if (!_reportedReady) {
      _reportedReady = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.reportScreenReady(assetsReady: true);
      });
    }
    final stage = resolveElevenTabletStage(game);
    final (title, subtitle) = elevenTabletHeadline(stage, game);
    final pub = game.public;
    final seated = pub.seatedPlayers;
    final needsRetry =
        _phaseCommand.needsRetry ||
        _timeoutCommand.needsRetry ||
        game.errorMessage != null;

    return Scaffold(
      backgroundColor: ElevenColors.background,
      body: GameRecoveryLayer(
        session: controller.recoverySession,
        request: GameRequestRecovery(
          visible: needsRetry,
          message: game.errorMessage,
          onRetry: _retryProgress,
        ),
        interruption: GameInterruptionRecovery(
          state: game.interruption,
          currentUid: _args!.uid,
          presentation: GameInterruptionPresentation.tabletController,
          isSubmitting: game.commandInFlight,
          failureMessage: game.errorMessage,
          onContinue: controller.excludeInterruptedPlayerAndContinue,
          onWaitMore: controller.waitMoreForInterruptedPlayer,
          onFinishNow: controller.endGame,
          onExpired: controller.expireInterruption,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 48),
                        Expanded(
                          child: Text(
                            title,
                            key: const ValueKey('eleven-tablet-title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ElevenColors.ink,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => unawaited(_openSettings()),
                          icon: const Icon(
                            Icons.settings_rounded,
                            color: ElevenColors.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      key: const ValueKey('eleven-tablet-subtitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ElevenColors.inkMuted,
                        fontSize: 20,
                      ),
                    ),
                    if (stage.hasDeadline)
                      GameTurnCountdown(
                        expiresAt: pub.turnDeadlineAt,
                        builder: (context, remaining) => Text(
                          remaining == null ? '' : '${remaining.inSeconds}s',
                          style: const TextStyle(
                            color: ElevenColors.accent,
                            fontSize: 26,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Expanded(child: Center(child: _body(stage, game, seated))),
                    if (game.history.isNotEmpty && !stage.isDrawPick)
                      ElevenHistoryStrip(
                        history: game.history,
                        seatOrder: [for (final p in seated) p.uid],
                      ),
                  ],
                ),
              ),
            ),
            // T09: 0.8초 겹침 안내. 입력을 막지 않고 deadline도 늦추지 않습니다.
            if (_introRound case final round?)
              IgnorePointer(
                child: ColoredBox(
                  color: const Color(0x99000000),
                  child: Center(
                    child: Text(
                      GameFlowCopy.round(round),
                      key: const ValueKey('eleven-round-intro'),
                      style: const TextStyle(
                        color: ElevenColors.ink,
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(
    ElevenTabletStage stage,
    ElevenGameState game,
    List<ElevenPlayerView> seated,
  ) {
    final pub = game.public;
    final draw = pub.draw;
    switch (stage) {
      case ElevenTabletStage.connecting:
        return const SizedBox.shrink();
      case ElevenTabletStage.firstDrawPick:
      case ElevenTabletStage.tieDrawPick:
      case ElevenTabletStage.firstDrawReveal:
      case ElevenTabletStage.tieDrawReveal:
        if (draw == null) return const SizedBox.shrink();
        return ElevenDrawGrid(
          draw: draw,
          nicknameOf: pub.nicknameOf,
          enabled: stage.isDrawPick && !game.commandInFlight,
          onPick: (slot) => unawaited(_controller.pickDrawTile(slot)),
        );
      case ElevenTabletStage.firstSubmit:
      case ElevenTabletStage.secondSubmit:
      case ElevenTabletStage.roundResult:
        final round = pub.currentRound;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final player in seated)
              ElevenPlayerPanel(
                key: ValueKey('eleven-panel-${player.uid}'),
                player: player,
                score: pub.scores[player.uid] ?? 0,
                isFirst: pub.firstUid == player.uid,
                isSecond: pub.secondUid == player.uid,
                isTurn: pub.turnUid == player.uid,
                color: pub.firstUid == player.uid
                    ? round.firstColor
                    : pub.secondUid == player.uid
                    ? round.secondColor
                    : null,
                autoSubmitted: round.autoSubmitted.contains(player.uid),
              ),
          ],
        );
      case ElevenTabletStage.result:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              [for (final p in seated) '${pub.scores[p.uid] ?? 0}'].join(' : '),
              style: const TextStyle(
                color: ElevenColors.ink,
                fontSize: 72,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 32),
            _resultActions(),
          ],
        );
      case ElevenTabletStage.closing:
        // 머리 문구로 종료 사유만 보여 주고 곧 자동으로 방에 복귀합니다.
        return const SizedBox.shrink();
    }
  }

  Widget _resultActions() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      FilledButton(
        key: const ValueKey('eleven-restart'),
        onPressed: _game.commandInFlight
            ? null
            : () => unawaited(_controller.restartGame()),
        child: Text(ElevenCopy.restart),
      ),
      const SizedBox(width: 16),
      OutlinedButton(
        key: const ValueKey('eleven-to-lobby'),
        onPressed: () => unawaited(Navigator.of(context).maybePop()),
        child: Text(ElevenCopy.toLobby),
      ),
    ],
  );
}
