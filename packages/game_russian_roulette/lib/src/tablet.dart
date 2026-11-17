import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/recovery/widgets/game_recovery_layer.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown_face.dart';
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
  });

  final String roomCode;
  final GameRoomContext provider;

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
    _backgroundMusic.stop();
    _victoryTimer?.cancel();
    _runSound(_sound?.stopSustainedEffect(), '회전음을 멈추지 못했습니다');
    _phaseTimer?.cancel();
    super.dispose();
  }

  void _runSound(Future<void>? operation, String message) {
    if (operation == null) return;
    unawaited(
      operation.catchError((Object error) {
        debugPrint('$message: $error');
      }),
    );
  }

  void _playEffect(String asset) => SoundEffects.play(context, asset);

  void _syncAudio(RussianRouletteView game) {
    if (!game.loaded) return;

    if (!game.finished && !game.paused) {
      _backgroundMusic.start(RussianRouletteSounds.background);
    } else {
      _backgroundMusic.stop();
    }

    if (game.paused) {
      _runSound(_sound?.stopSustainedEffect(), '회전음을 멈추지 못했습니다');
      return;
    }

    final key =
        '${game.status}:${game.phase}:${game.round}:${game.targetUid}:'
        '${game.spinCount}:${game.shotBlocked}:${game.winnerUid}';
    if (_audioKey == null) {
      _audioKey = key;
      _lastAudioPhase = game.phase;
      return;
    }
    if (_audioKey == key) return;

    final previousPhase = _lastAudioPhase;
    _audioKey = key;
    _lastAudioPhase = game.phase;
    _victoryTimer?.cancel();

    if (game.phase != 'rotating') {
      _runSound(_sound?.stopSustainedEffect(), '회전음을 멈추지 못했습니다');
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
        if (game.spinCount > 0) {
          _runSound(
            _sound?.playSustainedEffect(
              RussianRouletteSounds.revolverSpin,
              window: RussianRouletteTiming.rotating(game.spinCount),
            ),
            '리볼버 회전음을 재생하지 못했습니다',
          );
        }
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
    _armPhase(
      key,
      Duration(milliseconds: math.max(0, delay.inMilliseconds - since)),
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

  Future<void> _timeout() async {
    await _run(() => _service.command.timeout(widget.roomCode));
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
    if (mounted) await Navigator.of(context).maybePop();
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

  // 게임 시작 연출: 1턴 선택이 막 시작됐을 때(남은 시간이 넉넉할 때) 한 번만.
  int? _introStartedAt;
  int _introDeadline = 0;

  int? _introMs(RussianRouletteView game) {
    final fresh =
        game.round == 1 &&
        game.phase == 'selecting' &&
        !game.paused &&
        game.deadlineAt != 0 &&
        game.deadlineAt != _introDeadline &&
        game.deadlineAt - _nowMs > 22000;
    if (fresh) {
      _introDeadline = game.deadlineAt;
      _introStartedAt = _nowMs;
    }
    final started = _introStartedAt;
    if (started == null) return null;
    final ms = _nowMs - started;
    if (game.round != 1 ||
        game.phase != 'selecting' ||
        ms >= rouletteIntroLength(game.aliveCount)) {
      _introStartedAt = null;
      return null;
    }
    return ms;
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
      _phaseStartedAt = _nowMs;
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
    return from + (to - from) * Curves.easeOutBack.transform(t);
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
    _syncAudio(game);
    _schedule(game);
    final elapsed = _elapsed(game);
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
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 1.04, end: 1.0).animate(animation),
          child: child,
        ),
      ),
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
          RouletteStage(model: rouletteWinnerModel(game, elapsed)),
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
      presentedDeadline: _introDeadline,
    );
    final intro = _introMs(game);
    if (intro != null || holdIntro) {
      _animating = intro != null;
      final frame = rouletteIntroFrame(game, intro ?? 0);
      _wedge = frame.wedgeOpacity;
      _wedgeAt = _nowMs;
      return (
        'play',
        RouletteStage(model: frame.build(_gunAim(frame.desiredAim))),
      );
    }
    _animating = game.phase != 'selecting' && !game.paused;
    final frame = rouletteTabletFrame(game, elapsed);
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
          onTimeout: () => unawaited(_timeout()),
          builder: (_, remaining) => RouletteStage(
            model: frame.build(
              aim,
              wedge: wedge,
              timerFraction:
                  (remaining?.inMilliseconds ??
                      RussianRouletteTiming.turn.inMilliseconds) /
                  RussianRouletteTiming.turn.inMilliseconds,
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
    this.trailFrom,
    this.trailTo,
    this.stepMarks = const [],
    this.cylinderReveal = 1,
    this.banner,
    this.bannerProgress = 1,
    this.flash,
  });

  /// 총구 섬광 진행(0 → 1)입니다.
  final double? flash;

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
  final double? trailFrom;
  final double? trailTo;
  final List<double> stepMarks;

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
    trailFrom: trailFrom,
    trailTo: trailTo,
    stepMarks: stepMarks,
    timerFraction: timerFraction,
    cylinderReveal: cylinderReveal,
    banner: banner,
    bannerProgress: bannerProgress,
    flash: flash,
  );
}

//=======================게임 시작 연출==============================
// 어두운 판 위에 총이 먼저 떨어지듯 등장 → 시계 방향으로 한 명씩 프로필에 불이
// 들어오며 총이 따라 돎(마지막이 첫 총구 대상) → 잠깐 정적 뒤 총구 방향으로
// 붉은 빔이 깜빡이며 켜지고 '게임 시작'이 찍힘.
const _introGunAt = 300;
const _introLightAt = 1200;
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

RouletteTabletFrame rouletteIntroFrame(RussianRouletteView game, int ms) {
  final players = game.orderedPlayers;
  final count = players.length;
  final theta = <String, double>{
    for (var i = 0; i < count; i++)
      players[i].uid: RouletteStageGeometry.seatAngle(i, count),
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
  final lit = ms < _introLightAt
      ? 0
      : math.min(n, (ms - _introLightAt) ~/ step + 1);
  final pointing = order.isEmpty
      ? game.targetUid
      : order[math.max(0, lit - 1)].uid;
  final index = {for (var i = 0; i < order.length; i++) order[i].uid: i};

  return RouletteTabletFrame(
    desiredAim: aimOf(pointing),
    cylinderReveal: ((ms - _introGunAt) / 700).clamp(0.0, 1.0),
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
  Duration elapsed,
) {
  final players = game.orderedPlayers;
  final count = players.length;
  final theta = <String, double>{
    for (var i = 0; i < count; i++)
      players[i].uid: RouletteStageGeometry.seatAngle(i, count),
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
      final startAim = n == 0 ? 0.0 : aimOf(alive[startIndex].uid);
      final marks = <double>[];
      var cursor = startAim;
      for (var j = 1; j <= done; j++) {
        final uid = alive[(startIndex + j) % n].uid;
        var next = RouletteStageGeometry.clockwiseFrom(cursor, aimOf(uid));
        if (next <= cursor + 1e-6) next += math.pi * 2;
        marks.add(next);
        cursor = next;
      }
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
        trailFrom: startAim,
        trailTo: marks.isEmpty ? null : marks.last,
        stepMarks: marks,
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
  Duration elapsed,
) {
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
          theta: RouletteStageGeometry.seatAngle(i, count),
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
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                              ),
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
