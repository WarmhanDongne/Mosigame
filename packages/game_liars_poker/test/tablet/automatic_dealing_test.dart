import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/tablet/animations/card_deal_animation.dart';
import 'package:game_liars_poker/shared/widgets/card_face_view.dart';
import 'package:game_liars_poker/tablet/animations/truth_lie_shuffle_animation.dart';
import 'package:game_liars_poker/tablet/providers/game_stage.dart';
import 'package:game_liars_poker/tablet/tablet_board.dart';

void main() {
  testWidgets('분배 전에는 진실·거짓 카드를 실제 장수만큼 깔고 장수 문구는 쓰지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiarsPokerTabletGameLayer(
            stage: LiarsPokerTabletStage.dealing,
            flowConfig: buildLiarsPokerTabletFlowConfig(roundNumber: 1),
            playerCount: 4,
            playerSeatIndexes: const [0, 1, 2, 3],
            dealPlayerSeatIndexes: const [0, 1, 2, 3],
            cardsPerPlayer: 5,
            truthCardCount: 12,
            lieCardCount: 11,
            unrevealedCardCount: 3,
            roundNumber: 1,
            cardPileVersion: 1,
            table: 'TRUTH',
            remainingCardCounts: const [5, 5, 5, 5],
            currentTurnPlayerIndex: 0,
            onDealCompleted: () {},
            onRoundRevealCompleted: () {},
            onRestartGame: () {},
            onExitToLobby: () {},
            winnerPlayer: null,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('이번 판 카드 구성'), findsOneWidget);
    expect(find.byType(LiarsPokerCardView), findsNWidgets(23));
    expect(find.textContaining('×'), findsNothing);
  });

  testWidgets('서버가 장수를 보내지 않아도 인원으로 진실·거짓 장수를 채운다', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _dealingLayer(roundNumber: 1, truthCardCount: 0, lieCardCount: 0),
    );
    await tester.pump();

    final shuffle = tester.widget<TruthLieShuffleAnimation>(
      find.byType(TruthLieShuffleAnimation),
    );
    expect(shuffle.truthCardCount, 12);
    expect(shuffle.lieCardCount, 11);
    expect(find.byType(LiarsPokerCardView), findsNWidgets(23));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  });

  testWidgets('첫 라운드 카드 분배는 태블릿 탭 없이 자동으로 끝난다', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var completed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiarsPokerTabletGameLayer(
            stage: LiarsPokerTabletStage.dealing,
            flowConfig: buildLiarsPokerTabletFlowConfig(roundNumber: 1),
            playerCount: 4,
            playerSeatIndexes: const [0, 1, 2, 3],
            dealPlayerSeatIndexes: const [0, 1, 2, 3],
            cardsPerPlayer: 5,
            truthCardCount: 12,
            lieCardCount: 11,
            unrevealedCardCount: 3,
            roundNumber: 1,
            cardPileVersion: 1,
            table: 'TRUTH',
            remainingCardCounts: const [5, 5, 5, 5],
            currentTurnPlayerIndex: 0,
            onDealCompleted: () => completed += 1,
            onRoundRevealCompleted: () {},
            onRestartGame: () {},
            onExitToLobby: () {},
            winnerPlayer: null,
          ),
        ),
      ),
    );

    // 덱 진입과 분배는 각각 별도 애니메이션 컨트롤러가 담당합니다. 두
    // 컨트롤러가 모두 안정화될 때까지 기다려 자동 완료 콜백을 확인합니다.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(completed, 1);
    expect(find.bySemanticsLabel('카드 분배 시작'), findsNothing);
  });

  testWidgets('섞기가 끝나면 덱을 다시 떨어뜨리지 않고 분배로 이어진다', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_dealingLayer(roundNumber: 1));
    await tester.pump();
    // 덱 등장 620ms + 섞기 4600ms 직전까지는 분배가 시작되지 않습니다.
    await tester.pump(const Duration(milliseconds: 630));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4500));
    expect(find.byType(TruthLieShuffleAnimation), findsOneWidget);
    expect(find.byType(CardDealAnimation), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    final deal = tester.widget<CardDealAnimation>(
      find.byType(CardDealAnimation),
    );
    expect(deal.playDeckEntry, isFalse);
    expect(deal.reserveCardCount, 3);
    for (var index = 0; index < 3; index++) {
      expect(find.byKey(ValueKey('reserved-card-$index')), findsOneWidget);
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  });

  testWidgets('다음 라운드의 섞기는 ROUND 안내가 끝난 뒤에 시작한다', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_dealingLayer(roundNumber: 2));
    await tester.pump(const Duration(milliseconds: 620));
    // 안내(1.9초)가 끝나기 전이므로 섞기 길이를 지나도 분배로 넘어가지 않습니다.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byType(TruthLieShuffleAnimation), findsOneWidget);
    expect(find.byType(CardDealAnimation), findsNothing);

    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(TruthLieShuffleAnimation), findsNothing);
  });
}

Widget _dealingLayer({
  required int roundNumber,
  int truthCardCount = 12,
  int lieCardCount = 11,
}) => MaterialApp(
  home: Scaffold(
    body: LiarsPokerTabletGameLayer(
      stage: LiarsPokerTabletStage.dealing,
      flowConfig: buildLiarsPokerTabletFlowConfig(roundNumber: roundNumber),
      playerCount: 4,
      playerSeatIndexes: const [0, 1, 2, 3],
      dealPlayerSeatIndexes: const [0, 1, 2, 3],
      cardsPerPlayer: 5,
      truthCardCount: truthCardCount,
      lieCardCount: lieCardCount,
      unrevealedCardCount: 3,
      roundNumber: roundNumber,
      cardPileVersion: 1,
      table: 'TRUTH',
      remainingCardCounts: const [5, 5, 5, 5],
      currentTurnPlayerIndex: 0,
      onDealCompleted: () {},
      onRoundRevealCompleted: () {},
      onRestartGame: () {},
      onExitToLobby: () {},
      winnerPlayer: null,
    ),
  ),
);
