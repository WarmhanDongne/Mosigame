import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/game_final_call.dart';
import 'package:game_final_call/tutorial/final_call_tutorial.dart';
import 'package:game_liars_poker/game_liars_poker.dart';
import 'package:game_liars_poker/tutorial/liars_tutorial.dart';
import 'package:game_russian_roulette/game_russian_roulette.dart';
import 'package:game_russian_roulette/src/tutorial.dart';
import 'package:game_kit/tutorial/game_tutorial.dart';

void main() {
  test('주요 세 게임은 자동 튜토리얼을 등록한다', () {
    final finalCall = const FinalCallGame().tutorial;
    final liars = const LiarsPokerGame().tutorial;
    final roulette = const RussianRouletteGame().tutorial;

    expect(finalCall, isA<FinalCallTutorial>());
    expect(liars, isA<LiarsPokerQuickTutorial>());
    expect(roulette, isA<RussianRouletteTutorial>());
    expect(finalCall.autoPlay, isTrue);
    expect(liars.autoPlay, isTrue);
    expect(roulette.autoPlay, isTrue);
  });

  test('자동 튜토리얼은 끝 화면 전까지 양수인 재생 시간을 제공한다', () {
    final tutorials = [
      const FinalCallTutorial(),
      const LiarsPokerQuickTutorial(),
      const RussianRouletteTutorial(),
    ];

    for (final tutorial in tutorials) {
      expect(tutorial.stepCount, greaterThan(1), reason: tutorial.gameId);
      for (var step = 0; step < tutorial.endStep; step++) {
        expect(
          tutorial.autoDuration(step),
          greaterThan(Duration.zero),
          reason: '${tutorial.gameId} step $step',
        );
      }
    }
    expect(const FinalCallTutorial().phoneLandscape, isTrue);
    expect(const LiarsPokerQuickTutorial().phoneLandscape, isFalse);
    expect(const RussianRouletteTutorial().phoneLandscape, isFalse);
  });

  testWidgets('세 게임의 모든 자동 튜토리얼 단계가 양쪽 기기에서 그려진다', (tester) async {
    final players = [
      for (var i = 0; i < 6; i++)
        TutorialPlayer(
          uid: 'u$i',
          nickname: '참가자 ${i + 1}',
          characterId: 'character_$i',
          seatIndex: i,
        ),
    ];
    final tutorials = <GameTutorial>[
      const FinalCallTutorial(),
      const LiarsPokerQuickTutorial(),
      const RussianRouletteTutorial(),
    ];

    for (final tutorial in tutorials) {
      for (var step = 0; step < tutorial.stepCount; step++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox.fromSize(
                  size: tutorial.tabletDesignSize,
                  child: Builder(
                    builder: (context) => tutorial.buildTablet(
                      context,
                      TutorialTabletView(
                        size: tutorial.tabletDesignSize,
                        players: players,
                        step: step,
                        phase: 0,
                        round: 1,
                        entries: const {},
                        ended: step == tutorial.endStep,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          tester.takeException(),
          isNull,
          reason: '${tutorial.gameId} tablet step $step',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FittedBox(
                child: SizedBox.fromSize(
                  size: tutorial.phoneDesignSize,
                  child: Builder(
                    builder: (context) => tutorial.buildPhone(
                      context,
                      TutorialPhoneView(
                        me: players.first,
                        players: players,
                        step: step,
                        phase: 0,
                        round: 1,
                        done: false,
                        value: '',
                        memo: '',
                        doneCount: 0,
                        ended: step == tutorial.endStep,
                        complete: (_, {memo}) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          tester.takeException(),
          isNull,
          reason: '${tutorial.gameId} phone step $step',
        );
      }
    }
  });
}
