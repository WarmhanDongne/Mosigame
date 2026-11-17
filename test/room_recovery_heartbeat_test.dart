import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_connection_band.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';
import 'package:game_kit/recovery/models/room_session_identity.dart';
import 'package:game_kit/recovery/services/controller_room_session_store.dart';
import 'package:game_kit/recovery/services/room_recovery_batch.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';
import 'package:game_kit/recovery/widgets/critical_network_guard.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/controller_presence.dart';
import 'package:project00/platform/home/room/services/deferred_room_leave.dart';
import 'package:project00/platform/home/room/services/player_room_session_store.dart';
import 'package:project00/platform/home/room/services/room_leave_intent.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/home/room/widgets/room_recovery_retry_band.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final paused in [false, true]) {
    test(
      'own connection false recovers only in foreground: paused=$paused',
      () async {
        SharedPreferences.setMockInitialValues({});
        await ControllerRoomSessionStore.instance.clear();
        final identity = RoomSessionIdentity(
          uid: 'own-loss-$paused',
          role: 'player',
          roomCode: 'ABCDE',
          roomInstanceId: 'room',
          membershipId: 'member',
          connectionId: 'current',
          connectionSeq: 1,
        );
        await RoomSessionIdentityStore.instance.save(identity);
        final service = _RecoveryService(identity, _Database());
        final provider =
            RoomProvider(
                service: service,
                gameService: _UnusedGameService(),
                currentUidReader: () => identity.uid,
              )
              ..roomCode = identity.roomCode
              ..listenRoom();
        addTearDown(() async {
          provider.dispose();
          await service.connected.close();
          await service.peerPlayers.close();
          await RoomSessionIdentityStore.instance.clear(
            identity.uid,
            'player',
            identity.roomCode,
          );
        });
        service.connected.add(true);
        await Future<void>.delayed(Duration.zero);
        if (paused) {
          provider.didChangeAppLifecycleState(AppLifecycleState.paused);
        }
        service.peerPlayers.add([
          RoomPlayer.fromJson({
            'isConnected': false,
            'lastSeen': 1,
            'membershipId': 'member',
            'currentConnectionId': 'current',
            'connectionSeq': 1,
          }, key: identity.uid),
        ]);
        for (var i = 0; i < 6; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(service.playerRestores, paused ? 0 : 1);
        if (paused) {
          provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
          await provider.retryConnectionRecovery();
          expect(service.playerRestores, 1);
        }
      },
    );
  }

  test(
    'route retries and resumed lifecycle share a completed connection episode',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      const identity = RoomSessionIdentity(
        uid: 'coalesced',
        role: 'player',
        roomCode: 'ABCDE',
        roomInstanceId: 'room',
        membershipId: 'member',
        connectionId: 'current',
        connectionSeq: 1,
      );
      await RoomSessionIdentityStore.instance.save(identity);
      final database = _Database();
      final service = _RecoveryService(identity, database)
        ..playerRestore = Completer<void>();
      final provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.connected.close();
        await RoomSessionIdentityStore.instance.clear(
          identity.uid,
          'player',
          'ABCDE',
        );
      });
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      final first = provider.retryConnectionRecovery();
      final second = provider.retryConnectionRecovery();
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(service.playerRestores, 1);
      final session = GameRecoverySession.forRoom('ABCDE', identity.uid);
      expect(session.transportRecovering, true);
      service.playerRestore!.complete();
      await Future.wait([first, second]);
      expect(session.transportRecovering, false);
      await provider.retryConnectionRecovery();
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(service.playerRestores, 1);
    },
  );

  test(
    'resumed lifecycle reopens a terminated RTDB connection monitor',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      const identity = RoomSessionIdentity(
        uid: 'resume-rtdb',
        role: 'player',
        roomCode: 'RESUME',
        roomInstanceId: 'room',
        membershipId: 'member',
        connectionId: 'current',
        connectionSeq: 1,
      );
      await RoomSessionIdentityStore.instance.save(identity);
      final service = _RecoveryService(identity, _Database())
        ..connectWhenRealtimeResumes = true;
      final provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.connected.close();
        await RoomSessionIdentityStore.instance.clear(
          identity.uid,
          identity.role,
          identity.roomCode,
        );
      });

      provider.didChangeAppLifecycleState(AppLifecycleState.paused);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _waitUntil(() => service.playerRestores == 1);
      final session = GameRecoverySession.forRoom(
        identity.roomCode,
        identity.uid,
      );
      await _waitUntil(() => !session.transportRecovering);

      expect(service.realtimeResumes, greaterThanOrEqualTo(1));
      expect(provider.isServerConnected, true);
      expect(provider.connectionRecoveryFailed, false);
    },
  );

  test(
    'inactive-resumed probes with one heartbeat without locking input',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      const identity = RoomSessionIdentity(
        uid: 'foreground-probe',
        role: 'player',
        roomCode: 'PROBE',
        roomInstanceId: 'room',
        membershipId: 'member',
        connectionId: 'current',
        connectionSeq: 1,
      );
      await RoomSessionIdentityStore.instance.save(identity);
      final service = _RecoveryService(identity, _Database());
      final provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.connected.close();
        await RoomSessionIdentityStore.instance.clear(
          identity.uid,
          identity.role,
          identity.roomCode,
        );
      });
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      await provider.retryConnectionRecovery();
      await Future<void>.delayed(Duration.zero);
      final heartbeatsBeforeResume = service.playerHeartbeats;
      final readsBeforeResume = service.playerReads;
      final revisionBeforeResume = provider.foregroundRefreshRevision;
      expect(service.playerRestores, 1);
      final session = GameRecoverySession.forRoom(
        identity.roomCode,
        identity.uid,
      );
      var invalidations = 0;
      void countInvalidation() {
        if (session.transportRecovering) invalidations++;
      }

      session.addListener(countInvalidation);
      addTearDown(() => session.removeListener(countInvalidation));

      // 알림·제어 센터처럼 앱이 화면에서 내려가지 않은 짧은 가림입니다.
      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(session.transportRecovering, false);
      await _waitUntil(
        () => service.playerHeartbeats == heartbeatsBeforeResume + 1,
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        service.playerRestores,
        1,
        reason: 'a valid server heartbeat keeps the existing connection id',
      );
      expect(
        service.playerReads,
        readsBeforeResume,
        reason: 'the short return does not re-read the server summary',
      );
      expect(invalidations, 0, reason: 'game input is never locked');
      expect(
        provider.foregroundRefreshRevision,
        revisionBeforeResume,
        reason: 'live subscriptions are not reopened',
      );
      expect(provider.players.single.isConnected, true);
      expect(
        GameRecoverySession.forRoom(
          identity.roomCode,
          identity.uid,
        ).transportRecovering,
        false,
      );
    },
  );

  test(
    'brief app switching preserves presence and a real pause reconnects once',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      const identity = RoomSessionIdentity(
        uid: 'lifecycle-sequence',
        role: 'player',
        roomCode: 'LIFE1',
        roomInstanceId: 'room',
        membershipId: 'member',
        connectionId: 'current',
        connectionSeq: 1,
      );
      await RoomSessionIdentityStore.instance.save(identity);
      final database = _Database();
      final service = _RecoveryService(identity, database);
      final provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.connected.close();
        await RoomSessionIdentityStore.instance.clear(
          identity.uid,
          identity.role,
          identity.roomCode,
        );
      });
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      await provider.retryConnectionRecovery();
      expect(service.playerRestores, 1);
      final initialRevision = provider.foregroundRefreshRevision;

      // Notification shade, app switcher, or a very short SNS check can stop
      // rendering without the OS fully pausing the process. This path must not
      // publish a false disconnect or allocate a new connection identity.
      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(provider.isAppForeground, false);
      expect(database.disconnectWrites, 0);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _waitUntil(
        () => provider.foregroundRefreshRevision > initialRevision,
      );
      expect(service.playerRestores, 1);
      expect(database.disconnectWrites, 0);
      expect(provider.isAppForeground, true);

      final briefSwitchRevision = provider.foregroundRefreshRevision;
      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.hidden);
      provider.didChangeAppLifecycleState(AppLifecycleState.paused);
      provider.didChangeAppLifecycleState(AppLifecycleState.hidden);
      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      expect(database.disconnectWrites, 1);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _waitUntil(
        () => provider.foregroundRefreshRevision > briefSwitchRevision,
      );
      expect(
        service.playerRestores,
        2,
        reason: 'a full pause allocates exactly one replacement connection',
      );
      expect(database.disconnectWrites, 1);
      expect(provider.isAppForeground, true);
    },
  );

  test('resumed recovery waits until RTDB reports a live connection', () async {
    SharedPreferences.setMockInitialValues({});
    await ControllerRoomSessionStore.instance.clear();
    const identity = RoomSessionIdentity(
      uid: 'offline-resume',
      role: 'player',
      roomCode: 'LIFE2',
      roomInstanceId: 'room',
      membershipId: 'member',
      connectionId: 'current',
      connectionSeq: 1,
    );
    await RoomSessionIdentityStore.instance.save(identity);
    final service = _RecoveryService(identity, _Database());
    final provider =
        RoomProvider(
            service: service,
            gameService: _UnusedGameService(),
            currentUidReader: () => identity.uid,
          )
          ..roomCode = identity.roomCode
          ..players = [
            RoomPlayer.fromJson({
              'nickname': 'Tester',
              'characterId': 'frog',
            }, key: identity.uid),
          ]
          ..listenRoom();
    addTearDown(() async {
      provider.dispose();
      await service.connected.close();
      await RoomSessionIdentityStore.instance.clear(
        identity.uid,
        identity.role,
        identity.roomCode,
      );
    });
    service.connected.add(true);
    await Future<void>.delayed(Duration.zero);
    await provider.retryConnectionRecovery();
    expect(service.playerRestores, 1);

    service.connected.add(false);
    await Future<void>.delayed(Duration.zero);
    provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
    provider.didChangeAppLifecycleState(AppLifecycleState.hidden);
    provider.didChangeAppLifecycleState(AppLifecycleState.paused);
    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(service.playerRestores, 1);
    expect(provider.isAppForeground, true);

    final revision = provider.foregroundRefreshRevision;
    service.connected.add(true);
    await _waitUntil(() => provider.foregroundRefreshRevision > revision);
    expect(service.playerRestores, 2);
    expect(
      GameRecoverySession.forRoom(
        identity.roomCode,
        identity.uid,
      ).transportRecovering,
      false,
    );
  });

  test('room join preview is reopened after returning to foreground', () async {
    SharedPreferences.setMockInitialValues({});
    const identity = RoomSessionIdentity(
      uid: 'preview-resume',
      role: 'player',
      roomCode: 'ENTRY',
      roomInstanceId: 'room',
      membershipId: 'member',
      connectionId: 'current',
      connectionSeq: 1,
    );
    final service = _RecoveryService(identity, _Database());
    final provider = RoomProvider(
      service: service,
      gameService: _UnusedGameService(),
      currentUidReader: () => identity.uid,
    );
    addTearDown(() async {
      provider.dispose();
      await service.connected.close();
    });

    provider.listenRoomPreview(identity.roomCode);
    await Future<void>.delayed(Duration.zero);
    expect(service.previewWatchCalls, 1);
    // 짧은 가림은 살아 있는 미리보기를 다시 열지 않아 화면이 깜빡이지 않습니다.
    provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(service.previewWatchCalls, 1);
    // 앱이 실제로 화면에서 내려갔다 오면 새로 엽니다.
    provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
    provider.didChangeAppLifecycleState(AppLifecycleState.hidden);
    provider.didChangeAppLifecycleState(AppLifecycleState.paused);
    provider.didChangeAppLifecycleState(AppLifecycleState.hidden);
    provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(service.previewWatchCalls, 2);
  });

  test(
    'inactive-resumed replaces a stale connection after heartbeat rejection',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      const identity = RoomSessionIdentity(
        uid: 'foreground-stale',
        role: 'player',
        roomCode: 'STALE',
        roomInstanceId: 'room',
        membershipId: 'member',
        connectionId: 'current',
        connectionSeq: 1,
      );
      await RoomSessionIdentityStore.instance.save(identity);
      final service = _RecoveryService(identity, _Database());
      final provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.connected.close();
        await RoomSessionIdentityStore.instance.clear(
          identity.uid,
          identity.role,
          identity.roomCode,
        );
      });
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      await provider.retryConnectionRecovery();
      await Future<void>.delayed(Duration.zero);
      expect(service.playerRestores, 1);
      service
        ..playerConnected = false
        ..playerHeartbeatFailures = 1;

      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await provider.retryConnectionRecovery();

      expect(
        service.playerRestores,
        2,
        reason: 'a rejected stale heartbeat must fall back to server resume',
      );
      expect(
        GameRecoverySession.forRoom(
          identity.roomCode,
          identity.uid,
        ).transportRecovering,
        false,
      );
      expect(provider.players.single.isConnected, true);
    },
  );

  test(
    'recovery stays locked until the server player summary confirms connected',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      const identity = RoomSessionIdentity(
        uid: 'summary-confirmation',
        role: 'player',
        roomCode: 'VERIFY',
        roomInstanceId: 'room',
        membershipId: 'member',
        connectionId: 'current',
        connectionSeq: 1,
      );
      await RoomSessionIdentityStore.instance.save(identity);
      final service = _RecoveryService(identity, _Database());
      final provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..playerSummaryConfirmRetryDelays = const [Duration.zero]
            ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.connected.close();
        await RoomSessionIdentityStore.instance.clear(
          identity.uid,
          identity.role,
          identity.roomCode,
        );
      });
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      await provider.retryConnectionRecovery();

      service
        ..playerConnected = false
        ..keepPlayerDisconnectedAfterRestore = true
        ..playerHeartbeatFailures = 1;
      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      final session = GameRecoverySession.forRoom(
        identity.roomCode,
        identity.uid,
      );
      await _waitUntil(() => session.recoveryError != null);

      expect(session.transportRecovering, true);
      expect(provider.errorMessage, contains('눌러 다시 연결'));
      expect(provider.connectionRecoveryFailed, true);

      service.keepPlayerDisconnectedAfterRestore = false;
      await provider.retryConnectionRecovery();
      expect(session.transportRecovering, false);
      expect(session.recoveryError, isNull);
      expect(provider.errorMessage, isNull);
      expect(provider.connectionRecoveryFailed, false);
      expect(provider.players.single.isConnected, true);
    },
  );

  test(
    'stale RTDB identity permission denial retries the bounded recovery',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      const identity = RoomSessionIdentity(
        uid: 'stale-rtdb-identity',
        role: 'player',
        roomCode: 'STALE',
        roomInstanceId: 'room',
        membershipId: 'member',
        connectionId: 'current',
        connectionSeq: 1,
      );
      await RoomSessionIdentityStore.instance.save(identity);
      final service = _RecoveryService(identity, _Database());
      final provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.connected.close();
        await RoomSessionIdentityStore.instance.clear(
          identity.uid,
          identity.role,
          identity.roomCode,
        );
      });
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      await provider.retryConnectionRecovery();
      await _waitUntil(() => service.playerHeartbeats >= 2);
      final restoresBefore = service.playerRestores;
      final heartbeatsBefore = service.playerHeartbeats;

      service.permissionDeniedHeartbeats = 1;
      provider.didChangeAppLifecycleState(AppLifecycleState.paused);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await provider.retryConnectionRecovery();

      expect(service.playerRestores, restoresBefore + 2);
      expect(
        service.playerHeartbeats,
        greaterThanOrEqualTo(heartbeatsBefore + 2),
      );
      expect(provider.connectionRecoveryFailed, false);
      expect(
        GameRecoverySession.forRoom(
          identity.roomCode,
          identity.uid,
        ).transportRecovering,
        false,
      );
    },
  );

  test(
    'an offline lobby leave exits at once and reaches the server after reconnect',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      RoomLeaveIntent.resetForTesting();
      DeferredRoomLeave.resetForTesting();
      const identity = RoomSessionIdentity(
        uid: 'offline-leave',
        role: 'player',
        roomCode: 'OFFLNE',
        roomInstanceId: 'room',
        membershipId: 'member',
        connectionId: 'current',
        connectionSeq: 1,
      );
      await RoomSessionIdentityStore.instance.save(identity);
      final service = _RecoveryService(identity, _Database());
      final provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        DeferredRoomLeave.resetForTesting();
        RoomLeaveIntent.resetForTesting();
        await service.connected.close();
        await RoomSessionIdentityStore.instance.clear(
          identity.uid,
          identity.role,
          identity.roomCode,
        );
      });
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      await provider.retryConnectionRecovery();

      // 인터넷이 끊긴 상태에서 띠의 나가기를 누릅니다.
      service.connected.add(false);
      await Future<void>.delayed(Duration.zero);
      service.leaveFailures = 1;
      final restoresBefore = service.playerRestores;

      expect(await provider.leaveRoomDeferred(), true);
      expect(provider.roomCode, isNull, reason: 'the device leaves at once');
      expect(RoomLeaveIntent.blocksRestore(identity.roomCode), true);
      await _waitUntil(() => service.leaveCalls == 1);
      expect(DeferredRoomLeave.isPending(identity.roomCode), true);
      expect(RoomLeaveIntent.hasLeft(identity.roomCode), false);

      // 연결이 돌아오면 화면 없이도 서버 퇴장을 마무리하고, 다시 참가하지 않습니다.
      service.connected.add(true);
      await _waitUntil(() => RoomLeaveIntent.hasLeft(identity.roomCode));
      expect(service.leaveCalls, 2);
      expect(DeferredRoomLeave.isPending(identity.roomCode), false);
      expect(service.playerRestores, restoresBefore);
    },
  );

  test(
    'a failed recovery retries automatically without a tap, a bounded number of times',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      const identity = RoomSessionIdentity(
        uid: 'auto-retry',
        role: 'player',
        roomCode: 'AUTORT',
        roomInstanceId: 'room',
        membershipId: 'member',
        connectionId: 'current',
        connectionSeq: 1,
      );
      await RoomSessionIdentityStore.instance.save(identity);
      final service = _RecoveryService(identity, _Database());
      final provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..playerSummaryConfirmRetryDelays = const []
            ..recoveryAutoRetryDelays = const [
              Duration(milliseconds: 20),
              Duration(milliseconds: 20),
            ]
            ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.connected.close();
        await RoomSessionIdentityStore.instance.clear(
          identity.uid,
          identity.role,
          identity.roomCode,
        );
      });
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      await provider.retryConnectionRecovery();
      final session = GameRecoverySession.forRoom(
        identity.roomCode,
        identity.uid,
      );

      // 서버 확인이 계속 실패하면 최초 1회 + 자동 2회만 시도하고 멈춥니다.
      service
        ..playerConnected = false
        ..keepPlayerDisconnectedAfterRestore = true
        ..playerHeartbeatFailures = 1;
      final restoresBefore = service.playerRestores;
      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _waitUntil(() => service.playerRestores == restoresBefore + 3);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(service.playerRestores, restoresBefore + 3);
      expect(provider.connectionRecoveryFailed, true);
      expect(session.transportRecovering, true);

      // 다음 복귀는 새 회차입니다. 서버가 정상으로 돌아오면 누르지 않아도 풀립니다.
      service.playerHeartbeatFailures = 1;
      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _waitUntil(() => provider.connectionRecoveryFailed);
      service.keepPlayerDisconnectedAfterRestore = false;
      await _waitUntil(() => session.transportRecovering == false);
      expect(provider.connectionRecoveryFailed, false);
      expect(provider.errorMessage, isNull);
    },
  );

  test(
    'a lagging server summary is re-read without allocating another connection',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      const identity = RoomSessionIdentity(
        uid: 'summary-lag',
        role: 'player',
        roomCode: 'LAGGED',
        roomInstanceId: 'room',
        membershipId: 'member',
        connectionId: 'current',
        connectionSeq: 1,
      );
      await RoomSessionIdentityStore.instance.save(identity);
      final service = _RecoveryService(identity, _Database());
      final provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..playerSummaryConfirmRetryDelays = const [
              Duration.zero,
              Duration.zero,
            ]
            ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.connected.close();
        await RoomSessionIdentityStore.instance.clear(
          identity.uid,
          identity.role,
          identity.roomCode,
        );
      });
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      await provider.retryConnectionRecovery();
      final restoresBefore = service.playerRestores;
      final session = GameRecoverySession.forRoom(
        identity.roomCode,
        identity.uid,
      );

      // 실제 background를 거쳐 새 접속을 할당받은 직후, 서버 요약 읽기가 두 번
      // 이전 값을 돌려줍니다.
      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.hidden);
      provider.didChangeAppLifecycleState(AppLifecycleState.paused);
      service.staleSummaryReads = 2;
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _waitUntil(() => session.transportRecovering == false);

      expect(service.staleSummaryReads, 0);
      expect(
        service.playerRestores,
        restoresBefore + 1,
        reason: 'the summary is re-read under the same connection identity',
      );
      expect(provider.connectionRecoveryFailed, false);
      expect(provider.errorMessage, isNull);
    },
  );

  test(
    'foreground recovery uses the saved profile before players replay',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      const identity = RoomSessionIdentity(
        uid: 'saved-profile',
        role: 'player',
        roomCode: 'SAVED',
        roomInstanceId: 'room',
        membershipId: 'member',
        connectionId: 'current',
        connectionSeq: 1,
      );
      await RoomSessionIdentityStore.instance.save(identity);
      await PlayerRoomSessionStore.instance.save(
        uid: identity.uid,
        roomCode: identity.roomCode,
        nickname: 'Stored player',
        characterId: 'frog',
      );
      final service = _RecoveryService(identity, _Database());
      final provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.connected.close();
        await PlayerRoomSessionStore.instance.clear(
          onlyRoomCode: identity.roomCode,
        );
        await RoomSessionIdentityStore.instance.clear(
          identity.uid,
          identity.role,
          identity.roomCode,
        );
      });
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);

      await provider.retryConnectionRecovery();

      expect(service.playerRestores, 1);
      expect(provider.connectionRecoveryFailed, false);
      expect(
        GameRecoverySession.forRoom(
          identity.roomCode,
          identity.uid,
        ).transportRecovering,
        false,
      );
    },
  );

  test(
    'a connection flap during foreground recovery still refreshes subscriptions',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      const identity = RoomSessionIdentity(
        uid: 'foreground-flap',
        role: 'player',
        roomCode: 'FLAPPY',
        roomInstanceId: 'room',
        membershipId: 'member',
        connectionId: 'current',
        connectionSeq: 1,
      );
      await RoomSessionIdentityStore.instance.save(identity);
      final service = _RecoveryService(identity, _Database());
      final provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.connected.close();
        await RoomSessionIdentityStore.instance.clear(
          identity.uid,
          identity.role,
          identity.roomCode,
        );
      });
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      await provider.retryConnectionRecovery();
      final revisionBefore = provider.foregroundRefreshRevision;
      final heartbeatsBefore = service.playerHeartbeats;
      final probe = Completer<void>();
      service.playerHeartbeatGate = probe;
      final session = GameRecoverySession.forRoom(
        identity.roomCode,
        identity.uid,
      );

      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _waitUntil(() => service.playerHeartbeats == heartbeatsBefore + 1);

      // 복귀 직후 오래된 소켓이 끊겼다가 다시 붙는 동안 첫 확인이 끝납니다.
      service.connected.add(false);
      await Future<void>.delayed(Duration.zero);
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      probe.complete();
      await _waitUntil(
        () => provider.foregroundRefreshRevision > revisionBefore,
      );

      expect(session.transportRecovering, false);
      expect(session.recoveryRetrying, false);
      expect(provider.connectionRecoveryFailed, false);
    },
  );

  testWidgets('lobby retry band restarts a failed room recovery', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const identity = RoomSessionIdentity(
      uid: 'retry-band',
      role: 'player',
      roomCode: 'BANDED',
      roomInstanceId: 'room',
      membershipId: 'member',
      connectionId: 'current',
      connectionSeq: 1,
    );
    late _RecoveryService service;
    late RoomProvider provider;
    await tester.runAsync(() async {
      await ControllerRoomSessionStore.instance.clear();
      await RoomSessionIdentityStore.instance.save(identity);
      service = _RecoveryService(identity, _Database());
      provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..playerSummaryConfirmRetryDelays = const []
            ..listenRoom();
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      await provider.retryConnectionRecovery();
      service
        ..playerConnected = false
        ..keepPlayerDisconnectedAfterRestore = true
        ..playerHeartbeatFailures = 1;
      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _waitUntil(() => provider.connectionRecoveryFailed);
    });
    addTearDown(() async {
      provider.dispose();
      await service.connected.close();
      await RoomSessionIdentityStore.instance.clear(
        identity.uid,
        identity.role,
        identity.roomCode,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RoomRecoveryRetryBand(provider: provider)),
      ),
    );
    final band = find.byKey(const ValueKey('room-recovery-retry-band'));
    final surface = find.byKey(const ValueKey('room-recovery-retry-surface'));
    expect(band, findsOneWidget);
    expect(surface, findsOneWidget);
    expect(tester.getSize(surface), const Size(800, 600));

    final restoresBefore = service.playerRestores;
    final retryGate = Completer<void>();
    service
      ..keepPlayerDisconnectedAfterRestore = false
      ..playerRestore = retryGate;
    await tester.runAsync(() async {
      // 하단 띠가 아닌 화면 위쪽도 같은 복구 동작을 시작합니다.
      await tester.tapAt(const Offset(40, 40));
      await _waitUntil(() => service.playerRestores > restoresBefore);
    });
    await tester.pump();
    expect(find.text('최신 상황을 불러오는 중…'), findsOneWidget);

    // 복구 중 다른 위치를 연속으로 눌러도 같은 요청 하나만 유지합니다.
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    expect(service.playerRestores, restoresBefore + 1);

    retryGate.complete();
    await tester.runAsync(() async {
      await _waitUntil(() => !provider.connectionRecoveryFailed);
      await _waitUntil(
        () =>
            GameRecoverySession.forRoom(
              identity.roomCode,
              identity.uid,
            ).transportRecovering ==
            false,
      );
    });
    await tester.pump();

    expect(service.playerRestores, greaterThan(restoresBefore));
    expect(provider.errorMessage, isNull);
    expect(band, findsNothing);
    expect(surface, findsNothing);
  });

  testWidgets('successful room retry clears the stale network recovery band', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const identity = RoomSessionIdentity(
      uid: 'guard-auto-retry',
      role: 'player',
      roomCode: 'GUARDR',
      roomInstanceId: 'room',
      membershipId: 'member',
      connectionId: 'current',
      connectionSeq: 1,
    );
    late _RecoveryService service;
    late RoomProvider provider;
    await tester.runAsync(() async {
      await ControllerRoomSessionStore.instance.clear();
      await RoomSessionIdentityStore.instance.save(identity);
      service = _RecoveryService(identity, _Database());
      provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..playerSummaryConfirmRetryDelays = const []
            ..recoveryAutoRetryDelays = const []
            ..listenRoom();
    });
    addTearDown(() async {
      provider.dispose();
      await service.connected.close();
      await RoomSessionIdentityStore.instance.clear(
        identity.uid,
        identity.role,
        identity.roomCode,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CriticalNetworkGuard(
            provider: provider,
            child: const Text('대기실'),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      await provider.retryConnectionRecovery();

      service.connected.add(false);
      await Future<void>.delayed(Duration.zero);
      service
        ..playerConnected = false
        ..keepPlayerDisconnectedAfterRestore = true;
      service.connected.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.textContaining('연결을 복구하지 못했어요'), findsOneWidget);

    await tester.runAsync(() async {
      service.keepPlayerDisconnectedAfterRestore = false;
      await provider.retryConnectionRecovery();
      await _waitUntil(
        () =>
            GameRecoverySession.forRoom(
              identity.roomCode,
              identity.uid,
            ).transportRecovering ==
            false,
      );
    });
    await tester.pump();
    await tester.pump();

    expect(provider.players.single.isConnected, true);
    expect(find.textContaining('연결을 복구하지 못했어요'), findsNothing);
    expect(find.byType(MosiConnectionBand), findsNothing);
  });

  test(
    'a newer inactive-resumed cycle is validated after an active recovery',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      const identity = RoomSessionIdentity(
        uid: 'foreground-repeat',
        role: 'player',
        roomCode: 'REPEAT',
        roomInstanceId: 'room',
        membershipId: 'member',
        connectionId: 'current',
        connectionSeq: 1,
      );
      await RoomSessionIdentityStore.instance.save(identity);
      final service = _RecoveryService(identity, _Database());
      final provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.connected.close();
        await RoomSessionIdentityStore.instance.clear(
          identity.uid,
          identity.role,
          identity.roomCode,
        );
      });
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      await provider.retryConnectionRecovery();
      final heartbeatsBeforeResume = service.playerHeartbeats;
      final firstProbe = Completer<void>();
      service.playerHeartbeatGate = firstProbe;

      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _waitUntil(
        () => service.playerHeartbeats == heartbeatsBeforeResume + 1,
      );

      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      firstProbe.complete();
      await _waitUntil(
        () => service.playerHeartbeats >= heartbeatsBeforeResume + 2,
      );

      expect(
        service.playerRestores,
        1,
        reason: 'both foreground probes can keep the valid connection id',
      );
      expect(
        GameRecoverySession.forRoom(
          identity.roomCode,
          identity.uid,
        ).transportRecovering,
        false,
      );
    },
  );

  test(
    'a newer foreground cycle retries after the active recovery fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      const identity = RoomSessionIdentity(
        uid: 'foreground-failure',
        role: 'player',
        roomCode: 'RETRY',
        roomInstanceId: 'room',
        membershipId: 'member',
        connectionId: 'current',
        connectionSeq: 1,
      );
      await RoomSessionIdentityStore.instance.save(identity);
      final service = _RecoveryService(identity, _Database());
      final provider =
          RoomProvider(
              service: service,
              gameService: _UnusedGameService(),
              currentUidReader: () => identity.uid,
            )
            ..roomCode = identity.roomCode
            ..players = [
              RoomPlayer.fromJson({
                'nickname': 'Tester',
                'characterId': 'frog',
              }, key: identity.uid),
            ]
            ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.connected.close();
        await RoomSessionIdentityStore.instance.clear(
          identity.uid,
          identity.role,
          identity.roomCode,
        );
      });
      service.connected.add(true);
      await Future<void>.delayed(Duration.zero);
      await provider.retryConnectionRecovery();
      // Let the immediate post-recovery heartbeat finish before arranging the
      // foreground probe below.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final heartbeatsBeforeResume = service.playerHeartbeats;
      final firstRestore = Completer<void>();
      service
        ..playerHeartbeatFailures = 1
        ..playerRestore = firstRestore;

      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _waitUntil(() => service.playerRestores == 2);

      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      service.playerRestoreFailures = 1;
      firstRestore.complete();
      await _waitUntil(
        () => service.playerHeartbeats >= heartbeatsBeforeResume + 2,
      );
      await _waitUntil(
        () => !GameRecoverySession.forRoom(
          identity.roomCode,
          identity.uid,
        ).transportRecovering,
      );

      expect(service.playerRestores, 2);
      expect(
        GameRecoverySession.forRoom(
          identity.roomCode,
          identity.uid,
        ).recoveryError,
        isNull,
      );
    },
  );

  test('invalidated controller restore cannot start player heartbeats', () async {
    SharedPreferences.setMockInitialValues({});
    const identity = RoomSessionIdentity(
      uid: 'stale-controller',
      role: 'controller',
      roomCode: 'STALE',
      roomInstanceId: 'stale-room',
      connectionId: 'controller-connection',
      connectionSeq: 1,
      controllerSessionId: 'old-controller-session',
    );
    await RoomSessionIdentityStore.instance.save(identity);
    // The same tablet account can also be a player; losing its controller token
    // must not silently switch the heartbeat role during controller recovery.
    await RoomSessionIdentityStore.instance.save(
      const RoomSessionIdentity(
        uid: 'stale-controller',
        role: 'player',
        roomCode: 'STALE',
        roomInstanceId: 'stale-room',
        connectionId: 'player-connection',
        connectionSeq: 1,
        membershipId: 'member',
      ),
    );
    await ControllerRoomSessionStore.instance.save(
      roomCode: identity.roomCode,
      sessionId: identity.controllerSessionId!,
    );
    final database = _Database();
    final service = _RecoveryService(identity, database)
      ..afterControllerRestore = ControllerRoomSessionStore.instance.clear;
    final provider = RoomProvider(
      service: service,
      gameService: _UnusedGameService(),
      currentUidReader: () => identity.uid,
    )..roomCode = identity.roomCode;
    addTearDown(() async {
      provider.dispose();
      await service.connected.close();
      await RoomSessionIdentityStore.instance.clear(
        identity.uid,
        'controller',
        identity.roomCode,
      );
      await RoomSessionIdentityStore.instance.clear(
        identity.uid,
        'player',
        identity.roomCode,
      );
      await ControllerRoomSessionStore.instance.clear();
    });
    provider.listenRoom();
    service.connected.add(true);
    await Future<void>.delayed(Duration.zero);
    await provider.retryConnectionRecovery();
    await Future<void>.delayed(const Duration(seconds: 11));
    expect(database.paths, isEmpty);
  });

  test(
    'controller and player keep writing heartbeats after recovery budget expires',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      final services = <_RecoveryService>[];
      final providers = <RoomProvider>[];
      addTearDown(() async {
        for (final provider in providers) {
          provider.dispose();
        }
        for (final service in services) {
          await service.connected.close();
          await RoomSessionIdentityStore.instance.clear(
            service.identity.uid,
            service.identity.role,
            service.identity.roomCode,
          );
        }
        await ControllerRoomSessionStore.instance.clear();
      });

      for (final role in ['controller', 'player']) {
        final identity = RoomSessionIdentity(
          uid: 'heartbeat-$role',
          role: role,
          roomCode: role == 'controller' ? 'HEART' : 'BEATS',
          roomInstanceId: 'room-$role',
          membershipId: role == 'player' ? 'member' : null,
          controllerSessionId: role == 'controller'
              ? 'controller-session'
              : null,
          connectionId: 'connection-$role',
          connectionSeq: 1,
        );
        await RoomSessionIdentityStore.instance.save(identity);
        if (role == 'controller') {
          await ControllerRoomSessionStore.instance.save(
            roomCode: identity.roomCode,
            sessionId: identity.controllerSessionId!,
          );
        }
        final database = _Database();
        final service = _RecoveryService(identity, database);
        services.add(service);
        final provider =
            RoomProvider(
                service: service,
                gameService: _UnusedGameService(),
                currentUidReader: () => identity.uid,
              )
              ..roomCode = identity.roomCode
              ..players = [
                RoomPlayer.fromJson({'nickname': 'Tester'}, key: identity.uid),
              ]
              ..listenRoom();
        providers.add(provider);
        service.connected.add(true);
        await Future<void>.delayed(Duration.zero);
        var parentElapsed = Duration.zero;
        final parent = RoomRecoveryBatch(elapsed: () => parentElapsed);
        await parent.run(
          provider.retryConnectionRecovery,
          isCurrent: () => true,
          retryable: (_) => false,
        );
        parentElapsed = const Duration(seconds: 31);
        database.recoveryOwner = service.recoveryOwner;
        expect(service.recoveryOwner, isNotNull);
      }

      // Use wall-clock time: RoomRecoveryBatch's Stopwatch is not FakeAsync time.
      // Both roles use the real RoomService identity lookup and write/retry path.
      await Future<void>.delayed(const Duration(seconds: 32));
      for (final service in services) {
        expect(
          service.recoveryOwner!.remaining,
          lessThanOrEqualTo(Duration.zero),
        );
        expect(
          service.database.writesAfterDeadline,
          greaterThan(0),
          reason:
              '${service.identity.role} must outlive the recovery operation',
        );
        expect(
          service.database.ownersAtWrite.first,
          same(service.recoveryOwner),
          reason:
              'Recovery confirms one heartbeat inside its owner before ready',
        );
        expect(service.database.ownersAtWrite.skip(1), everyElement(isNull));
        expect(
          service.database.paths,
          everyElement(
            'rooms/${service.identity.roomCode}/connections/${service.identity.uid}/${service.identity.connectionId}/lastSeen',
          ),
        );
      }
    },
    timeout: const Timeout(Duration(seconds: 55)),
  );

  for (final tokenCleared in [true, false]) {
    test(
      'null controller restore clears the room only after token removal: $tokenCleared',
      () async {
        SharedPreferences.setMockInitialValues({});
        const identity = RoomSessionIdentity(
          uid: 'closed-controller',
          role: 'controller',
          roomCode: 'CLOSE',
          roomInstanceId: 'closed-room',
          connectionId: 'connection',
          connectionSeq: 1,
          controllerSessionId: 'controller-session',
        );
        await RoomSessionIdentityStore.instance.save(identity);
        await ControllerRoomSessionStore.instance.save(
          roomCode: identity.roomCode,
          sessionId: identity.controllerSessionId!,
        );
        final database = _Database();
        final service = _RecoveryService(identity, database)
          ..controllerClosed = true;
        if (tokenCleared) {
          service.afterControllerRestore =
              ControllerRoomSessionStore.instance.clear;
        }
        final provider = RoomProvider(
          service: service,
          gameService: _UnusedGameService(),
          currentUidReader: () => identity.uid,
        )..roomCode = identity.roomCode;
        addTearDown(() async {
          provider.dispose();
          await service.connected.close();
          await RoomSessionIdentityStore.instance.clear(
            identity.uid,
            identity.role,
            identity.roomCode,
          );
          await ControllerRoomSessionStore.instance.clear();
        });
        provider.listenRoom();
        service.connected.add(true);
        await Future<void>.delayed(Duration.zero);
        await provider.retryConnectionRecovery();
        expect(provider.roomCode, tokenCleared ? null : identity.roomCode);
        expect(provider.wasRoomClosed, tokenCleared);
        if (tokenCleared) expect(database.paths, isEmpty);
      },
    );
  }
}

