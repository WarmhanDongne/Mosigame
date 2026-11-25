// [game_screen.dart] 휴대폰에서 보이는 손패, 턴 정보,
// LIAR·FOLD·SUBMIT 버튼과 벌칙 표시를 배치하는 실제 게임 화면 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:game_kit/game_feedback.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:game_liars_poker/game_copy.dart';
import 'package:game_liars_poker/phone/phone_board.dart';
import 'package:game_kit/phone/animations/control_entry_animation.dart';
import 'package:game_kit/game_flow/game_announcement.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/errors/widgets/leave_failure_notice.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_liars_poker/shared/providers/game_controller.dart';
import 'package:game_liars_poker/shared/widgets/wood_table_background.dart';
import 'package:game_liars_poker/phone/widgets/hand_card_stack.dart';
import 'package:game_liars_poker/phone/widgets/liar_accusation.dart';
import 'package:game_liars_poker/phone/widgets/penalty_status.dart';
import 'package:game_liars_poker/phone/widgets/exit_modal.dart';
import 'package:game_liars_poker/phone/widgets/settings_dialog.dart';
import 'package:game_liars_poker/phone/widgets/turn_timer.dart';
import 'package:game_liars_poker/phone/widgets/top_bar.dart';
import 'package:game_liars_poker/phone/widgets/my_profile_plate.dart';
import 'package:game_liars_poker/phone/widgets/timeout_notice.dart';
import 'package:game_liars_poker/phone/widgets/truth_count_hint.dart';
import 'package:game_liars_poker/phone/widgets/turn_action_switcher.dart';
import 'package:game_liars_poker/shared/widgets/pressable_button.dart';
import 'package:game_kit/phone/widgets/rulebook_dialog.dart';
import 'package:game_kit/phone/widgets/ripple_dialog.dart';
import 'package:game_kit/shared/widgets/game_announcement_layer.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_liars_poker/phone/providers/game_stage.dart';

part 'game_screen/landscape_view.dart';
part 'game_screen/penalty_stage_switcher.dart';
part 'game_screen/portrait_view.dart';
part 'game_screen/supporting_view.dart';

// ============================================================

// LiarsPokerPhoneGameScreen
// │
// ├─ ① 생명주기와 조작 상태
// ├─ ② 세로·가로 화면 레이아웃
// ├─ ③ 손패, CALL/FOLD, 턴 타이머와 오류 안내
// └─ ④ 라이어 판정, 벌칙, 폴드 확인 화면

/// 기기 방향에 따라 가로·세로 배치를 전환하는 휴대폰 게임 화면입니다.
///
/// Firebase 구독, 손패 공개 상태, 헤더 진입 상태는 방향이 바뀌어도
/// 하나의 [State]에서 계속 유지합니다.
class LiarsPokerPhoneGameScreen extends StatefulWidget {
  const LiarsPokerPhoneGameScreen({
    super.key,
    this.controller,
    this.provider,
    this.onExitRoom,
    this.showSpectatorTopBar = false,
    required this.flowConfig,
  });

  final LiarsPokerController? controller;
  final GameRoomContext? provider;
  final Future<bool> Function()? onExitRoom;
  final GameFlowConfig<LiarsPokerPhoneStage> flowConfig;

  /// 탈락한 관전자가 판정·벌칙 화면을 보고 있을 때도 상단바를 유지합니다.
  final bool showSpectatorTopBar;

  @override
  State<LiarsPokerPhoneGameScreen> createState() =>
      _LiarsPokerPhoneGameScreenState();
}

