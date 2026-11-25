import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/recovery/widgets/game_recovery_layer.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown_face.dart';
import 'package:game_kit/shared/widgets/game_route_exit.dart';
import 'package:game_kit/sound/game_background_music.dart';
import 'package:game_kit/sound/providers/sound_provider.dart';
import 'package:game_kit/sound/sound_effects.dart';
import 'package:game_kit/tablet/widgets/game_menu_overlay.dart';
import 'package:game_kit/tablet/widgets/game_rulebook_dialog.dart';
import 'package:game_kit/tablet/widgets/game_settings_dialog.dart';
import 'package:game_russian_roulette/game_sounds.dart';
import 'package:game_russian_roulette/src/service.dart';
import 'package:game_russian_roulette/src/session.dart';
import 'package:game_russian_roulette/src/stage.dart';
import 'package:game_russian_roulette/src/theme.dart';
import 'package:game_russian_roulette/src/timing.dart';
import 'package:game_russian_roulette/src/view.dart';
import 'package:game_russian_roulette/src/widgets.dart';

class RussianRouletteTabletScreen extends ConsumerStatefulWidget {
  const RussianRouletteTabletScreen({
    super.key,
    required this.roomCode,
    required this.provider,
    required this.playerLayout,
  });

  final String roomCode;
  final GameRoomContext provider;
  final PlayerLayoutModel playerLayout;

  @override
  ConsumerState<RussianRouletteTabletScreen> createState() =>
      _RussianRouletteTabletScreenState();
}

