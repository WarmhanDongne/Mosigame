import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/phone/animations/game_entry_unroll.dart';
import 'package:game_kit/phone/widgets/exit_modal.dart';
import 'package:game_kit/phone/widgets/ripple_dialog.dart';
import 'package:game_kit/phone/widgets/rulebook_dialog.dart';
import 'package:game_kit/recovery/widgets/game_recovery_layer.dart';
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
      _phaseStartedAt = _nowMs;
    }
    final elapsed = _nowMs - _phaseStartedAt;
    _animating = switch (game.phase) {
      'revealing' =>
        elapsed <
            RussianRouletteTiming.revealing(game.aliveCount).inMilliseconds,
      'rotating' =>
        elapsed < RussianRouletteTiming.rotating(game.spinCount).inMilliseconds,
      'firing' => elapsed < RussianRouletteTiming.firingHold.inMilliseconds,
      'outcome' => elapsed < 600,
      _ => false,
    };
    return elapsed;
  }

  Future<void> _choose(RouletteAction action) async {
    await ref
        .read(russianRouletteSessionProvider(_args).notifier)
        .execute(
          () => _service.command.submitAction(widget.roomCode, action.name),
        );
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
    final elapsed = _elapsedMs(game);
    final screen = _screen(
      game,
      me,
      submitted,
      myAction,
      session.commandInFlight,
      elapsed,
    );

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
                    child: AnimatedSwitcher(
                      duration: RussianRouletteTiming.stageFade,
                      reverseDuration: const Duration(milliseconds: 380),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, .05),
                            end: Offset.zero,
                          ).animate(animation),
                          child: ScaleTransition(
                            scale: Tween(
                              begin: .97,
                              end: 1.0,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(screen.key),
                        child: screen.body,
                      ),
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

  _PhoneScreen _screen(
    RussianRouletteView game,
    RoulettePlayerView? me,
    bool submitted,
    RouletteAction? myAction,
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
    if (me == null || !me.alive) {
      if (me != null && game.phase == 'outcome' && game.eliminatedUid == _uid) {
        return _PhoneScreen(
          key: 'out-${game.round}',
          body: _OutBody(game: game, me: me),
          bandTop: null,
        );
      }
      return _PhoneScreen(
        key: 'spectate',
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
        body: _BlockedBody(me: me, turn: turn),
      );
    }
    if (game.phase == 'selecting') {
      // 고르기와 기다리기는 한 화면 안에서 가운데만 바뀌고 버튼은 서서히 어두워집니다.
      return _PhoneScreen(
        key: 'select-${game.round}',
        bandTop: 150,
        body: _ChooseBody(
          game: game,
          me: me,
          turn: turn,
          busy: busy || game.paused,
          onChoose: _choose,
          submitted: submitted,
          myAction: myAction,
        ),
      );
    }
    if (game.phase == 'rotating') {
      return _PhoneScreen(
        key: 'rotate-${game.round}',
        bandTop: 118,
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
        body: _FiringBody(game: game, me: me, elapsed: elapsed),
      );
    }
    return _PhoneScreen(
      key: 'reveal-${game.round}',
      bandTop: 118,
      body: _RevealBody(game: game, me: me, meUid: _uid, elapsed: elapsed),
    );
  }
}

class _PhoneScreen {
  const _PhoneScreen({
    required this.key,
    required this.body,
    this.background = RouletteColors.ink,
    this.bandColor = RouletteColors.red,
    this.bandTop,
    this.showIcons = true,
  });
  final String key;
  final Widget body;
  final Color background;
  final Color bandColor;
  final double? bandTop;
  final bool showIcons;
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
    required this.me,
    this.subline,
    this.subColor = RouletteColors.sub,
    this.right,
  });
  final RoulettePlayerView? me;
  final String? subline;
  final Color subColor;
  final Widget? right;

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
            if (subline != null) ...[
              const SizedBox(height: 4),
              Text(
                subline!,
                style: RouletteType.body(13, subColor, weight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
      ?right,
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
              Text(
                title,
                style: RouletteType.display(22, RouletteColors.cream),
              ),
              const SizedBox(height: 4),
              Text(
                description,
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

class _HalfButton extends StatelessWidget {
  const _HalfButton({
    required this.action,
    required this.mode,
    required this.onTap,
  });
  final RouletteAction action;
  final _ButtonMode mode;
  final VoidCallback? onTap;

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
            const Positioned(right: -6, top: -10, child: _PickedTag()),
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
      duration: RussianRouletteTiming.plateFade,
      curve: Curves.easeInOut,
      opacity: mode == _ButtonMode.dimmed ? .35 : 1,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: disabled
              ? null
              : const [BoxShadow(color: Colors.black, offset: Offset(6, 6))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(onTap: disabled ? null : onTap, child: content),
        ),
      ),
    );
  }
}

class _PickedTag extends StatelessWidget {
  const _PickedTag();

  @override
  Widget build(BuildContext context) => Container(
    color: RouletteColors.ink,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check, color: RouletteColors.cream, size: 14),
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
  );
}

