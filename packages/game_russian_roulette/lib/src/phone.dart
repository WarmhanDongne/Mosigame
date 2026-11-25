import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/mosi_ui/mosi_balanced_text.dart';
import 'package:game_kit/phone/animations/game_entry_unroll.dart';
import 'package:game_kit/phone/widgets/exit_modal.dart';
import 'package:game_kit/phone/widgets/ripple_dialog.dart';
import 'package:game_kit/phone/widgets/rulebook_dialog.dart';
import 'package:game_kit/recovery/widgets/game_recovery_layer.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown_face.dart';
import 'package:game_russian_roulette/src/service.dart';
import 'package:game_russian_roulette/src/session.dart';
import 'package:game_russian_roulette/src/stage.dart';
import 'package:game_russian_roulette/src/theme.dart';
import 'package:game_russian_roulette/src/timing.dart';
import 'package:game_russian_roulette/src/view.dart';
import 'package:game_russian_roulette/src/widgets.dart';

class RussianRoulettePhoneScreen extends ConsumerStatefulWidget {
  const RussianRoulettePhoneScreen({
    super.key,
    required this.roomCode,
    required this.provider,
    required this.onExitRoom,
  });

  final String roomCode;
  final GameRoomContext provider;
  final Future<bool> Function() onExitRoom;

  @override
  ConsumerState<RussianRoulettePhoneScreen> createState() =>
      _RussianRoulettePhoneScreenState();
}

