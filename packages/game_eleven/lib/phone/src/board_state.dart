// 휴대폰 세션 수명·타일 선택·제출·예비 시간 초과를 맡는 내부 구현입니다.
// board와 같은 Dart library의 part로 유지해 private 상태를 외부에 노출하지 않습니다.
part of '../phone_board.dart';

class _ElevenPhoneGameState extends ConsumerState<ElevenPhoneGame> {
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
  Timer? _timeoutTimer;
  (int, String)? _timeoutKey;

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
    _subscription?.close();
    super.dispose();
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
    final value = _selected;
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
    final uid = _args!.uid;
    final stage = resolveElevenPhoneStage(
      game,
      uid: uid,
      locallySubmittedRound: _submittedRound,
    );
    final pub = game.public;
    final opponentUid = pub.players.keys.firstWhere(
      (id) => id != uid,
      orElse: () => '',
    );
    final submission = game.private.submissionFor(pub.round);
    final showDeadline =
        stage == ElevenPhoneStage.firstChoosing ||
        stage == ElevenPhoneStage.secondChoosing ||
        stage == ElevenPhoneStage.secondPreselect;

    return Scaffold(
      backgroundColor: ElevenColors.background,
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(
                  title: ElevenCopy.round(pub.round),
                  myScore: pub.scores[uid] ?? 0,
                  opponentName: pub.nicknameOf(opponentUid),
                  opponentScore: pub.scores[opponentUid] ?? 0,
                  onExit: () => unawaited(_leaveRoom()),
                ),
                const SizedBox(height: 8),
                if (stage == ElevenPhoneStage.finished)
                  Expanded(
                    child: Center(
                      key: const ValueKey('eleven-phone-finished'),
                      child: Text(
                        pub.winnerUid == uid
                            ? ElevenCopy.youWin
                            : ElevenCopy.youLose,
                        style: const TextStyle(
                          color: ElevenColors.ink,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else
                  // 가로 화면: 왼쪽은 차례 안내·남은 시간, 오른쪽은 손패와 제출.
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                elevenPhoneMessage(stage, game),
                                key: const ValueKey('eleven-phone-message'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: ElevenColors.ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 28,
                                child: showDeadline
                                    ? GameTurnCountdown(
                                        expiresAt: pub.turnDeadlineAt,
                                        builder: (context, remaining) => Text(
                                          remaining == null
                                              ? ''
                                              : '${remaining.inSeconds}s',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: ElevenColors.accent,
                                            fontSize: 18,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              // P06 시간 초과 자동 제출 / P09 마지막 타일
                              if (submission?.auto == true)
                                _Notice(ElevenCopy.autoSubmitted)
                              else if (stage.canSelect &&
                                  game.private.tiles.length == 1)
                                _Notice(ElevenCopy.lastTile),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Center(
                                  child: ElevenTileRack(
                                    remaining: game.private.tiles,
                                    selected: submission?.value ?? _selected,
                                    enabled: stage.canSelect && !_submitting,
                                    onSelect: (value) =>
                                        setState(() => _selected = value),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton(
                                key: const ValueKey('eleven-phone-submit'),
                                onPressed:
                                    stage.canSubmit &&
                                        _selected != null &&
                                        !_submitting
                                    ? () => unawaited(_submit(game, stage))
                                    : null,
                                child: Text(ElevenCopy.submit),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.myScore,
    required this.opponentName,
    required this.opponentScore,
    required this.onExit,
  });

  final String title;
  final int myScore;
  final String opponentName;
  final int opponentScore;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: ElevenColors.ink, fontSize: 16);
    return Row(
      children: [
        IconButton(
          onPressed: onExit,
          icon: const Icon(Icons.close_rounded, color: ElevenColors.ink),
        ),
        Expanded(
          child: Text(title, style: style, textAlign: TextAlign.center),
        ),
        Flexible(
          child: Text(
            '$myScore : $opponentScore  $opponentName',
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: ElevenColors.accent, fontSize: 15),
    ),
  );
}
