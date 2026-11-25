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
  late final ElevenTabletPhaseClock _phaseClock = ElevenTabletPhaseClock(
    _phaseCommand,
  );
  Timer? _timeoutTimer;
  Object? _timeoutKey;

  /// T09 새 라운드 안내를 보여 주는 라운드입니다. 입력·deadline을 막지 않습니다.
  int? _introRound;
  int? _lastSubmitRound;
  Timer? _introTimer;
  Timer? _closingTimer;
  Timer? _resultRevealTimer;
  Timer? _resultEmphasisTimer;
  Timer? _gameEndTimer;
  Timer? _drawFaceTimer;
  Object? _visualKey;
  bool _seenSnapshot = false;
  bool _roundResultRevealed = true;
  bool _resultEmphasized = true;
  bool _gameEndRevealed = true;
  bool _drawRevealed = true;
  bool _animateVisuals = false;

  /// 판 내내 깔리는 배경음악입니다. 화면을 떠날 때 반드시 멈춥니다.
  final GameBackgroundMusic _backgroundMusic = GameBackgroundMusic();

  /// 인트로가 울린 뒤 배경음악을 시작하는 타이머입니다.
  Timer? _backgroundStartTimer;

  /// 효과음 판정에 쓰는 직전 공개 상태입니다.
  ElevenPublicSnapshot? _soundSnapshot;
  bool _soundsPreloaded = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // dispose에서는 context를 읽을 수 없으므로 미리 붙잡아 둡니다.
    _backgroundMusic.attach(context);
    if (_soundsPreloaded) return;
    _soundsPreloaded = true;
    final sound = SoundEffects.of(context);
    if (sound == null) return;
    unawaited(
      sound
          .preloadEffects(
            ElevenSounds.preloadTargets,
            scope: ElevenSounds.preloadScope,
          )
          .catchError((Object error) {
            debugPrint('ELEVEN 효과음을 준비하지 못했습니다: $error');
          }),
    );
  }

  @override
  void dispose() {
    _backgroundStartTimer?.cancel();
    _backgroundMusic.dispose();
    _timeoutTimer?.cancel();
    _introTimer?.cancel();
    _closingTimer?.cancel();
    _resultRevealTimer?.cancel();
    _resultEmphasisTimer?.cancel();
    _gameEndTimer?.cancel();
    _drawFaceTimer?.cancel();
    _phaseClock.dispose();
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
    _armVisuals(game, stage);
    _playSoundCues(game, stage);
    _syncBackgroundMusic(stage);
  }

  // ---------------------------------------------------------------------------
  // 소리 (태블릿만 냄)
  // ---------------------------------------------------------------------------
  void _playSoundCues(ElevenGameState game, ElevenTabletStage stage) {
    if (game.loading) return;
    final cues = resolveElevenTabletSoundCues(
      previous: _soundSnapshot,
      next: game.public,
      stage: stage,
    );
    _soundSnapshot = game.public;
    for (final cue in cues) {
      switch (cue) {
        case ElevenTabletSoundCue.intro:
          _playSound(ElevenSounds.intro);
          // 새 판(다시 하기 포함)은 인트로 뒤에 곡을 처음부터 깝니다.
          _backgroundMusic.stop();
          _backgroundStartTimer?.cancel();
          _backgroundStartTimer = Timer(ElevenSounds.backgroundAfterIntro, () {
            _backgroundStartTimer = null;
            if (mounted) _syncBackgroundMusic(resolveElevenTabletStage(_game));
          });
        case ElevenTabletSoundCue.place:
          _playSound(ElevenSounds.cardPlace);
      }
    }
  }

  void _syncBackgroundMusic(ElevenTabletStage stage) {
    switch (stage) {
      case ElevenTabletStage.connecting:
        return;
      case ElevenTabletStage.closing:
        _backgroundStartTimer?.cancel();
        _backgroundStartTimer = null;
        _backgroundMusic.stop();
      case ElevenTabletStage.result:
        _backgroundStartTimer?.cancel();
        _backgroundStartTimer = null;
        _backgroundMusic.fadeOut();
      case ElevenTabletStage.firstDrawPick ||
          ElevenTabletStage.firstDrawReveal ||
          ElevenTabletStage.firstSubmit ||
          ElevenTabletStage.secondSubmit ||
          ElevenTabletStage.roundResult ||
          ElevenTabletStage.tieDrawPick ||
          ElevenTabletStage.tieDrawReveal:
        // 인트로가 울리는 중이면 타이머가 곡을 시작합니다. 재접속처럼 인트로 없이
        // 진행 중인 판에 들어오면 바로 깝니다. 이미 재생 중이면 start는 무시됩니다.
        if (_backgroundStartTimer != null) return;
        _backgroundMusic.start(ElevenSounds.background);
    }
  }

  void _playSound(String asset) {
    if (mounted) SoundEffects.play(context, asset);
  }

  // ---------------------------------------------------------------------------
  // 연출 완료 → complete_phase
  // ---------------------------------------------------------------------------
  void _armPhaseCompletion(ElevenGameState game, ElevenTabletStage stage) {
    final revision = game.public.revision;
    _phaseClock.arm(
      game,
      stage,
      isCurrent: () =>
          mounted &&
          _game.public.revision == revision &&
          resolveElevenTabletStage(_game).completesPhase,
      send: _controller.sendCompletePhase,
      onFired: () {
        if (mounted) setState(() {});
      },
    );
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
    if (stage != ElevenTabletStage.firstSubmit) {
      _introTimer?.cancel();
      if (_introRound != null) setState(() => _introRound = null);
      return;
    }
    final round = game.public.round;
    if (_lastSubmitRound == round) return;
    _lastSubmitRound = round;
    if (!_seenSnapshot || round <= 1) return;
    _introTimer?.cancel();
    setState(() => _introRound = round);
    _introTimer = Timer(ElevenTiming.roundIntro, () {
      if (mounted) setState(() => _introRound = null);
    });
  }

  void _armVisuals(ElevenGameState game, ElevenTabletStage stage) {
    if (game.loading) return;
    final pub = game.public;
    final key = (pub.startedAt, pub.round, pub.phase, pub.revision);
    if (_visualKey == key) return;
    _resultRevealTimer?.cancel();
    _resultEmphasisTimer?.cancel();
    _gameEndTimer?.cancel();
    _drawFaceTimer?.cancel();
    _visualKey = key;
    // 처음 받은 상태는 보통 이미 진행 중인 판이라 연출을 건너뛴다. 단, 아직 아무도 뽑지
    // 않은 첫 선공 뽑기는 막 시작한 판이므로 딜·“타일 선택” 토스트를 그대로 보여 준다
    // (첫 판에서 토스트가 첫 선택 뒤에야 나오던 원인).
    final freshDraw =
        stage == ElevenTabletStage.firstDrawPick &&
        (pub.draw?.picks.isEmpty ?? true);
    final animate = _seenSnapshot || freshDraw;
    _seenSnapshot = true;
    _animateVisuals = animate;
    _roundResultRevealed =
        !animate ||
        stage != ElevenTabletStage.roundResult ||
        pub.currentRound.autoSubmitted.isEmpty;
    _resultEmphasized = !animate || stage != ElevenTabletStage.roundResult;
    if (!_resultEmphasized) {
      _resultEmphasisTimer = Timer(ElevenRoundFlowMotion.emphasisAt, () {
        if (mounted && _visualKey == key) {
          setState(() => _resultEmphasized = true);
          _playSound(ElevenSounds.cardFlip);
        }
      });
    }
    _gameEndRevealed =
        !animate ||
        pub.finishDetail != 'earlyEnd' ||
        stage != ElevenTabletStage.result;
    _drawRevealed = !animate || !stage.isDrawReveal;
    if (!_roundResultRevealed) {
      _resultRevealTimer = Timer(ElevenRoundFlowMotion.emphasisAt, () {
        if (mounted && _visualKey == key) {
          setState(() => _roundResultRevealed = true);
        }
      });
    }
    if (!_gameEndRevealed) {
      _gameEndTimer = Timer(ElevenGameEndFlowMotion.finalScreenAt, () {
        if (mounted && _visualKey == key) {
          setState(() => _gameEndRevealed = true);
        }
      });
    }
    if (!_drawRevealed) {
      _drawFaceTimer = Timer(ElevenDrawMotion.flipAt, () {
        if (mounted && _visualKey == key) {
          setState(() => _drawRevealed = true);
          _playSound(ElevenSounds.cardFlip);
        }
      });
    }
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

  void _openRules() {
    showDialog<void>(
      context: context,
      builder: (_) => TabletGameRulebookDialog(
        title: ElevenScreenCopy.rulebookTitle,
        markdown: ElevenScreenCopy.rulebookMarkdown,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _initializationError;
    if (error != null || _args == null) {
      return Scaffold(
        backgroundColor: ElevenNoirColors.table,
        body: Center(
          child: Text(
            error ?? GameFlowCopy.gameOpenFailed,
            style: ElevenNoirText.body(20, color: ElevenNoirColors.cream),
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
    final needsRetry =
        _phaseCommand.needsRetry ||
        _timeoutCommand.needsRetry ||
        game.errorMessage != null;
    return Scaffold(
      backgroundColor: ElevenNoirColors.table,
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
        child: ElevenTabletBoardView(
          game: game,
          screen: resolveElevenTabletScreen(
            game,
            roundIntroActive: _introRound == game.public.round,
            roundResultRevealed: _roundResultRevealed,
            gameEndRevealed: _gameEndRevealed,
          ),
          drawRevealed: _drawRevealed,
          resultEmphasized: _resultEmphasized,
          animate: _animateVisuals,
          onPick: (slot) => unawaited(controller.pickDrawTile(slot)),
          onRules: _openRules,
          onSettings: () => unawaited(_openSettings()),
          onRestart: () => unawaited(controller.restartGame()),
          onHome: () => unawaited(Navigator.of(context).maybePop()),
        ),
      ),
    );
  }
}
