import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_connection_band.dart';
import 'package:game_kit/widgets/game_route_exit.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 태블릿 진행 기기가 잠시 사라졌을 때 현재 게임 화면을 보존하고 공통 상태 띠를
/// 표시합니다. 게임 명령의 허용 여부는 서버 상태와 각 게임의 명령 가드가 결정합니다.
class ControllerReconnectGuard extends StatefulWidget {
  const ControllerReconnectGuard({
    super.key,
    required this.provider,
    required this.child,
  });

  final RoomProvider provider;
  final Widget child;

  @override
  State<ControllerReconnectGuard> createState() =>
      _ControllerReconnectGuardState();
}

class _ControllerReconnectGuardState extends State<ControllerReconnectGuard> {
  bool _observedGameSession = false;
  bool _exitScheduled = false;

  bool get _hasGameSession =>
      (widget.provider.selectedGameId?.isNotEmpty ?? false) ||
      widget.provider.roomStatus == 'playing' ||
      widget.provider.roomStatus == 'finished';

  bool get _isAuthoritativelyBackInWaitingRoom =>
      _observedGameSession &&
      widget.provider.roomCode != null &&
      widget.provider.roomStatus == 'waiting' &&
      !(widget.provider.selectedGameId?.isNotEmpty ?? false);

  void _scheduleFinishedGameExit(BuildContext gameContext) {
    if (_exitScheduled || !_isAuthoritativelyBackInWaitingRoom) return;
    _exitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !gameContext.mounted) return;
      if (!_isAuthoritativelyBackInWaitingRoom) {
        _exitScheduled = false;
        return;
      }
      exitGameRoute(gameContext);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.provider,
      child: widget.child,
      builder: (context, child) {
        if (_hasGameSession) _observedGameSession = true;
        _scheduleFinishedGameExit(context);
        final reconnecting =
            widget.provider.isServerConnected &&
            widget.provider.controllerPresenceState ==
                ControllerPresenceState.reconnecting;
        return Stack(
          fit: StackFit.expand,
          children: [
            ?child,
            if (reconnecting)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: MosiConnectionBand(
                    phase: MosiConnectionBandPhase.reconnecting,
                    labels: MosiConnectionBandLabels(
                      lost: '태블릿 연결을 확인하는 중'.localized,
                      reconnecting: '태블릿 연결을 기다리는 중…'.localized,
                      restored: '태블릿에 다시 연결됐어요'.localized,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
