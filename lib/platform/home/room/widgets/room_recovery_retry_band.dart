// [room_recovery_retry_band.dart] 는 로비에서 방 연결 복구가 실패했을 때 다시 시도하는 띠를 그리는 파일이다.
//
// - [Platform] : 로비(휴대폰 대기실·태블릿 선반)
// - [Widget] : 복구 실패를 알리고, 누르면 방 연결 복구를 다시 시작함
//
// 즉, RTDB 연결은 살아 있는데 방 세션 복구만 실패한 경우에도 사용자가 다시 연결할 수 있게 하는 파일이다.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_connection_band.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 방 연결 복구 실패를 알리는 전체 화면 재시도 영역과 아래 상태 띠입니다.
///
/// 네트워크 가드의 재시도 영역은 RTDB 단절을 관찰했을 때만 생깁니다. 연결은
/// 살아 있고 callable·서버 확인만 실패한 경우는 이 영역이 재시도 경로입니다.
/// 실패 중에는 오래된 방 상태를 조작하지 않도록 화면 전체 터치를 복구로 전환하고,
/// 복구 중에는 중복 요청을 보내지 않습니다.
class RoomRecoveryRetryBand extends StatefulWidget {
  const RoomRecoveryRetryBand({super.key, required this.provider});

  final RoomProvider provider;

  @override
  State<RoomRecoveryRetryBand> createState() => _RoomRecoveryRetryBandState();
}

class _RoomRecoveryRetryBandState extends State<RoomRecoveryRetryBand> {
  bool _isRetrying = false;

  Future<void> _retry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    try {
      await widget.provider.retryConnectionRecovery();
    } catch (_) {
      // 실패 상태와 다음 재시도 안내는 provider가 다시 표시합니다.
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        // 단절 중에는 바깥 네트워크 가드·연결 띠가 안내와 재시도를 맡습니다.
        if (!widget.provider.isInRoom ||
            (!widget.provider.connectionRecoveryFailed && !_isRetrying) ||
            !widget.provider.isServerConnected) {
          return const SizedBox.shrink();
        }
        final label = _isRetrying
            ? GameLocale.select(
                ko: '최신 상황을 불러오는 중…',
                en: 'Loading the latest room state…',
                zhHans: '正在加载最新房间状态…',
                zhHant: '正在載入最新房間狀態…',
              )
            : GameLocale.select(
                ko: '연결을 복구하지 못했어요 · 눌러서 다시 시도',
                en: 'Could not recover the connection · Tap to retry',
                zhHans: '连接恢复失败 · 点按重试',
                zhHant: '連線恢復失敗 · 點按重試',
              );
        return Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            key: const ValueKey('room-recovery-retry-surface'),
            behavior: HitTestBehavior.opaque,
            // 복구 중에도 전체 화면 hit target을 유지하되 새 요청은 만들지 않습니다.
            onTap: _isRetrying ? () {} : () => unawaited(_retry()),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: MosiConnectionBand(
                    key: const ValueKey('room-recovery-retry-band'),
                    phase: _isRetrying
                        ? MosiConnectionBandPhase.reconnecting
                        : MosiConnectionBandPhase.lost,
                    labels: MosiConnectionBandLabels(
                      lost: label,
                      reconnecting: label,
                      restored: label,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