class _RussianRoulettePhoneScreenState
    extends ConsumerState<RussianRoulettePhoneScreen>
    with SingleTickerProviderStateMixin {
  final _service = RussianRouletteService();
  bool _reportedReady = false;
  bool _leaving = false;

  // 공개·회전 단계 안의 진행은 태블릿과 같은 간격으로 이 기기에서 셉니다.
  late final Ticker _ticker = createTicker(_onTick);
  String _phaseKey = '';
  int _phaseStartedAt = 0;
  bool _animating = false;

  // 누르는 즉시 '선택함'을 보여 주려고 서버 확인 전 고른 행동을 잠깐 들고 있습니다.
  // 전송이 실패하면 비우고, 다음 턴이 되면 버립니다.
  RouletteAction? _pending;

  /// 고른 게임과 턴입니다('시작 시각:턴'). 다시 시작한 게임의 1턴과 섞이지 않게 합니다.
  String _pendingTurn = '';

  String get _uid => ref.read(russianRouletteUidProvider);
  RussianRouletteSessionArgs get _args => RussianRouletteSessionArgs(
    roomCode: widget.roomCode,
    uid: _uid,
    watchPrivate: true,
  );

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    if (mounted && _animating) setState(() {});
  }

  int _elapsedMs(RussianRouletteView game) {
    final key = '${game.status}:${game.phase}:${game.round}';
    if (key != _phaseKey) {
      _phaseKey = key;
      // 서버의 단계 시작 시각에 맞춰 태블릿·다른 휴대폰과 같은 장면을 보여 줍니다.
      _phaseStartedAt = rouletteLocalPhaseStart(
        localNow: _nowMs,
        serverNow: ServerClock.hasSynced ? ServerClock.nowMillis() : null,
        phaseStartedAt: game.phaseStartedAt,
      );
    }
    final elapsed = _nowMs - _phaseStartedAt;
    _animating = switch (game.phase) {
      'revealing' =>
        elapsed <
            RussianRouletteTiming.revealing(game.aliveCount).inMilliseconds,
      'rotating' =>
        elapsed < RussianRouletteTiming.rotating(game.spinCount).inMilliseconds,
      // 발포 직전 1인칭 장면은 서버가 결과를 낼 때까지 계속 숨 쉬듯 움직입니다.
      'firing' => true,
      'outcome' => elapsed < 600,
      _ => false,
    };
    return elapsed;
  }

  Future<void> _choose(RouletteAction action, String turn) async {
    if (_pending != null && _pendingTurn == turn) return;
    setState(() {
      _pending = action;
      _pendingTurn = turn;
    });
    final ok = await ref
        .read(russianRouletteSessionProvider(_args).notifier)
        .execute(
          () => _service.command.submitAction(widget.roomCode, action.name),
        );
    if (!ok && mounted && _pendingTurn == turn) {
      setState(() => _pending = null);
    }
  }

  void _showRules(Offset origin) {
    showPhoneRippleDialog<void>(
      context: context,
      origin: origin,
      builder: (_) => PhoneGameRulebookDialog(
        title: RouletteCopy.title,
        markdown: RouletteCopy.rulesMarkdown,
      ),
    );
  }

  Future<void> _requestExit(Offset origin, String? characterId) async {
    if (_leaving) return;
    final leave = await SharedPhoneExitModal.show(
      context,
      origin: origin,
      doorImage: const Icon(Icons.door_front_door_outlined, size: 92),
      characterId: characterId,
      imageHeight: 130,
      maxWidth: 340,
      surfaceColor: RouletteColors.paper,
      primaryColor: RouletteColors.red,
      titleColor: RouletteColors.ink,
      descriptionColor: RouletteColors.muted,
    );
    if (leave != true || !mounted) return;
    setState(() => _leaving = true);
    final left = await widget.onExitRoom();
    if (!mounted) return;
    if (left) Navigator.of(context).pop(true);
    setState(() => _leaving = false);
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
    final me = game.players[_uid];
    final submitted = session.privateState['choiceSubmitted'] == true;
    final myAction = actionFromWire(session.privateState['action']);
    // 시간 초과로 서버가 '아무것도 안 하기'를 대신 골랐는지입니다(내 화면 안내 전용).
    _autoSelected = session.privateState['autoSelected'] == true;
    final elapsed = _elapsedMs(game);
    final pending = _pendingTurn == _turnId(game) ? _pending : null;
    final screen = _screen(
      game,
      me,
      submitted,
      myAction,
      pending,
      session.commandInFlight,
      elapsed,
    );
    final header = screen.header;

    return GameEntryUnroll(
      child: Scaffold(
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
            isSubmitting: session.commandInFlight,
            failureMessage: session.errorMessage,
            onExpired: controller.expireInterruption,
          ),
          child: AnimatedContainer(
            duration: RussianRouletteTiming.stageFade,
            curve: Curves.easeInOutCubic,
            color: screen.background,
            child: Stack(
              children: [
                // 화면이 바뀌면 붉은 띠가 새 자리로 미끄러지듯 옮겨 갑니다.
                AnimatedPositioned(
                  duration: RussianRouletteTiming.stageFade,
                  curve: Curves.easeInOutCubic,
                  left: -60,
                  top: screen.bandTop ?? -220,
                  width: 560,
                  height: 70,
                  child: Transform.rotate(
                    angle: -14 * math.pi / 180,
                    child: AnimatedContainer(
                      duration: RussianRouletteTiming.stageFade,
                      color: screen.bandColor,
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
                    // 머리줄(프로필·이름)은 단계가 바뀌어도 그대로 두고, 단계 이름과
                    // 오른쪽 칸만 겹쳐 바꿉니다. 아래 본문만 짧게 겹쳐 넘어갑니다.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSwitcher(
                          duration: RussianRouletteTiming.bodyFade,
                          child: header == null
                              ? const SizedBox(
                                  key: ValueKey('no-header'),
                                  width: double.infinity,
                                )
                              : _MeHeader(
                                  key: const ValueKey('header'),
                                  me: me,
                                  subline: header.subline,
                                  subColor: header.subColor,
                                  right: header.right,
                                  rightKey: header.rightKey,
                                ),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: RussianRouletteTiming.bodyFade,
                            reverseDuration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween(
                                      begin: const Offset(0, .02),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: KeyedSubtree(
                              key: ValueKey(screen.key),
                              child: screen.body,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (screen.showIcons)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 8, 24, 0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SquareIcon(
                              icon: Icons.help_outline,
                              label: rouletteText(
                                '게임 규칙 보기',
                                'Rules',
                                '查看规则',
                                '查看規則',
                              ),
                              onTap: _showRules,
                            ),
                            const SizedBox(width: 10),
                            _SquareIcon(
                              icon: Icons.logout,
                              label: rouletteText('나가기', 'Leave', '离开', '離開'),
                              onTap: (origin) =>
                                  _requestExit(origin, me?.characterId),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // 총에 맞은 사람의 휴대폰은 발포 순간 화면 전체가 하얗게 번쩍입니다(시안과 같음).
                if (_shotFlash(game, elapsed) > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: RouletteColors.cream.withValues(
                          alpha: _shotFlash(game, elapsed),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 게임(시작 시각)과 턴을 함께 묶은 식별자입니다.
  static String _turnId(RussianRouletteView game) =>
      '${game.startedAt}:${game.round}';

  /// 발포 섬광: 0.08초 만에 켜졌다가 0.3초 동안 꺼집니다.
  double _shotFlash(RussianRouletteView game, int elapsed) {
    final hitMe =
        game.phase == 'outcome' &&
        (game.targetUid == _uid || game.eliminatedUid == _uid);
    if (!hitMe || elapsed < 0) return 0;
    if (elapsed < 84) return elapsed / 84;
    if (elapsed < 378) return 1 - (elapsed - 84) / 294;
    return 0;
  }

  /// 이번 턴 내 선택이 시간 초과로 자동으로 정해졌는지입니다.
  bool _autoSelected = false;

  _PhoneScreen _screen(
    RussianRouletteView game,
    RoulettePlayerView? me,
    bool submitted,
    RouletteAction? myAction,
    RouletteAction? pending,
    bool busy,
    int elapsed,
  ) {
    if (!game.loaded) {
      return const _PhoneScreen(
        key: 'loading',
        body: Center(
          child: CircularProgressIndicator(color: RouletteColors.red),
        ),
        showIcons: false,
        bandTop: null,
      );
    }
    if (game.finished) {
      return _PhoneScreen(
        key: 'result',
        body: _ResultBody(game: game, meUid: _uid),
        showIcons: false,
        bandTop: 60,
      );
    }
    final turn = rouletteText(
      '${game.round}턴',
      'Turn ${game.round}',
      '第${game.round}回合',
      '第${game.round}回合',
    );
    final fire = rouletteText('발포', 'Fire', '开枪', '開槍');
    if (me == null || !me.alive) {
      if (me != null && game.phase == 'outcome' && game.eliminatedUid == _uid) {
        return _PhoneScreen(
          key: 'out-${game.round}',
          header: _HeaderSpec(
            right: Text(
              rouletteText(
                '생존 ${game.aliveCount}',
                'ALIVE ${game.aliveCount}',
                '存活 ${game.aliveCount}',
                '存活 ${game.aliveCount}',
              ),
              style: RouletteType.number(13, RouletteColors.sub, spacing: 2.4),
            ),
            rightKey: 'alive',
          ),
          body: _OutBody(game: game, me: me),
          bandTop: null,
        );
      }
      final selecting = game.phase == 'selecting';
      return _PhoneScreen(
        key: 'spectate',
        header: _HeaderSpec(
          subline: rouletteText(
            '관전 중 · 탈락',
            'Spectating · out',
            '观战中 · 已淘汰',
            '觀戰中 · 已淘汰',
          ),
          right: selecting
              ? _TimerBox(deadlineAt: game.deadlineAt, boxed: false)
              : null,
          rightKey: 'timer-plain',
        ),
        body: _SpectateBody(game: game, me: me, meUid: _uid, elapsed: elapsed),
        bandTop: 104,
      );
    }
    if (game.phase == 'outcome' &&
        game.shotBlocked == true &&
        game.targetUid == _uid) {
      return _PhoneScreen(
        key: 'blocked-${game.round}',
        background: RouletteColors.red,
        bandColor: RouletteColors.ink,
        bandTop: 430,
        header: _HeaderSpec(
          subline: '$turn · $fire',
          subColor: RouletteColors.cream,
        ),
        body: _BlockedBody(me: me, turn: turn),
      );
    }
    final order = _revealOrder(game);
    final lockedLead =
        game.phase == 'revealing' &&
        RussianRouletteTiming.revealedCount(
              Duration(milliseconds: elapsed),
              order.length,
            ) ==
            0;
    if (game.phase == 'selecting' || lockedLead) {
      // 고르기 → 기다리기 → 선택 마감은 같은 화면 안에서 이어집니다.
      // 버튼은 제자리에서 사라지고, 대기 표시는 처음부터 제 위치에 나타나며,
      // 마감되면 같은 자리에 도장이 찍힙니다.
      return _PhoneScreen(
        key: 'turn-${_turnId(game)}',
        bandTop: 150,
        header: _HeaderSpec(
          subline: turn,
          right: lockedLead
              ? const _LockedTimer()
              : _TimerBox(deadlineAt: game.deadlineAt),
          rightKey: lockedLead ? 'timer-locked' : 'timer',
        ),
        body: _ChooseBody(
          game: game,
          me: me,
          busy: busy || game.paused,
          onChoose: (action) => _choose(action, _turnId(game)),
          submitted: submitted,
          myAction: myAction,
          pending: pending,
          locked: lockedLead,
          lockedTotal: order.length,
          autoSelected: _autoSelected,
        ),
      );
    }
    if (game.phase == 'rotating') {
      final done = RussianRouletteTiming.completedRotationSteps(
        Duration(milliseconds: elapsed),
        game.spinCount,
      );
      return _PhoneScreen(
        key: 'rotate-${game.round}',
        bandTop: 118,
        header: _HeaderSpec(
          subline: rouletteText('회전', 'Spin', '转动', '轉動'),
          right: _StepCounter(done: done, total: game.spinCount),
          rightKey: 'rotate',
        ),
        body: _RotationBody(game: game, me: me, elapsed: elapsed),
      );
    }
    if (game.phase == 'firing') {
      final aimedAtMe = game.targetUid == _uid;
      return _PhoneScreen(
        key: 'fire-${game.round}',
        background: aimedAtMe ? RouletteColors.red : RouletteColors.ink,
        bandColor: aimedAtMe ? RouletteColors.ink : RouletteColors.red,
        bandTop: aimedAtMe ? 500 : 118,
        header: _HeaderSpec(
          subline: fire,
          subColor: aimedAtMe ? RouletteColors.cream : RouletteColors.sub,
        ),
        body: _FiringBody(game: game, me: me, elapsed: elapsed),
      );
    }
    final revealing = game.phase == 'revealing';
    final summary =
        revealing &&
        RussianRouletteTiming.showsSpinSummary(
          Duration(milliseconds: elapsed),
          order.length,
        );
    return _PhoneScreen(
      key: 'reveal-${game.round}',
      bandTop: 118,
      header: _HeaderSpec(
        subline: switch (game.phase) {
          'revealing' when summary => rouletteText(
            '돌리기 집계',
            'Spin total',
            '转动统计',
            '轉動統計',
          ),
          'revealing' => rouletteText('공개', 'Reveal', '公开', '公開'),
          'rotating' => rouletteText('회전', 'Spin', '转动', '轉動'),
          _ => fire,
        },
      ),
      body: _RevealBody(
        game: game,
        me: me,
        meUid: _uid,
        elapsed: elapsed,
        autoSelected: _autoSelected,
      ),
    );
  }
}

class _PhoneScreen {
  const _PhoneScreen({
    required this.key,
    required this.body,
    this.header,
    this.background = RouletteColors.ink,
    this.bandColor = RouletteColors.red,
    this.bandTop,
    this.showIcons = true,
  });
  final String key;
  final Widget body;

  /// 본문 위에 고정해 두는 머리줄 내용입니다. `null`이면 머리줄을 숨깁니다.
  final _HeaderSpec? header;
  final Color background;
  final Color bandColor;
  final double? bandTop;
  final bool showIcons;
}

class _HeaderSpec {
  const _HeaderSpec({
    this.subline,
    this.subColor = RouletteColors.sub,
    this.right,
    this.rightKey = '',
  });
  final String? subline;
  final Color subColor;
  final Widget? right;

  /// 오른쪽 칸의 종류입니다. 종류가 바뀔 때만 겹쳐 바꾸고, 같은 종류 안의
  /// 숫자 변화(타이머·회전 횟수)는 그 자리에서 바뀝니다.
  final String rightKey;
}

//=======================공통 조각==============================
class _SquareIcon extends StatelessWidget {
  const _SquareIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final void Function(Offset origin) onTap;

  @override
  Widget build(BuildContext context) => Builder(
    builder: (buttonContext) => Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          final box = buttonContext.findRenderObject() as RenderBox?;
          onTap(
            box?.localToGlobal(box.size.center(Offset.zero)) ?? Offset.zero,
          );
        },
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: RouletteColors.cream, width: 2),
          ),
          child: Icon(icon, color: RouletteColors.cream, size: 22),
        ),
      ),
    ),
  );
}

/// 왼쪽 위 내 프로필 머리줄입니다. 이름 옆에 '나'를 붙입니다.
class _MeHeader extends StatelessWidget {
  const _MeHeader({
    super.key,
    required this.me,
    this.subline,
    this.subColor = RouletteColors.sub,
    this.right,
    this.rightKey = '',
  });
  final RoulettePlayerView? me;
  final String? subline;
  final Color subColor;
  final Widget? right;
  final String rightKey;

  static Widget _swap(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .25),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Container(
        padding: const EdgeInsets.all(3),
        color: RouletteColors.cream,
        child: RouletteProfile(characterId: me?.characterId, size: 46),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    me?.nickname ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RouletteType.display(
                      24,
                      RouletteColors.cream,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const _MeTag(),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: RussianRouletteTiming.bodyFade,
              transitionBuilder: _swap,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              child: Text(
                subline ?? '',
                key: ValueKey((subline, subColor)),
                style: RouletteType.body(13, subColor, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
      AnimatedSwitcher(
        duration: RussianRouletteTiming.bodyFade,
        transitionBuilder: _swap,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.bottomRight,
          children: [...previous, ?current],
        ),
        child: right == null
            ? const SizedBox.shrink(key: ValueKey('no-right'))
            : KeyedSubtree(key: ValueKey('right-$rightKey'), child: right!),
      ),
    ],
  );
}

/// 선택 마감: 시간이 다 된 타이머를 붉게 남깁니다(시안).
class _LockedTimer extends StatelessWidget {
  const _LockedTimer();

  /// 타이머 상자와 같은 높이(숫자 40 + 위아래 4)로 맞춰 자리가 흔들리지 않게 합니다.
  static const _height = 48.0;

  @override
  Widget build(BuildContext context) => Container(
    height: _height,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: RouletteColors.red,
      border: Border.all(color: RouletteColors.cream, width: 2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline, color: RouletteColors.cream, size: 22),
        const SizedBox(width: 6),
        Text(
          rouletteText('선택 마감', 'Locked', '选择截止', '選擇截止'),
          style: RouletteType.display(20, RouletteColors.cream, height: 1),
        ),
      ],
    ),
  );
}

/// 회전 횟수 'n / 전체'. 숫자만 위로 밀려 바뀝니다.
class _StepCounter extends StatelessWidget {
  const _StepCounter({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -.4),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Text(
          '$done',
          key: ValueKey(done),
          style: RouletteType.number(34, RouletteColors.cream),
        ),
      ),
      Text(' / $total', style: RouletteType.number(34, RouletteColors.sub)),
    ],
  );
}

class _MeTag extends StatelessWidget {
  const _MeTag();

  @override
  Widget build(BuildContext context) => Container(
    color: RouletteColors.cream,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    child: Text(
      rouletteText('나', 'ME', '我', '我'),
      style: RouletteType.body(12, RouletteColors.ink, weight: FontWeight.w700),
    ),
  );
}

class _TimerBox extends StatelessWidget {
  const _TimerBox({required this.deadlineAt, this.boxed = true});
  final int deadlineAt;
  final bool boxed;

  @override
  Widget build(BuildContext context) => GameTurnCountdownFace(
    expiresAt: deadlineAt == 0 ? null : deadlineAt,
    builder: (_, remaining) {
      final seconds = (remaining?.inSeconds ?? 30).clamp(0, 30);
      final text = '00:${seconds.toString().padLeft(2, '0')}';
      if (!boxed) {
        return Text(text, style: RouletteType.number(34, RouletteColors.cream));
      }
      final urgent = seconds <= 5;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        color: urgent ? RouletteColors.red : RouletteColors.cream,
        child: Text(
          text,
          style: RouletteType.number(
            40,
            urgent ? RouletteColors.cream : RouletteColors.ink,
          ),
        ),
      );
    },
  );
}

class _Alert extends StatelessWidget {
  const _Alert({
    required this.title,
    required this.description,
    this.striped = false,
  });
  final String title;
  final String description;
  final bool striped;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 26),
    decoration: BoxDecoration(
      color: RouletteColors.ink,
      border: Border.all(color: RouletteColors.cream, width: 2),
    ),
    child: Stack(
      children: [
        if (striped)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 8,
            child: CustomPaint(painter: _Stripes()),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, striped ? 20 : 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MosiBalancedText(
                title,
                maxLines: 2,
                style: RouletteType.display(22, RouletteColors.cream),
              ),
              const SizedBox(height: 4),
              MosiBalancedText(
                description,
                maxLines: 3,
                style: RouletteType.body(13, RouletteColors.sub, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Stripes extends CustomPainter {
  const _Stripes();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final p = Paint()
      ..color = RouletteColors.cream
      ..strokeWidth = 4;
    for (var x = -size.height; x < size.width + size.height; x += 12) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//=======================행동 버튼==============================
enum _ButtonMode { normal, selected, dimmed, disabled }

/// 누르면 그림자 쪽으로 눌려 들어갔다가, 떼면 살짝 튀어 오르며 돌아옵니다(시안).
class _PressFx extends StatefulWidget {
  const _PressFx({
    required this.onTap,
    required this.child,
    this.shadow = true,
    this.color,
  });
  final VoidCallback? onTap;
  final Widget child;
  final bool shadow;
  final Color? color;

  @override
  State<_PressFx> createState() => _PressFxState();
}

class _PressFxState extends State<_PressFx> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    if (!enabled && _down) _down = false;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: _down ? 70 : 240),
          curve: _down ? Curves.easeOut : Curves.easeOutBack,
          transform: Matrix4.translationValues(_down ? 5 : 0, _down ? 5 : 0, 0),
          decoration: BoxDecoration(
            color: widget.color,
            boxShadow: widget.shadow
                ? [
                    BoxShadow(
                      color: Colors.black,
                      offset: _down ? const Offset(1, 1) : const Offset(6, 6),
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _HalfButton extends StatelessWidget {
  const _HalfButton({
    required this.action,
    required this.mode,
    required this.onTap,
    this.confirmed = true,
  });
  final RouletteAction action;
  final _ButtonMode mode;
  final VoidCallback? onTap;

  /// 서버가 선택을 받았는지입니다. 받기 전에는 '선택함' 옆에 점이 움직입니다.
  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final spin = action == RouletteAction.spin;
    final disabled = mode == _ButtonMode.disabled;
    var bg = spin ? RouletteColors.red : RouletteColors.cream;
    var fg = spin ? RouletteColors.cream : RouletteColors.ink;
    var sub = spin ? RouletteColors.cream : RouletteColors.line;
    var lines = spin
        ? [
            rouletteText('총구 +1칸', 'Gun +1 seat', '枪口 +1格', '槍口 +1格'),
            rouletteText(
              '이번 턴 방어 불가',
              'No defense this turn',
              '本回合无法防御',
              '本回合無法防禦',
            ),
          ]
        : [
            rouletteText('총구 그대로', 'Gun stays', '枪口不动', '槍口不動'),
            rouletteText('맞아도 생존', 'Survive a hit', '中弹也能存活', '中彈也能存活'),
            rouletteText('다음 턴 사용 불가', 'Not next turn', '下回合不可用', '下回合不可用'),
          ];
    Border? border;
    if (mode == _ButtonMode.selected) {
      border = Border.all(
        color: spin ? RouletteColors.cream : RouletteColors.red,
        width: 4,
      );
    }
    if (disabled) {
      bg = Colors.transparent;
      fg = RouletteColors.dim;
      sub = RouletteColors.dim;
      border = Border.all(color: RouletteColors.dash, width: 2);
      lines = [
        rouletteText('지난 턴에 사용', 'Used last turn', '上回合已使用', '上回合已使用'),
        rouletteText('다음 턴에 다시 가능', 'Back next turn', '下回合可再用', '下回合可再用'),
      ];
    }
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(color: bg, border: border),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 30),
              Icon(
                disabled
                    ? Icons.remove_moderator
                    : (spin ? Icons.rotate_right : Icons.shield),
                color: fg,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                spin
                    ? rouletteText('돌리기', 'Spin', '转动', '轉動')
                    : rouletteText('방패', 'Shield', '护盾', '護盾'),
                style: RouletteType.display(30, fg),
              ),
              const SizedBox(height: 6),
              for (final line in lines)
                Text(line, style: RouletteType.body(13, sub, height: 1.45)),
            ],
          ),
          if (mode == _ButtonMode.selected)
            Positioned(
              right: -6,
              top: -10,
              child: _PickedTag(confirmed: confirmed),
            ),
          if (disabled)
            Positioned(
              right: -6,
              top: -10,
              child: Container(
                color: RouletteColors.track,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  rouletteText('사용 불가', 'Unavailable', '不可用', '不可用'),
                  style: RouletteType.body(
                    12,
                    RouletteColors.sub,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      opacity: mode == _ButtonMode.dimmed ? .35 : 1,
      child: _PressFx(
        shadow: !disabled,
        onTap: disabled ? null : onTap,
        child: content,
      ),
    );
  }
}

class _PickedTag extends StatelessWidget {
  const _PickedTag({this.confirmed = true});
  final bool confirmed;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    // 누르는 순간 살짝 크게 붙었다가 제자리로 내려앉습니다.
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 360),
    curve: Curves.easeOutBack,
    builder: (context, v, child) => Opacity(
      opacity: v.clamp(0.0, 1.0),
      child: Transform.scale(scale: 1.2 - .2 * v, child: child),
    ),
    child: Container(
      color: RouletteColors.ink,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: confirmed
                  ? const Icon(
                      Icons.check,
                      key: ValueKey('ok'),
                      color: RouletteColors.cream,
                      size: 14,
                    )
                  : const _SendingDots(key: ValueKey('sending')),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            rouletteText('선택함', 'Picked', '已选择', '已選擇'),
            style: RouletteType.body(
              12,
              RouletteColors.cream,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 서버 확인을 기다리는 동안 '선택함' 앞에서 움직이는 작은 점 세 개입니다.
/// 시간 초과로 저절로 눌린 '아무것도 안 하기'에 붙는 꼬리표입니다.
class _AutoPickedTag extends StatelessWidget {
  const _AutoPickedTag();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 360),
    curve: Curves.easeOutBack,
    builder: (context, v, child) => Opacity(
      opacity: v.clamp(0.0, 1.0),
      child: Transform.scale(scale: 1.3 - .3 * v, child: child),
    ),
    child: Container(
      color: RouletteColors.ink,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_outlined,
            color: RouletteColors.cream,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            rouletteText('자동 선택', 'Auto', '自动选择', '自動選擇'),
            style: RouletteType.body(
              12,
              RouletteColors.cream,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SendingDots extends StatefulWidget {
  const _SendingDots({super.key});

  @override
  State<_SendingDots> createState() => _SendingDotsState();
}

class _SendingDotsState extends State<_SendingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var k = 0; k < 3; k++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: .5),
            child: Transform.translate(
              offset: Offset(
                0,
                -2.5 *
                    math
                        .sin(((_controller.value - k * .15) % 1) * math.pi * 2)
                        .clamp(0.0, 1.0),
              ),
              child: Container(
                width: 3.5,
                height: 3.5,
                color: RouletteColors.cream,
              ),
            ),
          ),
      ],
    ),
  );
}

class _NoneButton extends StatelessWidget {
  const _NoneButton({
    required this.mode,
    required this.onTap,
    this.autoTag = false,
    this.autoPicked = false,
    this.confirmed = true,
  });
  final _ButtonMode mode;
  final VoidCallback? onTap;
  final bool confirmed;

  /// 시간 초과로 저절로 눌렸는지입니다. '선택함' 대신 '자동 선택'을 붙입니다.
  final bool autoPicked;

  /// 방패가 잠긴 턴에만 '시간 끝나면 자동 선택' 표시를 붙입니다(시안 잠긴 턴).
  final bool autoTag;

  @override
  Widget build(BuildContext context) {
    final selected = mode == _ButtonMode.selected;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      opacity: mode == _ButtonMode.dimmed ? .35 : 1,
      child: _PressFx(
        color: RouletteColors.ink,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? RouletteColors.red : RouletteColors.cream,
            border: Border.all(
              color: selected ? RouletteColors.cream : RouletteColors.ink,
              width: selected ? 4 : 3,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.remove_circle_outline,
                color: selected ? RouletteColors.cream : RouletteColors.ink,
                size: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rouletteText('아무것도 안 하기', 'Do nothing', '什么都不做', '什麼都不做'),
                      style: RouletteType.display(
                        21,
                        selected ? RouletteColors.cream : RouletteColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    MosiBalancedText(
                      autoTag
                          ? rouletteText(
                              '총구 그대로 · 방어 없음',
                              'Gun stays · no defense',
                              '枪口不动 · 无防御',
                              '槍口不動 · 無防禦',
                            )
                          : rouletteText(
                              '총구 그대로 · 방어 없음 · 다음 턴 제약 없음',
                              'Gun stays · no defense · no limit next turn',
                              '枪口不动 · 无防御 · 下回合无限制',
                              '槍口不動 · 無防禦 · 下回合無限制',
                            ),
                      maxLines: 2,
                      style: RouletteType.body(
                        12,
                        selected ? RouletteColors.cream : RouletteColors.ink,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected && autoPicked)
                const _AutoPickedTag()
              else if (selected)
                _PickedTag(confirmed: confirmed)
              else if (autoTag)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: RouletteColors.ink,
                    border: Border.all(color: RouletteColors.cream, width: 1.5),
                  ),
                  child: Text(
                    rouletteText(
                      '시간 끝나면\n자동 선택',
                      'Auto on\ntimeout',
                      '超时\n自动选择',
                      '逾時\n自動選擇',
                    ),
                    textAlign: TextAlign.center,
                    style: RouletteType.body(
                      10.5,
                      RouletteColors.cream,
                      weight: FontWeight.w700,
                      height: 1.25,
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

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.shieldLocked,
    this.autoPicked = false,
    required this.onChoose,
    this.picked,
    this.confirmed = false,
    this.hint,
    this.introLocked = false,
  });
  final bool shieldLocked;

  /// 시간 초과로 '아무것도 안 하기'가 자동으로 골라졌는지입니다.
  final bool autoPicked;
  final void Function(RouletteAction)? onChoose;

  /// 버튼 위에 잠깐 띄우는 한 줄 안내입니다(시작 연출 대기, 자동 선택 예고).
  final String? hint;

  /// 첫 턴 시작 연출이 끝나기 전이라 아직 고를 수 없습니다.
  final bool introLocked;

  /// 고른 행동입니다(서버 확인 전이어도). 고르면 나머지는 제자리에서 어두워집니다.
  final RouletteAction? picked;
  final bool confirmed;

  _ButtonMode _mode(RouletteAction action) {
    if (action == RouletteAction.shield && shieldLocked) {
      return _ButtonMode.disabled;
    }
    final mine = picked;
    if (mine == null) return _ButtonMode.normal;
    return mine == action ? _ButtonMode.selected : _ButtonMode.dimmed;
  }

  VoidCallback? _tap(RouletteAction action) {
    final choose = onChoose;
    if (choose == null || picked != null || introLocked) return null;
    return () => choose(action);
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _HalfButton(
                  action: RouletteAction.spin,
                  mode: _mode(RouletteAction.spin),
                  onTap: _tap(RouletteAction.spin),
                  confirmed: confirmed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HalfButton(
                  action: RouletteAction.shield,
                  mode: _mode(RouletteAction.shield),
                  onTap: _tap(RouletteAction.shield),
                  confirmed: confirmed,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _NoneButton(
          mode: _mode(RouletteAction.none),
          onTap: _tap(RouletteAction.none),
          autoTag: shieldLocked,
          autoPicked: autoPicked,
          confirmed: confirmed,
        ),
      ],
    );
    final panel = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 버튼은 아래에 붙어 있어 안내가 생겨도 위로만 자라고 버튼은 움직이지 않습니다.
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: hint == null
                ? const SizedBox(
                    key: ValueKey('no-hint'),
                    width: double.infinity,
                  )
                : Padding(
                    key: ValueKey(hint),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MosiBalancedText(
                      hint!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: RouletteType.body(
                        13,
                        RouletteColors.cream,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: introLocked ? .45 : 1,
          child: body,
        ),
      ],
    );
    if (onChoose != null && picked == null && !introLocked) return panel;
    return IgnorePointer(child: panel);
  }
}

//=======================화면별 본문==============================
/// 고르기 → 기다리기 → 선택 마감을 한 화면 안에서 이어 보여 줍니다.
///
/// 누르는 즉시 '선택함'이 붙고 나머지 버튼은 어두워집니다(서버 확인 전).
/// 확인이 오면 잠깐 뒤 버튼과 안내 상자가 제자리에서 사라지고, 대기 표시는
/// 처음부터 최종 위치에 나타납니다. 아무것도 밀려 움직이지 않습니다.
class _ChooseBody extends StatefulWidget {
  const _ChooseBody({
    required this.game,
    required this.me,
    required this.busy,
    required this.onChoose,
    this.submitted = false,
    this.myAction,
    this.pending,
    this.locked = false,
    this.lockedTotal = 0,
    this.autoSelected = false,
  });
  final RussianRouletteView game;
  final RoulettePlayerView me;
  final bool busy;
  final void Function(RouletteAction) onChoose;

  /// 시간 초과로 '아무것도 안 하기'가 자동으로 정해졌는지입니다. 마감 순간에
  /// 기다림 화면으로 넘어가지 않고, 저절로 눌린 버튼을 보여 줍니다.
  final bool autoSelected;

  /// 서버가 내 선택을 받았는지입니다.
  final bool submitted;

  /// 서버가 돌려준 내 선택입니다.
  final RouletteAction? myAction;

  /// 서버 확인 전에 화면에서 먼저 보여 주는 내 선택입니다.
  final RouletteAction? pending;

  /// 모두 골라 선택이 마감된 순간(공개 직전)입니다.
  final bool locked;
  final int lockedTotal;

  @override
  State<_ChooseBody> createState() => _ChooseBodyState();
}

class _ChooseBodyState extends State<_ChooseBody> {
  /// 선택함 표시를 잠깐 보여 준 뒤 버튼을 거두는 시간입니다.
  static const _settleDelay = Duration(milliseconds: 450);

  bool _settled = false;
  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();
    // 이미 고른 뒤 다시 그려지는 경우(재접속 등)는 바로 대기 상태로 둡니다.
    _settled = widget.submitted || widget.locked;
  }

  @override
  void didUpdateWidget(covariant _ChooseBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_settled) return;
    if (widget.locked) {
      _settleTimer?.cancel();
      setState(() => _settled = true);
    } else if (widget.submitted && _settleTimer == null) {
      _settleTimer = Timer(_settleDelay, () {
        if (mounted) setState(() => _settled = true);
      });
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 시간 초과로 자동 선택된 마감 순간에는 기다림 화면 대신 눌린 버튼을 둡니다.
    final settled = _settled && !(widget.autoSelected && widget.locked);
    final game = widget.game;
    final me = widget.me;
    final target = game.players[game.targetUid];
    final aimedAtMe = game.targetUid == me.uid;
    final _Alert alert;
    if (me.shieldLocked) {
      alert = _Alert(
        striped: true,
        title: rouletteText('방패 사용 불가', 'Shield locked', '护盾不可用', '護盾不可用'),
        description: rouletteText(
          '지난 턴에 방패를 들어서 이번 턴엔 돌리기나 아무것도 안 하기만 고를 수 있어요.',
          'You used the shield last turn. Spin or do nothing this turn.',
          '上回合使用了护盾，本回合只能转动或什么都不做。',
          '上回合使用了護盾，本回合只能轉動或什麼都不做。',
        ),
      );
    } else if (aimedAtMe) {
      // 시안처럼 이번 턴에 방패를 못 쓰는 사람을 알려 줍니다(없으면 기본 안내).
      final locked = [
        for (final p in game.orderedPlayers)
          if (p.alive && p.shieldLocked && p.uid != me.uid) p.nickname,
      ];
      final names = locked.join(', ');
      alert = _Alert(
        title: rouletteText(
          '총구가 당신을 겨눈다',
          'The gun is on you',
          '枪口对准了你',
          '槍口對準了你',
        ),
        description: locked.isEmpty
            ? rouletteText(
                '돌린 사람 수만큼 총구가 움직여요. 방패를 들면 맞아도 살아남아요.',
                'The gun moves once per Spin. A shield survives the shot.',
                '每有一人转动，枪口就移动一格。举起护盾即使中弹也能存活。',
                '每有一人轉動，槍口就移動一格。舉起護盾即使中彈也能存活。',
              )
            : rouletteText(
                '$names${_topicParticle(locked.last)} 지난 턴에 방패를 들어서 이번 턴엔 방패를 못 써요.',
                '$names used a shield last turn and cannot use it this turn.',
                '$names 上回合用了护盾，本回合不能使用护盾。',
                '$names 上回合用了護盾，本回合不能使用護盾。',
              ),
      );
    } else {
      final name = target?.nickname ?? '';
      alert = _Alert(
        title: rouletteText(
          '총구는 $name에게',
          'Aimed at $name',
          '枪口对准 $name',
          '槍口對準 $name',
        ),
        description: rouletteText(
          '돌리기를 고른 사람 수만큼 총구가 시계 방향으로 한 칸씩 움직여요.',
          'The gun moves clockwise one seat for each Spin.',
          '每有一人选择转动，枪口就顺时针移动一格。',
          '每有一人選擇轉動，槍口就順時針移動一格。',
        ),
      );
    }
    final picked = widget.myAction ?? widget.pending;
    final total = widget.locked ? widget.lockedTotal : game.aliveCount;
    final ready = widget.locked ? total : game.choiceCount.clamp(0, total);
    const fade = Duration(milliseconds: 420);
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: AnimatedSlide(
              duration: fade,
              curve: Curves.easeInCubic,
              offset: settled ? const Offset(0, -.12) : Offset.zero,
              child: AnimatedOpacity(
                duration: fade,
                curve: Curves.easeIn,
                opacity: settled ? 0 : 1,
                child: alert,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 650),
              // 버튼이 거의 사라진 뒤에 떠오르게 조금 늦게 시작합니다.
              curve: const Interval(.35, 1, curve: Curves.easeOut),
              opacity: settled ? 1 : 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 650),
                curve: const Interval(.35, 1, curve: Curves.easeOutCubic),
                offset: settled ? Offset.zero : const Offset(0, .02),
                child: _WaitingMiddle(
                  total: total,
                  ready: ready,
                  locked: widget.locked,
                  myPick: picked,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: settled,
            child: AnimatedSlide(
              duration: fade,
              curve: Curves.easeInCubic,
              offset: settled ? const Offset(0, .06) : Offset.zero,
              child: AnimatedOpacity(
                duration: fade,
                curve: Curves.easeIn,
                opacity: settled ? 0 : 1,
                // 1초마다 남은 시간을 보고 버튼 잠금과 안내를 정합니다.
                child: GameTurnCountdown(
                  expiresAt: game.deadlineAt == 0 ? null : game.deadlineAt,
                  builder: (context, remaining) {
                    final left = remaining?.inMilliseconds;
                    // 첫 턴은 마감까지 30초보다 많이 남은 동안 태블릿 시작 연출 중입니다.
                    final intro =
                        game.round == 1 &&
                        left != null &&
                        left > RussianRouletteTiming.turn.inMilliseconds;
                    final hurry =
                        picked == null &&
                        !intro &&
                        left != null &&
                        left <= 5000;
                    return _ActionPanel(
                      autoPicked: widget.autoSelected,
                      shieldLocked: me.shieldLocked,
                      onChoose: widget.busy ? null : widget.onChoose,
                      picked: picked,
                      confirmed: widget.submitted,
                      introLocked: intro,
                      // 시작 연출 중에는 버튼만 잠그고 따로 안내 문구는 띄우지 않습니다.
                      hint: hurry
                          ? rouletteText(
                              "시간이 끝나면 '아무것도 안 하기'로 정해져요",
                              "Time out picks 'Do nothing'",
                              "超时将自动选择“什么都不做”",
                              "逾時將自動選擇「什麼都不做」",
                            )
                          : null,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 대기 표시입니다. 마감되면 같은 자리에서 제목·안내가 바뀌고 도장이 찍힙니다.
class _WaitingMiddle extends StatelessWidget {
  const _WaitingMiddle({
    required this.total,
    required this.ready,
    this.locked = false,
    this.myPick,
  });
  final int total;
  final int ready;
  final bool locked;
  final RouletteAction? myPick;

  @override
  Widget build(BuildContext context) => Padding(
    // 버튼이 빠진 자리만큼 가운데보다 조금 위에 놓습니다.
    padding: const EdgeInsets.only(bottom: 120),
    child: Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 330,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: locked ? 1 : 0),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(opacity: 1 - v, child: const _BouncingDots()),
                const SizedBox(height: 18),
                SizedBox(
                  height: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 1 - v,
                        child: Text(
                          rouletteText(
                            '다른 사람들의\n선택을 기다리는 중',
                            'Waiting for the\nothers to choose',
                            '正在等待\n其他人选择',
                            '正在等待\n其他人選擇',
                          ),
                          textAlign: TextAlign.center,
                          style: RouletteType.display(
                            28,
                            RouletteColors.cream,
                            height: 1.3,
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - v)),
                          child: Text(
                            rouletteText(
                              '모두 골랐어요',
                              'Everyone has chosen',
                              '所有人都选好了',
                              '所有人都選好了',
                            ),
                            textAlign: TextAlign.center,
                            style: RouletteType.display(
                              30,
                              RouletteColors.cream,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (var i = 0; i < total; i++)
                          _AnonSlot(ready: i < ready),
                      ],
                    ),
                    if (locked) const _Slam(child: _LockBadge()),
                  ],
                ),
                const SizedBox(height: 26),
                SizedBox(
                  height: 20,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 1 - v,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            rouletteText(
                              '누가 골랐는지는 공개되지 않아요',
                              'Who has chosen stays hidden',
                              '不会公开谁已经选择',
                              '不會公開誰已經選擇',
                            ),
                            maxLines: 1,
                            softWrap: false,
                            style: RouletteType.body(13, RouletteColors.sub),
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: v,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            rouletteText(
                              '총구 대상부터 한 명씩 공개해요',
                              'Revealing from the target, one by one',
                              '从枪口对象开始逐一公开',
                              '從槍口對象開始逐一公開',
                            ),
                            maxLines: 1,
                            softWrap: false,
                            style: RouletteType.body(13, RouletteColors.sub),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (myPick != null) ...[
                  const SizedBox(height: 18),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rouletteText('내 선택', 'My choice', '我的选择', '我的選擇'),
                        style: RouletteType.body(
                          13,
                          RouletteColors.sub,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      RouletteActionChip(action: myPick!, size: 15),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AnonSlot extends StatelessWidget {
  const _AnonSlot({required this.ready});
  final bool ready;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: RussianRouletteTiming.plateFade,
    curve: Curves.easeOutBack,
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: ready ? RouletteColors.cream : Colors.transparent,
      border: Border.all(
        color: ready ? RouletteColors.cream : RouletteColors.dash,
        width: ready ? 3 : 2,
      ),
    ),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: Alignment.bottomCenter,
          child: Icon(
            Icons.person,
            size: 44,
            color: ready ? RouletteColors.ink : RouletteColors.line,
          ),
        ),
        if (ready)
          Positioned(
            right: -5,
            bottom: -5,
            child: Container(
              width: 20,
              height: 20,
              color: RouletteColors.red,
              child: const Icon(
                Icons.check,
                size: 13,
                color: RouletteColors.cream,
              ),
            ),
          ),
      ],
    ),
  );
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var k = 0; k < 3; k++)
          Builder(
            builder: (context) {
              final phase = (_controller.value - k * .17) % 1;
              final wave = math.sin(phase * math.pi * 2).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Transform.translate(
                  offset: Offset(0, -6 * wave),
                  child: Opacity(
                    opacity: .2 + .8 * wave,
                    child: Container(
                      width: 12,
                      height: 12,
                      color: k < 2 ? RouletteColors.cream : RouletteColors.red,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    ),
  );
}

/// 공개·회전·발포 단계(내가 맞은 결과가 아닐 때)입니다.
class _RevealBody extends StatelessWidget {
  const _RevealBody({
    required this.game,
    required this.me,
    required this.meUid,
    required this.elapsed,
    this.autoSelected = false,
  });
  final RussianRouletteView game;
  final RoulettePlayerView me;
  final String meUid;
  final int elapsed;

  /// 시간 초과로 내 선택이 자동으로 정해졌으면 공개 목록 위에 알려 줍니다.
  final bool autoSelected;

  @override
  Widget build(BuildContext context) {
    final order = _revealOrder(game);
    final revealing = game.phase == 'revealing';
    final shown = revealing
        ? RussianRouletteTiming.revealedCount(
            Duration(milliseconds: elapsed),
            order.length,
          )
        : order.length;
    final summary =
        revealing &&
        RussianRouletteTiming.showsSpinSummary(
          Duration(milliseconds: elapsed),
          order.length,
        );
    final originalTarget = revealing
        ? game.targetUid
        : (order.isEmpty ? null : order.first.uid);
    // 선택 마감 도장(공개 직전)은 고르기 화면 안에서 보여 줍니다. 머리줄은
    // 화면 위에 고정돼 있어 여기서는 목록만 그립니다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              if (revealing && autoSelected) ...[
                const _AutoChoiceCard(),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (var i = 0; i < order.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        // 집계 때는 돌리기만 밝게 남깁니다.
                        child: AnimatedOpacity(
                          duration: RussianRouletteTiming.plateFade,
                          opacity:
                              summary &&
                                  game.actions[order[i].uid] !=
                                      RouletteAction.spin
                              ? .35
                              : 1,
                          child: _ActionRow(
                            player: order[i],
                            action: i < shown
                                ? game.actions[order[i].uid]
                                : null,
                            mine: order[i].uid == meUid,
                            target: order[i].uid == originalTarget,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: RussianRouletteTiming.stageFade,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .3),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: summary
                    ? _SpinTally(
                        key: const ValueKey('tally'),
                        spins: game.spinCount,
                      )
                    : const SizedBox(
                        key: ValueKey('no-tally'),
                        width: double.infinity,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 붉은 '선택 마감' 도장입니다.
/// 시간 초과로 정해진 내 선택을 크게 알려 주는 카드입니다.
class _AutoChoiceCard extends StatelessWidget {
  const _AutoChoiceCard();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutBack,
    builder: (context, v, child) => Opacity(
      opacity: v.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
    ),
    child: Semantics(
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          color: RouletteColors.ink,
          border: Border.all(color: RouletteColors.cream, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: RouletteColors.red,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: RouletteColors.cream,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rouletteText(
                        '시간 초과로 자동 선택됐어요',
                        'Time ran out, so this was picked for you',
                        '超时，已为你自动选择',
                        '逾時，已為你自動選擇',
                      ),
                      style: RouletteType.body(
                        13,
                        RouletteColors.cream,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.remove_circle_outline,
                    color: RouletteColors.cream,
                    size: 34,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rouletteText('내 선택', 'My choice', '我的选择', '我的選擇'),
                          style: RouletteType.body(
                            13,
                            RouletteColors.sub,
                            weight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          rouletteText(
                            '아무것도 안 하기',
                            'Do nothing',
                            '什么都不做',
                            '什麼都不做',
                          ),
                          style: RouletteType.display(
                            24,
                            RouletteColors.cream,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          rouletteText(
                            '총구 그대로 · 방어 없음',
                            'Gun stays · no defense',
                            '枪口不动 · 无防御',
                            '槍口不動 · 無防禦',
                          ),
                          style: RouletteType.body(
                            12,
                            RouletteColors.sub,
                            weight: FontWeight.w700,
                          ),
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
  );
}

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -8 * math.pi / 180,
    child: Container(
      width: 250,
      height: 88,
      decoration: BoxDecoration(
        color: RouletteColors.red,
        border: Border.all(color: RouletteColors.cream, width: 4),
        boxShadow: const [
          BoxShadow(color: Color(0xBF000000), offset: Offset(10, 10)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, color: RouletteColors.cream, size: 34),
          const SizedBox(width: 12),
          Text(
            rouletteText('선택 마감', 'LOCKED', '选择截止', '選擇截止'),
            style: RouletteType.display(40, RouletteColors.cream, height: 1),
          ),
        ],
      ),
    ),
  );
}

/// 돌리기 집계: 붉은 칸에 큰 숫자, '돌리기 N명', 1 → 2 → 3 칸 표시.
class _SpinTally extends StatelessWidget {
  const _SpinTally({super.key, required this.spins});
  final int spins;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12, right: 10, bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    decoration: BoxDecoration(
      color: RouletteColors.red,
      border: Border.all(color: RouletteColors.cream, width: 4),
      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(10, 10))],
    ),
    child: Row(
      children: [
        Text('$spins', style: RouletteType.number(96, RouletteColors.cream)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.rotate_right,
                    color: RouletteColors.cream,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      rouletteText(
                        '돌리기 $spins명',
                        '$spins spins',
                        '转动 $spins人',
                        '轉動 $spins人',
                      ),
                      style: RouletteType.display(28, RouletteColors.cream),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (spins > 0)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (var i = 1; i <= spins; i++) ...[
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        color: RouletteColors.cream,
                        child: Text(
                          '$i',
                          style: RouletteType.number(15, RouletteColors.ink),
                        ),
                      ),
                      if (i < spins)
                        const Icon(
                          Icons.arrow_forward,
                          color: RouletteColors.cream,
                          size: 14,
                        ),
                    ],
                  ],
                ),
              const SizedBox(height: 8),
              MosiBalancedText(
                spins == 0
                    ? rouletteText(
                        '총구는 움직이지 않아요',
                        'The gun stays put',
                        '枪口不会移动',
                        '槍口不會移動',
                      )
                    : rouletteText(
                        '총구가 시계 방향으로 $spins칸 움직여요',
                        'The gun moves $spins seats clockwise',
                        '枪口将顺时针移动$spins格',
                        '槍口將順時針移動$spins格',
                      ),
                maxLines: 2,
                style: RouletteType.body(13, RouletteColors.cream),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

//=======================회전: 휴대폰용 작은 판==============================
/// 태블릿 판을 줄인 회전 화면입니다. 생존자 프로필이 둘레에 놓이고, 가운데
/// 크림 원판의 총과 붉은 빔이 지금 사람을 가리키며 지나온 길은 점선으로 남습니다.
class _RotationBody extends StatelessWidget {
  const _RotationBody({
    required this.game,
    required this.me,
    required this.elapsed,
  });

  final RussianRouletteView game;
  final RoulettePlayerView me;
  final int elapsed;

  static const _w = 342.0;
  static const _h = 420.0;
  static const _rx = 128.0;
  static const _ry = 160.0;
  static const _c = Offset(_w / 2, 200);

  static double _theta(int index, int count) =>
      RouletteStageGeometry.seatAngle(index, count);

  static Offset _seat(double theta) =>
      _c + Offset(_rx * math.cos(theta), _ry * math.sin(theta));

  static double _aim(double theta) =>
      math.atan2(_ry * math.sin(theta), _rx * math.cos(theta));

  @override
  Widget build(BuildContext context) {
    final players = game.orderedPlayers;
    final count = players.length;
    final alive = players.where((p) => p.alive).toList();
    final n = alive.length;
    final finalIndex = alive.indexWhere((p) => p.uid == game.targetUid);
    final startIndex = n == 0 ? 0 : ((finalIndex - game.spinCount) % n + n) % n;
    final done = RussianRouletteTiming.completedRotationSteps(
      Duration(milliseconds: elapsed),
      game.spinCount,
    );
    final seatIndex = {for (var i = 0; i < count; i++) players[i].uid: i};
    double aimOf(String uid) => _aim(_theta(seatIndex[uid] ?? 0, count));
    // 시계 방향으로 이어지는 각도 목록(0번은 출발 자리).
    final marks = <double>[];
    if (n > 0) {
      marks.add(aimOf(alive[startIndex].uid));
      for (var j = 1; j <= game.spinCount; j++) {
        var next = RouletteStageGeometry.clockwiseFrom(
          marks.last,
          aimOf(alive[(startIndex + j) % n].uid),
        );
        if (next <= marks.last + 1e-6) next += math.pi * 2;
        marks.add(next);
      }
    }
    final current = n == 0 ? null : alive[(startIndex + done) % n];
    final gunAngle = marks.isEmpty
        ? math.pi / 2
        : marks[done.clamp(0, marks.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: _w,
                height: _h + 60,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: gunAngle),
                  duration: RussianRouletteTiming.gunTurn,
                  curve: RussianRouletteTiming.gunTurnCurve,
                  builder: (context, angle, _) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        width: _w,
                        height: _h,
                        child: CustomPaint(
                          painter: _MiniTablePainter(gunAngle: angle),
                        ),
                      ),
                      for (final p in players)
                        _tile(
                          p,
                          _seat(_theta(seatIndex[p.uid]!, count)),
                          current: p.uid == current?.uid,
                          mine: p.uid == me.uid,
                        ),
                      if (current != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: _h + 14,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                rouletteText(
                                  '지금 총구',
                                  'Now aiming',
                                  '当前枪口',
                                  '目前槍口',
                                ),
                                style: RouletteType.display(
                                  18,
                                  RouletteColors.sub,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward,
                                color: RouletteColors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(2),
                                color: RouletteColors.red,
                                child: RouletteProfile(
                                  characterId: current.characterId,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  current.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RouletteType.display(
                                    24,
                                    RouletteColors.cream,
                                  ),
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
          ),
        ),
      ],
    );
  }

  Widget _tile(
    RoulettePlayerView p,
    Offset c, {
    required bool current,
    required bool mine,
  }) {
    if (!p.alive) {
      return Positioned(
        left: c.dx - 26,
        top: c.dy - 26,
        width: 52,
        height: 52,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(color: RouletteColors.dash),
          ),
          child: RouletteProfile(
            characterId: p.characterId,
            size: 44,
            gray: true,
          ),
        ),
      );
    }
    return Positioned(
      left: c.dx - 28,
      top: c.dy - 28,
      width: 56,
      height: 56,
      child: AnimatedContainer(
        duration: RussianRouletteTiming.plateFade,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: current
              ? RouletteColors.red
              : (mine ? RouletteColors.cream : RouletteColors.line),
          boxShadow: current
              ? const [BoxShadow(color: Colors.black, offset: Offset(6, 6))]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            RouletteProfile(characterId: p.characterId, size: 48),
            if (current)
              Positioned(
                left: -8,
                right: -8,
                top: -30,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: RouletteColors.red,
                      border: Border.all(color: RouletteColors.cream, width: 2),
                    ),
                    child: Text(
                      rouletteText('조준', 'AIM', '瞄准', '瞄準'),
                      style: RouletteType.display(13, RouletteColors.cream),
                    ),
                  ),
                ),
              ),
            if (mine)
              const Positioned(right: -14, bottom: -14, child: _MeTag()),
          ],
        ),
      ),
    );
  }
}

class _MiniTablePainter extends CustomPainter {
  const _MiniTablePainter({required this.gunAngle});
  final double gunAngle;

  @override
  void paint(Canvas canvas, Size size) {
    const c = _RotationBody._c;
    const half = 11 * math.pi / 180;
    const length = 600.0;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(
          c.dx + math.cos(gunAngle - half) * length,
          c.dy + math.sin(gunAngle - half) * length,
        )
        ..lineTo(
          c.dx + math.cos(gunAngle + half) * length,
          c.dy + math.sin(gunAngle + half) * length,
        )
        ..close(),
      Paint()..color = RouletteColors.red,
    );
    canvas.drawCircle(
      c,
      62,
      Paint()
        ..color = RouletteColors.track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    canvas.drawCircle(c, 56, Paint()..color = RouletteColors.cream);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(gunAngle);
    paintRouletteGun(canvas, scale: .235);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MiniTablePainter old) =>
      old.gunAngle != gunAngle;
}

//=======================발포 직전==============================
/// 발포 직전 화면입니다(시안 B-P13·P14·P16·P17).
///
/// 총구가 나를 겨누면 1인칭으로 총구를 마주 봅니다. 내 선택에 따라 그림이
/// 다릅니다. 방패면 방패 뒤에서, 돌리기면 실린더가 도는 총구를 정면으로,
/// 아무것도 안 하기면 같은 총구를 실린더 없이 봅니다.
/// 다른 사람이 대상이면 옆으로 돌아간 총이 그 사람을 겨누는 장면을 보고,
/// 내가 방패를 골랐다면 화면 아래에 내 방패가 보입니다.
class _FiringBody extends StatelessWidget {
  const _FiringBody({
    required this.game,
    required this.me,
    required this.elapsed,
  });

  final RussianRouletteView game;
  final RoulettePlayerView me;
  final int elapsed;

  static const _stage = Size(342, 400);

  @override
  Widget build(BuildContext context) {
    final target = game.players[game.targetUid];
    final aimedAtMe = target?.uid == me.uid;
    final mine = game.actions[me.uid];
    final t = elapsed.toDouble();

    final Widget stage;
    if (aimedAtMe) {
      final kind = switch (mine) {
        RouletteAction.shield => _PovKind.shield,
        RouletteAction.spin => _PovKind.spin,
        _ => _PovKind.bare,
      };
      stage = CustomPaint(
        size: _stage,
        painter: _PovPainter(kind: kind, t: t),
      );
    } else {
      final tremble = Offset(
        math.sin(elapsed * .09) * 1.2,
        math.cos(elapsed * .11) * 1.2,
      );
      stage = ClipRect(
        child: SizedBox.fromSize(
          size: _stage,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _SideAimPainter(t: t)),
              ),
              Positioned(
                left: _SideAimPainter.target.dx - 56,
                top: _SideAimPainter.target.dy - 56,
                child: Transform.translate(
                  offset: tremble,
                  child: _AimedProfile(player: target),
                ),
              ),
              if (mine == RouletteAction.shield)
                Positioned.fill(
                  child: CustomPaint(painter: _HeldShieldPainter(t: t)),
                ),
            ],
          ),
        ),
      );
    }

    final name = target?.nickname ?? '';
    final title = aimedAtMe
        ? rouletteText(
            '총구가 당신을\n겨누고 있습니다',
            'The gun is\naimed at you',
            '枪口\n正对着你',
            '槍口\n正對著你',
          )
        : rouletteText(
            '총구가 $name${_objectParticle(name)}\n겨누고 있어요',
            'The gun is\naimed at $name',
            '枪口\n正对着$name',
            '槍口\n正對著$name',
          );
    final sub = !aimedAtMe
        ? null
        : switch (mine) {
            RouletteAction.shield => rouletteText(
              '방패를 들었어요 · 맞아도 살아남아요',
              'Shield up · you survive a hit',
              '举起了护盾 · 中弹也能存活',
              '舉起了護盾 · 中彈也能存活',
            ),
            RouletteAction.spin => rouletteText(
              '돌리기를 골라 막을 수 없어요',
              'You spun, so you cannot block',
              '选择了转动，无法防御',
              '選擇了轉動，無法防禦',
            ),
            _ => rouletteText('곧 발포해요', 'Firing soon', '即将开枪', '即將開槍'),
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Flexible(
          flex: 8,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox.fromSize(size: _stage, child: stage),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: RouletteType.display(34, RouletteColors.cream, height: 1.2),
        ),
        if (sub != null) ...[
          const SizedBox(height: 8),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: RouletteType.body(
              15,
              RouletteColors.cream.withValues(alpha: .85),
            ),
          ),
        ],
        if (mine != null) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                rouletteText('내 선택', 'My choice', '我的选择', '我的選擇'),
                style: RouletteType.body(
                  13,
                  aimedAtMe
                      ? RouletteColors.cream.withValues(alpha: .8)
                      : RouletteColors.sub,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              // 붉은 배경 위 붉은 돌리기 칩은 크림 테두리로 구분합니다.
              if (aimedAtMe && mine == RouletteAction.spin)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: RouletteColors.cream, width: 2),
                  ),
                  child: RouletteActionChip(action: mine, size: 15),
                )
              else
                RouletteActionChip(action: mine, size: 16),
            ],
          ),
        ],
        const Spacer(),
      ],
    );
  }
}

/// 다른 사람이 겨눠질 때 그 사람 프로필(붉은 테두리 + '조준' 표시)입니다.
class _AimedProfile extends StatelessWidget {
  const _AimedProfile({required this.player});
  final RoulettePlayerView? player;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    height: 112,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: RouletteColors.red,
            boxShadow: [
              BoxShadow(color: Color(0x99000000), offset: Offset(8, 8)),
            ],
          ),
          child: RouletteProfile(characterId: player?.characterId, size: 100),
        ),
        Positioned(
          left: 20,
          top: -26,
          width: 72,
          height: 26,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: RouletteColors.red,
              border: Border.all(color: RouletteColors.cream, width: 2),
            ),
            child: Text(
              rouletteText('조준', 'AIM', '瞄准', '瞄準'),
              style: RouletteType.display(15, RouletteColors.cream, height: 1),
            ),
          ),
        ),
      ],
    ),
  );
}