class _NoneButton extends StatelessWidget {
  const _NoneButton({
    required this.mode,
    required this.onTap,
    this.autoTag = false,
  });
  final _ButtonMode mode;
  final VoidCallback? onTap;

  /// 방패가 잠긴 턴에만 '시간 끝나면 자동 선택' 표시를 붙입니다(시안 잠긴 턴).
  final bool autoTag;

  @override
  Widget build(BuildContext context) {
    final selected = mode == _ButtonMode.selected;
    return AnimatedOpacity(
      duration: RussianRouletteTiming.plateFade,
      curve: Curves.easeInOut,
      opacity: mode == _ButtonMode.dimmed ? .35 : 1,
      child: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black, offset: Offset(6, 6))],
        ),
        child: Material(
          color: RouletteColors.ink,
          child: InkWell(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: RouletteColors.cream,
                  width: selected ? 4 : 2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.remove_circle_outline,
                    color: RouletteColors.cream,
                    size: 30,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rouletteText(
                            '아무것도 안 하기',
                            'Do nothing',
                            '什么都不做',
                            '什麼都不做',
                          ),
                          style: RouletteType.display(21, RouletteColors.cream),
                        ),
                        const SizedBox(height: 2),
                        Text(
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
                          style: RouletteType.body(12, RouletteColors.sub),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (selected)
                    const _PickedTag()
                  else if (autoTag)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: RouletteColors.cream,
                          width: 1.5,
                        ),
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
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    super.key,
    required this.shieldLocked,
    required this.onChoose,
  });
  final bool shieldLocked;
  final void Function(RouletteAction)? onChoose;

  _ButtonMode _mode(RouletteAction action) {
    if (action == RouletteAction.shield && shieldLocked) {
      return _ButtonMode.disabled;
    }
    return _ButtonMode.normal;
  }

  VoidCallback? _tap(RouletteAction action) {
    final choose = onChoose;
    if (choose == null) return null;
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HalfButton(
                  action: RouletteAction.shield,
                  mode: _mode(RouletteAction.shield),
                  onTap: _tap(RouletteAction.shield),
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
        ),
      ],
    );
    if (onChoose != null) return body;
    return IgnorePointer(child: body);
  }
}

//=======================화면별 본문==============================
class _ChooseBody extends StatelessWidget {
  const _ChooseBody({
    required this.game,
    required this.me,
    required this.turn,
    required this.busy,
    required this.onChoose,
    this.submitted = false,
    this.myAction,
  });
  final bool submitted;
  final RouletteAction? myAction;
  final RussianRouletteView game;
  final RoulettePlayerView me;
  final String turn;
  final bool busy;
  final void Function(RouletteAction) onChoose;

  @override
  Widget build(BuildContext context) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MeHeader(
          me: me,
          subline: turn,
          right: _TimerBox(deadlineAt: game.deadlineAt),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: RussianRouletteTiming.stageFade,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: .96, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: submitted
                ? _WaitingMiddle(key: const ValueKey('wait'), game: game)
                : Column(
                    key: const ValueKey('choose'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [alert, const Spacer()],
                  ),
          ),
        ),
        // 고르고 나면 버튼은 '선택함'이 붙은 채 잠깐 어두워졌다가 아래로 내려가며 사라집니다.
        AnimatedSwitcher(
          duration: RussianRouletteTiming.stageFade,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: const Alignment(-1, -1),
            child: FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, .12),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
          ),
          child: submitted
              ? const SizedBox(
                  key: ValueKey('no-buttons'),
                  width: double.infinity,
                )
              : _ActionPanel(
                  key: const ValueKey('buttons'),
                  shieldLocked: me.shieldLocked,
                  onChoose: busy ? null : onChoose,
                ),
        ),
      ],
    );
  }
}

