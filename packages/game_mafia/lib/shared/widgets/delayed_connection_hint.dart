import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_connection_band.dart';

/// 짧은 네트워크 흔들림은 숨기고, 연결이 오래 끊겼을 때만 보여 주는 안내입니다.
///
/// 게임 화면은 마지막으로 확인한 장면을 그대로 유지합니다. 따라서 이 안내는
/// 화면을 막거나 로딩 화면으로 바꾸지 않고, 사용자가 앱이 멈춘 것으로 오해할
/// 정도로 연결 지연이 길어졌을 때 공통 연결 상태 띠로 나타납니다.
class MafiaDelayedConnectionHint extends StatefulWidget {
  const MafiaDelayedConnectionHint({
    super.key,
    required this.connectionChanges,
    this.enabled = true,
    this.delay = const Duration(milliseconds: 1600),
    this.alignment = Alignment.topCenter,
    this.margin = const EdgeInsets.only(top: 82),
  });

  final Stream<bool> connectionChanges;
  final bool enabled;
  final Duration delay;
  final Alignment alignment;
  final EdgeInsets margin;

  @override
  State<MafiaDelayedConnectionHint> createState() =>
      _MafiaDelayedConnectionHintState();
}

class _MafiaDelayedConnectionHintState
    extends State<MafiaDelayedConnectionHint> {
  StreamSubscription<bool>? _subscription;
  Timer? _delayTimer;
  bool _connected = true;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(MafiaDelayedConnectionHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectionChanges != widget.connectionChanges) _listen();
    if (!widget.enabled && oldWidget.enabled) _hide();
    if (widget.enabled && !oldWidget.enabled && !_connected) {
      _scheduleReveal();
    }
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = widget.connectionChanges.listen(_handleConnection);
  }

  void _handleConnection(bool connected) {
    _connected = connected;
    if (connected || !widget.enabled) {
      _hide();
      return;
    }
    _scheduleReveal();
  }

  void _scheduleReveal() {
    _delayTimer?.cancel();
    _delayTimer = Timer(widget.delay, () {
      if (!mounted || _connected || !widget.enabled) return;
      setState(() => _visible = true);
    });
  }

  void _hide() {
    _delayTimer?.cancel();
    _delayTimer = null;
    if (_visible && mounted) setState(() => _visible = false);
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 240),
          child: SizedBox(
            key: const ValueKey('mafia-delayed-connection-hint'),
            width: double.infinity,
            child: MosiConnectionBand(
              phase: MosiConnectionBandPhase.lost,
              labels: MosiConnectionBandLabels(
                lost: '네트워크 연결을 확인하는 중…'.localized,
                reconnecting: '최신 상황을 불러오는 중…'.localized,
                restored: '다시 연결됐어요'.localized,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