enum _PovKind { spin, shield, bare }

/// 0 → 1 → 0으로 숨 쉬듯 오가는 값입니다.
double _pulse(double t, double periodMs) =>
    0.5 - 0.5 * math.cos(t / periodMs * math.pi * 2);

void _paintRays(
  Canvas canvas,
  Offset c, {
  required int count,
  required double r0,
  required double r1,
  required double widthDeg,
  required Color color,
}) {
  final paint = Paint()..color = color;
  for (var k = 0; k < count; k++) {
    final a = k * math.pi * 2 / count;
    final b = a + widthDeg / 2 * math.pi / 180;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + r0 * math.cos(a), c.dy + r0 * math.sin(a))
        ..lineTo(c.dx + r1 * math.cos(a), c.dy + r1 * math.sin(a))
        ..lineTo(c.dx + r1 * math.cos(b), c.dy + r1 * math.sin(b))
        ..lineTo(c.dx + r0 * math.cos(b), c.dy + r0 * math.sin(b))
        ..close(),
      paint,
    );
  }
}

Paint _fill(Color c) => Paint()..color = c;
Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

/// 정면에서 본 리볼버(총열 끝 구멍 + 뒤쪽 실린더 면)를 그립니다.
/// [r]은 총열 바깥 반지름, [spin]은 실린더 회전각(라디안, null이면 정지).
void _paintMuzzle(
  Canvas canvas,
  Offset c,
  double r, {
  required double glow,
  double? spin,
  bool arrows = false,
}) {
  final cylR = r * 1.85;
  final cyl = Offset(c.dx, c.dy + r * 1.55);
  canvas.drawCircle(
    cyl + const Offset(8, 8),
    cylR,
    _fill(const Color(0x8C000000)),
  );
  canvas.drawCircle(cyl, cylR, _fill(RouletteColors.ink));
  canvas.drawCircle(cyl, cylR, _stroke(RouletteColors.cream, 4));
  canvas.save();
  canvas.translate(cyl.dx, cyl.dy);
  canvas.rotate(spin ?? 0);
  for (var k = 0; k < 6; k++) {
    final a = (90 + k * 60) * math.pi / 180;
    final h = Offset(cylR * .62 * math.cos(a), cylR * .62 * math.sin(a));
    canvas.drawCircle(h, cylR * .2, _fill(RouletteColors.track));
    canvas.drawCircle(h, cylR * .2, _stroke(RouletteColors.cream, 3));
    canvas.drawCircle(h, cylR * .1, _fill(RouletteColors.ink));
  }
  canvas.drawCircle(Offset.zero, cylR * .13, _fill(RouletteColors.cream));
  canvas.restore();
  if (arrows) {
    // 돌린 실린더: 바깥쪽 회전 흔적 두 줄과 화살촉
    final rect = Rect.fromCircle(center: cyl, radius: cylR + 18);
    final arc = _stroke(RouletteColors.cream, 5);
    canvas.drawArc(rect, 190 * math.pi / 180, 60 * math.pi / 180, false, arc);
    canvas.drawArc(rect, 10 * math.pi / 180, 60 * math.pi / 180, false, arc);
    for (final end in [250.0, 70.0]) {
      final a = end * math.pi / 180;
      final p =
          cyl + Offset((cylR + 18) * math.cos(a), (cylR + 18) * math.sin(a));
      final dir = Offset(-math.sin(a), math.cos(a)); // 시계 방향 접선
      final n = Offset(math.cos(a), math.sin(a));
      canvas.drawPath(
        Path()
          ..moveTo(p.dx + dir.dx * 12, p.dy + dir.dy * 12)
          ..lineTo(p.dx + n.dx * 9, p.dy + n.dy * 9)
          ..lineTo(p.dx - n.dx * 9, p.dy - n.dy * 9)
          ..close(),
        _fill(RouletteColors.cream),
      );
    }
  }
  // 총열을 감싸는 몸체와 가늠쇠
  final body = RRect.fromRectAndRadius(
    Rect.fromLTWH(c.dx - r * 1.25, c.dy - r * 1.25, r * 2.5, r * 2.9),
    Radius.circular(r * .5),
  );
  canvas.drawRRect(
    body.shift(const Offset(8, 8)),
    _fill(const Color(0x8C000000)),
  );
  canvas.drawRRect(body, _fill(RouletteColors.ink));
  canvas.drawRRect(body, _stroke(RouletteColors.cream, 4));
  final sight = Rect.fromLTWH(
    c.dx - r * .16,
    c.dy - r * 1.62,
    r * .32,
    r * .42,
  );
  canvas.drawRect(sight, _fill(RouletteColors.ink));
  canvas.drawRect(sight, _stroke(RouletteColors.cream, 3));
  // 총구 구멍: 크림 테두리, 강선 무늬, 붉게 깜빡이는 속
  canvas.drawCircle(c, r, _fill(RouletteColors.cream));
  canvas.drawCircle(c, r * .78, _fill(RouletteColors.ink));
  final rifling = _stroke(RouletteColors.line, r * .12)
    ..strokeCap = StrokeCap.butt;
  final ring = Rect.fromCircle(center: c, radius: r * .78);
  for (var k = 0; k < 10; k++) {
    canvas.drawArc(ring, k * math.pi / 5, math.pi / 5 * .53, false, rifling);
  }
  canvas.drawCircle(c, r * .5, _fill(Colors.black));
  canvas.drawCircle(
    c,
    r * .5,
    _fill(RouletteColors.red.withValues(alpha: .35 + .45 * glow)),
  );
  canvas.drawCircle(c, r * .3, _fill(Colors.black));
}

