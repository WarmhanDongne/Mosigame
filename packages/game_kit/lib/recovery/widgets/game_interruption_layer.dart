import 'dart:async';
import 'package:flutter/material.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/widgets/game_request_notice.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

enum GameInterruptionPresentation { player, tabletController }

/// 실제 복구 중단은 원인이 해소된 준비 barrier까지 기존 안내로 표시합니다.
class GameInterruptionLayer extends StatefulWidget {
  const GameInterruptionLayer({
    super.key,
    required this.interruption,
    required this.currentUid,
    this.presentation = GameInterruptionPresentation.player,
    this.onContinue,
    this.onFinishNow,
    this.onExpired,
    this.onWaitMore,
    this.onExit,
    this.failureMessage,
    this.isSubmitting = false,
    this.scrimColor = const Color(0xE8000000),
  });
  final GameInterruption? interruption;
  final String currentUid;
  final GameInterruptionPresentation presentation;
  final Future<bool> Function()? onContinue, onFinishNow, onExpired, onWaitMore;
  final VoidCallback? onExit;
  final String? failureMessage;
  final bool isSubmitting;
  final Color scrimColor;
  @override
  State<GameInterruptionLayer> createState() => _GameInterruptionLayerState();
}

class _GameInterruptionLayerState extends State<GameInterruptionLayer> {
  Timer? _timer;
  bool _busy = false, _failed = false, _confirmEnd = false;
  String? _expired;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final current = widget.interruption;
      if (widget.presentation ==
              GameInterruptionPresentation.tabletController &&
          current != null &&
          (current.causes.isNotEmpty || current.playerUid.isNotEmpty) &&
          current.deadlineAt > 0 &&
          _remaining(current) == 0 &&
          _expired != current.id) {
        _expired = current.id;
        // This only marks awaitingDecision and owns one bounded callable batch.
        if (widget.onExpired != null) unawaited(widget.onExpired!());
      }
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(GameInterruptionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interruption?.id != widget.interruption?.id) {
      _expired = null;
      _failed = false;
      _busy = false;
      _confirmEnd = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _remaining(GameInterruption current) =>
      (ServerClock.remainingUntil(current.deadlineAt).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 60);
  Future<void> _act(Future<bool> Function()? action) async {
    if (action == null || _busy) return;
    final id = widget.interruption?.id;
    setState(() {
      _busy = true;
      _failed = false;
    });
    var success = false;
    try {
      success = await action();
    } catch (_) {
      success = false;
    }
    if (!mounted || widget.interruption?.id != id) return;
    setState(() {
      _busy = false;
      _failed = !success;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.interruption;
    if (current == null ||
        (current.pauseId == null &&
            current.causes.isEmpty &&
            current.playerUid.isEmpty)) {
      return const SizedBox.shrink();
    }
    final controller =
        widget.presentation == GameInterruptionPresentation.tabletController;
    if (!controller) {
      // 휴대폰의 기존 상단바·퇴장 모달을 유지하며 오류 안내만 재사용합니다.
      return GameRequestNotice(
        message:
            widget.failureMessage ??
            GameLocale.select(
              ko: '게임을 잠시 멈췄어요. 연결과 화면 준비를 기다리고 있어요.',
              en: 'The game is paused while connections and screens get ready.',
              zhHans: '游戏已暂停，正在等待连接和画面准备。',
              zhHant: '遊戲已暫停，正在等待連線和畫面準備。',
            ),
      );
    }
    final seconds = current.deadlineAt > 0 ? _remaining(current) : null;
    final total = current.extended ? 60 : 30;
    // 진행자가 결정해야 하는 원인만 이름표로 보여 줍니다.
    final decisions = [
      for (final cause in current.causes)
        if (cause['awaitingDecision'] == true)
          cause['role'] == 'controller'
              ? GameLocale.select(
                  ko: '진행 기기',
                  en: 'Tablet',
                  zhHans: '平板',
                  zhHant: '平板',
                )
              : (cause['playerNickname']?.toString() ??
                    GameLocale.select(
                      ko: '참가자',
                      en: 'Player',
                      zhHans: '玩家',
                      zhHant: '玩家',
                    )),
    ];
    final showPlayerActions = current.playerUid.isNotEmpty;
    final busy = _busy || widget.isSubmitting;
    final notes = <(String, Color)>[
      if (seconds == 0)
        (
          GameLocale.select(
            ko: '자동으로 제외하거나 종료하지 않아요.',
            en: 'Nobody is removed and the game will not end automatically.',
            zhHans: '不会自动移除玩家或结束游戏。',
            zhHant: '不會自動移除玩家或結束遊戲。',
          ),
          const Color(0xFFD9D3FF),
        ),
      if (showPlayerActions && !current.canContinue)
        (
          GameLocale.select(
            ko: '제외하면 남은 인원으로 진행할 수 없어요.',
            en: 'The remaining players cannot continue if this player is removed.',
            zhHans: '移除该玩家后，剩余人数无法继续游戏。',
            zhHant: '移除該玩家後，剩餘人數無法繼續遊戲。',
          ),
          const Color(0xFFD9D3FF),
        ),
      if (_failed || widget.failureMessage != null)
        (
          widget.failureMessage ??
              GameLocale.select(
                ko: '요청 결과를 확인하지 못했어요. 다시 시도해주세요.',
                en: 'Could not confirm the result. Try again.',
                zhHans: '无法确认请求结果，请重试。',
                zhHant: '無法確認請求結果，請重試。',
              ),
          const Color(0xFFFF9AA5),
        ),
    ];
    final buttons = <Widget>[
      if (showPlayerActions && seconds == 0 && !current.extended)
        _DecisionButton(
          label: '30초 더 기다리기'.localized,
          tone: _DecisionTone.primary,
          onPressed: busy ? null : () => unawaited(_act(widget.onWaitMore)),
        ),
      if (showPlayerActions)
        _DecisionButton(
          label: '제외하고 계속하기'.localized,
          tone: _DecisionTone.secondary,
          onPressed: !current.canContinue || busy
              ? null
              : () => unawaited(_act(widget.onContinue)),
        ),
      if (widget.onFinishNow != null) ...[
        _DecisionButton(
          label: _confirmEnd ? '종료 확인'.localized : '게임 종료'.localized,
          tone: _confirmEnd ? _DecisionTone.dangerFilled : _DecisionTone.danger,
          onPressed: _busy
              ? null
              : () {
                  if (_confirmEnd) {
                    unawaited(_act(widget.onFinishNow));
                  } else {
                    setState(() => _confirmEnd = true);
                  }
                },
        ),
        if (_confirmEnd)
          _DecisionButton(
            label: '계속 기다리기'.localized,
            tone: _DecisionTone.secondary,
            onPressed: _busy ? null : () => setState(() => _confirmEnd = false),
          ),
      ],
    ];
    // 게임 화면은 살짝 어둡게만 두고, 아래 남색 띠에 상태와 선택지를 모읍니다.
    return Positioned.fill(
      child: Material(
        color: const Color(0x590E0A3D),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: MosiColors.navy,
              border: Border(top: BorderSide(color: MosiColors.ink, width: 4)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (seconds != null) ...[
                      _CountdownRing(seconds: seconds, total: total),
                      const SizedBox(width: 24),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: MosiColors.sun,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: MosiColors.ink,
                                width: 2.5,
                              ),
                            ),
                            child: Text(
                              GameLocale.select(
                                ko: '일시정지',
                                en: 'Paused',
                                zhHans: '已暂停',
                                zhHant: '已暫停',
                              ),
                              style: MosiFonts.sans(
                                size: 13,
                                weight: FontWeight.w700,
                                color: MosiColors.ink,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            GameLocale.select(
                              ko: '게임을 잠시 멈췄어요',
                              en: 'Game paused',
                              zhHans: '游戏已暂停',
                              zhHant: '遊戲已暫停',
                            ),
                            style: MosiFonts.sans(
                              size: 24,
                              weight: FontWeight.w700,
                              color: MosiColors.white,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            current.causes.isEmpty
                                ? GameLocale.select(
                                    ko: '모든 기기의 화면 준비를 확인하고 있어요.',
                                    en: 'Checking that every screen is ready.',
                                    zhHans: '正在确认所有设备的画面已准备。',
                                    zhHant: '正在確認所有裝置的畫面已準備。',
                                  )
                                : GameLocale.select(
                                    ko: '연결과 화면 준비를 기다리고 있어요.',
                                    en: 'Waiting for connections and screens.',
                                    zhHans: '正在等待连接与画面准备。',
                                    zhHant: '正在等待連線與畫面準備。',
                                  ),
                            style: MosiFonts.sans(
                              size: 15,
                              color: const Color(0xFFD9D3FF),
                            ),
                          ),
                          if (decisions.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final name in decisions)
                                  _DecisionChip(name: name),
                              ],
                            ),
                          ],
                          for (final (text, color) in notes)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                text,
                                style: MosiFonts.sans(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ),
                          if (_confirmEnd)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                GameLocale.select(
                                  ko: '게임을 종료할까요?',
                                  en: 'End the game?',
                                  zhHans: '要结束游戏吗？',
                                  zhHant: '要結束遊戲嗎？',
                                ),
                                style: MosiFonts.sans(
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: MosiColors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (buttons.isNotEmpty) ...[
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 280,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (i, button) in buttons.indexed) ...[
                              if (i > 0) const SizedBox(height: 10),
                              button,
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 진행자 결정이 필요한 사람의 이름표입니다.
class _DecisionChip extends StatelessWidget {
  const _DecisionChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
    decoration: BoxDecoration(
      color: MosiColors.white,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: MosiColors.ink, width: 2.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: MosiColors.coral,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.wifi_off_rounded,
            size: 15,
            color: MosiColors.white,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          GameLocale.select(
            ko: '$name · 결정 필요',
            en: '$name · needs a decision',
            zhHans: '$name · 需要决定',
            zhHant: '$name · 需要決定',
          ),
          style: MosiFonts.sans(
            size: 14,
            weight: FontWeight.w700,
            color: MosiColors.navy,
          ),
        ),
      ],
    ),
  );
}

enum _DecisionTone { primary, secondary, danger, dangerFilled }

/// 띠 오른쪽의 선택 버튼입니다. 세 버튼 모두 같은 모양(검정 테두리 · 그림자)이고
/// 역할만 색으로 나눕니다.
class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    required this.label,
    required this.tone,
    required this.onPressed,
  });

  final String label;
  final _DecisionTone tone;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      _DecisionTone.primary => (MosiColors.lime, MosiColors.ink),
      _DecisionTone.secondary => (MosiColors.white, MosiColors.navy),
      _DecisionTone.danger => (MosiColors.white, MosiColors.red),
      _DecisionTone.dangerFilled => (MosiColors.red, MosiColors.white),
    };
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(0, 5)),
          ],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: background,
            disabledForegroundColor: foreground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: MosiColors.ink, width: 3),
            ),
            textStyle: MosiFonts.sans(size: 17, weight: FontWeight.w700),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// 남은 복구 대기 시간을 노란 원으로 보여 줍니다.
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.seconds, required this.total});

  final int seconds;
  final int total;

  @override
  Widget build(BuildContext context) => Semantics(
    label: GameLocale.select(
      ko: '남은 시간 $seconds초',
      en: '$seconds seconds left',
      zhHans: '剩余 $seconds 秒',
      zhHant: '剩餘 $seconds 秒',
    ),
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: 112,
      child: CustomPaint(
        painter: _RingPainter(
          progress: total <= 0 ? 0 : (seconds / total).clamp(0.0, 1.0),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$seconds',
                style: MosiFonts.grotesk(
                  size: 34,
                  color: MosiColors.white,
                  height: 1,
                ),
              ),
              Text(
                GameLocale.select(ko: '초', en: 'sec', zhHans: '秒', zhHant: '秒'),
                style: MosiFonts.sans(
                  size: 12,
                  weight: FontWeight.w700,
                  color: const Color(0xFFD9D3FF),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(8);
    final track = Paint()
      ..color = const Color(0x2EFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawArc(rect, 0, 2 * 3.141592653589793, false, track);
    canvas.drawArc(
      rect,
      -3.141592653589793 / 2,
      2 * 3.141592653589793 * progress,
      false,
      Paint()
        ..color = MosiColors.sun
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 10,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