class _RussianRouletteTabletScreenState
    extends ConsumerState<RussianRouletteTabletScreen>
    with SingleTickerProviderStateMixin {
  final _service = RussianRouletteService();
  final _backgroundMusic = GameBackgroundMusic();
  static const _maxPhaseAttempts = 3;
  static const _phaseRetryDelay = Duration(seconds: 1);

  Timer? _phaseTimer;
  Timer? _victoryTimer;
  final List<Timer> _rotationSoundTimers = [];
  String _scheduledKey = '';
  int _phaseAttempts = 0;
  String? _audioKey;
  String? _lastAudioPhase;
  SoundProvider? _sound;
  bool _reportedReady = false;
  bool _soundPrepared = false;

  String get _uid => ref.read(russianRouletteUidProvider);
  RussianRouletteSessionArgs get _args => RussianRouletteSessionArgs(
    roomCode: widget.roomCode,
    uid: _uid,
    watchPrivate: false,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _backgroundMusic.attach(context);
    _sound ??= SoundEffects.of(context);
    final sound = _sound;
    if (!_soundPrepared && sound != null) {
      _soundPrepared = true;
      unawaited(
        sound
            .preloadEffects(
              RussianRouletteSounds.preloadTargets,
              solo: true,
              scope: 'russian_roulette',
            )
            .catchError((Object error) {
              debugPrint('러시안 룰렛 효과음을 준비하지 못했습니다: $error');
            }),
      );
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _backgroundMusic.dispose();
    _victoryTimer?.cancel();
    _cancelRotationSounds();
    _phaseTimer?.cancel();
    super.dispose();
  }

  void _playEffect(String asset) => SoundEffects.play(context, asset);

  void _syncAudio(RussianRouletteView game, Duration elapsed) {
    if (!game.loaded) return;

    if (!game.finished && !game.paused) {
      _backgroundMusic.start(RussianRouletteSounds.background);
    } else {
      _backgroundMusic.stop();
    }

    if (game.paused) {
      _cancelRotationSounds();
      _audioKey = null;
      return;
    }

    final key =
        '${game.status}:${game.phase}:${game.round}:${game.targetUid}:'
        '${game.spinCount}:${game.shotBlocked}:${game.winnerUid}';
    if (_audioKey == null) {
      _audioKey = key;
      _lastAudioPhase = game.phase;
      if (game.phase == 'rotating') {
        _scheduleRotationSounds(game, elapsed, key);
      }
      return;
    }
    if (_audioKey == key) return;

    final previousPhase = _lastAudioPhase;
    _audioKey = key;
    _lastAudioPhase = game.phase;
    _victoryTimer?.cancel();

    if (game.phase != 'rotating') {
      _cancelRotationSounds();
    }

    if (game.finished) {
      if (previousPhase == 'firing') {
        _playEffect(RussianRouletteSounds.gunshot);
      }
      if (game.winnerUid != null) {
        final delay = previousPhase == 'firing'
            ? const Duration(milliseconds: 900)
            : Duration.zero;
        _victoryTimer = Timer(delay, () {
          if (mounted) _playEffect(RussianRouletteSounds.victory);
        });
      }
      return;
    }

    switch (game.phase) {
      case 'rotating':
        _scheduleRotationSounds(game, elapsed, key);
        break;
      case 'outcome':
        _playEffect(RussianRouletteSounds.gunshot);
        if (game.shotBlocked == true) {
          _playEffect(RussianRouletteSounds.shieldImpact);
        }
        break;
      default:
        break;
    }
  }

  void _cancelRotationSounds() {
    for (final timer in _rotationSoundTimers) {
      timer.cancel();
    }
    _rotationSoundTimers.clear();
  }

  /// 총구가 생존 좌석 사이를 한 칸 이동하기 시작할 때마다 짧은 회전음을 한 번
  /// 재생합니다. 상태 수신이 늦으면 끝난 칸은 건너뛰고 현재·남은 칸만 맞춥니다.
  void _scheduleRotationSounds(
    RussianRouletteView game,
    Duration elapsed,
    String audioKey,
  ) {
    _cancelRotationSounds();
    final delays = rouletteRotationAudioDelays(elapsed, game.spinCount);
    for (final delay in delays) {
      void play() {
        if (!mounted || _audioKey != audioKey) return;
        _playEffect(RussianRouletteSounds.revolverSpin);
      }

      if (delay == Duration.zero) {
        play();
        continue;
      }
      late final Timer timer;
      timer = Timer(delay, () {
        _rotationSoundTimers.remove(timer);
        play();
      });
      _rotationSoundTimers.add(timer);
    }
  }

  Future<bool> _run(Future<Object?> Function() command) =>
      ref.read(russianRouletteSessionProvider(_args).notifier).execute(command);

  void _schedule(RussianRouletteView game) {
    final key = roulettePhaseKey(game);
    if (_scheduledKey == key) return;
    _scheduledKey = key;
    _phaseAttempts = 0;
    _phaseTimer?.cancel();
    _phaseTimer = null;
    // 중단·종료 중에는 진행 명령을 보내지 않습니다. 서버도 거절합니다.
    final delay = roulettePhaseDelay(game);
    if (delay == null) return;
    // 중단 동안에도 단계 시계는 흘렀고 연출은 끝까지 그려졌습니다. 남은
    // 시간만 기다려 재개 직후 이미 끝난 연출을 처음부터 다시 기다리지
    // 않습니다. 새 단계는 아직 시계를 맞추기 전이라 전체 시간을 씁니다.
    final since = _phaseKey == '${game.status}:${game.phase}:${game.round}'
        ? _nowMs - _phaseStartedAt
        : 0;
    // 응답이 오는 동안 화면이 멈춰 보이지 않게 끝나기 조금 전에 요청합니다.
    final lead = RussianRouletteTiming.phaseRequestLead.inMilliseconds;
    _armPhase(
      key,
      Duration(milliseconds: math.max(0, delay.inMilliseconds - lead - since)),
    );
  }

  void _armPhase(String key, Duration wait) {
    _phaseTimer?.cancel();
    _phaseTimer = Timer(wait, () {
      _phaseTimer = null;
      if (!mounted || _scheduledKey != key) return;
      unawaited(_advancePhase(key));
    });
  }

  Future<void> _advancePhase(String key) async {
    final advanced = await _run(
      () => _service.command.completePhase(widget.roomCode),
    );
    // 전송이 실패하면 단계도 예약도 그대로 소진됩니다. 제한된 횟수만 다시
    // 걸어 일시적인 오류 한 번으로 연출이 멈추지 않게 합니다. 무한 재전송은
    // 하지 않으며, 소진 뒤에는 중단·재개나 다시 시작이 새 예약을 만듭니다.
    if (advanced ||
        !mounted ||
        _scheduledKey != key ||
        _phaseAttempts >= _maxPhaseAttempts) {
      return;
    }
    _phaseAttempts += 1;
    _armPhase(key, _phaseRetryDelay);
  }

  /// 마감이 지나면 시간 초과를 보냅니다. 실패하면(네트워크, 서버 시각 오차)
  /// 같은 마감의 선택 단계가 그대로일 때만 몇 번 더 보내 턴이 멈추지 않게 합니다.
  Future<void> _timeout(int deadline) async {
    for (var attempt = 0; attempt <= _maxPhaseAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_phaseRetryDelay);
        if (!mounted) return;
        final latest = RussianRouletteView.fromPublic(
          ref.read(russianRouletteSessionProvider(_args)).publicState,
        );
        if (latest.phase != 'selecting' ||
            latest.paused ||
            latest.deadlineAt != deadline) {
          return;
        }
      }
      final ok = await _run(() => _service.command.timeout(widget.roomCode));
      if (ok || !mounted) return;
    }
  }

  Future<void> _restart() async {
    await _run(
      () => _service.command.startGame(widget.roomCode, restart: true),
    );
  }

  Future<void> _endAndExit(RussianRouletteView game) async {
    if (!game.finished) {
      final ended = await _run(() => _service.command.endGame(widget.roomCode));
      if (!ended) return;
    }
    if (mounted) exitGameRoute(context);
  }

  //=======================연출 시계==============================
  // 서버 단계는 한 번에 바뀌므로, 단계 안의 한 명씩 공개·한 칸씩 회전은
  // 태블릿이 단계를 처음 본 순간부터 흐른 시간으로 그립니다.
  late final Ticker _ticker = createTicker(_onTick);
  String _phaseKey = '';
  int _phaseStartedAt = 0;
  bool _sawPlaying = false;
  bool _animating = false;
  double? _gunFrom;
  double? _gunTo;
  int _gunStartedAt = 0;

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;
  int get _serverNow => ServerClock.nowMillis();

  // 게임 시작 연출: 1턴 선택이 막 시작됐을 때(남은 시간이 넉넉할 때) 한 번만.
  int? _introStartedAt;

  /// 시작 연출을 보여 준 게임의 시작 시각입니다.
  int _introGame = 0;

  /// 시작 연출 종료를 서버에 알린 게임의 시작 시각입니다(게임마다 한 번).
  int _introReportedGame = 0;

  int? _introMs(RussianRouletteView game) {
    final fresh = rouletteShouldStartIntro(
      game,
      presentedStartedAt: _introGame,
      serverNow: _serverNow,
    );
    if (fresh) {
      _introGame = game.startedAt;
      // 화면 준비가 늦어도 어두운 준비 → 좌석 점등 → 랜덤 총구 지정 순서를
      // 건너뛰지 않고 새 게임마다 한 번 온전히 보여 줍니다.
      _introStartedAt = _nowMs;
    }
    final started = _introStartedAt;
    if (started == null) return null;
    final ms = _nowMs - started;
    if (game.round != 1 ||
        game.phase != 'selecting' ||
        ms >= rouletteIntroLength(game.aliveCount)) {
      _introStartedAt = null;
      if (game.round == 1 && game.phase == 'selecting') {
        _reportIntroCompleted(game.startedAt);
      }
      return null;
    }
    return ms;
  }

  /// 시작 연출이 끝난 순간 서버에 알려, 첫 턴 타이머가 연출 중에 줄지 않고
  /// 지금부터 30초를 세게 합니다. 알리지 못해도 서버의 여유 마감으로 진행됩니다.
  void _reportIntroCompleted(int startedAt) {
    if (startedAt <= 0 || _introReportedGame == startedAt) return;
    _introReportedGame = startedAt;
    unawaited(
      _service.command
          .completeIntro(widget.roomCode)
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) =>
                debugPrint('[RussianRoulette] 시작 연출 종료를 알리지 못했습니다: $error'),
          ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  void _onTick(Duration _) {
    if (!mounted) return;
    final turning =
        _nowMs - _gunStartedAt <
        RussianRouletteTiming.gunTurn.inMilliseconds + 60;
    if (_animating || turning) setState(() {});
  }

  Duration _elapsed(RussianRouletteView game) {
    final key = '${game.status}:${game.phase}:${game.round}';
    if (key != _phaseKey) {
      _phaseKey = key;
      // 서버의 단계 시작 시각에 맞춰 휴대폰과 같은 장면을 보여 주고, 단계 진행
      // 예약도 같은 기준으로 잡습니다.
      _phaseStartedAt = rouletteLocalPhaseStart(
        localNow: _nowMs,
        serverNow: ServerClock.hasSynced ? ServerClock.nowMillis() : null,
        phaseStartedAt: game.phaseStartedAt,
      );
    }
    return Duration(milliseconds: _nowMs - _phaseStartedAt);
  }

  /// 총구를 [desired] 방향으로 시계 방향 회전시키고 지금 각도를 돌려줍니다.
  double _gunAim(double desired) {
    final to = _gunTo;
    if (to == null) {
      _gunFrom = desired;
      _gunTo = desired;
      return desired;
    }
    final normalizedTo = to % (math.pi * 2);
    final normalizedDesired = desired % (math.pi * 2);
    if ((normalizedTo - normalizedDesired).abs() > 1e-3 &&
        ((normalizedTo - normalizedDesired).abs() - math.pi * 2).abs() > 1e-3) {
      _gunFrom = _gunValue();
      _gunTo = RouletteStageGeometry.clockwiseFrom(to, desired);
      _gunStartedAt = _nowMs;
    }
    return _gunValue();
  }

  double _gunValue() {
    final from = _gunFrom ?? 0.0;
    final to = _gunTo ?? 0.0;
    final t =
        ((_nowMs - _gunStartedAt) /
                RussianRouletteTiming.gunTurn.inMilliseconds)
            .clamp(0.0, 1.0);
    return from + (to - from) * RussianRouletteTiming.gunTurnCurve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(russianRouletteSessionProvider(_args));
    final controller = ref.read(russianRouletteSessionProvider(_args).notifier);
    if (!_reportedReady) {
      _reportedReady = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(russianRouletteSessionProvider(_args).notifier)
              .reportScreenReady(assetsReady: true);
        }
      });
    }
    final game = RussianRouletteView.fromPublic(session.publicState);
    final elapsed = _elapsed(game);
    _syncAudio(game, elapsed);
    _schedule(game);
    if (game.loaded && !game.finished) _sawPlaying = true;
    return Scaffold(
      backgroundColor: RouletteColors.ink,
      body: GameRecoveryLayer(
        session: controller.recoverySession,
        request: GameRequestRecovery(
          message: session.errorMessage,
          onRetry: () => unawaited(controller.retryLastCommand()),
        ),
        interruption: GameInterruptionRecovery(
          state: controller.interruption,
          currentUid: _uid,
          presentation: GameInterruptionPresentation.tabletController,
          isSubmitting: session.commandInFlight,
          failureMessage: session.errorMessage,
          onContinue: controller.excludeInterruptedPlayerAndContinue,
          onWaitMore: controller.waitMoreForInterruptedPlayer,
          onFinishNow: controller.endGame,
          onExpired: controller.expireInterruption,
        ),
        child: Stack(
          children: [
            Positioned.fill(child: _table(game, elapsed)),
            TabletGameMenuOverlay(
              visible: game.loaded && !game.finished,
              roleIcon: const Icon(
                Icons.menu_book,
                color: RouletteColors.cream,
              ),
              settingIcon: const Icon(
                Icons.settings,
                color: RouletteColors.cream,
              ),
              roleDialogBuilder: (_) => TabletGameRulebookDialog(
                title: RouletteCopy.title,
                markdown: RouletteCopy.rulesMarkdown,
                cards: const [
                  Icon(Icons.rotate_right, color: RouletteColors.red, size: 52),
                  Icon(Icons.shield, color: RouletteColors.red, size: 52),
                  Icon(
                    Icons.remove_circle_outline,
                    color: RouletteColors.red,
                    size: 52,
                  ),
                ],
              ),
              settingDialogBuilder: (_) => TabletGameSettingsDialog(
                provider: widget.provider,
                onRestartGame: () => unawaited(_restart()),
                onEndGame: () => unawaited(_endAndExit(game)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 단계가 바뀌어도 빔 밝기가 툭 바뀌지 않게 천천히 따라갑니다.
  double _wedge = 0;
  int _wedgeAt = 0;

  double _smoothWedge(double target) {
    final now = _nowMs;
    final dt = (now - _wedgeAt).clamp(0, 200);
    _wedgeAt = now;
    _wedge += (target - _wedge) * (1 - math.exp(-dt / 160));
    if ((target - _wedge).abs() > .01) _animating = true;
    return _wedge;
  }

  /// 로딩 · 진행 · 우승 · 끝 화면 사이를 부드럽게 겹쳐 넘깁니다.
  Widget _table(RussianRouletteView game, Duration elapsed) {
    final (mode, child) = _tableContent(game, elapsed);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 900),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(key: ValueKey(mode), child: child),
    );
  }

  (String, Widget) _tableContent(RussianRouletteView game, Duration elapsed) {
    if (!game.loaded) {
      _animating = false;
      return (
        'loading',
        const Center(
          child: CircularProgressIndicator(color: RouletteColors.red),
        ),
      );
    }
    if (game.finished) {
      final showWinner =
          _sawPlaying &&
          game.winnerUid != null &&
          elapsed < const Duration(milliseconds: 3800);
      _animating = showWinner;
      if (showWinner) {
        return (
          'win',
          RouletteStage(
            model: rouletteWinnerModel(
              game,
              elapsed,
              seatLayoutMode: widget.playerLayout.seatLayoutMode,
            ),
          ),
        );
      }
      return (
        'end',
        RouletteEndBoard(
          game: game,
          onRestart: () => unawaited(_restart()),
          onHome: () => unawaited(_endAndExit(game)),
        ),
      );
    }
    final holdIntro = rouletteShouldHoldIntroFrame(
      game,
      presentedStartedAt: _introGame,
    );
    final intro = _introMs(game);
    if (intro != null || holdIntro) {
      _animating = intro != null;
      final frame = rouletteIntroFrame(
        game,
        intro ?? 0,
        seatLayoutMode: widget.playerLayout.seatLayoutMode,
      );
      _wedge = frame.wedgeOpacity;
      _wedgeAt = _nowMs;
      return (
        'play',
        RouletteStage(model: frame.build(_gunAim(frame.desiredAim))),
      );
    }
    _animating = game.phase != 'selecting' && !game.paused;
    final frame = rouletteTabletFrame(
      game,
      elapsed,
      seatLayoutMode: widget.playerLayout.seatLayoutMode,
    );
    final aim = _gunAim(frame.desiredAim);
    final wedge = game.phase == 'firing'
        ? frame.wedgeOpacity
        : _smoothWedge(frame.wedgeOpacity);
    if (game.phase == 'firing') _wedge = frame.wedgeOpacity;
    if (game.phase == 'selecting' && !game.paused) {
      return (
        'play',
        GameTurnCountdownFace(
          expiresAt: game.deadlineAt == 0 ? null : game.deadlineAt,
          onTimeout: () => unawaited(_timeout(game.deadlineAt)),
          builder: (_, remaining) => RouletteStage(
            model: frame.build(
              aim,
              wedge: wedge,
              // 첫 턴은 시작 연출 동안 마감이 30초보다 멀어 꽉 찬 채로 기다립니다.
              timerFraction:
                  ((remaining?.inMilliseconds ??
                              RussianRouletteTiming.turn.inMilliseconds) /
                          RussianRouletteTiming.turn.inMilliseconds)
                      .clamp(0.0, 1.0),
            ),
          ),
        ),
      );
    }
    return ('play', RouletteStage(model: frame.build(aim, wedge: wedge)));
  }
}

//=======================단계별 판 구성==============================
/// 한 프레임의 판 정보입니다. 총 각도만 화면 상태(회전 모션)에서 받습니다.
class RouletteTabletFrame {
  RouletteTabletFrame({
    required this.desiredAim,
    required this.seats,
    this.wedgeOpacity = 1,
    this.secondWedge = true,
    this.shot = false,
    this.label,
    this.labelTag,
    this.stamp,
    this.shake = Offset.zero,
    this.cylinderReveal = 1,
    this.banner,
    this.bannerProgress = 1,
    this.flash,
    this.gunPose,
    this.discBump = 1,
  });

  /// 총구 섬광 진행(0 → 1)입니다.
  final double? flash;

  /// 시작 연출의 총 자세(눕힘 → 세움)입니다. null이면 세워 둔 총입니다.
  final RouletteGunPose? gunPose;
  final double discBump;

  final double cylinderReveal;
  final String? banner;
  final double bannerProgress;
  final double desiredAim;
  final List<RouletteSeatModel> seats;
  final double wedgeOpacity;
  final bool secondWedge;
  final bool shot;
  final String? label;
  final String? labelTag;
  final RouletteStampModel? stamp;
  final Offset shake;

  RouletteStageModel build(
    double aim, {
    double? timerFraction,
    double? wedge,
  }) => RouletteStageModel(
    seats: seats,
    gunAim: aim,
    wedgeOpacity: wedge ?? wedgeOpacity,
    secondWedge: secondWedge,
    shot: shot,
    label: label,
    labelTag: labelTag,
    stamp: stamp,
    shake: shake,
    timerFraction: timerFraction,
    cylinderReveal: cylinderReveal,
    banner: banner,
    bannerProgress: bannerProgress,
    flash: flash,
    gunPose: gunPose,
    discBump: discBump,
  );
}

//=======================게임 시작 연출==============================
// 어두운 판 위에 총이 옆으로 눕힌 채 첫 총구 대상 방향으로 떨어지듯 놓임 →
// 손으로 집듯 살짝 들렸다가 굴러 세워지며, 첫 불빛이 켜지는 순간 내려앉음
// (원판이 툭 튀고 먼지 자국) → 시계 방향으로 한 명씩 프로필에 불이 들어옴
// (마지막이 첫 총구 대상) → 잠깐 정적 뒤 총구 방향으로 붉은 빔이 깜빡이며
// 켜지고 '게임 시작'이 찍힘. 시안: B-Anim.
const _introGunAt = 60;
const _introLightAt = 1200;
const _introStandMs = 800;

/// 세우기 동작에서 총이 판에 닿는 지점(진행 %)입니다. 이 순간이 첫 불빛입니다.
const _introLandAt = 68.0;
final _introStandAt =
    _introLightAt - (_introStandMs * _introLandAt / 100).round();
const _introDustMs = 500;
const _introBumpMs = 450;
const _introBeamDelay = 750;
const _introBannerDelay = 1250;
const _introTail = 2700;

int _introStep(int alive) =>
    alive <= 1 ? 480 : math.min(480, 2900 ~/ (alive - 1));

int rouletteIntroLength(int alive) =>
    _introLightAt +
    _introStep(alive) * math.max<int>(0, alive - 1) +
    _introTail;

/// 0 → 1 동안 형광등처럼 깜빡이며 켜지는 밝기입니다.
double _flicker(double t) {
  const keys = [
    (0.0, 0.0),
    (0.08, 1.0),
    (0.16, 0.15),
    (0.26, 1.0),
    (0.36, 0.4),
    (0.48, 1.0),
    (1.0, 1.0),
  ];
  if (t <= 0) return 0;
  for (var i = 1; i < keys.length; i++) {
    if (t <= keys[i].$1) {
      final a = keys[i - 1];
      final b = keys[i];
      return a.$2 + (b.$2 - a.$2) * (t - a.$1) / (b.$1 - a.$1);
    }
  }
  return 1;
}

Offset _thud(int ms, int at) {
  final t = (ms - at) / 500;
  if (t < 0 || t >= 1) return Offset.zero;
  final strength = 1 - t;
  return Offset(
    math.sin(t * math.pi * 6) * 8 * strength,
    math.cos(t * math.pi * 5) * 5 * strength,
  );
}

/// (진행 %, 값) 키 사이를 부드럽게(smoothstep) 잇습니다.
double _introKeys(List<(double, double)> keys, double p) {
  for (var i = 1; i < keys.length; i++) {
    final (p1, v1) = keys[i];
    if (p <= p1) {
      final (p0, v0) = keys[i - 1];
      var t = ((p - p0) / (p1 - p0)).clamp(0.0, 1.0);
      t = t * t * (3 - 2 * t);
      return v0 + (v1 - v0) * t;
    }
  }
  return keys.last.$2;
}

// 세우기(0.8초) 키입니다. 살짝 더 눕혔다(집기) 들어 올려 굴리고, 조금 지나치게
// 돌았다 되돌아오며, 68%에 판에 닿아 살짝 눌렸다 튀어 오릅니다.
const _standRoll = <(double, double)>[
  (0, 90),
  (10, 94),
  (26, 82),
  (50, 28),
  (62, -14),
  (74, 6),
  (86, -2),
  (100, 0),
];
const _standScale = <(double, double)>[
  (0, .94),
  (10, .95),
  (30, 1.05),
  (50, 1.07),
  (62, 1.02),
  (68, .97),
  (80, 1.01),
  (100, 1),
];
const _standShift = <(double, double)>[(0, 37), (10, 37), (55, 0), (100, 0)];
const _standTilt = <(double, double)>[
  (0, 0),
  (10, 1.5),
  (35, -6),
  (55, -3),
  (68, 1.5),
  (84, -.5),
  (100, 0),
];
const _standLift = <(double, double)>[
  (0, 0),
  (10, .08),
  (30, .85),
  (50, 1),
  (62, .55),
  (68, 0),
  (100, 0),
];

/// 시작 연출 [ms]의 총 자세입니다. 다 세운 뒤 먼지도 걷히면 null입니다.
RouletteGunPose? rouletteIntroGunPose(int ms) {
  if (ms < _introStandAt) return RouletteGunPose.lying;
  final dust = ms >= _introLightAt && ms < _introLightAt + _introDustMs
      ? (ms - _introLightAt) / _introDustMs
      : null;
  final p = (ms - _introStandAt) / _introStandMs * 100;
  if (p >= 100) return dust == null ? null : RouletteGunPose(dust: dust);
  return RouletteGunPose(
    roll: _introKeys(_standRoll, p),
    scale: _introKeys(_standScale, p),
    shift: _introKeys(_standShift, p),
    tilt: _introKeys(_standTilt, p),
    lift: _introKeys(_standLift, p),
    dust: dust,
  );
}

/// 총이 내려앉을 때 원판이 툭 튀는 배율입니다.
double _introDiscBump(int ms) {
  final t = (ms - _introLightAt) / _introBumpMs;
  if (t <= 0 || t >= 1) return 1;
  const keys = [(0.0, 1.0), (.3, 1.018), (.6, .996), (1.0, 1.0)];
  for (var i = 1; i < keys.length; i++) {
    final (t1, v1) = keys[i];
    if (t <= t1) {
      final (t0, v0) = keys[i - 1];
      return v0 + (v1 - v0) * Curves.easeOut.transform((t - t0) / (t1 - t0));
    }
  }
  return 1;
}

RouletteTabletFrame rouletteIntroFrame(
  RussianRouletteView game,
  int ms, {
  SeatLayoutMode? seatLayoutMode,
}) {
  final players = game.orderedPlayers;
  final count = players.length;
  final theta = <String, double>{
    for (var i = 0; i < count; i++)
      players[i].uid: RouletteStageGeometry.seatAngle(
        i,
        count,
        mode: seatLayoutMode,
      ),
  };
  final centers = <String, Offset>{
    for (var i = 0; i < count; i++)
      players[i].uid: RouletteStageGeometry.seatCenter(
        i,
        count,
        mode: seatLayoutMode,
      ),
  };
  double aimOf(String? uid) =>
      RouletteStageGeometry.aimAngle(theta[uid] ?? -math.pi / 2);
  final alive = players.where((p) => p.alive).toList();
  final n = alive.length;
  final targetIndex = alive.indexWhere((p) => p.uid == game.targetUid);
  // 대상 다음 자리부터 시계 방향으로 켜서 마지막에 대상이 켜지게 합니다.
  final order = targetIndex < 0
      ? alive
      : [for (var k = 1; k <= n; k++) alive[(targetIndex + k) % n]];
  final step = _introStep(n);
  final lightEnd = _introLightAt + step * math.max<int>(0, n - 1);
  final beamAt = lightEnd + _introBeamDelay;
  final bannerAt = lightEnd + _introBannerDelay;
  final index = {for (var i = 0; i < order.length; i++) order[i].uid: i};

  return RouletteTabletFrame(
    // 총은 처음부터 첫 총구 대상 쪽으로 놓여 돌지 않습니다.
    desiredAim: aimOf(game.targetUid),
    cylinderReveal: ((ms - _introGunAt) / 700).clamp(0.0, 1.0),
    gunPose: rouletteIntroGunPose(ms),
    discBump: _introDiscBump(ms),
    wedgeOpacity: ms < beamAt ? 0 : _flicker((ms - beamAt) / 700),
    shake: _thud(ms, _introGunAt) + _thud(ms, beamAt),
    banner: ms >= bannerAt
        ? rouletteText('게임 시작', 'GAME START', '游戏开始', '遊戲開始')
        : null,
    bannerProgress: ((ms - bannerAt) / 550).clamp(0.0, 1.0),
    seats: [
      for (final p in players)
        () {
          if (!p.alive) {
            return RouletteSeatModel(
              key: p.uid,
              characterId: p.characterId,
              theta: theta[p.uid]!,
              center: centers[p.uid],
              state: RouletteSeatState.out,
            );
          }
          final litAt = _introLightAt + (index[p.uid] ?? 0) * step;
          final state = p.uid == game.targetUid && ms >= beamAt
              ? RouletteSeatState.target
              : (p.shieldLocked
                    ? RouletteSeatState.locked
                    : RouletteSeatState.waiting);
          return RouletteSeatModel(
            key: p.uid,
            characterId: p.characterId,
            theta: theta[p.uid]!,
            center: centers[p.uid],
            state: state,
            dim: ms < litAt,
            glow: ((ms - litAt) / 750).clamp(0.0, 1.0),
          );
        }(),
    ],
  );
}

RouletteSeatState _actionState(RouletteAction? action) => switch (action) {
  RouletteAction.spin => RouletteSeatState.spin,
  RouletteAction.shield => RouletteSeatState.shield,
  RouletteAction.none => RouletteSeatState.none,
  null => RouletteSeatState.waiting,
};

/// 총구 대상부터 시계 방향으로 돈 생존자 순서(공개 순서)입니다.
List<RoulettePlayerView> rouletteRevealOrder(RussianRouletteView game) {
  final alive = game.orderedPlayers
      .where((p) => game.actions.containsKey(p.uid) || p.alive)
      .toList();
  final start = alive.indexWhere((p) => p.uid == game.targetUid);
  if (start <= 0) return alive;
  return [...alive.sublist(start), ...alive.sublist(0, start)];
}

RouletteTabletFrame rouletteTabletFrame(
  RussianRouletteView game,
  Duration elapsed, {
  SeatLayoutMode? seatLayoutMode,
}) {
  final players = game.orderedPlayers;
  final count = players.length;
  final theta = <String, double>{
    for (var i = 0; i < count; i++)
      players[i].uid: RouletteStageGeometry.seatAngle(
        i,
        count,
        mode: seatLayoutMode,
      ),
  };
  final centers = <String, Offset>{
    for (var i = 0; i < count; i++)
      players[i].uid: RouletteStageGeometry.seatCenter(
        i,
        count,
        mode: seatLayoutMode,
      ),
  };
  double aimOf(String? uid) =>
      RouletteStageGeometry.aimAngle(theta[uid] ?? -math.pi / 2);
  final ms = elapsed.inMilliseconds;
  final targetUid = game.targetUid;

  RouletteSeatModel seat(
    RoulettePlayerView p,
    RouletteSeatState state, {
    double shield = 0,
    bool shieldHit = false,
    String? badge,
    bool badgeOn = false,
    double flip = 1,
    int? hitMs,
  }) => RouletteSeatModel(
    key: p.uid,
    characterId: p.characterId,
    theta: theta[p.uid]!,
    center: centers[p.uid],
    state: state,
    shield: shield,
    shieldHit: shieldHit,
    badge: badge,
    badgeOn: badgeOn,
    flip: flip,
    hitMs: hitMs,
  );

  switch (game.phase) {
    case 'revealing':
      final order = rouletteRevealOrder(game);
      final step = RussianRouletteTiming.revealStep.inMilliseconds;
      final shown = RussianRouletteTiming.revealedCount(elapsed, order.length);
      final summary = RussianRouletteTiming.showsSpinSummary(
        elapsed,
        order.length,
      );
      final index = {for (var i = 0; i < order.length; i++) order[i].uid: i};
      return RouletteTabletFrame(
        desiredAim: aimOf(targetUid),
        wedgeOpacity: .35,
        secondWedge: false,
        label: summary
            ? rouletteText('돌리기 집계', 'Spin total', '转动统计', '轉動統計')
            : shown == 0
            ? rouletteText('선택 마감', 'Choices locked', '选择锁定', '選擇鎖定')
            : rouletteText('공개', 'Reveal', '公开', '公開'),
        labelTag: summary ? '${game.spinCount}' : '$shown / ${order.length}',
        seats: [
          for (final p in players)
            if (!p.alive && !game.actions.containsKey(p.uid))
              seat(p, RouletteSeatState.out)
            else if ((index[p.uid] ?? 99) < shown)
              seat(
                p,
                _actionState(game.actions[p.uid]),
                flip:
                    ((ms -
                                RussianRouletteTiming
                                    .revealLead
                                    .inMilliseconds -
                                index[p.uid]! * step) /
                            420)
                        .clamp(0.0, 1.0),
                shield: game.actions[p.uid] == RouletteAction.shield
                    ? ((ms -
                                  RussianRouletteTiming
                                      .revealLead
                                      .inMilliseconds -
                                  index[p.uid]! * step -
                                  200) /
                              520)
                          .clamp(0.0, 1.0)
                    : 0,
              )
            else
              seat(p, RouletteSeatState.hidden),
        ],
      );
    case 'rotating':
      final alive = players.where((p) => p.alive).toList();
      final n = alive.length;
      final finalIndex = alive.indexWhere((p) => p.uid == targetUid);
      final spins = game.spinCount;
      final startIndex = n == 0 ? 0 : ((finalIndex - spins) % n + n) % n;
      final done = RussianRouletteTiming.completedRotationSteps(elapsed, spins);
      final current = n == 0 ? targetUid : alive[(startIndex + done) % n].uid;
      final spinners = rouletteRevealOrder(
        game,
      ).where((p) => game.actions[p.uid] == RouletteAction.spin).toList();
      final badges = {
        for (var i = 0; i < spinners.length; i++) spinners[i].uid: i + 1,
      };
      return RouletteTabletFrame(
        desiredAim: aimOf(current),
        label: rouletteText('회전', 'Spin', '转动', '轉動'),
        labelTag: '$done / $spins',
        seats: [
          for (final p in players)
            if (!p.alive)
              seat(p, RouletteSeatState.out)
            else
              seat(
                p,
                _actionState(game.actions[p.uid]),
                shield: game.actions[p.uid] == RouletteAction.shield
                    ? 1.0
                    : 0.0,
                badge: badges[p.uid]?.toString(),
                badgeOn: (badges[p.uid] ?? 99) <= done,
              ),
        ],
      );
    case 'firing':
    case 'outcome':
      final outcome = game.phase == 'outcome';
      final blocked = outcome && game.shotBlocked == true;
      final hitUid = outcome
          ? (blocked ? targetUid : game.eliminatedUid ?? targetUid)
          : null;
      // 시안(태블릿 애니메이션 프로토타입)과 같은 발포: 정적 뒤 한 번에 섬광(0.55초),
      // 화면 흔들림(0.5초), 도장(0.45초), 맞은 자리 연출(0.5초)이 함께 나옵니다.
      return RouletteTabletFrame(
        desiredAim: aimOf(hitUid ?? targetUid),
        flash: outcome && ms < 550 ? ms / 550 : null,
        label: rouletteText('발포', 'Fire', '开枪', '開槍'),
        labelTag: rouletteText(
          '${game.spinCount}칸',
          '${game.spinCount} steps',
          '${game.spinCount}格',
          '${game.spinCount}格',
        ),
        shake: outcome ? rouletteShake(ms / 500) : Offset.zero,
        stamp: outcome && hitUid != null && theta[hitUid] != null
            ? RouletteStampModel(
                theta: theta[hitUid]!,
                center: centers[hitUid],
                blocked: blocked,
                progress: ms / 450,
              )
            : null,
        seats: [
          for (final p in players)
            if (outcome && p.uid == hitUid)
              seat(
                p,
                blocked ? RouletteSeatState.blocked : RouletteSeatState.dead,
                shield: blocked ? 1.0 : 0.0,
                shieldHit: blocked,
                hitMs: ms,
              )
            else if (!p.alive)
              seat(p, RouletteSeatState.out)
            else
              seat(
                p,
                _actionState(game.actions[p.uid]),
                shield: game.actions[p.uid] == RouletteAction.shield
                    ? 1.0
                    : 0.0,
              ),
        ],
      );
    default:
      return RouletteTabletFrame(
        desiredAim: aimOf(targetUid),
        seats: [
          for (final p in players)
            if (!p.alive)
              seat(p, RouletteSeatState.out)
            else if (p.uid == targetUid)
              seat(p, RouletteSeatState.target)
            else if (p.shieldLocked)
              seat(p, RouletteSeatState.locked)
            else
              seat(p, RouletteSeatState.waiting),
        ],
      );
  }
}

/// 최종 순위입니다. 우승자가 1위, 나머지는 서버 순위, 순위가 없는(나간) 사람은 뒤.
List<(RoulettePlayerView, int?)> rouletteRanking(RussianRouletteView game) {
  int? rankOf(RoulettePlayerView p) => p.uid == game.winnerUid ? 1 : p.rank;
  final list = [for (final p in game.orderedPlayers) (p, rankOf(p))];
  list.sort((a, b) => (a.$2 ?? 99).compareTo(b.$2 ?? 99));
  return list;
}

RouletteStageModel rouletteWinnerModel(
  RussianRouletteView game,
  Duration elapsed, {
  SeatLayoutMode? seatLayoutMode,
}) {
  final players = game.orderedPlayers;
  final count = players.length;
  final winner = game.players[game.winnerUid];
  final t = (elapsed.inMilliseconds / 500).clamp(0.0, 1.0);
  return RouletteStageModel(
    gunAim: 0,
    showCylinder: false,
    rays: true,
    seats: [
      for (var i = 0; i < count; i++)
        RouletteSeatModel(
          key: players[i].uid,
          characterId: players[i].characterId,
          theta: RouletteStageGeometry.seatAngle(
            i,
            count,
            mode: seatLayoutMode,
          ),
          center: RouletteStageGeometry.seatCenter(
            i,
            count,
            mode: seatLayoutMode,
          ),
          state: RouletteSeatState.rank,
          rank: players[i].uid == game.winnerUid ? 1 : players[i].rank,
        ),
    ],
    center: Transform.scale(
      scale: .4 + .6 * Curves.easeOutBack.transform(t),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(angle: math.pi, child: _WinnerTag()),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: RouletteColors.cream,
              boxShadow: [
                BoxShadow(color: Color(0xB3000000), offset: Offset(12, 12)),
              ],
            ),
            child: RouletteProfile(characterId: winner?.characterId, size: 204),
          ),
          const SizedBox(height: 14),
          _WinnerTag(),
        ],
      ),
    ),
  );
}

