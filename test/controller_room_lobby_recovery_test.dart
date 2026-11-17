import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:game_kit/recovery/services/controller_room_session_store.dart';
import 'package:game_kit/template_game.dart';
import 'package:project00/firebase_bootstrap.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/controller_presence.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_room_panel.dart';
import 'package:project00/platform/home/tablet/screens/tablet_home.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_lobby_layout.dart';
import 'package:project00/platform/widgets/app_startup_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(MockFirebaseApp());
  setUpAll(() async {
    await Firebase.initializeApp();
    if (FirebaseBackend.isTest) await initializeFirebaseBackend();
  });
  late _Service service;
  late RoomProvider provider;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ControllerRoomSessionStore.instance.clear();
    await ControllerRoomSessionStore.instance.save(
      roomCode: 'ABCDE',
      sessionId: 'controller-session',
    );
    service = _Service();
    provider = RoomProvider(
      service: service,
      gameService: _Games(),
      currentUidReader: () => 'tablet',
    );
  });
  tearDown(() async {
    provider.dispose();
    await service.players.close();
    await service.connection.close();
    await service.gameStatus.close();
    await ControllerRoomSessionStore.instance.clear();
  });

  test('saved controller room is restored before a new allocation', () async {
    service.failRestore = false;
    await provider.createRoom();
    expect(service.restores, 1);
    expect(service.creates, 0);
    expect(provider.roomCode, 'ABCDE');
  });

  testWidgets('태블릿 시작은 진행 중 게임을 묻지 않고 자동으로 연다', (tester) async {
    service
      ..failRestore = false
      ..activeGame = true;
    provider.selectedGameId = 'unknown-game';
    await tester.pumpWidget(
      MaterialApp(
        home: TabletHome(
          gameCatalog: const EmptyGameCatalog(),
          roomProvider: provider,
          gameProvider: _GameProvider(),
          storeProvider: _GameProvider(scope: GameListScope.store),
        ),
      ),
    );
    // ControllerRoomSessionStore/SharedPreferences는 FakeAsync 바깥 zone에서
    // 초기화되므로 복원 Future가 실제 event loop에서 완료될 시간을 줍니다.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    for (
      var attempt = 0;
      attempt < 20 && find.byType(AppStartupSurface).evaluate().isNotEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.text('진행 중인 게임이 있어요'), findsNothing);
    expect(find.text('게임으로 돌아가기'), findsNothing);
    expect(find.text('기존 방 종료'), findsNothing);
    expect(find.byType(AppStartupSurface), findsNothing);
    expect(find.byType(TabletLobbyLayout), findsOneWidget);
  });

  testWidgets('foreground recovery reopens the tablet game status stream', (
    tester,
  ) async {
    provider.dispose();
    provider = _ForegroundRoomProvider(
      service: service,
      gameService: _Games(),
      currentUidReader: () => 'tablet',
    );
    service.failRestore = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TabletHome(
          gameCatalog: const EmptyGameCatalog(),
          roomProvider: provider,
          gameProvider: _GameProvider(),
          storeProvider: _GameProvider(scope: GameListScope.store),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      service.gameStatus.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump(const Duration(milliseconds: 20));
    final initialWatches = service.gameStatusWatchCalls;
    expect(initialWatches, greaterThan(0));

    (provider as _ForegroundRoomProvider).completeForegroundRecovery();
    await tester.pump();
    expect(service.gameStatusWatchCalls, initialWatches + 1);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  test(
    'same-account player removal preserves controller room and session',
    () async {
      service.failRestore = false;
      await provider.restoreControllerRoom();
      service.connection.add(true);
      service.players.add([
        RoomPlayer.fromJson({'nickname': 'same-account'}, key: 'tablet'),
      ]);
      await Future<void>.delayed(Duration.zero);
      await provider.removePlayer('tablet');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(provider.roomCode, 'ABCDE');
      expect(provider.wasKicked, false);
      expect(service.playerReads, 0);
      expect(service.closedCodes, isEmpty);
      expect(ControllerRoomSessionStore.instance.roomCode, 'ABCDE');
      await provider.createRoom();
      expect(service.creates, 0);
    },
  );

  test(
    'player role still exits when its participant node is removed',
    () async {
      await ControllerRoomSessionStore.instance.clear();
      provider.roomCode = 'ABCDE';
      provider.listenRoom();
      service.connection.add(true);
      service.players.add([
        RoomPlayer.fromJson({'nickname': 'phone'}, key: 'tablet'),
      ]);
      await Future<void>.delayed(Duration.zero);
      service.players.add([]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(service.playerReads, 1);
      expect(provider.wasKicked, true);
      expect(provider.roomCode, isNull);
    },
  );

  test('late player removal cannot clear a restored controller', () async {
    service.failRestore = false;
    service.playerReadGate = Completer<bool>();
    provider.roomCode = 'ABCDE';
    provider.listenRoom();
    service.connection.add(true);
    service.players.add([
      RoomPlayer.fromJson({'nickname': 'phone'}, key: 'tablet'),
    ]);
    await Future<void>.delayed(Duration.zero);
    service.players.add([]);
    await Future<void>.delayed(Duration.zero);
    expect(service.playerReads, 1);
    provider.clearRoom();
    await provider.restoreControllerRoom();
    service.playerReadGate!.complete(false);
    await Future<void>.delayed(Duration.zero);
    expect(provider.roomCode, 'ABCDE');
    expect(provider.wasKicked, false);
  });

  test(
    'initial restore blocks allocation; failed restore retries the existing room',
    () async {
      service.gate = Completer<String?>();
      final restore = provider.restoreControllerRoom();
      await provider.createRoom();
      expect(service.creates, 0);
      expect(provider.isLoading, true);
      service.gate!.completeError(
        FirebaseFunctionsException(code: 'internal', message: 'server error'),
      );
      await restore;
      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNotNull);
      expect(ControllerRoomSessionStore.instance.roomCode, 'ABCDE');

      service.gate = null;
      service.failRestore = false;
      await provider.createRoom();
      expect(service.restores, 2);
      expect(service.creates, 0);
      expect(provider.roomCode, 'ABCDE');
      expect(provider.errorMessage, isNull);
    },
  );

  testWidgets(
    'failed restore offers retry and close; confirmed close allows a new invite',
    (tester) async {
      // Shared stores were initialized outside FakeAsync; use their owning zone.
      await tester.runAsync(provider.restoreControllerRoom);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 310,
              height: 800,
              child: TabletRoomPanel(provider: provider),
            ),
          ),
        ),
      );
      expect(find.text('초대하기'), findsNothing);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.byKey(const Key('close-unrestored-room')), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('close-unrestored-room')));
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(service.closedCodes, ['ABCDE']);
      expect(ControllerRoomSessionStore.instance.roomCode, isNull);
      expect(provider.errorMessage, isNull);
      expect(find.text('초대하기'), findsOneWidget);
      await tester.tap(find.text('초대하기'));
      await tester.pumpAndSettle();
      expect(service.creates, 1);
      expect(provider.roomCode, 'NEW12');
    },
  );

  test(
    'unconfirmed close preserves the stored room and cannot allocate a new room',
    () async {
      await provider.restoreControllerRoom();
      service.failClose = true;
      await provider.closeRoom();
      expect(ControllerRoomSessionStore.instance.roomCode, 'ABCDE');
      await provider.createRoom();
      expect(service.creates, 0);
      expect(provider.roomCode, isNull);
      expect(service.restores, 2);
    },
  );
}