class _LiarsPokerPhoneGameScreenState extends State<LiarsPokerPhoneGameScreen>
    with SingleTickerProviderStateMixin {
  bool _isExitModalOpen = false;
  late final AnimationController _controlsEntryController;
  final PhoneHandCardStackController _handCardStackController =
      PhoneHandCardStackController();
  bool _wasDealing = false;
  bool _isRevealInProgress = false;
  late bool _hasCompletedGameStart;

  /// 직전 화면에서 '태블릿을 봐 주세요!' 안내가 보였는지입니다.
  bool _truthHintWasVisible = false;

  /// 안내가 사라지는 동안 새 손패 진입을 잠깐 미룹니다. 카드가 안내를 반쯤
  /// 덮은 채로 겹쳐 보이지 않게, 안내가 다 사라진 뒤 카드가 내려옵니다.
  bool _holdHandForTruthHint = false;
  Timer? _truthHintExitTimer;

  /// 지금 타이머 자리에 보이는 시간 초과 안내입니다. 없으면 null입니다.
  LiarsPokerTimeoutKind? _timeoutNotice;
  int _timeoutNoticeId = 0;
  Timer? _timeoutNoticeTimer;

  /// 이미 안내한 서버 시간 초과 기록의 시각입니다. 같은 기록은 한 번만 띄웁니다.
  int? _handledTimeoutAt;

  /// 이 휴대폰이 직접 시간 초과 행동을 보낸 시각입니다. 바로 뒤에 태블릿이
  /// 같은 턴을 대신 처리해도 안내가 두 번 뜨지 않게 막습니다.
  DateTime? _localTimeoutAt;
  static const _truthHintExitHold = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    // 시작 안내가 꺼진 구성은 문구 완료 콜백을 기다리지 않고
    // 서버 준비가 되자마자 손패 공개 단계를 열도록 간주합니다.
    _hasCompletedGameStart =
        widget.flowConfig
            .stepFor(LiarsPokerPhoneStage.gameStart)
            .buildAnnouncement() ==
        null;
    _controlsEntryController = AnimationController(
      vsync: this,
      duration: LiarsPokerPhoneTiming.phoneControlsEntry,
    );
    if (widget.showSpectatorTopBar ||
        widget.controller?.hasRevealedHand == true) {
      _controlsEntryController.value = 1;
    }
  }

  @override
  void didUpdateWidget(LiarsPokerPhoneGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasCompletedGameStart &&
        widget.flowConfig
                .stepFor(LiarsPokerPhoneStage.gameStart)
                .buildAnnouncement() ==
            null) {
      _hasCompletedGameStart = true;
    }
    if (!oldWidget.showSpectatorTopBar && widget.showSpectatorTopBar) {
      _controlsEntryController.value = 1;
    }
  }

  void _markRevealStarted() {
    if (mounted) {
      setState(() => _isRevealInProgress = true);
    }
    widget.controller?.markHandRevealed();
  }

  void _handleRevealCompleted() {
    widget.controller?.markHandRevealed();
    if (mounted) {
      setState(() => _isRevealInProgress = false);
    }
    _showGameControls();
  }

  void _showGameControls() {
    if (_controlsEntryController.isAnimating ||
        _controlsEntryController.isCompleted) {
      return;
    }
    _controlsEntryController.forward();
  }

  GameAnnouncementStyle _announcementStyle(
    GameAnnouncement? announcement, {
    required bool isLandscape,
    double? statusFontSize,
    bool isMyTurn = false,
  }) {
    if (announcement?.kind == GameAnnouncementKind.persistent) {
      return GameAnnouncementStyle(
        fontFamily: null,
        fontSize: statusFontSize ?? (isLandscape ? 15 : 17),
        gameStartFontSize: 58,
        fontWeight: isMyTurn ? FontWeight.w700 : FontWeight.w500,
        height: 1.2,
        letterSpacing: 0,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
      );
    }

    if (announcement?.tone != GameAnnouncementTone.neutral) {
      return GameAnnouncementStyle(
        fontSize: isLandscape ? 34 : 32.sp,
        gameStartFontSize: 58,
        height: 1.15,
        letterSpacing: 0.7,
        shadows: const [Shadow(color: Colors.black, blurRadius: 14)],
        beginScale: 0.96,
        endScale: 0.96,
      );
    }

    return GameAnnouncementStyle(
      fontSize: isLandscape ? 31 : 30.sp,
      gameStartFontSize: 58,
      height: 1.18,
      letterSpacing: 0.5,
      shadows: const [Shadow(color: Colors.black87, blurRadius: 12)],
    );
  }

  void _showControlsAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showGameControls();
    });
  }

  void _handleGameStartCompleted() {
    if (!mounted || _hasCompletedGameStart) return;
    setState(() => _hasCompletedGameStart = true);
  }

  Future<void> _showExitModal({Offset? origin}) async {
    // 모달을 열기 전에 판정합니다. 가드가 없으면 빠른 두 번 탭에 확인 모달이
    // 두 개 쌓입니다.
    if (_isExitModalOpen) return;
    _isExitModalOpen = true;
    final shouldExit = await PhoneExitModal.show(context, origin: origin);
    _isExitModalOpen = false;
    if (!mounted || shouldExit != true) return;

    // 퇴장에 성공하면 화면 방향 복원과 화면 전환은 라우트를 가진 상위
    // PhoneGame이 처리합니다. 이 화면은 퇴장 도중 관전·배경 화면으로 교체될 수
    // 있어 여기서 pop을 맡으면 홈으로 돌아가지 못하는 경우가 있습니다.
    final left = await widget.onExitRoom?.call() ?? false;
    if (!mounted || left) return;

    showLeaveFailureNotice(context, widget.provider);
  }

  @override
  void dispose() {
    _truthHintExitTimer?.cancel();
    _timeoutNoticeTimer?.cancel();
    _handCardStackController.dispose();
    _controlsEntryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Firebase 상태는 상위 PhoneGame에서 한 번만 구독합니다. 이 화면은 전달된
    // 최신 상태만 그려 카드·컨트롤 애니메이션이 중복 rebuild되지 않게 합니다.
    final controller = widget.controller;
    if (controller == null) return _buildGameScreen(null);
    return AnimatedBuilder(
      animation: controller.recoverySession,
      builder: (context, _) => _buildGameScreen(controller),
    );
  }

  Widget _buildGameScreen(LiarsPokerController? controller) {
    _watchServerTimeout(controller);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final turnPlayer = controller?.players[controller.turnUid];
    final showFoldPrompt = controller?.showFoldPrompt ?? false;
    final showPenaltyHandOverlay = controller?.showPenaltyHandOverlay ?? false;
    // 허위 선언 판정 문구를 보여주는 동안에는 기존 요청대로 손패를
    // 어둡게 유지하고, 실제 벌칙 진행 및 결과 표시 단계에서는 숨깁니다.
    final hideHandDuringPenalty =
        showPenaltyHandOverlay &&
        controller?.liarVerdictMessage == null &&
        controller?.isLiarVerdictPending != true;
    final isDealing = controller?.phase == 'dealing';
    if (isDealing && !_wasDealing) {
      _wasDealing = true;
      _isRevealInProgress = false;
      final dealingRound = controller?.round;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            widget.controller?.phase != 'dealing' ||
            widget.controller?.round != dealingRound) {
          return;
        }
        _controlsEntryController.reset();
      });
    } else if (!isDealing) {
      _wasDealing = false;
    }
    _trackTruthHintExit(controller);

    final stage = resolveLiarsPokerPhoneStage(
      game: controller,
      gameStartCompleted: _hasCompletedGameStart,
      revealInProgress: _isRevealInProgress,
      showSpectatorTopBar: widget.showSpectatorTopBar,
    );
    final flowStep = widget.flowConfig.stepFor(stage);
    final regions = flowStep.phoneRegions ?? const PhoneGameRegions();
    final hasRecoveryFailure =
        controller != null &&
        (!controller.recoverySession.transportConnected ||
            controller.interruption?.causes.isNotEmpty == true ||
            (controller.errorMessage != null &&
                !controller.recoverySession.canSend));
    final showHeader = regions.showTopBar || hasRecoveryFailure;
    final showControls =
        regions.showActions &&
        !widget.showSpectatorTopBar &&
        (controller == null ||
            controller.handCards.isNotEmpty ||
            controller.showFoldPrompt);
    final announcement = flowStep.buildAnnouncement();

    // 공개 완료 콜백 전에 화면이 재생성되거나 hot reload된 경우에도
    // 헤더가 투명도 0에 멈추지 않도록 현재 상태에서 진입을 보장합니다.
    if (!isLandscape && showHeader && _controlsEntryController.isDismissed) {
      _showControlsAfterFrame();
    }

    if (isLandscape && controller != null) {
      return _buildLandscapeScreen(
        controller,
        turnPlayer: turnPlayer,
        showHeader: showHeader,
        showControls: showControls,
        showFoldPrompt: showFoldPrompt,
        showPenaltyHandOverlay: showPenaltyHandOverlay,
        hideHandDuringPenalty: hideHandDuringPenalty,
        announcement: announcement,
        regions: regions,
      );
    }

    return _buildPortraitScreen(
      controller,
      turnPlayer: turnPlayer,
      showHeader: showHeader,
      showControls: showControls,
      showFoldPrompt: showFoldPrompt,
      showPenaltyHandOverlay: showPenaltyHandOverlay,
      hideHandDuringPenalty: hideHandDuringPenalty,
      announcement: announcement,
      regions: regions,
    );
  }

  void _showRules([Offset? origin]) {
    final screenSize = MediaQuery.sizeOf(context);
    showPhoneRippleDialog<void>(
      context: context,
      origin: origin ?? Offset(screenSize.width - 82, 28),
      builder: (_) => PhoneGameRulebookDialog(
        title: "LIAR'S POKER",
        markdown: LiarsPokerCopy.tabletRules,
      ),
    );
  }

  /// 상단바 왼쪽의 내 프로필 명패입니다. 내 플레이어 정보가 아직 없으면 비웁니다.
  Widget? _buildMyProfilePlate(
    LiarsPokerController? controller, {
    required bool isLandscape,
  }) {
    if (controller == null) return null;
    final me = controller.players[controller.uid];
    if (me == null) return null;
    return LiarsPokerMyProfilePlate(
      nickname: me.nickname,
      characterId: me.characterId,
      isLandscape: isLandscape,
    );
  }

  // ---------------------------------------------------------------------------
  // 카드 분배 전 '태블릿을 봐 주세요!' 안내
  // ---------------------------------------------------------------------------
  //
  // 서버 dealing 동안 빈 화면에 안내를 띄웁니다. 분배가 끝나 새 손패가 오면
  // 안내가 먼저 살짝 작아지며 사라지고([_truthHintExitHold] 동안 손패 대기),
  // 그 뒤에 카드가 위에서 내려옵니다. 둘이 겹쳐 보이지 않게 합니다.
  bool _shouldShowTruthCountHint(LiarsPokerController? controller) {
    if (controller == null || controller.isInitialLoading) return false;
    if (widget.showSpectatorTopBar || controller.isEliminated) return false;
    if (controller.showPenaltyHandOverlay) return false;
    if (controller.isFinished || controller.isNaturalResult) return false;
    if (_isRevealInProgress || controller.hasRevealedHand) return false;
    return controller.phase == 'dealing';
  }

  /// 안내가 보이다가 손패 도착으로 꺼지는 순간 손패 진입을 잠깐 미룹니다.
  void _trackTruthHintExit(LiarsPokerController? controller) {
    final visible = _shouldShowTruthCountHint(controller);
    final handArrived =
        controller != null &&
        controller.phase != 'dealing' &&
        controller.handCards.isNotEmpty &&
        !controller.hasRevealedHand;
    if (_truthHintWasVisible && !visible && handArrived) {
      _holdHandForTruthHint = true;
      _truthHintExitTimer?.cancel();
      _truthHintExitTimer = Timer(_truthHintExitHold, () {
        if (mounted) setState(() => _holdHandForTruthHint = false);
      });
    }
    _truthHintWasVisible = visible;
  }

  Widget _buildTruthCountHintLayer(
    LiarsPokerController? controller, {
    required Key key,
    double top = 0,
    double? height,
  }) {
    final visible = _shouldShowTruthCountHint(controller);
    final child = IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        reverseDuration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: visible
            ? const Center(
                key: ValueKey('liars-truth-count-hint'),
                child: LiarsPokerTruthCountHint(),
              )
            : const SizedBox.shrink(key: ValueKey('liars-truth-count-off')),
      ),
    );
    if (height == null) return Positioned.fill(key: key, child: child);
    return Positioned(
      key: key,
      top: top,
      left: 0,
      right: 0,
      height: height,
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // 가로·세로 공통 손패
  // ---------------------------------------------------------------------------
  Widget _buildHand(
    LiarsPokerController? controller, {
    required bool isLandscape,
    required bool dimmed,
    double entryCenterOffsetX = 0,
    double entryCenterOffsetY = 0,
    Offset announcementCenterOffset = Offset.zero,
  }) {
    if (!_hasCompletedGameStart) return const SizedBox.shrink();

    if (controller == null) {
      return _dimHandCards(
        PhoneHandCardStack(
          isLandscape: isLandscape,
          controller: _handCardStackController,
          onRevealCompleted: _showGameControls,
          entryCenterOffsetX: entryCenterOffsetX,
          entryCenterOffsetY: entryCenterOffsetY,
          announcementCenterOffset: announcementCenterOffset,
          flowConfig: widget.flowConfig,
        ),
        dimmed: dimmed,
      );
    }

    if (controller.isInitialLoading) {
      return const SizedBox.shrink();
    }

    // 손패 데이터가 먼저 도착해도 태블릿의 실제 배분 연출이 끝날 때까지
    // 카드 위→아래 진입 애니메이션을 생성하지 않습니다.
    if (controller.phase == 'dealing') {
      return const SizedBox.shrink();
    }
    // '태블릿을 봐 주세요!' 안내가 다 사라진 뒤에 카드가 내려옵니다.
    if (_holdHandForTruthHint) return const SizedBox.shrink();
    // 벌칙 룰렛으로 넘어가는 짧은 틈과 탈락 확정 뒤에는 빈 손패 문구를
    // 만들지 않습니다. 해당 단계는 판정·룰렛 또는 관전 화면이 소유합니다.
    if (controller.phase == 'penalty' || controller.isEliminated) {
      return const SizedBox.shrink();
    }
    // 손패가 아직 없거나 모두 소진된 동안에는 빈 상태 문구를 표시합니다.
    if (controller.handCards.isEmpty && !controller.hasRevealedHand) {
      _showControlsAfterFrame();
      if (!controller.isEliminated) return const SizedBox.shrink();
      return _emptyHandMessage();
    }

    return _dimHandCards(
      PhoneHandCardStack(
        key: ValueKey(
          '${isLandscape ? 'landscape' : 'portrait'}-deal-'
          '${controller.handDealVersion}',
        ),
        isLandscape: isLandscape,
        controller: _handCardStackController,
        cards: controller.handCardAssets,
        enabled: controller.canSelectCards,
        submissionEnabled: controller.canSubmitCards,
        initiallyRevealed: controller.hasRevealedHand,
        roundNumber: controller.round,
        tableCardValue: controller.table,
        onRevealStarted: _markRevealStarted,
        onRevealCompleted: _handleRevealCompleted,
        onCardsSubmitRequested: controller.submitCardIndexes,
        entryCenterOffsetX: entryCenterOffsetX,
        entryCenterOffsetY: entryCenterOffsetY,
        announcementCenterOffset: announcementCenterOffset,
        flowConfig: widget.flowConfig,
      ),
      dimmed: dimmed,
    );
  }

  /// 투명한 손패 영역은 유지하고 실제 카드 픽셀만 어둡게 처리합니다.
  Widget _dimHandCards(Widget child, {required bool dimmed}) {
    const normal = ColorFilter.mode(Colors.transparent, BlendMode.dst);
    const dark = ColorFilter.matrix([
      .34,
      0,
      0,
      0,
      0,
      0,
      .34,
      0,
      0,
      0,
      0,
      0,
      .34,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);

    return ColorFiltered(colorFilter: dimmed ? dark : normal, child: child);
  }

  // ---------------------------------------------------------------------------
  // 제한 시간 종료
  // ---------------------------------------------------------------------------
  void _handleTurnTimeout(LiarsPokerController controller) {
    if (!controller.isMyTurn || controller.phase == 'penalty') return;

    // 잔여카드를 가진 마지막 1인이 응답하지 않으면 상대를 의심하지 않고
    // FOLD 처리해 새 라운드로 진행합니다.
    if (controller.showFoldPrompt && controller.canFoldLastCardChallenge) {
      _showTimeoutNotice(LiarsPokerTimeoutKind.fold, local: true);
      unawaited(controller.foldLastCardChallenge());
      return;
    }

    if (controller.canCallLiar) {
      _showTimeoutNotice(LiarsPokerTimeoutKind.liar, local: true);
      unawaited(controller.callLiar());
      return;
    }
    _showTimeoutNotice(LiarsPokerTimeoutKind.submit, local: true);
    unawaited(controller.submitCardIndexes([0]));
  }

  // ---------------------------------------------------------------------------
  // 시간 초과 안내
  // ---------------------------------------------------------------------------
  //
  // 두 길로 들어옵니다.
  // 1. 이 휴대폰 타이머가 0이 되어 직접 자동 행동을 보낸 경우(_handleTurnTimeout)
  // 2. 휴대폰이 늦거나 끊겨 태블릿이 대신 처리하고 서버가 lastTimeout을 남긴 경우
  // 안내는 화면 표시만 바꾸고 게임 진행에는 끼어들지 않습니다.
  void _showTimeoutNotice(LiarsPokerTimeoutKind kind, {bool local = false}) {
    if (!mounted) return;
    if (local) _localTimeoutAt = DateTime.now();
    _timeoutNoticeTimer?.cancel();
    setState(() {
      _timeoutNotice = kind;
      _timeoutNoticeId += 1;
    });
    _timeoutNoticeTimer = Timer(LiarsPokerTimeoutNotice.visibleFor, () {
      if (mounted) setState(() => _timeoutNotice = null);
    });
  }

  void _watchServerTimeout(LiarsPokerController? controller) {
    final record = controller?.lastTimeout;
    if (controller == null || record == null) return;
    if (record.at == _handledTimeoutAt) return;
    _handledTimeoutAt = record.at;
    if (!record.isFreshFor(controller.uid)) return;
    final kind = LiarsPokerTimeoutKind.fromWire(record.kind);
    if (kind == null) return;
    final local = _localTimeoutAt;
    if (local != null &&
        DateTime.now().difference(local) < const Duration(seconds: 5)) {
      return;
    }
    // build 도중이라 다음 프레임에 띄웁니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showTimeoutNotice(kind);
    });
  }

  Widget _buildTimeoutNoticeLayer({required Key key, required double textTop}) {
    final kind = _timeoutNotice;
    return Positioned.fill(
      key: key,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          reverseDuration: const Duration(milliseconds: 320),
          child: kind == null
              ? const SizedBox.expand(key: ValueKey('timeout-notice-off'))
              : LiarsPokerTimeoutNotice(
                  key: ValueKey('timeout-notice-$_timeoutNoticeId'),
                  kind: kind,
                  textTop: textTop,
                ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LIAR·SUBMIT 버튼
  // ---------------------------------------------------------------------------
  Widget _buildGameActionButton(
    LiarsPokerController? controller, {
    required bool isLandscape,
    double? portraitHeight,
  }) {
    return AnimatedBuilder(
      animation: _handCardStackController,
      builder: (context, _) {
        final showSubmit = _handCardStackController.hasSelection;
        final enabled = controller == null
            ? true
            : showSubmit
            ? controller.canSubmitCards
            : controller.canCallLiar;

        return LiarAccusation(
          isLandscape: isLandscape,
          portraitHeight: portraitHeight,
          showSubmit: showSubmit,
          enabled: enabled,
          onAccuse: controller == null
              ? null
              : () {
                  // 판을 뒤집는 선언이므로 강한 진동으로 확정감을 줍니다.
                  GameFeedback.declare();
                  unawaited(controller.callLiar());
                },
          onSubmit: () {
            // 되돌릴 수 없는 확정 동작이므로 진동으로 알립니다.
            GameFeedback.commit();
            unawaited(_handCardStackController.submitSelectedCards());
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 손패 없음 안내
  // ---------------------------------------------------------------------------
  // 손패가 없을 때 가로·세로에서 공통으로 사용하는 문구입니다.
  Widget _emptyHandMessage() {
    return Center(
      child: Text(
        LiarsPokerCopy.noCards,
        style: const TextStyle(color: Colors.white70, fontSize: 17),
      ),
    );
  }
}