/// 내 선택을 마친 뒤 가운데에 보이는 대기 표시입니다. 몇 명이 골랐는지만 익명으로 보입니다.
class _WaitingMiddle extends StatelessWidget {
  const _WaitingMiddle({super.key, required this.game});
  final RussianRouletteView game;

  @override
  Widget build(BuildContext context) {
    final total = game.aliveCount;
    final ready = game.choiceCount.clamp(0, total);
    // 버튼이 빠진 자리만큼 가운데보다 조금 위에 놓습니다.
    return Padding(
      padding: const EdgeInsets.only(bottom: 120),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 330,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BouncingDots(),
                const SizedBox(height: 18),
                Text(
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
                const SizedBox(height: 22),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (var i = 0; i < total; i++) _AnonSlot(ready: i < ready),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  rouletteText(
                    '누가 골랐는지는 공개되지 않아요',
                    'Who has chosen stays hidden',
                    '不会公开谁已经选择',
                    '不會公開誰已經選擇',
                  ),
                  style: RouletteType.body(13, RouletteColors.sub),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
  });
  final RussianRouletteView game;
  final RoulettePlayerView me;
  final String meUid;
  final int elapsed;

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
    final locked = revealing && shown == 0;
    final subline = switch (game.phase) {
      'revealing' when locked => rouletteText(
        '${game.round}턴',
        'Turn ${game.round}',
        '第${game.round}回合',
        '第${game.round}回合',
      ),
      'revealing' when summary => rouletteText(
        '돌리기 집계',
        'Spin total',
        '转动统计',
        '轉動統計',
      ),
      'revealing' => rouletteText('공개', 'Reveal', '公开', '公開'),
      'rotating' => rouletteText('회전', 'Spin', '转动', '轉動'),
      _ => rouletteText('발포', 'Fire', '开枪', '開槍'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MeHeader(
          me: me,
          subline: subline,
          // 선택 마감: 시간이 다 된 타이머를 붉게 남깁니다(시안).
          right: locked
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  color: RouletteColors.red,
                  child: Text(
                    '00:00',
                    style: RouletteType.number(40, RouletteColors.cream),
                  ),
                )
              : null,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: RussianRouletteTiming.stageFade,
            child: locked
                ? _LockedStamp(
                    key: const ValueKey('choices-locked'),
                    total: order.length,
                  )
                : Column(
                    key: const ValueKey('reveal-list'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 30),
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
        ),
      ],
    );
  }
}

/// 선택 마감: 모두 찬 익명 칸 위에 붉은 '선택 마감' 도장을 찍습니다.
class _LockedStamp extends StatelessWidget {
  const _LockedStamp({super.key, required this.total});
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 140),
    child: Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (var i = 0; i < total; i++)
                          const _AnonSlot(ready: true),
                      ],
                    ),
                  ),
                  _Slam(
                    child: Transform.rotate(
                      angle: -8 * math.pi / 180,
                      child: Container(
                        width: 250,
                        height: 88,
                        decoration: BoxDecoration(
                          color: RouletteColors.red,
                          border: Border.all(
                            color: RouletteColors.cream,
                            width: 4,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xBF000000),
                              offset: Offset(10, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              color: RouletteColors.cream,
                              size: 34,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              rouletteText(
                                '선택 마감',
                                'LOCKED',
                                '选择截止',
                                '選擇截止',
                              ),
                              style: RouletteType.display(
                                40,
                                RouletteColors.cream,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                rouletteText(
                  '모두 골랐어요.\n총구 대상부터 한 명씩 공개해요.',
                  'Everyone has chosen.\nRevealing from the target, one by one.',
                  '所有人都选好了。\n从枪口对象开始逐一公开。',
                  '所有人都選好了。\n從槍口對象開始逐一公開。',
                ),
                textAlign: TextAlign.center,
                style: RouletteType.body(15, RouletteColors.sub, height: 1.6),
              ),
            ],
          ),
        ),
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
              Text(
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
    final gunAngle = marks.isEmpty ? math.pi / 2 : marks[done.clamp(0, marks.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MeHeader(
          me: me,
          subline: rouletteText('회전', 'Spin', '转动', '轉動'),
          right: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$done'),
                TextSpan(
                  text: ' / ${game.spinCount}',
                  style: RouletteType.number(34, RouletteColors.sub),
                ),
              ],
            ),
            style: RouletteType.number(34, RouletteColors.cream),
          ),
        ),
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
                  curve: Curves.easeOutBack,
                  builder: (context, angle, _) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        width: _w,
                        height: _h,
                        child: CustomPaint(
                          painter: _MiniTablePainter(
                            gunAngle: angle,
                            trail: marks.isEmpty
                                ? const []
                                : marks.sublist(0, done + 1),
                          ),
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
            if (mine) const Positioned(right: -14, bottom: -14, child: _MeTag()),
          ],
        ),
      ),
    );
  }
}