/// 총구가 나를 겨눌 때의 1인칭 장면입니다(342×400 기준).
class _PovPainter extends CustomPainter {
  const _PovPainter({required this.kind, required this.t});
  final _PovKind kind;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const rays = Color(0x2E121110);
    final glow = _pulse(t, 1400);
    if (kind == _PovKind.shield) {
      _paintRays(
        canvas,
        const Offset(171, 100),
        count: 16,
        r0: 70,
        r1: 360,
        widthDeg: 9,
        color: rays,
      );
      _breathe(canvas, const Offset(171, 96), 1400, () {
        _paintMuzzle(canvas, const Offset(171, 96), 34, glow: glow);
      });
      _paintShieldBack(canvas);
      return;
    }
    final spin = kind == _PovKind.spin;
    _paintRays(
      canvas,
      const Offset(171, 130),
      count: 20,
      r0: 90,
      r1: 420,
      widthDeg: 8,
      color: rays,
    );
    _breathe(canvas, const Offset(171, 130), 1200, () {
      _paintMuzzle(
        canvas,
        const Offset(171, 112),
        52,
        glow: glow,
        spin: spin ? t / 1600 * math.pi * 2 : null,
        arrows: spin,
      );
    });
  }

  void _breathe(Canvas canvas, Offset c, double period, VoidCallback draw) {
    final s = 1 + .035 * _pulse(t, period);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(s);
    canvas.translate(-c.dx, -c.dy);
    draw();
    canvas.restore();
  }

  /// 방패 안쪽(손잡이 쪽)을 내 눈앞에서 봅니다.
  void _paintShieldBack(Canvas canvas) {
    canvas.save();
    canvas.translate(math.sin(t * .018) * 1.5, math.cos(t * .021) * 1.0);
    final outer = Path()
      ..moveTo(18, 196)
      ..quadraticBezierTo(171, 150, 324, 196)
      ..lineTo(324, 300)
      ..quadraticBezierTo(324, 372, 171, 400)
      ..quadraticBezierTo(18, 372, 18, 300)
      ..close();
    canvas.drawPath(
      outer.shift(const Offset(8, 8)),
      _fill(const Color(0x8C000000)),
    );
    canvas.drawPath(outer, _fill(RouletteColors.cream));
    canvas.drawPath(outer, _stroke(RouletteColors.ink, 6));
    final inner = Path()
      ..moveTo(40, 210)
      ..quadraticBezierTo(171, 172, 302, 210)
      ..lineTo(302, 296)
      ..quadraticBezierTo(302, 350, 171, 376)
      ..quadraticBezierTo(40, 350, 40, 296)
      ..close();
    canvas.drawPath(inner, _stroke(const Color(0xFFC9BFAA), 4));
    canvas.drawRRect(
      RRect.fromLTRBR(96, 252, 246, 286, const Radius.circular(6)),
      _fill(RouletteColors.ink),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(112, 258, 230, 280, const Radius.circular(11)),
      _fill(RouletteColors.track),
    );
    for (final x in [104.0, 238.0]) {
      canvas.drawCircle(Offset(x, 269), 7, _fill(RouletteColors.cream));
      canvas.drawCircle(Offset(x, 269), 7, _stroke(RouletteColors.ink, 3));
    }
    for (final p in const [
      Offset(48, 220),
      Offset(294, 220),
      Offset(58, 330),
      Offset(284, 330),
    ]) {
      canvas.drawCircle(p, 5, _fill(RouletteColors.ink));
    }
    canvas.drawRRect(
      RRect.fromLTRBR(150, 296, 192, 356, const Radius.circular(8)),
      _fill(RouletteColors.ink),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PovPainter old) =>
      old.kind != kind || old.t != t;
}