class _RecoveryService extends RoomService {
  _RecoveryService(this.identity, this.database)
    : super(
        database: database,
        auth: _Auth(identity.uid),
        functions: _Functions(),
      );

  final RoomSessionIdentity identity;
  final _Database database;
  final connected = StreamController<bool>.broadcast();
  final peerPlayers = StreamController<List<RoomPlayer>>.broadcast();
  RoomRecoveryBatch? recoveryOwner;
  bool controllerClosed = false;
  Future<void> Function()? afterControllerRestore;
  Completer<void>? playerRestore;
  int playerRestores = 0;
  int playerRestoreFailures = 0;
  int playerHeartbeats = 0;
  int playerHeartbeatFailures = 0;
  int permissionDeniedHeartbeats = 0;
  int playerReads = 0;
  bool playerConnected = true;
  bool keepPlayerDisconnectedAfterRestore = false;
  int staleSummaryReads = 0;
  int leaveCalls = 0;
  int leaveFailures = 0;
  int realtimeResumes = 0;
  bool connectWhenRealtimeResumes = false;

  @override
  Future<void> leaveRoom(String roomCode) async {
    leaveCalls++;
    if (leaveFailures > 0) {
      leaveFailures--;
      throw StateError('offline');
    }
  }

  Completer<void>? playerHeartbeatGate;
  int previewWatchCalls = 0;