class _MiniTablePainter extends CustomPainter {
  const _MiniTablePainter({required this.gunAngle, required this.trail});
  final double gunAngle;
  final List<double> trail;

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
    if (trail.length > 1) {
      const rx = _RotationBody._rx - 58;
      const ry = _RotationBody._ry - 62;
      Offset along(double a) {
        final r =
            1 /
            math.sqrt(
              math.cos(a) * math.cos(a) / (rx * rx) +
                  math.sin(a) * math.sin(a) / (ry * ry),
            );
        return c + Offset(math.cos(a) * r, math.sin(a) * r);
      }

      final dot = Paint()..color = RouletteColors.red;
      for (var a = trail.first + .18; a <= trail.last - .1; a += .14) {
        canvas.drawCircle(along(a), 2.6, dot);
      }
      for (final mark in trail.skip(1)) {
        final p = along(mark);
        canvas.drawCircle(p, 6, Paint()..color = RouletteColors.ink);
        canvas.drawCircle(
          p,
          6,
          Paint()
            ..color = RouletteColors.red
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
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
      old.gunAngle != gunAngle || old.trail.length != trail.length;
}

//=======================발포 직전==============================
/// 위쪽 원판의 총이 아래를 겨누고, 숨 쉬듯 깜빡이는 빔이 대상의 큰 프로필로
/// 이어집니다. 내가 대상이면 붉은 바탕에 먹색 빔과 '총구가 당신을 겨누고 있습니다'.
class _FiringBody extends StatelessWidget {
  const _FiringBody({
    required this.game,
    required this.me,
    required this.elapsed,
  });

  final RussianRouletteView game;
  final RoulettePlayerView me;
  final int elapsed;

  @override
  Widget build(BuildContext context) {
    final target = game.players[game.targetUid];
    final aimedAtMe = target?.uid == me.uid;
    final breathe = .55 + .45 * (0.5 - 0.5 * math.cos(elapsed / 1400 * math.pi * 2));
    final tremble = Offset(
      math.sin(elapsed * .09) * 1.2,
      math.cos(elapsed * .11) * 1.2,
    );
    final choice = game.actions[target?.uid];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MeHeader(
          me: me,
          subline: rouletteText('발포', 'Fire', '开枪', '開槍'),
          subColor: aimedAtMe ? RouletteColors.cream : RouletteColors.sub,
        ),
        const Spacer(),
        Center(
          child: SizedBox(
            width: 342,
            height: 330,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _AimPainter(
                      beam: (aimedAtMe ? RouletteColors.ink : RouletteColors.red)
                          .withValues(alpha: breathe),
                    ),
                  ),
                ),
                Positioned(
                  left: 96,
                  top: 168,
                  width: 150,
                  height: 150,
                  child: Transform.translate(
                    offset: tremble,
                    child: Container(
                      decoration: BoxDecoration(
                        color: RouletteColors.cream,
                        border: Border.all(
                          color: RouletteColors.cream,
                          width: 6,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(10, 10)),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          RouletteProfile(
                            characterId: target?.characterId,
                            size: 138,
                          ),
                          if (aimedAtMe)
                            const Positioned(
                              right: -18,
                              bottom: -18,
                              child: _MeTag(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (aimedAtMe) ...[
          Text(
            rouletteText(
              '총구가 당신을\n겨누고 있습니다',
              'The gun is\naimed at you',
              '枪口\n正对着你',
              '槍口\n正對著你',
            ),
            textAlign: TextAlign.center,
            style: RouletteType.display(34, RouletteColors.cream, height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            rouletteText('곧 발포해요', 'Firing soon', '即将开枪', '即將開槍'),
            textAlign: TextAlign.center,
            style: RouletteType.body(
              15,
              RouletteColors.cream.withValues(alpha: .8),
            ),
          ),
        ] else ...[
          Text(
            rouletteText('발포 직전', 'ABOUT TO FIRE', '即将开枪', '即將開槍'),
            textAlign: TextAlign.center,
            style: RouletteType.display(46, RouletteColors.cream, height: 1),
          ),
          const SizedBox(height: 8),
          Text(
            rouletteText(
              '총구가 ${target?.nickname ?? ''}에게 멈췄어요',
              'The gun stopped on ${target?.nickname ?? ''}',
              '枪口停在${target?.nickname ?? ''}',
              '槍口停在${target?.nickname ?? ''}',
            ),
            textAlign: TextAlign.center,
            style: RouletteType.body(15, RouletteColors.sub),
          ),
        ],
        if (choice != null) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                aimedAtMe
                    ? rouletteText('내 선택', 'My choice', '我的选择', '我的選擇')
                    : rouletteText(
                        '${target?.nickname ?? ''}의 선택',
                        "${target?.nickname ?? ''}'s choice",
                        '${target?.nickname ?? ''}的选择',
                        '${target?.nickname ?? ''}的選擇',
                      ),
                style: RouletteType.body(
                  13,
                  aimedAtMe ? RouletteColors.cream : RouletteColors.sub,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              RouletteActionChip(action: choice, size: 16),
            ],
          ),
        ],
        const Spacer(),
      ],
    );
  }
}

class _AimPainter extends CustomPainter {
  const _AimPainter({required this.beam});
  final Color beam;

  @override
  void paint(Canvas canvas, Size size) {
    const c = Offset(171, 70);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(120, 300)
        ..lineTo(222, 300)
        ..close(),
      Paint()..color = beam,
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
    canvas.rotate(math.pi / 2);
    paintRouletteGun(canvas, scale: .235);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AimPainter old) => old.beam != beam;
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
      _MeHeader(
        me: me,
        subline: '$turn · ${rouletteText('발포', 'Fire', '开枪', '開槍')}',
        subColor: RouletteColors.cream,
      ),
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
      _MeHeader(
        me: me,
        right: Text(
          rouletteText(
            '생존 ${game.aliveCount}',
            'ALIVE ${game.aliveCount}',
            '存活 ${game.aliveCount}',
            '存活 ${game.aliveCount}',
          ),
          style: RouletteType.number(13, RouletteColors.sub, spacing: 2.4),
        ),
      ),
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
        _MeHeader(
          me: me,
          subline: rouletteText(
            '관전 중 · 탈락',
            'Spectating · out',
            '观战中 · 已淘汰',
            '觀戰中 · 已淘汰',
          ),
          right: selecting
              ? _TimerBox(deadlineAt: game.deadlineAt, boxed: false)
              : null,
        ),
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
        Text(
          rouletteText(
            '선택 내용은 공개 전까지 관전자에게도 보이지 않아요',
            'Choices stay hidden from spectators until the reveal',
            '公开前观战者也看不到选择',
            '公開前觀戰者也看不到選擇',
          ),
          textAlign: TextAlign.center,
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
                        Flexible(
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
                        const Spacer(),
                        Text(
                          entry.$2 == null
                              ? '–'
                              : rouletteText(
                                  '${entry.$2}위',
                                  '#${entry.$2}',
                                  '第${entry.$2}名',
                                  '第${entry.$2}名',
                                ),
                          style: RouletteType.display(20, RouletteColors.cream),
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
