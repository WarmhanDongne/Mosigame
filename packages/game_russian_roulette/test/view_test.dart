import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';
import 'package:game_russian_roulette/game_russian_roulette.dart';
import 'package:game_russian_roulette/game_sounds.dart';
import 'package:game_russian_roulette/src/stage.dart';
import 'package:game_russian_roulette/src/timing.dart';
import 'package:game_russian_roulette/src/view.dart';

void main() {
  test('game entrypoint exposes the 2-6 player portrait game', () {
    const game = RussianRouletteGame();
    expect(game.id, 'russian_roulette');
    expect(game.supportedPlayerCounts, [2, 3, 4, 5, 6]);
    expect(game.leaveFunctionName, 'game_russian_roulette_leave_game');
    expect(game.layoutChairImage, isA<AssetImage>());
  });

  test('game seats and gun targets share the lobby layout positions', () {
    for (var count = 2; count <= 6; count++) {
      final lobby = normalizedPlayerCenters(count);
      for (var index = 0; index < count; index++) {
        final game = RouletteStageGeometry.onEllipse(
          RouletteStageGeometry.seatAngle(index, count),
        );
        final expected = Offset(
          lobby[index].dx * RouletteStageGeometry.width,
          lobby[index].dy * RouletteStageGeometry.height,
        );
        expect(
          (game - expected).distance,
          lessThan(.001),
          reason: '$count players, seat $index',
        );
      }
    }
  });

  test('public state is converted into ordered player and action views', () {
    final view = RussianRouletteView.fromPublic({
      'status': 'playing',
      'phase': 'revealing',
      'round': 2,
      'targetUid': 'b',
      'choiceCount': 3,
      'spinCount': 1,
      'players': {
        'b': {
          'nickname': 'B',
          'characterId': 'frog',
          'seatIndex': 1,
          'status': 'alive',
          'shieldLocked': true,
        },
        'a': {
          'nickname': 'A',
          'characterId': 'milk',
          'seatIndex': 0,
          'status': 'eliminated',
        },
      },
      'revealedActions': {'b': 'shield', 'a': 'spin'},
    });

    expect(view.loaded, isTrue);
    expect(view.orderedPlayers.map((player) => player.uid), ['a', 'b']);
    expect(view.players['b']!.shieldLocked, isTrue);
    expect(view.actions['b'], RouletteAction.shield);
    expect(view.aliveCount, 1);
  });

  test('empty state remains a safe loading view', () {
    final view = RussianRouletteView.fromPublic(const {});
    expect(view.loaded, isFalse);
    expect(view.players, isEmpty);
    expect(view.finished, isFalse);
  });

  test('presentation timing uses the slower tension pacing', () {
    expect(
      RussianRouletteTiming.revealing(5),
      const Duration(milliseconds: 6900),
    );
    expect(
      RussianRouletteTiming.rotating(3),
      const Duration(milliseconds: 5400),
    );
    expect(
      RussianRouletteTiming.firingHold,
      const Duration(milliseconds: 2200),
    );
    expect(
      RussianRouletteTiming.outcome(blocked: true),
      const Duration(milliseconds: 3200),
    );
    expect(
      RussianRouletteTiming.outcome(blocked: false),
      const Duration(milliseconds: 4200),
    );
  });

  test('reveal and rotation wait before their first visible step', () {
    expect(RussianRouletteTiming.revealedCount(Duration.zero, 4), 0);
    expect(
      RussianRouletteTiming.revealedCount(const Duration(milliseconds: 699), 4),
      0,
    );
    expect(
      RussianRouletteTiming.revealedCount(RussianRouletteTiming.revealLead, 4),
      1,
    );
    expect(
      RussianRouletteTiming.showsSpinSummary(
        const Duration(milliseconds: 4699),
        4,
      ),
      isFalse,
    );
    expect(
      RussianRouletteTiming.showsSpinSummary(
        const Duration(milliseconds: 4700),
        4,
      ),
      isTrue,
    );
    expect(
      RussianRouletteTiming.completedRotationSteps(
        const Duration(milliseconds: 799),
        3,
      ),
      0,
    );
    expect(
      RussianRouletteTiming.completedRotationSteps(
        RussianRouletteTiming.rotationLead,
        3,
      ),
      1,
    );
  });

  group('연출 단계 예약', () {
    Map<String, dynamic> publicState({
      required String phase,
      bool paused = false,
      String status = 'playing',
    }) => {
      'status': status,
      'phase': phase,
      'round': 2,
      'targetUid': 'a',
      'spinCount': 3,
      'players': {
        'a': {
          'nickname': 'A',
          'characterId': 'frog',
          'seatIndex': 0,
          'status': 'alive',
        },
        'b': {
          'nickname': 'B',
          'characterId': 'milk',
          'seatIndex': 1,
          'status': 'alive',
        },
      },
      if (paused) 'recovery': {'paused': true},
    };

    test('중단 중에는 진행 명령을 예약하지 않는다', () {
      final running = RussianRouletteView.fromPublic(
        publicState(phase: 'revealing'),
      );
      final paused = RussianRouletteView.fromPublic(
        publicState(phase: 'revealing', paused: true),
      );

      expect(roulettePhaseDelay(running), RussianRouletteTiming.revealing(2));
      expect(roulettePhaseDelay(paused), isNull);
    });

    test('첫 시작 준비 중에는 공개된 선택 화면 대신 어두운 시작 프레임을 유지한다', () {
      final paused = RussianRouletteView.fromPublic({
        ...publicState(phase: 'selecting', paused: true),
        'round': 1,
        'turnDeadlineAt': 31000,
      });
      final running = RussianRouletteView.fromPublic({
        ...publicState(phase: 'selecting'),
        'round': 1,
        'turnDeadlineAt': 31000,
      });

      expect(
        rouletteShouldHoldIntroFrame(paused, presentedDeadline: 0),
        isTrue,
      );
      expect(
        rouletteShouldHoldIntroFrame(paused, presentedDeadline: 31000),
        isFalse,
      );
      expect(
        rouletteShouldHoldIntroFrame(running, presentedDeadline: 0),
        isFalse,
      );
    });

    test('중단으로 버린 예약은 재개에서 다시 걸린다', () {
      // 태블릿은 식별자가 같으면 다시 예약하지 않습니다. 중단 중 예약을
      // 버리므로 재개의 식별자가 중단 중 식별자와 달라야 연출이 이어집니다.
      for (final phase in ['revealing', 'rotating', 'firing', 'outcome']) {
        final paused = RussianRouletteView.fromPublic(
          publicState(phase: phase, paused: true),
        );
        final resumed = RussianRouletteView.fromPublic(
          publicState(phase: phase),
        );
        expect(roulettePhaseDelay(paused), isNull, reason: phase);
        expect(roulettePhaseDelay(resumed), isNotNull, reason: phase);
        expect(
          roulettePhaseKey(resumed),
          isNot(roulettePhaseKey(paused)),
          reason: phase,
        );
      }
    });

    test('선택 단계와 종료는 태블릿이 단계를 넘기지 않는다', () {
      expect(
        roulettePhaseDelay(
          RussianRouletteView.fromPublic(publicState(phase: 'selecting')),
        ),
        isNull,
      );
      expect(
        roulettePhaseDelay(
          RussianRouletteView.fromPublic(
            publicState(phase: 'outcome', status: 'finished'),
          ),
        ),
        isNull,
      );
    });

    test('같은 단계의 진행 중 상태는 한 번만 예약된다', () {
      final first = RussianRouletteView.fromPublic(
        publicState(phase: 'rotating'),
      );
      final again = RussianRouletteView.fromPublic(
        publicState(phase: 'rotating'),
      );
      expect(roulettePhaseKey(again), roulettePhaseKey(first));
    });
  });

  testWidgets('supplied audio files are included in the package bundle', (
    tester,
  ) async {
    for (final asset in [
      'packages/game_russian_roulette/assets/games/russian_roulette/images/layout_chair.png',
      RussianRouletteSounds.background,
      ...RussianRouletteSounds.preloadTargets,
    ]) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
  });
}