class _Service implements RoomService {
  int restores = 0, creates = 0;
  int playerReads = 0;
  Completer<bool>? playerReadGate;
  final players = StreamController<List<RoomPlayer>>.broadcast();
  final connection = StreamController<bool>.broadcast();
  final gameStatus = StreamController<String?>.broadcast();
  int gameStatusWatchCalls = 0;
  bool activeGame = false;
  bool failRestore = true, failClose = false;
  Completer<String?>? gate;
  final closedCodes = <String>[];
  @override
  Future<String?> restoreControllerRoom() async {
    restores++;
    if (gate != null) return gate!.future;
    if (failRestore) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'server error',
      );
    }
    return 'ABCDE';
  }

  @override
  Future<String> createRoom({String? operationId}) async {
    creates++;
    return 'NEW12';
  }

  @override
  Future<void> closeControllerRoom(String code) async {
    closedCodes.add(code);
    if (failClose) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'server error',
      );
    }
    await ControllerRoomSessionStore.instance.clear(onlyRoomCode: code);
  }

  @override
  Stream<bool> watchServerConnection() => connection.stream;
  @override
  Stream<DatabaseEvent> watchRoom(String code) => const Stream.empty();
  @override
  Stream<List<RoomPlayer>> watchRoomPlayers(
    String code, {
    bool observeCurrent = false,
    String? ownUid,
  }) => players.stream;
  @override
  Future<void> removePlayer(String code, String uid) async {
    players.add([]);
  }

  @override
  Future<bool> roomExists(String code) async => true;
  @override
  Future<bool> hasActivePlayerNode(String code) async {
    playerReads++;
    return playerReadGate?.future ?? false;
  }

  @override
  Stream<String?> watchRoomStatus(String code) => const Stream.empty();
  @override
  Stream<String?> watchGameStatus(String code) {
    gameStatusWatchCalls++;
    return activeGame ? Stream<String?>.value('playing') : gameStatus.stream;
  }

  @override
  Stream<ControllerPresence> watchControllerPresence(String code) =>
      const Stream.empty();
  @override
  Stream<bool> watchRoomExists(String code) => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Games implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ForegroundRoomProvider extends RoomProvider {
  _ForegroundRoomProvider({
    required super.service,
    required super.gameService,
    required super.currentUidReader,
  });

  int _revision = 0;

  @override
  int get foregroundRefreshRevision => _revision;

  void completeForegroundRecovery() {
    _revision++;
    notifyListeners();
  }
}

class _GameProvider extends ChangeNotifier implements GameProvider {
  _GameProvider({this.scope = GameListScope.library});

  @override
  final GameListScope scope;
  @override
  final List<GameInfo> games = <GameInfo>[];
  @override
  bool isLoading = false;
  @override
  String? errorMessage;
  @override
  Future<void> fetchGames() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
