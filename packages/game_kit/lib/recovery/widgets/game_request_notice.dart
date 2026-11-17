import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_connection_band.dart';

/// 마지막 정상 게임 화면을 유지하면서 요청의 진행/실패를 알리는 공용 표시입니다.
/// 재시도 버튼은 현재 단계에서 여전히 유효한 명령일 때만 호출부가 제공합니다.
class GameRequestNotice extends StatelessWidget {
  const GameRequestNotice({
    super.key,
    this.busy = false,
    this.message,
    this.onRetry,
    this.busyMessage = '서버 응답을 기다리고 있습니다…',
  });
  final bool busy;
  final String? message;
  final VoidCallback? onRetry;
  final String busyMessage;

  @override
  Widget build(BuildContext context) {
    if (!busy && (message == null || message!.isEmpty)) {
      return const SizedBox.shrink();
    }
    final retryLabel = GameLocale.select(
      ko: '재시도',
      en: 'Retry',
      zhHans: '重试',
      zhHant: '重試',
    );
    final baseLabel = (busy ? busyMessage : message!).localized;
    final label = !busy && onRetry != null
        ? '$baseLabel · $retryLabel'
        : baseLabel;
    final phase = busy
        ? MosiConnectionBandPhase.reconnecting
        : MosiConnectionBandPhase.lost;
    final band = SizedBox(
      width: double.infinity,
      child: MosiConnectionBand(
        phase: phase,
        labels: MosiConnectionBandLabels(
          lost: label,
          reconnecting: label,
          restored: label,
        ),
      ),
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: onRetry == null || busy
          ? IgnorePointer(child: band)
          : Semantics(
              button: true,
              label: label,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onRetry, child: band),
              ),
            ),
    );
  }
}
