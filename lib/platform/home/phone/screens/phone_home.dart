import 'package:project00/platform/localization/lobby_connection_band.dart';
import 'package:project00/platform/localization/platform_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/core/layout/app_system_ui.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/phone/screens/phone_room_join.dart';
import 'package:project00/platform/home/phone/screens/phone_room_waiting.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/phone/widgets/phone_header.dart';
import 'package:project00/platform/home/phone/widgets/phone_flow_transition.dart';
import 'package:project00/platform/home/phone/widgets/phone_own_game_list.dart';
import 'package:project00/platform/home/phone/widgets/session_return_prompt.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:game_kit/template_game.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:project00/platform/widgets/app_startup_surface.dart';
import 'package:project00/platform/announcements/widgets/platform_announcement_host.dart';

class PhoneHome extends StatefulWidget {
  const PhoneHome({
    super.key,
    required this.gameCatalog,
    this.roomProvider,
    this.games,
  });

  final GameCatalog gameCatalog;
  final RoomProvider? roomProvider;
  final Future<List<GameInfo>>? games;

  @override
  State<PhoneHome> createState() => _PhoneHomeState();
}

class _PhoneHomeState extends State<PhoneHome> {
  late final Future<List<GameInfo>>
  _games; // PhoneGamePortraitCard에 들어갈 데이터 보관할 객체
  late final RoomProvider _restoredRoomProvider =
      widget.roomProvider ?? RoomProvider(gameCatalog: widget.gameCatalog);
  StreamSubscription<bool>? _connectionSubscription;

  /// 아래 연결 띠가 듣는 서버 연결 상태입니다. 다시 그려도 같은 스트림을 씁니다.
  late final Stream<bool> _serverConnection = _restoredRoomProvider
      .watchServerConnection();
  bool _restoreInFlight = false;
  bool _waitingRoomOpen = false;
  bool _checkingPreviousRoom = true;
  bool _detectionInFlight = false;
  bool _detectionFailed = false;

  /// 돌아갈 수 있는 세션입니다. none이 아니면 복귀 안내 화면을 띄웁니다.
  RestorableSession _restorable = RestorableSession.none;

  /// 이 앱 실행에서 사용자가 이미 복귀를 거절했습니다.
  ///
  /// 거절하면 저장 세션을 지우므로 보통은 다시 뜨지 않지만, 지우기 전에
  /// `.info/connected` 복구가 겹치면 안내가 한 번 더 뜰 수 있습니다.
  bool _declined = false;