/// 다른 사람이 겨눠질 때: 빛줄기, 붉은 조준선, 옆에서 본 리볼버(342×400 기준).
class _SideAimPainter extends CustomPainter {
  const _SideAimPainter({required this.t});
  final double t;

  /// 총구 끝과 대상 프로필 가운데입니다.
  static const muzzle = Offset(172, 176);
  static const target = Offset(262, 256);

  @override
  void paint(Canvas canvas, Size size) {
    _paintRays(
      canvas,
      muzzle,
      count: 14,
      r0: 60,
      r1: 360,
      widthDeg: 7,
      color: const Color(0x2E2A2724),
    );
    final glow = _pulse(t, 1400);
    canvas.drawPath(
      Path()
        ..moveTo(muzzle.dx, muzzle.dy - 6)
        ..lineTo(target.dx, target.dy - 46)
        ..lineTo(target.dx, target.dy + 46)
        ..lineTo(muzzle.dx, muzzle.dy + 6)
        ..close(),
      _fill(RouletteColors.red.withValues(alpha: .5 + .4 * glow)),
    );
    final angle = math.atan2(target.dy - muzzle.dy, target.dx - muzzle.dx);
    canvas.save();
    canvas.translate(muzzle.dx, muzzle.dy);
    canvas.rotate(angle);
    canvas.scale(.8);
    canvas.translate(-200, -31); // 그림 안의 총구 끝(200, 31)
    canvas.save();
    canvas.translate(8, 8);
    _revolver(canvas, const Color(0x99000000), const Color(0x99000000));
    canvas.restore();
    _revolver(canvas, RouletteColors.cream, RouletteColors.ink);
    canvas.restore();
  }

