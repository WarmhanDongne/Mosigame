// 휴대폰 세션 수명·타일 선택·제출·예비 시간 초과를 맡는 내부 구현입니다.
// board와 같은 Dart library의 part로 유지해 private 상태를 외부에 노출하지 않습니다.
part of '../phone_board.dart';

class _ElevenPhoneGameState extends ConsumerState<ElevenPhoneGame>
    with TickerProviderStateMixin {
  late final ElevenService _service = widget.service ?? ElevenService();
  ElevenSessionArgs? _args;
  ProviderSubscription<ElevenGameState>? _subscription;
  String? _initializationError;

  /// 로컬 선택(P03 미리 선택 포함). 서버에는 제출할 때만 보냅니다.
  int? _selected;

  /// 제출 응답이 성공한 라운드입니다(P07).
  int? _submittedRound;
  bool _submitting = false;
  bool _reportedReady = false;
  bool _closingScheduled = false;
  bool _leaving = false;
  bool _exitModalOpen = false;
  int? _previousRound;
  late final AnimationController _turnController;
  late final AnimationController _selectionController;
  late final AnimationController _endController;
  Timer? _revealTimer;
  String? _previousPhase;
  String? _previousDrawPickerUid;
  bool _roundResultRevealed = true;
  bool _gameEndRevealed = true;

  /// 뽑기 공개 직후 태블릿이 카드를 뒤집기 전까지 결과를 숨긴다(재접속 때는 바로 보임).
  bool _drawResultRevealed = true;
  Timer? _timeoutTimer;
  (int, String)? _timeoutKey;

  @override
  void initState() {
    super.initState();
    _turnController = AnimationController(
      vsync: this,
      duration: ElevenTurnMotion.total,
      value: 1,
    )..addListener(_rebuildForMotion);
    _selectionController = AnimationController(
      vsync: this,
      duration: ElevenTurnMotion.popTotal,
      value: 1,
    )..addListener(_rebuildForMotion);
    _endController = AnimationController(
      vsync: this,
      duration: ElevenPhoneEndMotion.total,
      value: 1,
    )..addListener(_rebuildForMotion);
    final uid = FirebaseBackend.auth.currentUser?.uid;
    if (uid == null) {
      _initializationError = GameFlowCopy.authenticationRequired;
      return;
    }
    final args = ElevenSessionArgs(
      roomCode: widget.roomCode,
      uid: uid,
      service: _service,
      isController: false,
    );
    _args = args;
    _subscription = ref.listenManual(
      elevenSessionProvider(args),
      (_, next) => _handleState(next),
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _revealTimer?.cancel();
    _turnController.dispose();
    _selectionController.dispose();
    _endController.dispose();
    _subscription?.close();
    super.dispose();
  }

  void _rebuildForMotion() {
    if (mounted) setState(() {});
  }

  void _playTurnMotion() {
    _turnController.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  ElevenController get _controller =>
      ref.read(elevenSessionProvider(_args!).notifier);

  void _handleState(ElevenGameState game) {
    if (!mounted) return;
    final uid = _args!.uid;
    final stage = resolveElevenPhoneStage(
      game,
      uid: uid,
      locallySubmittedRound: _submittedRound,
    );
    // 승부 없이 끝나면 결과 화면에 머무르지 않고 게임 라우트를 닫습니다.
    if (stage == ElevenPhoneStage.closing) {
      if (!_closingScheduled && !_leaving) {
        _closingScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) exitGameRoute(context);
        });
      }
      return;
    }
    _closingScheduled = false;
    final phase = game.public.phase;
    final pickerUid = phase == 'drawPick'
        ? game.public.draw?.nextPickerUid
        : null;
    final drawTurnArrived =
        !game.loading &&
        _previousPhase != null &&
        pickerUid == uid &&
        _previousDrawPickerUid != uid;
    if (!game.loading) _previousDrawPickerUid = pickerUid;
    if (!game.loading && phase != _previousPhase) {
      final previous = _previousPhase;
      _previousPhase = phase;
      _revealTimer?.cancel();
      _roundResultRevealed = true;
      _gameEndRevealed = true;
      _drawResultRevealed = true;
      if (previous != null && phase == 'drawReveal') {
        _drawResultRevealed = false;
        _revealTimer = Timer(ElevenDrawMotion.flipAt, () {
          if (mounted) setState(() => _drawResultRevealed = true);
        });
      } else if (previous != null && phase == 'roundResult') {
        _roundResultRevealed = false;
        _revealTimer = Timer(ElevenRoundFlowMotion.toastAt, () {
          if (mounted) setState(() => _roundResultRevealed = true);
        });
      } else if (previous != null &&
          game.public.isFinished &&
          game.public.finishDetail == 'earlyEnd') {
        _gameEndRevealed = false;
        _endController.value = 0;
        _revealTimer = Timer(ElevenGameEndFlowMotion.crownAt, () {
          if (!mounted) return;
          setState(() => _gameEndRevealed = true);
          _endController.forward();
        });
      } else if (previous != null && game.public.isFinished) {
        _endController.forward(from: 0);
      } else if (previous != null &&
          (drawTurnArrived ||
              (game.public.turnUid == uid &&
                  (phase == 'firstSubmit' || phase == 'secondSubmit')))) {
        _playTurnMotion();
      } else {
        _turnController.value = 1;
      }
    } else if (drawTurnArrived) {
      _playTurnMotion();
    }
    final round = game.public.round;
    if (_previousRound != round) {
      _previousRound = round;
      _submittedRound = null;
      _selected = null;
    }
    // 미리 고른 타일은 후공 차례가 와도 유지합니다. 이미 쓴 타일이면 지웁니다.
    if (_selected != null && !game.private.tiles.contains(_selected)) {
      _selected = null;
    }
    _armBackupTimeout(game);
  }

  /// 두 휴대폰은 태블릿의 예비로 시간 초과를 보냅니다(계약 5절).
  /// 태블릿이 먼저 처리하면 서버가 `ignored`로 돌려줍니다.
  void _armBackupTimeout(ElevenGameState game) {
    final pub = game.public;
    final deadline = pub.turnDeadlineAt;
    final active =
        !pub.isFinished &&
        deadline != null &&
        (pub.phase == 'firstSubmit' || pub.phase == 'secondSubmit');
    final key = active ? (pub.round, pub.phase) : null;
    if (key == _timeoutKey) return;
    _timeoutTimer?.cancel();
    _timeoutKey = key;
    if (key == null) return;
    final wait =
        ServerClock.remainingUntil(deadline!) + ElevenTiming.playerTimeoutGrace;
    _timeoutTimer = Timer(wait, () {
      if (!mounted || _timeoutKey != key) return;
      unawaited(_controller.sendTimeout(round: key.$1, phase: key.$2));
    });
  }

  Future<void> _submit(ElevenGameState game, ElevenPhoneStage stage) async {
    final value =
        _selected ??
        (game.private.tiles.length == 1 ? game.private.tiles.single : null);
    if (!stage.canSubmit || value == null || _submitting) return;
    final round = game.public.round;
    setState(() => _submitting = true);
    final ok = await _controller.submitTile(round: round, value: value);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      // 서버 거절이면 완료 표시를 하지 않습니다(계약 5절 응답).
      if (ok && game.public.round == round) _submittedRound = round;
    });
  }

  Future<void> _leaveRoom() async {
    if (_leaving || _exitModalOpen) return;
    _exitModalOpen = true;
    final leave = await SharedPhoneExitModal.show(
      context,
      doorImage: const Icon(
        Icons.logout_rounded,
        size: 96,
        color: ElevenColors.ink,
      ),
      surfaceColor: ElevenColors.background,
      primaryColor: ElevenColors.blackTile,
      titleColor: ElevenColors.ink,
      descriptionColor: ElevenColors.ink,
      showSurface: false,
    );
    _exitModalOpen = false;
    if (leave != true || !mounted) return;
    _leaving = true;
    final left = await widget.onExitRoom();
    if (!mounted) return;
    if (left) {
      Navigator.of(context).pop(true);
      return;
    }
    _leaving = false;
    showLeaveFailureNotice(context, widget.provider);
  }

  void _showRules() {
    showDialog<void>(
      context: context,
      builder: (_) => PhoneGameRulebookDialog(
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
            style: ElevenNoirText.topBar(color: ElevenNoirColors.cream),
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
    final uid = _args!.uid;
    final stage = resolveElevenPhoneStage(
      game,
      uid: uid,
      locallySubmittedRound: _submittedRound,
    );
    final screen = resolveElevenPhoneScreen(
      game,
      uid: uid,
      locallySubmittedRound: _submittedRound,
      roundResultRevealed: _roundResultRevealed,
      gameEndRevealed: _gameEndRevealed,
      drawResultRevealed: _drawResultRevealed,
    );
    return Scaffold(
      backgroundColor: ElevenNoirColors.table,
      body: GameRecoveryLayer(
        session: controller.recoverySession,
        onExit: () => unawaited(_leaveRoom()),
        interruption: GameInterruptionRecovery(
          state: game.interruption,
          currentUid: uid,
          isSubmitting: game.commandInFlight,
          failureMessage: game.errorMessage,
          onExpired: controller.expireInterruption,
        ),
        child: AnimatedSwitcher(
          duration: stage == ElevenPhoneStage.finished
              ? screen == ElevenPhoneScreen.p11Loser
                    ? ElevenPhoneEndMotion.crossFadeLoser
                    : ElevenPhoneEndMotion.crossFade
              : ElevenPhoneLayerMotion.crossFade,
          child: ElevenPhoneNoirView(
            key: ValueKey(screen),
            game: game,
            uid: uid,
            screen: screen,
            stage: stage,
            selected: _selected,
            submitting: _submitting,
            onSelect: (value) {
              if (_selected == value) return;
              setState(() => _selected = value);
              if (stage.canSubmit) _selectionController.forward(from: 0);
            },
            onSubmit: () => unawaited(_submit(game, stage)),
            onExit: () => unawaited(_leaveRoom()),
            onRules: _showRules,
            turnProgress: _turnController.value,
            selectionProgress: _selectionController.value,
            endProgress: _endController.value,
          ),
        ),
      ),
    );
  }
}