  @override
  void initState() {
    super.initState();
    //================상태바 표시=================
    unawaited(AppSystemUi.showPlatformSystemBars());
    // 앱 첫 화면의 방향은 iOS scene이 resumed 된 뒤 main.dart에서 적용합니다.
    // 게임 종료 후 세로 복원은 휴대폰 게임 화면과 대기 화면이 담당합니다.
    _games = widget.games ?? GameService().fetchGames();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _connectionSubscription = _restoredRoomProvider
          .watchServerConnection()
          .listen(
            (connected) {
              if (connected && (_checkingPreviousRoom || _detectionFailed)) {
                unawaited(_detectPreviousRoom());
              }
            },
            // 연결 상태 스트림 오류가 unhandled exception으로 앱을 멈추지
            // 않게 합니다. 복원은 아래의 직접 호출로 한 번은 시도됩니다.
            onError: (_) {},
          );
      unawaited(_detectPreviousRoom());
    });
  }

  /// 돌아갈 세션이 있는지 **서버에 쓰지 않고** 확인만 합니다.
  ///
  /// 예전에는 여기서 곧바로 복원하고 대기 화면을 띄웠습니다. 게임을 그만두려고
  /// 앱을 껐어도 다시 켜면 그 방으로 끌려 들어갔습니다(P-01).
  Future<void> _detectPreviousRoom() async {
    if (_restoreInFlight ||
        _waitingRoomOpen ||
        _detectionInFlight ||
        _declined ||
        !mounted) {
      return;
    }
    if (_restoredRoomProvider.isLeaving) return;
    if (_restoredRoomProvider.isInRoom) {
      await _openWaitingRoom();
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return;

    _detectionInFlight = true;
    setState(() {
      _checkingPreviousRoom = true;
      _detectionFailed = false;
    });
    try {
      final restorable = await _restoredRoomProvider.detectRestorableSession();
      if (!mounted || _declined) return;
      setState(() => _restorable = restorable);
    } catch (_) {
      if (mounted && !_declined) setState(() => _detectionFailed = true);
    } finally {
      _detectionInFlight = false;
      if (mounted) setState(() => _checkingPreviousRoom = false);
    }
  }

  /// 사용자가 복귀를 골랐습니다. 이제서야 서버에 참가자를 되살립니다.
  Future<void> _acceptReturn() async {
    if (_restoreInFlight || _waitingRoomOpen || !mounted) return;
    // 라우트 확인을 복원 호출보다 먼저 합니다. restorePlayerRoom()은 서버에
    // 참가자를 다시 만들고 heartbeat를 시작하므로, 결과를 버릴 상황이면 애초에
    // 부르지 않아야 합니다.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _restoreInFlight = true);
    var restored = false;
    try {
      restored = await _restoredRoomProvider.restorePlayerRoom();
    } catch (_) {
      /* retain the saved membership */
    }
    if (!mounted) return;
    setState(() {
      _restoreInFlight = false;
      if (restored) _restorable = RestorableSession.none;
    });
    if (!restored) return;
    await _openWaitingRoom();
  }

  Future<void> _declineReturn() async {
    setState(() {
      _declined = true;
      _restoreInFlight = true;
    });
    // 명시적 복귀 거절은 기존 퇴장 의도를 처리한 뒤 저장 세션을 정리합니다.
    try {
      await _restoredRoomProvider.declineRestorableSession();
      if (mounted) setState(() => _restorable = RestorableSession.none);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _declined = false;
        _detectionFailed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            GameLocale.select(
              ko: '퇴장 결과를 확인하지 못했습니다. 연결 복구 후 다시 확인합니다.',
              en: 'Could not confirm that you left. It will be checked after reconnecting.',
              zhHans: '无法确认退出结果。恢复连接后将再次确认。',
              zhHant: '無法確認退出結果。恢復連線後將再次確認。',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _restoreInFlight = false);
    }
  }

  Future<void> _openWaitingRoom() async {
    if (_waitingRoomOpen ||
        !mounted ||
        !_restoredRoomProvider.isInRoom ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _waitingRoomOpen = true;
    await Navigator.of(context).push<void>(
      PhoneFlowRoute<void>(
        builder: (_) => PhoneRoomWaiting(provider: _restoredRoomProvider),
      ),
    );
    _waitingRoomOpen = false;
    if (mounted) setState(() => _restorable = RestorableSession.none);
  }

  Future<void> _openRoomJoin() async {
    if (_restoreInFlight || _waitingRoomOpen) return;
    await Navigator.push<void>(
      context,
      PhoneFlowRoute<void>(
        builder: (_) => PhoneRoomJoin(gameCatalog: widget.gameCatalog),
      ),
    );
    // 방금 직접 입장했다면 묻지 않고 그 방을 씁니다. 새로 들어간 방을 두고
    // '돌아가시겠어요?'를 묻는 것은 말이 되지 않습니다.
    _declined = false;
    if (mounted) unawaited(_detectPreviousRoom());
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    if (widget.roomProvider == null) _restoredRoomProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPreviousRoom) return const AppStartupSurface();
    if (_detectionFailed) {
      return AppStartupSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '이전 게임을 확인하지 못했어요.'.localized,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            MosiButton(
              label: '다시 시도'.localized,
              onPressed: () => unawaited(_detectPreviousRoom()),
            ),
          ],
        ),
      );
    }
    if (_restorable != RestorableSession.none) {
      return SessionReturnPrompt(
        session: _restorable,
        isBusy: _restoreInFlight,
        onReturn: () => unawaited(_acceptReturn()),
        onDecline: () => unawaited(_declineReturn()),
      );
    }
    return PlatformAnnouncementHost(
      child: ListenableBuilder(
        listenable: _restoredRoomProvider,
        builder: (context, child) => LobbyConnectionBand(
          connectionChanges: _restoredRoomProvider.isInRoom
              ? _serverConnection
              : null,
          child: child!,
        ),
        child: Scaffold(
          backgroundColor: MosiColors.violet,
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                const PhoneHeader(),
                PhoneOwnGameList(games: _games),
                _buildJoinBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //================하단 고정 그룹 참여 버튼=================
  Widget _buildJoinBar() {
    final busy = _restoreInFlight || _waitingRoomOpen;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: MosiColors.white,
        border: Border(top: BorderSide(color: MosiColors.ink, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.phonePlayHint,
              textAlign: TextAlign.center,
              style: MosiFonts.sans(size: 12, color: MosiColors.muted),
            ),
            const SizedBox(height: 10),
            MosiButton(
              label: busy ? context.l10n.reconnecting : context.l10n.joinGroup,
              height: 56,
              fontSize: 18,
              shadowOffset: 5,
              expand: true,
              leading: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: busy ? null : () => unawaited(_openRoomJoin()),
            ),
          ],
        ),
      ),
    );
  }
}