  /// 총구가 오른쪽을 향한 리볼버 옆모습입니다(손잡이가 왼쪽 아래).
  void _revolver(Canvas canvas, Color fill, Color line) {
    void shape(Path p, double w) {
      canvas.drawPath(p, _fill(fill));
      canvas.drawPath(p, _stroke(line, w));
    }

    shape(Path()..addRect(const Rect.fromLTWH(96, 22, 104, 18)), 4);
    shape(Path()..addRect(const Rect.fromLTWH(188, 14, 8, 10)), 3);
    shape(Path()..addRect(const Rect.fromLTWH(100, 40, 74, 9)), 3);
    shape(
      Path()
        ..moveTo(40, 18)
        ..lineTo(100, 14)
        ..lineTo(100, 66)
        ..lineTo(52, 70)
        ..close(),
      4,
    );
    shape(
      Path()
        ..addRRect(RRect.fromLTRBR(60, 14, 112, 60, const Radius.circular(9))),
      4,
    );
    final flutes = _stroke(line, 3);
    for (final y in [26.0, 37.0, 48.0]) {
      canvas.drawLine(Offset(68, y), Offset(104, y), flutes);
    }
    shape(
      Path()
        ..moveTo(40, 20)
        ..lineTo(30, 4)
        ..lineTo(46, 6)
        ..lineTo(52, 18)
        ..close(),
      3,
    );
    canvas.drawPath(
      Path()
        ..moveTo(62, 66)
        ..quadraticBezierTo(64, 90, 86, 88)
        ..quadraticBezierTo(96, 86, 94, 66),
      _stroke(line, 4),
    );
    canvas.drawLine(
      const Offset(76, 66),
      const Offset(74, 80),
      _stroke(line, 4),
    );
    shape(
      Path()
        ..moveTo(42, 62)
        ..lineTo(70, 66)
        ..lineTo(58, 112)
        ..quadraticBezierTo(40, 118, 22, 110)
        ..close(),
      4,
    );
    canvas.drawLine(const Offset(36, 78), const Offset(56, 80), flutes);
    canvas.drawLine(const Offset(32, 92), const Offset(52, 94), flutes);
  }

