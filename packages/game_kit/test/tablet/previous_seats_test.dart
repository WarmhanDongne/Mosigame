import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/player_layouts/services/player_layout_factory.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';
import 'package:game_kit/player_layouts/widgets/player_layout_editor.dart';

class _Player implements GameRoomPlayer {
  const _Player(this.uid, this.seatIndex);

  @override
  final String uid;
  @override
  final int seatIndex;
  @override
  String get nickname => uid;
  @override
  String get characterId => 'bear';
  @override
  bool get isConnected => true;
  @override
  String get role => 'player';
  @override
  String get status => 'active';
  @override
  bool get isPlayer => true;
  @override
  bool get isActive => true;
}

void main() {
  test('면 배치는 모든 좌석을 같은 각도로 회전하고 원형 순서를 유지한다', () {
    for (final playerCount in [2, 3, 4, 6, 8]) {
      final corners = normalizedPlayerCenters(playerCount);
      final sides = normalizedSideSeatCenters(playerCount);
      final expectedRotation = math.pi / playerCount;
      for (var index = 0; index < playerCount; index++) {
        final from = corners[index] - const Offset(0.5, 0.5);
        final to = sides[index] - const Offset(0.5, 0.5);
        var delta = to.direction - from.direction;
        while (delta < 0) {
          delta += math.pi * 2;
        }
        while (delta >= math.pi * 2) {
          delta -= math.pi * 2;
        }
        expect(delta, closeTo(expectedRotation, 1e-9));
      }
    }
  });

  group('SavedSeatLayout', () {
    test('저장 명단과 현재 명단이 완전히 같을 때만 자동 복원한다', () {
      final saved = SavedSeatLayout.fromWire({
        'playerUids': ['c', 'a', 'b'],
        'mode': 'sides',
      });

      expect(saved, isNotNull);
      expect(saved!.mode, SeatLayoutMode.sides);
      expect(saved.matches(['a', 'b', 'c']), isTrue);
      expect(saved.matches(['a', 'b']), isFalse);
      expect(saved.matches(['a', 'b', 'c', 'd']), isFalse);
      expect(saved.matches(['a', 'b', 'd']), isFalse);
    });

    test('중복되거나 부족한 저장 명단은 복원하지 않는다', () {
      expect(
        SavedSeatLayout.fromWire({
          'playerUids': ['a', 'a'],
          'mode': 'corners',
        }),
        isNull,
      );
      expect(
        SavedSeatLayout.fromWire({
          'playerUids': ['a'],
          'mode': 'corners',
        }),
        isNull,
      );
    });
  });

  group('PlayerLayoutFactory.fromSavedSeats', () {
    test('지난 게임 자리를 참가자 순서 그대로 다시 만든다', () {
      final layout = PlayerLayoutFactory.fromSavedSeats(const [
        _Player('a', 2),
        _Player('b', 0),
        _Player('c', 1),
      ]);
      expect(layout?.players.map((player) => player.uid), ['a', 'b', 'c']);
      expect(layout?.seatIndexes, [2, 0, 1]);
    });

    test('누가 나가 번호가 비면 남은 사람 순서만 유지해 다시 매긴다', () {
      final layout = PlayerLayoutFactory.fromSavedSeats(const [
        _Player('a', 3),
        _Player('b', 0),
        _Player('c', 1),
      ]);
      expect(layout?.seatIndexes, [2, 0, 1]);
    });

    test('새로 들어온 사람이 있거나 번호가 겹치면 불러오지 않는다', () {
      expect(
        PlayerLayoutFactory.fromSavedSeats(const [
          _Player('a', 0),
          _Player('b', -1),
        ]),
        isNull,
      );
      expect(
        PlayerLayoutFactory.fromSavedSeats(const [
          _Player('a', 1),
          _Player('b', 1),
        ]),
        isNull,
      );
    });
  });

  group('PlayerLayoutFactory.mergeSavedRoster', () {
    test('교체된 새 참가자는 나간 참가자의 빈 자리를 채운다', () {
      final layout = PlayerLayoutFactory.mergeSavedRoster(
        const [
          _Player('a', 0),
          _Player('b', 1),
          _Player('d', 3),
          _Player('new', -1),
        ],
        savedPlayerUids: const {'a', 'b', 'c', 'd'},
      );

      expect(layout?.seatIndexes, [0, 1, 3, 2]);
    });

    test('인원이 줄면 남은 참가자의 이전 순서를 유지해 다시 매긴다', () {
      final layout = PlayerLayoutFactory.mergeSavedRoster(
        const [_Player('a', 3), _Player('b', 0), _Player('c', 1)],
        savedPlayerUids: const {'a', 'b', 'c', 'd'},
      );

      expect(layout?.seatIndexes, [2, 0, 1]);
    });

    test('인원이 늘면 기존 좌석을 유지하고 새 참가자를 남는 자리에 둔다', () {
      final layout = PlayerLayoutFactory.mergeSavedRoster(
        const [
          _Player('a', 2),
          _Player('b', 0),
          _Player('c', 1),
          _Player('new', -1),
        ],
        savedPlayerUids: const {'a', 'b', 'c'},
      );

      expect(layout?.seatIndexes, [2, 0, 1, 3]);
    });

    test('기존 참가자가 없거나 이전 좌석이 손상되면 기본 배치를 사용한다', () {
      expect(
        PlayerLayoutFactory.mergeSavedRoster(
          const [_Player('new-a', -1), _Player('new-b', -1)],
          savedPlayerUids: const {'old-a', 'old-b'},
        ),
        isNull,
      );
      expect(
        PlayerLayoutFactory.mergeSavedRoster(
          const [_Player('a', 1), _Player('b', 1), _Player('new', -1)],
          savedPlayerUids: const {'a', 'b'},
        ),
        isNull,
      );
    });
  });

  group('PlayerLayoutEditor 이전 자리', () {
    const players = [_Player('a', 2), _Player('b', 0), _Player('c', 1)];
    final initial = PlayerLayoutFactory.create(players);
    final previous = PlayerLayoutFactory.fromSavedSeats(players);

    Future<List<PlayerLayoutModel>> pumpEditor(
      WidgetTester tester, {
      PlayerLayoutModel? previousLayout,
    }) async {
      tester.view.physicalSize = const Size(1180, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prepared = <PlayerLayoutModel>[];
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerLayoutEditor(
            initialLayout: initial,
            previousLayout: previousLayout,
            tableColor: Colors.green,
            onPrepare: (layout) async {
              prepared.add(layout);
              return false;
            },
            onComplete: (_) {},
            onCancel: () async => true,
          ),
        ),
      );
      await tester.pump();
      return prepared;
    }

    testWidgets('이전 자리가 유효하면 버튼 없이 지난 배치가 기본값이다', (tester) async {
      final prepared = await pumpEditor(tester, previousLayout: previous);
      final button = find.widgetWithText(MosiButton, '이전 자리');
      expect(button, findsNothing);
      expect(find.widgetWithText(MosiButton, '섞기'), findsOneWidget);

      await tester.tap(find.widgetWithText(MosiButton, '설정 완료'));
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 300));
      expect(prepared.single.seatIndexes, [2, 0, 1]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('불러올 배치가 없으면 버튼을 보이지 않는다', (tester) async {
      final prepared = await pumpEditor(tester);
      expect(find.widgetWithText(MosiButton, '이전 자리'), findsNothing);
      expect(find.widgetWithText(MosiButton, '섞기'), findsOneWidget);
      await tester.tap(find.widgetWithText(MosiButton, '설정 완료'));
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 300));
      expect(prepared.single.seatIndexes, [0, 1, 2]);
    });

    testWidgets('모서리에서 면 자리로 바꾸면 완료 배치에 형태가 포함된다', (tester) async {
      final prepared = await pumpEditor(tester);
      expect(find.text('면 자리'), findsOneWidget);

      await tester.tap(find.byKey(const Key('seat-layout-mode-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('모서리 자리'), findsOneWidget);

      await tester.tap(find.widgetWithText(MosiButton, '설정 완료'));
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 300));
      expect(prepared.single.seatLayoutMode, SeatLayoutMode.sides);
    });

    testWidgets('모서리와 면 전환은 좌석 묶음의 간격을 유지하며 한 방향으로 돈다', (tester) async {
      await pumpEditor(tester);
      final players = [
        find.byKey(const ValueKey('a')),
        find.byKey(const ValueKey('b')),
        find.byKey(const ValueKey('c')),
      ];
      final toggle = find.byKey(const Key('seat-layout-mode-toggle'));
      final start = players.map(tester.getCenter).toList(growable: false);

      await tester.tap(toggle);
      await tester.pump();
      expect(tester.widget<MosiButton>(toggle).onPressed, isNull);

      await tester.pump(const Duration(milliseconds: 325));
      final middle = players.map(tester.getCenter).toList(growable: false);
      for (var left = 0; left < players.length; left++) {
        for (var right = left + 1; right < players.length; right++) {
          expect(
            (middle[left] - middle[right]).distance,
            closeTo((start[left] - start[right]).distance, 0.5),
            reason: '회전 중에도 좌석 묶음의 상대 간격이 유지되어야 한다.',
          );
        }
      }

      await tester.pumpAndSettle();
      expect(tester.widget<MosiButton>(toggle).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('세 글자 닉네임은 자리 카드에서 말줄임 없이 보인다', (tester) async {
      final threeCharacterPlayers = [
        const _Player('가나다', 0),
        const _Player('라마바사', 1),
      ];
      final threeCharacterLayout = PlayerLayoutFactory.create(
        threeCharacterPlayers,
      );
      tester.view.physicalSize = const Size(1180, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: PlayerLayoutEditor(
              initialLayout: threeCharacterLayout,
              tableColor: Colors.green,
              onPrepare: (_) async => false,
              onComplete: (_) {},
              onCancel: () async => true,
            ),
          ),
        ),
      );

      expect(find.text('가나다'), findsOneWidget);
      expect(find.text('라마바사'), findsNothing);
      expect(find.text('라마바…'), findsOneWidget);
    });
  });
}
