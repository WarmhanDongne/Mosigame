// [app_network_guard.dart] 는 여러 게임이 함께 사용하는 네트워크 연결 상태와 재연결 흐름을 관리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [RecoveryWidget] : 앱 범위의 연결 단절과 복구 UI를 관리함
//
// 즉, 통신이 끊겨도 연결 문제를 안내하고 안전하게 복구하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_connection_band.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

// ============================================================

/// 서버 연결이 필수인 화면에서만 사용하는 네트워크 연결 상태 띠입니다.
///
/// [connectionChanges]를 전달하지 않으면 아무 연결도 감시하지 않습니다. 앱 루트는
/// 이 비활성 형태를 사용해 초기 Firebase 연결 수립 과정만으로 팝업이 나타나는 것을
/// 막고, 방 대기실과 진행 중 게임처럼 실시간 연결이 실제로 필요한 화면만 스트림을
/// 전달합니다.
class AppNetworkGuard extends StatefulWidget {
  const AppNetworkGuard({
    super.key,
    required this.child,
    this.connectionChanges,
    this.onRetry,
    this.onExit,
    this.exitLabel = '홈으로',
    this.blockChildInput = true,
    this.showExitInBand = false,
    this.noticeDelay = const Duration(seconds: 3),
    this.showDelay = const Duration(seconds: 10),
  });

  final Widget child;
  final Stream<bool>? connectionChanges;
  final Future<void> Function()? onRetry;
  final VoidCallback? onExit;
  final String exitLabel;

  /// Game routes protect gameplay through their session/command checks while
  /// retaining access to recovery and exit controls. Lobby routes block input.
  final bool blockChildInput;

  /// 연결 띠 오른쪽에 [onExit]을 부르는 나가기 버튼을 둡니다.
  ///
  /// 입력을 막는 화면(대기실)은 연결이 돌아오지 않으면 나갈 방법이 없으므로
  /// 띠 안에 나가기를 둡니다. 띠의 나머지와 화면 전체는 계속 재시도입니다.
  final bool showExitInBand;

  /// 이 시간 이전에는 안내를 숨깁니다. 게임 입력은 연결 단절 즉시 보호합니다.
  final Duration noticeDelay;

  /// 단절 뒤 장기 대기 문구로 바뀌는 시간입니다. 작은 안내 이후 추가 시간이 아닙니다.
  final Duration showDelay;

  @override
  State<AppNetworkGuard> createState() => _AppNetworkGuardState();
}