  @override
  bool shouldRepaint(covariant _SideAimPainter old) => old.t != t;
}

/// 다른 사람이 겨눠질 때 화면 아래로 보이는 내 방패 윗부분입니다.
class _HeldShieldPainter extends CustomPainter {
  const _HeldShieldPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(math.sin(t * .012) * 1.5, math.cos(t * .014) * 1.0);
    final outer = Path()
      ..moveTo(30, 330)
      ..quadraticBezierTo(171, 296, 312, 330)
      ..lineTo(312, 430)
      ..lineTo(30, 430)
      ..close();
    canvas.drawPath(
      outer.shift(const Offset(8, 8)),
      _fill(const Color(0x8C000000)),
    );
    canvas.drawPath(outer, _fill(RouletteColors.cream));
    canvas.drawPath(outer, _stroke(RouletteColors.ink, 6));
    canvas.drawPath(
      Path()
        ..moveTo(50, 342)
        ..quadraticBezierTo(171, 314, 292, 342)
        ..lineTo(292, 430),
      _stroke(const Color(0xFFC9BFAA), 4),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(106, 362, 236, 392, const Radius.circular(6)),
      _fill(RouletteColors.ink),
    );
    for (final x in [114.0, 228.0]) {
      canvas.drawCircle(Offset(x, 377), 6, _fill(RouletteColors.cream));
      canvas.drawCircle(Offset(x, 377), 6, _stroke(RouletteColors.ink, 3));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeldShieldPainter old) => old.t != t;
}

