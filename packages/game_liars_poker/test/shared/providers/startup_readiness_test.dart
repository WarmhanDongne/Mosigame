import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';
import 'package:game_liars_poker/shared/models/game_state.dart';
import 'package:game_liars_poker/shared/providers/game_controller.dart';
import 'package:game_liars_poker/shared/services/command_service.dart';
import 'package:game_liars_poker/shared/services/game_service.dart';
import 'package:game_liars_poker/shared/services/query_service.dart';

void main() {
  var sessionNumber = 0;
  late ProviderContainer container;
  late _Query query;
  late _Reports reports;
  late _Commands commands;
  late LiarsPokerController game;
  void start() {
    query = _Query();
    reports = _Reports();
    commands = _Commands();
    container = ProviderContainer();
    final provider =
        NotifierProvider<LiarsPokerController, LiarsPokerGameState>(
          () => LiarsPokerController(
            roomCode: 'LPREADY${++sessionNumber}',
            uid: 'phone',
            service: LiarsPokerService(
              command: commands,
              query: query,
              interruption: reports,
            ),
          ),
        );
    container.listen(provider, (_, _) {});
    game = container.read(provider.notifier);
  }

  tearDown(() async {
    container.dispose();
    await query.pub.close();
    await query.priv.close();
  });

  testWidgets('dealing prepares assets and reports ready before hands exist', (
    tester,
  ) async {
    start();
    var dataReady = false;
    unawaited(game.waitForInitialData().then((_) => dataReady = true));
    query.pub.add(_Event(_public('dealing')));
    await tester.pump();
    expect(
      dataReady,
      true,
      reason: 'Do not wait for a hand behind the ready barrier',
    );
    expect(game.isEntryDataReady, false);
    expect(game.players.keys, contains('phone'));
    final prepared = game.prepareScreen(() async {});
    await tester.pump();
    await tester.pump();
    await prepared;
    await tester.pump();
    expect(reports.ready, [true]);
    expect(game.localUsable, true);
    expect(
      game.recoverySession.canSend,
      false,
      reason: 'The server pause still blocks play',
    );
    expect(game.isEntryDataReady, false);
  });

  testWidgets(
    'joining a running game still waits for its matching private hand',
    (tester) async {
      start();
      var dataReady = false;
      unawaited(game.waitForInitialData().then((_) => dataReady = true));
      query.pub.add(_Event(_public('playing')));
      await tester.pump();
      expect(dataReady, false);
      query.priv.add(_Event(_private('old-game')));
      await tester.pump();
      expect(dataReady, false);
      query.priv.add(_Event(_private('liars-startup')));
      await tester.pump();
      expect(dataReady, true);
      expect(game.isEntryDataReady, true);
      expect(game.handCards, hasLength(1));
      final prepared = game.prepareScreen(() async {});
      await tester.pump();
      await tester.pump();
      await prepared;
      await tester.pump();
      expect(reports.ready, [true]);
    },
  );
  testWidgets(
    'play selection remains blocked through preparation and server pause',
    (tester) async {
      start();
      final value = _public('playing');
      (value['players'] as Map)['other'] = {
        'status': 'alive',
        'remainingCardCount': 5,
      };
      query.pub.add(_Event(value));
      query.priv.add(_Event(_private('liars-startup')));
      await tester.pump();
      expect(game.isEntryDataReady, true);
      expect(game.canSelectCards, false);
      final prepared = game.prepareScreen(() async {});
      await tester.pump();
      await tester.pump();
      await prepared;
      await tester.pump();
      expect(game.localUsable, true);
      expect(game.canSelectCards, false);
      query.pub.add(
        _Event({
          ...value,
          'revision': 2,
          'recovery': {'paused': false},
        }),
      );
      await tester.pump();
      expect(game.canSelectCards, true);
      game.recoverySession.transportConnected = false;
      game.recoverySession.changed();
      expect(game.canSelectCards, false);
      expect(game.canSubmitCards, false);
      expect(game.canCallLiar, false);
      expect(game.canFoldLastCardChallenge, false);
    },
  );
  testWidgets(
    'first turn cannot call LIAR until a previous submission exists',
    (tester) async {
      start();
      final value = {
        ..._public('playing'),
        'turnUid': 'phone',
        'players': {
          'phone': {'status': 'alive', 'remainingCardCount': 5},
          'other': {'status': 'alive', 'remainingCardCount': 5},
          'peer': {'status': 'alive', 'remainingCardCount': 5},
        },
      };
      query.pub.add(_Event(value));
      query.priv.add(_Event(_private('liars-startup')));
      await tester.pump();
      final prepared = game.prepareScreen(() async {});
      await tester.pump();
      await tester.pump();
      await prepared;
      query.pub.add(
        _Event({
          ...value,
          'revision': 2,
          'recovery': {'paused': false},
        }),
      );
      await tester.pump();

      expect(game.canCallLiar, false);

      query.pub.add(
        _Event({
          ...value,
          'revision': 3,
          'recovery': {'paused': false},
          'lastPlay': {
            'playId': 'play-1',
            'playerUid': 'other',
            'cardCount': 1,
            'revealed': false,
          },
        }),
      );
      await tester.pump();
      expect(game.canCallLiar, true);

      query.pub.add(
        _Event({
          ...value,
          'revision': 4,
          'recovery': {'paused': false},
          'players': {
            'phone': {'status': 'alive', 'remainingCardCount': 5},
            'other': {'status': 'eliminated', 'remainingCardCount': 0},
            'peer': {'status': 'alive', 'remainingCardCount': 5},
          },
          'lastPlay': {
            'playId': 'play-1',
            'playerUid': 'other',
            'cardCount': 1,
            'revealed': false,
          },
        }),
      );
      await tester.pump();
      expect(game.canCallLiar, false);
      expect(game.canSelectCards, true);
    },
  );
  testWidgets(
    'dealing timeout accepts the matching public phase instead of showing a false failure',
    (tester) async {
      start();
      commands.completeError = TimeoutException('response lost');
      query.pub.add(_Event(_public('dealing')));
      await tester.pump();
      final prepared = game.prepareScreen(() async {});
      await tester.pump();
      await tester.pump();
      await prepared;
      await tester.pump();

      final completion = game.completeDealing();
      await tester.pump(const Duration(milliseconds: 300));
      query.pub.add(_Event({..._public('playing'), 'revision': 2}));
      query.priv.add(_Event(_private('liars-startup')));
      await tester.pump(const Duration(milliseconds: 150));

      expect(await completion, isTrue);
      expect(game.errorMessage, isNull);
    },
  );

  testWidgets('a new round never shows the previous round hand as its own', (
    tester,
  ) async {
    start();
    query.pub.add(_Event(_public('playing')));
    query.priv.add(_Event(_private('liars-startup')));
    await tester.pump();
    expect(game.handCards, hasLength(1));

    // 앱을 잠시 떠나 분배 단계를 놓치고 다음 라운드의 공개 상태만 먼저 받습니다.
    final nextRound = {
      ..._public('playing'),
      'round': 2,
      'phaseSeq': 3,
      'turnSeq': 4,
      'dataSeq': 9,
      'revision': 9,
    };
    query.pub.add(_Event(nextRound));
    await tester.pump();
    expect(
      game.handCards,
      isEmpty,
      reason: 'the previous round cards are not the new hand',
    );
    expect(game.isEntryDataReady, false);
    expect(game.localUsable, false);

    query.priv.add(
      _Event(
        _private(
          'liars-startup',
          phaseSeq: 3,
          turnSeq: 4,
          dataSeq: 9,
          cards: 5,
        ),
      ),
    );
    await tester.pump();
    expect(game.handCards, hasLength(5));
    expect(game.isEntryDataReady, true);
    // 준비 대기 타이머는 화면 폐기와 함께 정리됩니다.
    container.dispose();
  });

  testWidgets('dealing for a new round hides the previous round hand', (
    tester,
  ) async {
    start();
    query.pub.add(_Event(_public('playing')));
    query.priv.add(_Event(_private('liars-startup')));
    await tester.pump();
    expect(game.handCards, hasLength(1));

    query.pub.add(
      _Event({
        ..._public('dealing'),
        'round': 2,
        'phaseSeq': 2,
        'turnSeq': 2,
        'dataSeq': 5,
        'revision': 5,
      }),
    );
    // 서버는 분배 중 개인 노드를 비웁니다.
    query.priv.add(_Event(null));
    await tester.pump();
    expect(game.handCards, isEmpty);
    // 준비 대기 타이머는 화면 폐기와 함께 정리됩니다.
    container.dispose();
  });

  testWidgets(
    'a ready report rejected as stale reloads the latest state instead of failing',
    (tester) async {
      start();
      // 복귀 직후 구독이 캐시된 이전 공개·개인 상태를 먼저 전달합니다.
      query.pub.add(
        _Event({
          ..._public('playing'),
          'recovery': {'paused': false},
        }),
      );
      query.priv.add(_Event(_private('liars-startup')));
      await tester.pump();
      final latest = {
        ..._public('playing'),
        'round': 2,
        'phaseSeq': 3,
        'turnSeq': 4,
        'dataSeq': 9,
        'revision': 9,
        'recovery': {'paused': false},
      };
      reports.responses.add({
        'status': 'staleContext',
        'context': {
          'gameInstanceId': 'liars-startup',
          'phaseSeq': 3,
          'turnSeq': 4,
          'dataSeq': 9,
        },
      });
      query.latestPublic = latest;

      final prepared = game.prepareScreen(() async {});
      await tester.pump();
      await tester.pump();
      await prepared;
      await tester.pump();
      await tester.pump();

      expect(reports.ready, [true]);
      expect(query.publicReads, 1, reason: 'the stale screen is reloaded');
      expect(game.errorMessage, isNull);
      expect(game.handCards, isEmpty);

      query.priv.add(
        _Event(
          _private(
            'liars-startup',
            phaseSeq: 3,
            turnSeq: 4,
            dataSeq: 9,
            cards: 5,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(game.handCards, hasLength(5));
      expect(reports.ready, [true, true]);
      expect(game.errorMessage, isNull);
      expect(game.recoverySession.serverConfirmed, true);
      expect(game.recoverySession.canSend, true);
    },
  );
}

Map<String, dynamic> _public(String phase) => {
  'gameInstanceId': 'liars-startup',
  'phaseSeq': 1,
  'turnSeq': 1,
  'dataSeq': 1,
  'resumeEpoch': 1,
  'startedAt': 100,
  'revision': 1,
  'status': 'playing',
  'phase': phase,
  'gameType': 'liars_poker',
  'players': {
    'phone': {'status': 'alive', 'remainingCardCount': 5},
  },
  'recovery': {'paused': true, 'pauseId': 'startup'},
};

Map<String, dynamic> _private(
  String gameId, {
  int phaseSeq = 1,
  int turnSeq = 1,
  int dataSeq = 1,
  int cards = 1,
}) => {
  '_context': {
    'gameInstanceId': gameId,
    'phaseSeq': phaseSeq,
    'turnSeq': turnSeq,
    'dataSeq': dataSeq,
  },
  'hand': {
    for (var index = 1; index <= cards; index += 1)
      'card-$dataSeq-$index': {'rank': 'TRUTH'},
  },
};

class _Snapshot extends Fake implements DataSnapshot {
  _Snapshot(this.value);
  @override
  final Object? value;
  @override
  bool get exists => value != null;
}

class _Event extends Fake implements DatabaseEvent {
  _Event(Object? value) : snapshot = _Snapshot(value);
  @override
  final DataSnapshot snapshot;
}

class _Query extends Fake implements LiarsPokerQueryService {
  final pub = StreamController<DatabaseEvent>.broadcast();
  final priv = StreamController<DatabaseEvent>.broadcast();
  @override
  Stream<DatabaseEvent> watchPublicGame(String roomCode) => pub.stream;
  @override
  Stream<DatabaseEvent> watchPrivatePlayer({
    required String roomCode,
    required String uid,
  }) => priv.stream;
  Object? latestPublic;
  int publicReads = 0;
  @override
  Future<DataSnapshot> readPublicGame(String roomCode) async {
    publicReads += 1;
    return _Snapshot(latestPublic);
  }
}

class _Commands extends Fake implements LiarsPokerCommandService {
  Object? completeError;

  @override
  Future<Map<String, dynamic>> completeDealing({
    required String roomCode,
  }) async {
    final error = completeError;
    if (error != null) throw error;
    return {'success': true};
  }
}

class _Reports extends Fake implements GameInterruptionCommandService {
  final ready = <bool>[];
  final responses = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> report({
    required String roomCode,
    required Map<String, dynamic> context,
    required int reportSeq,
    required bool ready,
  }) async {
    this.ready.add(ready);
    if (responses.isNotEmpty) return responses.removeAt(0);
    return {'status': 'accepted'};
  }
}