  @override
  Future<void> resumeRealtimeConnection() async {
    realtimeResumes++;
    if (connectWhenRealtimeResumes) {
      connected.add(true);
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<String?> restoreControllerRoom() async {
    recoveryOwner = RoomRecoveryBatch.current;
    await afterControllerRestore?.call();
    return controllerClosed ? null : identity.roomCode;
  }

  @override
  Future<void> restorePlayerConnection({
    required String roomCode,
    required String nickname,
    required String characterId,
  }) async {
    recoveryOwner = RoomRecoveryBatch.current;
    playerRestores++;
    await playerRestore?.future;
    if (playerRestoreFailures > 0) {
      playerRestoreFailures--;
      throw StateError('restore failed');
    }
    playerConnected = !keepPlayerDisconnectedAfterRestore;
  }

  @override
  Future<void> heartbeatPlayer(String roomCode) async {
    playerHeartbeats++;
    final gate = playerHeartbeatGate;
    playerHeartbeatGate = null;
    await gate?.future;
    if (playerHeartbeatFailures > 0) {
      playerHeartbeatFailures--;
      throw StateError('stale connection');
    }
    if (permissionDeniedHeartbeats > 0) {
      permissionDeniedHeartbeats--;
      throw FirebaseException(
        plugin: 'firebase_database',
        code: 'permission-denied',
      );
    }
    if (!playerConnected) throw StateError('disconnected connection');
    await super.heartbeatPlayer(roomCode);
  }

  @override
  Future<RoomPlayer?> getRoomPlayer(String roomCode, String uid) async {
    playerReads++;
    final stale = staleSummaryReads > 0;
    if (stale) staleSummaryReads--;
    return RoomPlayer(
      uid: identity.uid,
      nickname: 'Tester',
      characterId: 'frog',
      isConnected: playerConnected && !stale,
      seatIndex: 0,
      role: 'player',
      status: 'active',
      membershipId: identity.membershipId,
      currentConnectionId: identity.connectionId,
      connectionSeq: identity.connectionSeq,
      penaltyAttemptCount: 0,
    );
  }

  @override
  Stream<bool> watchServerConnection() => connected.stream;
  @override
  Stream<ControllerPresence> watchControllerPresence(String roomCode) =>
      const Stream.empty();
  @override
  Stream<bool> watchRoomExists(String roomCode) => const Stream.empty();
  @override
  Stream<String?> watchRoomStatus(String roomCode) => const Stream.empty();
  @override
  Stream<DatabaseEvent> watchRoom(String roomCode) => const Stream.empty();
  @override
  Stream<List<RoomPlayer>> watchRoomPlayers(
    String roomCode, {
    bool observeCurrent = false,
    String? ownUid,
  }) => peerPlayers.stream;

  @override
  Stream<List<RoomPlayer>> watchRoomJoinPreview(String roomCode) {
    previewWatchCalls++;
    return Stream<List<RoomPlayer>>.value(const []);
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw TimeoutException('condition was not reached');
}

class _Database extends Fake implements FirebaseDatabase {
  RoomRecoveryBatch? recoveryOwner;
  int writesAfterDeadline = 0;
  final ownersAtWrite = <RoomRecoveryBatch?>[];
  final paths = <String>[];
  int disconnectWrites = 0;
  @override
  DatabaseReference ref([String? path]) => _Reference(this, path!);
}

class _Reference extends Fake implements DatabaseReference {
  _Reference(this.database, this.path);
  final _Database database;
  @override
  final String path;
  @override
  Future<void> update(Map<String, Object?> value) async {
    expect(value['connected'], false);
    expect(value['lastSeen'], ServerValue.timestamp);
    database.disconnectWrites++;
  }

  @override
  DatabaseReference child(String childPath) =>
      _Reference(database, '$path/$childPath');
  @override
  Future<void> set(Object? value) async {
    expect(value, ServerValue.timestamp);
    expect(path.endsWith('/lastSeen'), true);
    database.paths.add(path);
    database.ownersAtWrite.add(RoomRecoveryBatch.inherited);
    if ((database.recoveryOwner?.remaining ?? const Duration(seconds: 30)) <=
        Duration.zero) {
      database.writesAfterDeadline++;
    }
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(String uid) : currentUser = _User(uid);
  @override
  final User currentUser;
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _Functions extends Fake implements FirebaseFunctions {}

class _UnusedGameService extends Fake implements GameService {}