/// 이름 끝 글자에 받침이 있으면 '을', 없으면 '를'을 붙입니다(한국어 안내 문구용).
String _objectParticle(String name) {
  if (name.isEmpty) return '를';
  final code = name.codeUnitAt(name.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return '를';
  return (code - 0xAC00) % 28 == 0 ? '를' : '을';
}

List<RoulettePlayerView> _revealOrder(RussianRouletteView game) {
  final players = game.orderedPlayers
      .where((p) => game.actions.containsKey(p.uid))
      .toList();
  if (game.phase != 'revealing') {
    // 회전 뒤에는 서버 대상이 바뀌므로, 공개 순서는 처음 대상 기준으로 다시 셉니다.
    final alive = [
      for (final p in game.orderedPlayers)
        if (game.actions.containsKey(p.uid)) p.uid,
    ];
    final finalIndex = alive.indexOf(game.targetUid ?? '');
    if (finalIndex >= 0 && alive.isNotEmpty) {
      final n = alive.length;
      final start = ((finalIndex - game.spinCount) % n + n) % n;
      return [...players.sublist(start), ...players.sublist(0, start)];
    }
    return players;
  }
  final start = players.indexWhere((p) => p.uid == game.targetUid);
  if (start <= 0) return players;
  return [...players.sublist(start), ...players.sublist(0, start)];
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.player,
    required this.action,
    required this.mine,
    required this.target,
  });
  final RoulettePlayerView player;
  final RouletteAction? action;
  final bool mine;
  final bool target;

  @override
  Widget build(BuildContext context) => Container(
    color: RouletteColors.panel,
    padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
    child: Row(
      children: [
        RouletteProfile(characterId: player.characterId, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  target ? rouletteText('총구 대상', 'Target', '枪口对象', '槍口對象') : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RouletteType.body(13, RouletteColors.sub),
                ),
              ),
              if (mine) ...[const SizedBox(width: 6), const _MeTag()],
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: RussianRouletteTiming.plateFade,
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: action == null
              ? Container(
                  key: const ValueKey('hidden'),
                  width: 44,
                  height: 32,
                  alignment: Alignment.center,
                  color: RouletteColors.ink,
                  child: Text(
                    '?',
                    style: RouletteType.display(20, RouletteColors.cream),
                  ),
                )
              : RouletteActionChip(key: ValueKey(action), action: action!),
        ),
      ],
    ),
  );
}

class _BlockedBody extends StatelessWidget {
  const _BlockedBody({required this.me, required this.turn});
  final RoulettePlayerView me;
  final String turn;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Spacer(),
      _Slam(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: RouletteColors.cream,
                boxShadow: [
                  BoxShadow(color: Colors.black, offset: Offset(10, 10)),
                ],
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: RouletteColors.red,
                size: 72,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              rouletteText('막아냄', 'Blocked', '挡住了', '擋住了'),
              style: RouletteType.display(72, RouletteColors.cream, height: 1),
            ),
            const SizedBox(height: 10),
            Text(
              rouletteText(
                '총구가 당신에게 멈췄지만\n방패로 막아냈습니다.',
                'The gun stopped on you,\nbut your shield held.',
                '枪口停在你身上，\n但护盾挡住了。',
                '槍口停在你身上，\n但護盾擋住了。',
              ),
              style: RouletteType.body(15, RouletteColors.cream, height: 1.55),
            ),
          ],
        ),
      ),
      const Spacer(),
      Container(
        color: RouletteColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(
              Icons.remove_moderator,
              color: RouletteColors.cream,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rouletteText(
                      '다음 턴에는 방패를 못 써요',
                      'No shield next turn',
                      '下回合不能用护盾',
                      '下回合不能用護盾',
                    ),
                    style: RouletteType.display(17, RouletteColors.cream),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rouletteText(
                      '돌리기나 아무것도 안 하기만 가능',
                      'Spin or do nothing only',
                      '只能转动或什么都不做',
                      '只能轉動或什麼都不做',
                    ),
                    style: RouletteType.body(13, RouletteColors.sub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _OutBody extends StatelessWidget {
  const _OutBody({required this.game, required this.me});
  final RussianRouletteView game;
  final RoulettePlayerView me;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Spacer(),
      // 시안처럼 프로필은 그대로 두고 붉은 X를 0.14초 뒤부터 0.42초 동안 긋습니다.
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 560),
        builder: (context, t, child) => Container(
          padding: const EdgeInsets.all(6),
          color: RouletteColors.red,
          child: RouletteProfile(
            characterId: me.characterId,
            size: 196,
            gray: true,
            crossed: true,
            crossProgress: ((t * 560 - 140) / 420).clamp(0.0, 1.0),
            background: RouletteColors.ink,
          ),
        ),
      ),
      const SizedBox(height: 10),
      _Slam(
        child: Text(
          rouletteText('탈락', 'OUT', '淘汰', '淘汰'),
          style: RouletteType.display(84, RouletteColors.red, height: 1),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        rouletteText(
          '총구가 당신에게 멈췄습니다.\n최종 ${me.rank ?? '-'}위',
          'The gun stopped on you.\nFinal rank #${me.rank ?? '-'}',
          '枪口停在了你身上。\n最终第${me.rank ?? '-'}名',
          '槍口停在了你身上。\n最終第${me.rank ?? '-'}名',
        ),
        textAlign: TextAlign.center,
        style: RouletteType.body(15, RouletteColors.sub, height: 1.55),
      ),
      const Spacer(),
    ],
  );
}

class _SpectateBody extends StatelessWidget {
  const _SpectateBody({
    required this.game,
    required this.me,
    required this.meUid,
    required this.elapsed,
  });
  final RussianRouletteView game;
  final RoulettePlayerView? me;
  final String meUid;
  final int elapsed;

  @override
  Widget build(BuildContext context) {
    final selecting = game.phase == 'selecting';
    final phaseName = switch (game.phase) {
      'selecting' => rouletteText('선택 중', 'Choosing', '选择中', '選擇中'),
      'revealing' => rouletteText('공개', 'Reveal', '公开', '公開'),
      'rotating' => rouletteText('회전', 'Spin', '转动', '轉動'),
      _ => rouletteText('발포', 'Fire', '开枪', '開槍'),
    };
    final alive = game.orderedPlayers.where((p) => p.alive).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          '${rouletteText('${game.round}턴', 'Turn ${game.round}', '第${game.round}回合', '第${game.round}回合')} · $phaseName',
          style: RouletteType.display(26, RouletteColors.cream),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final p in alive)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    color: RouletteColors.panel,
                    padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                    child: Row(
                      children: [
                        RouletteProfile(characterId: p.characterId, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selecting
                                ? (p.shieldLocked
                                      ? rouletteText(
                                          '방패 불가 · 선택 중',
                                          'No shield · choosing',
                                          '不能用护盾 · 选择中',
                                          '不能用護盾 · 選擇中',
                                        )
                                      : rouletteText(
                                          '선택 중',
                                          'Choosing',
                                          '选择中',
                                          '選擇中',
                                        ))
                                : '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RouletteType.body(14, RouletteColors.sub),
                          ),
                        ),
                        if (!selecting && game.actions[p.uid] != null)
                          RouletteActionChip(
                            action: game.actions[p.uid]!,
                            size: 14,
                          )
                        else if (p.uid == game.targetUid)
                          Container(
                            width: 10,
                            height: 10,
                            color: RouletteColors.red,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        MosiBalancedText(
          rouletteText(
            '선택 내용은 공개 전까지 관전자에게도 보이지 않아요',
            'Choices stay hidden from spectators until the reveal',
            '公开前观战者也看不到选择',
            '公開前觀戰者也看不到選擇',
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: RouletteType.body(13, RouletteColors.sub),
        ),
      ],
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.game, required this.meUid});
  final RussianRouletteView game;
  final String meUid;

  @override
  Widget build(BuildContext context) {
    final winner = game.players[game.winnerUid];
    final ranking = [
      for (final p in game.orderedPlayers)
        (p, p.uid == game.winnerUid ? 1 : p.rank),
    ]..sort((a, b) => (a.$2 ?? 99).compareTo(b.$2 ?? 99));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          rouletteText(
            '총 ${game.round}턴',
            '${game.round} TURNS',
            '共${game.round}回合',
            '共${game.round}回合',
          ),
          style: RouletteType.number(13, RouletteColors.sub, spacing: 3.6),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: RouletteColors.cream,
                boxShadow: [
                  BoxShadow(color: Colors.black, offset: Offset(8, 8)),
                ],
              ),
              child: winner == null
                  ? const SizedBox.square(
                      dimension: 100,
                      child: Icon(
                        Icons.sports_score,
                        color: RouletteColors.ink,
                        size: 60,
                      ),
                    )
                  : RouletteProfile(characterId: winner.characterId, size: 100),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                winner == null
                    ? rouletteText('게임\n종료', 'Game\nover', '游戏\n结束', '遊戲\n結束')
                    : rouletteText(
                        '최후의\n1인',
                        'Last one\nstanding',
                        '最后\n一人',
                        '最後\n一人',
                      ),
                style: RouletteType.display(
                  40,
                  RouletteColors.cream,
                  height: 1.05,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final entry in ranking)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    color: entry.$2 == 1
                        ? RouletteColors.red
                        : RouletteColors.panel,
                    padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
                    child: Row(
                      children: [
                        RouletteProfile(
                          characterId: entry.$1.characterId,
                          size: 38,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.$1.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RouletteType.body(
                              13,
                              entry.$2 == 1
                                  ? RouletteColors.cream
                                  : RouletteColors.sub,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (entry.$1.uid == meUid) ...[
                          const SizedBox(width: 6),
                          const _MeTag(),
                        ],
                        const SizedBox(width: 12),
                        SizedBox(
                          key: ValueKey('roulette-result-rank-${entry.$1.uid}'),
                          width: 58,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              entry.$2 == null
                                  ? '–'
                                  : rouletteText(
                                      '${entry.$2}위',
                                      '#${entry.$2}',
                                      '第${entry.$2}名',
                                      '第${entry.$2}名',
                                    ),
                              maxLines: 1,
                              softWrap: false,
                              textAlign: TextAlign.right,
                              style: RouletteType.display(
                                20,
                                RouletteColors.cream,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 시안의 결과 글자 등장(slam): 2.4배에서 0.92배로 내리꽂혔다가 제자리.
/// 발포 섬광이 걷힐 즈음(0.15초 뒤) 시작해 0.49초 걸립니다.
class _Slam extends StatelessWidget {
  const _Slam({required this.child, this.alignment = Alignment.center});
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 640),
    builder: (context, v, child) {
      final t = ((v * 640 - 150) / 490).clamp(0.0, 1.0);
      final scale = t < .57
          ? 2.4 + (.92 - 2.4) * (t / .57)
          : .92 + .08 * ((t - .57) / .43);
      return Opacity(
        opacity: (t / .57).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          alignment: alignment,
          child: child,
        ),
      );
    },
    child: child,
  );
}

/// 이름 끝 글자에 받침이 있으면 '은', 없으면 '는'을 붙입니다(한국어 안내 문구용).
String _topicParticle(String name) {
  if (name.isEmpty) return '는';
  final code = name.codeUnitAt(name.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return '는';
  return (code - 0xAC00) % 28 == 0 ? '는' : '은';
}