class _AppNetworkGuardState extends State<AppNetworkGuard>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? _subscription;
  Timer? _showTimer;
  Timer? _noticeTimer;
  bool _isConnected = true;
  bool _needsRecovery = false;
  bool _isNoticeVisible = false;
  bool _isModalVisible = false;
  bool _isRetrying = false;
  bool _isForeground = true;
  int _subscriptionGeneration = 0;
  int _connectionGeneration = 0;
  bool _hasParentGuard = false;
  bool _didSubscribe = false;
  bool _isCurrentRoute = true;

  // RTDB 연결은 SDK가 복구합니다. 이 간격은 연결 후 세션 복구 실패에만 적용하며
  // 카드 제출/CALL 등 게임 행동을 새 명령으로 재전송하지 않습니다.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    if (_isCurrentRoute != currentRoute) {
      _isCurrentRoute = currentRoute;
      if (!currentRoute) {
        _showTimer?.cancel();
        _showTimer = null;
        _noticeTimer?.cancel();
        _noticeTimer = null;
      } else if (_needsRecovery) {
        _scheduleNotices();
        // Do not synchronously setState during dependency updates.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_retry());
        });
      }
    }
    final hasParent =
        context.dependOnInheritedWidgetOfExactType<_NetworkGuardScope>() !=
        null;
    if (!_didSubscribe || _hasParentGuard != hasParent) {
      _didSubscribe = true;
      _hasParentGuard = hasParent;
      _subscribe();
    }
  }

  @override
  void didUpdateWidget(AppNetworkGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectionChanges != widget.connectionChanges) {
      _subscribe();
    } else if ((oldWidget.showDelay != widget.showDelay ||
            oldWidget.noticeDelay != widget.noticeDelay) &&
        _needsRecovery &&
        _isForeground &&
        !_isModalVisible) {
      _showTimer?.cancel();
      _showTimer = null;
      _noticeTimer?.cancel();
      _noticeTimer = null;
      _scheduleNotices();
    }
  }

  void _subscribe() {
    final generation = ++_subscriptionGeneration;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _connectionGeneration++;
    _showTimer?.cancel();
    _showTimer = null;
    _noticeTimer?.cancel();
    _noticeTimer = null;
    _isConnected = true;
    _needsRecovery = false;
    _isNoticeVisible = false;
    _isModalVisible = false;
    final stream = widget.connectionChanges;
    // 앱 루트 가드가 비활성이면 자식이 담당하고, 활성 부모가 있으면 중복하지 않습니다.
    if (stream == null || _hasParentGuard) return;
    _subscription = stream.listen(
      (isConnected) {
        if (generation == _subscriptionGeneration) {
          _handleConnectionChanged(isConnected);
        }
      },
      onError: (_) {
        if (generation == _subscriptionGeneration) {
          _handleConnectionChanged(false);
        }
      },
      onDone: () {
        if (generation == _subscriptionGeneration) {
          _handleConnectionChanged(false);
        }
      },
    );
  }

  void _handleConnectionChanged(bool isConnected) {
    if (!mounted) return;
    _log('connection_changed', {'connected': isConnected});
    if (_isConnected != isConnected) _connectionGeneration++;
    _isConnected = isConnected;
    if (isConnected) {
      if (_needsRecovery && !_isRetrying) unawaited(_retry());
      return;
    }

    setState(() => _needsRecovery = true);
    _scheduleNotices();
  }

  // 연결이 반복해서 끊기거나 세션 복구만 실패해도 안내 시간을 초기화하지 않습니다.
  void _scheduleNotices() {
    if (!_isCurrentRoute || !_isForeground || !_needsRecovery) return;
    if (!_isNoticeVisible && _noticeTimer == null) {
      _noticeTimer = Timer(widget.noticeDelay, () {
        _noticeTimer = null;
        if (mounted && _needsRecovery) {
          setState(() => _isNoticeVisible = true);
        }
      });
    }
    if (!_isForeground || _isModalVisible || _showTimer != null) return;
    _showTimer = Timer(widget.showDelay, () {
      _showTimer = null;
      if (mounted && _needsRecovery) {
        _log('long_wait_shown', {'delayMs': widget.showDelay.inMilliseconds});
        setState(() => _isModalVisible = true);
      }
    });
  }

  void _retryFromUserTap() {
    if (_isRetrying || !_needsRecovery) return;
    unawaited(_retry(allowDisconnected: true));
  }

  Future<void> _retry({bool allowDisconnected = false}) async {
    // 자동 복구는 오프라인 callable 반복을 피합니다. 화면을 직접 누른 수동
    // 재시도만 현재 연결 신호가 false여도 전체 세션 복구 파이프라인을 시작합니다.
    if (!_isCurrentRoute ||
        !_isForeground ||
        !_needsRecovery ||
        _isRetrying ||
        (!allowDisconnected && !_isConnected)) {
      return;
    }
    final subscriptionGeneration = _subscriptionGeneration;
    final connectionGeneration = _connectionGeneration;
    _log('recovery_started');
    setState(() => _isRetrying = true);
    var recovered = false;
    try {
      await widget.onRetry?.call();
      recovered = true;
    } catch (error) {
      _log('recovery_failed', {'errorType': error.runtimeType.toString()});
      if (mounted &&
          _isForeground &&
          _isCurrentRoute &&
          subscriptionGeneration == _subscriptionGeneration &&
          connectionGeneration == _connectionGeneration) {
        setState(() => _isModalVisible = true);
      }
      // 실패 횟수만으로 게임을 종료하거나 홈으로 이동하지 않습니다.
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
        // 이전 연결의 늦은 응답이 새 연결의 입력 잠금을 풀지 못하도록 합니다.
        if (recovered &&
            _isConnected &&
            subscriptionGeneration == _subscriptionGeneration &&
            connectionGeneration == _connectionGeneration) {
          _completeRecovery();
        } else {
          if (_isConnected && connectionGeneration != _connectionGeneration) {
            unawaited(_retry());
          }
        }
      }
    }
  }

  void _completeRecovery() {
    _log('recovery_succeeded');
    _showTimer?.cancel();
    _showTimer = null;
    _noticeTimer?.cancel();
    _noticeTimer = null;
    setState(() {
      _needsRecovery = false;
      _isNoticeVisible = false;
      _isModalVisible = false;
    });
  }

  void _log(String event, [Map<String, Object?> fields = const {}]) {
    if (!kDebugMode) return;
    final details = fields.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    debugPrint(
      '[network_guard] event=$event${details.isEmpty ? '' : ' $details'}',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) {
      _showTimer?.cancel();
      _showTimer = null;
      _noticeTimer?.cancel();
      _noticeTimer = null;
      return;
    }
    // 백그라운드 시간만으로 새 모달을 띄우지 않고 복귀 시 다시 복구를 시도합니다.
    if (_needsRecovery) {
      _scheduleNotices();
      unawaited(_retry());
    }
  }

  @override
  void dispose() {
    _subscriptionGeneration += 1;
    _showTimer?.cancel();
    _noticeTimer?.cancel();
    unawaited(_subscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasParentGuard || widget.connectionChanges == null) {
      return widget.child;
    }
    // 상태 띠가 올라와도 child의 위치를 유지합니다. wrapper를 빼면 게임 State와
    // 구독이 폐기됩니다. 가려진 화면에서는 안내·입력 차단만 비활성화합니다.
    final active = _isCurrentRoute;
    final showBand =
        active &&
        _needsRecovery &&
        (_isNoticeVisible || _isModalVisible || _isRetrying);
    final retryFailed =
        _isConnected && _isModalVisible && !_isRetrying && _needsRecovery;
    final canTapToRetry = active && _needsRecovery && !_isRetrying;
    final useFullScreenRetrySurface = canTapToRetry && widget.blockChildInput;
    final bandLabel = retryFailed
        ? GameLocale.select(
            ko: '연결을 복구하지 못했어요 · 눌러서 다시 시도',
            en: 'Could not recover the connection · Tap to retry',
            zhHans: '连接恢复失败 · 点按重试',
            zhHant: '連線恢復失敗 · 點按重試',
          )
        : _isConnected && _isRetrying
        ? GameLocale.select(
            ko: '최신 상황을 불러오는 중…',
            en: 'Loading the latest game state…',
            zhHans: '正在加载最新游戏状态…',
            zhHant: '正在載入最新遊戲狀態…',
          )
        : _isModalVisible
        ? GameLocale.select(
            ko: '네트워크 연결을 기다리는 중…',
            en: 'Waiting for the network connection…',
            zhHans: '正在等待网络连接…',
            zhHant: '正在等待網路連線…',
          )
        : GameLocale.select(
            ko: '네트워크 연결을 확인하는 중…',
            en: 'Checking the network connection…',
            zhHans: '正在检查网络连接…',
            zhHant: '正在檢查網路連線…',
          );
    final showExit = showBand && widget.showExitInBand && widget.onExit != null;
    final bandPhase = retryFailed || !_isConnected && !_isModalVisible
        ? MosiConnectionBandPhase.lost
        : MosiConnectionBandPhase.reconnecting;
    return _NetworkGuardScope(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 화면은 유지하되 오래된 손패/턴을 보고 행동하지 못하도록 입력을 보호합니다.
          // 서버의 턴 시간과 이미 전송된 명령은 이 레이어가 중지하지 않습니다.
          AbsorbPointer(
            absorbing: widget.blockChildInput && active && _needsRecovery,
            child: ExcludeFocus(
              excluding: widget.blockChildInput && active && _needsRecovery,
              child: widget.child,
            ),
          ),
          // 입력이 잠긴 화면은 빈 곳을 포함한 전체 영역이 재시도 버튼입니다.
          // 첫 터치가 _isRetrying을 동기적으로 세우므로 빠른 연속 터치는 새 요청을
          // 만들지 않습니다. 입력을 유지하는 화면은 기존 컨트롤을 가리지 않습니다.
          if (useFullScreenRetrySurface)
            Positioned.fill(
              child: Semantics(
                button: true,
                label: GameLocale.select(
                  ko: '화면을 눌러 다시 연결',
                  en: 'Tap the screen to reconnect',
                  zhHans: '点按屏幕重新连接',
                  zhHant: '點按螢幕重新連線',
                ),
                child: GestureDetector(
                  key: const ValueKey('network-recovery-tap-surface'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _retryFromUserTap,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          if (showBand)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: canTapToRetry ? _retryFromUserTap : null,
                  child: MosiConnectionBand(
                    phase: bandPhase,
                    trailingReserve: showExit ? _BandExitButton.reserve : 0,
                    labels: MosiConnectionBandLabels(
                      lost: bandLabel,
                      reconnecting: bandLabel,
                      restored: bandLabel,
                    ),
                  ),
                ),
              ),
            ),
          // 재시도 영역 위에 두어 이 버튼의 터치만 나가기로 처리합니다.
          if (showExit)
            Positioned(
              right: 8,
              bottom: MediaQuery.paddingOf(context).bottom,
              height: MosiConnectionBand.height,
              child: Center(
                child: _BandExitButton(
                  label: widget.exitLabel.localized,
                  onPressed: widget.onExit!,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 같은 위젯 트리의 플랫폼/게임 가드가 안내와 복구를 중복 실행하지 않게 합니다.
class _NetworkGuardScope extends InheritedWidget {
  const _NetworkGuardScope({required super.child});

  @override
  bool updateShouldNotify(_NetworkGuardScope oldWidget) => false;
}

/// 연결 띠 오른쪽의 흰 알약 모양 나가기 버튼입니다.
class _BandExitButton extends StatelessWidget {
  const _BandExitButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  /// 띠 문구가 버튼과 겹치지 않도록 띠가 비워 두는 너비입니다.
  static const double reserve = 76;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('network-band-exit'),
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: reserve),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: MosiColors.white,
              border: Border.all(color: MosiColors.ink, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: MosiFonts.sans(
                  locale: Localizations.maybeLocaleOf(context),
                  size: 12,
                  weight: FontWeight.w700,
                  color: MosiColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
