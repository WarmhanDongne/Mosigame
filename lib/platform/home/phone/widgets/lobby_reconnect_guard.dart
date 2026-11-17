import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_connection_band.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/widgets/room_recovery_retry_band.dart';

/// 대기실 본문을 보존하며 태블릿 연결 복구를 기다립니다.
/// 휴대폰 자체 단절은 바깥 CriticalNetworkGuard가 담당합니다.
class LobbyReconnectGuard extends StatelessWidget {
  const LobbyReconnectGuard({
    super.key,
    required this.provider,
    required this.child,
  });

  final RoomProvider provider;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provider,
      child: child,
      builder: (context, child) {
        final reconnecting =
            provider.isServerConnected &&
            provider.controllerPresenceState ==
                ControllerPresenceState.reconnecting &&
            (ModalRoute.of(context)?.isCurrent ?? true);
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
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
            // 휴대폰 자신의 방 연결 복구가 실패하면 여기서 다시 시도합니다.
            RoomRecoveryRetryBand(provider: provider),
          ],
        );
      },
    );
  }
}