class _WinnerTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: RouletteColors.ink,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    child: Text(
      rouletteText('최후의 1인', 'LAST ONE STANDING', '最后一人', '最後一人'),
      style: RouletteType.display(34, RouletteColors.cream),
    ),
  );
}

//=======================끝 화면==============================
class RouletteEndBoard extends StatelessWidget {
  const RouletteEndBoard({
    super.key,
    required this.game,
    required this.onRestart,
    required this.onHome,
  });

  final RussianRouletteView game;
  final VoidCallback onRestart;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final winner = game.players[game.winnerUid];
    final ranking = rouletteRanking(game);
    return ColoredBox(
      color: RouletteColors.ink,
      child: Center(
        child: FittedBox(
          child: SizedBox(
            width: RouletteStageGeometry.width,
            height: RouletteStageGeometry.height,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _FaintRays()),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: RouletteColors.cream,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(8, 8),
                                ),
                              ],
                            ),
                            child: winner == null
                                ? const SizedBox.square(
                                    dimension: 120,
                                    child: Icon(
                                      Icons.sports_score,
                                      size: 72,
                                      color: RouletteColors.ink,
                                    ),
                                  )
                                : RouletteProfile(
                                    characterId: winner.characterId,
                                    size: 120,
                                  ),
                          ),
                          const SizedBox(width: 22),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                color: RouletteColors.cream,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                child: Text(
                                  winner == null
                                      ? rouletteText(
                                          '게임 종료',
                                          'Game over',
                                          '游戏结束',
                                          '遊戲結束',
                                        )
                                      : rouletteText(
                                          '최후의 1인',
                                          'Last one standing',
                                          '最后一人',
                                          '最後一人',
                                        ),
                                  style: RouletteType.display(
                                    22,
                                    RouletteColors.red,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                winner?.nickname ?? RouletteCopy.title,
                                style: RouletteType.display(
                                  48,
                                  RouletteColors.cream,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                rouletteText(
                                  '총 ${game.round}턴 · ${game.players.length}명 참가',
                                  '${game.round} turns · ${game.players.length} players',
                                  '共${game.round}回合 · ${game.players.length}人参加',
                                  '共${game.round}回合 · ${game.players.length}人參加',
                                ),
                                style: RouletteType.body(
                                  15,
                                  RouletteColors.sub,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final entry in ranking)
                            SizedBox(
                              width: 96,
                              child: _RankChip(
                                player: entry.$1,
                                rank: entry.$2,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BigButton(
                            label: rouletteText(
                              '다시 하기',
                              'Play again',
                              '再玩一次',
                              '再玩一次',
                            ),
                            icon: Icons.rotate_right,
                            background: RouletteColors.red,
                            foreground: RouletteColors.cream,
                            onTap: onRestart,
                          ),
                          const SizedBox(width: 24),
                          _BigButton(
                            label: rouletteText('홈으로', 'Home', '返回首页', '返回首頁'),
                            icon: Icons.home_outlined,
                            background: RouletteColors.cream,
                            foreground: RouletteColors.ink,
                            onTap: onHome,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        rouletteText(
                          '다시 하기를 누르면 같은 사람들과 바로 새 판을 시작해요',
                          'Play again starts a new game with the same seats',
                          '点击再玩一次，将以相同座位立即开始新一局',
                          '點擊再玩一次，將以相同座位立即開始新一局',
                        ),
                        style: RouletteType.body(13, RouletteColors.sub),
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

class _RankChip extends StatelessWidget {
  const _RankChip({required this.player, required this.rank});
  final RoulettePlayerView player;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final win = rank == 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              color: win ? RouletteColors.red : RouletteColors.line,
              child: RouletteProfile(
                characterId: player.characterId,
                size: 54,
                gray: !win,
                background: win ? RouletteColors.cream : RouletteColors.ink,
              ),
            ),
            Positioned(
              left: -10,
              top: -10,
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: win ? RouletteColors.red : RouletteColors.ink,
                  border: Border.all(
                    color: win ? RouletteColors.cream : RouletteColors.grey,
                    width: 2,
                  ),
                ),
                child: Text(
                  rank?.toString() ?? '–',
                  style: RouletteType.number(13, RouletteColors.cream),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 76,
          child: Text(
            player.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: RouletteType.body(
              12,
              win ? RouletteColors.cream : RouletteColors.sub,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      boxShadow: [BoxShadow(color: Colors.black, offset: Offset(8, 8))],
    ),
    child: Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 260, minHeight: 84),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            border: Border.all(color: RouletteColors.ink, width: 3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 32),
              const SizedBox(width: 14),
              Text(label, style: RouletteType.display(30, foreground)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FaintRays extends CustomPainter {
  const _FaintRays();

  @override
  void paint(Canvas canvas, Size size) {
    const c = RouletteStageGeometry.center;
    final paint = Paint()..color = RouletteColors.red.withValues(alpha: .12);
    for (var i = 0; i < 12; i++) {
      final a = -math.pi / 2 + i * math.pi / 6;
      const half = 5 * math.pi / 180;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(
            c.dx + math.cos(a - half) * 1100,
            c.dy + math.sin(a - half) * 1100,
          )
          ..lineTo(
            c.dx + math.cos(a + half) * 1100,
            c.dy + math.sin(a + half) * 1100,
          )
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
