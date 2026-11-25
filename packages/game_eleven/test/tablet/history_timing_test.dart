// 하준 실기기 확인(2026-11-25): 라운드 결과 단계에서 전적판이 카드 결과보다 먼저 승패를 보이면 안 된다.
// 이번 라운드 행은 다음 라운드가 시작될 때 채운다(시안·MotionKit 7).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/services/history_mapper.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';
import 'package:game_eleven/tablet/providers/game_stage.dart';
import 'package:game_eleven/tablet/widgets/noir_board.dart';
import 'package:game_eleven/tablet/widgets/score_board.dart';

ElevenGameState _game(Map<String, Object?> public) =>
    ElevenGameState.initial().copyWith(
      loading: false,
      public: ElevenPublicSnapshot.fromValue({
        'status': 'playing',
        'firstUid': 'a',
        'secondUid': 'b',
        'players': {
          'a': {'uid': 'a', 'nickname': 'Ann', 'seatIndex': 0},
          'b': {'uid': 'b', 'nickname': 'Bo', 'seatIndex': 1},
        },
        ...public,
      }),
      history: parseElevenHistory([
        {
          'round': 1,
          'firstUid': 'a',
          'colors': {'a': 'black', 'b': 'white'},
          'winnerUid': 'a',
        },
        {
          'round': 2,
          'firstUid': 'a',
          'colors': {'a': 'white', 'b': 'black'},
          'winnerUid': 'b',
        },
      ]),
    );

Future<List<int>> _rounds(WidgetTester tester, ElevenGameState game) async {
  tester.view.physicalSize = const Size(1194, 834);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ElevenTabletBoardView(
          game: game,
          screen: resolveElevenTabletScreen(game),
          onPick: (_) {},
          onRules: () {},
          onSettings: () {},
          onRestart: () {},
          onHome: () {},
          animate: false,
        ),
      ),
    ),
  );
  return tester
      .widget<ElevenHistoryStrip>(find.byType(ElevenHistoryStrip))
      .history
      .map((e) => e.round)
      .toList();
}

void main() {
  testWidgets('round result hides the just-judged row', (tester) async {
    final rounds = await _rounds(
      tester,
      _game({
        'phase': 'roundResult',
        'round': 2,
        'lastRoundResult': {'round': 2, 'winnerUid': 'b'},
      }),
    );
    expect(rounds, [1]);
  });

  testWidgets('next round shows the previous row', (tester) async {
    final rounds = await _rounds(
      tester,
      _game({'phase': 'firstSubmit', 'round': 3}),
    );
    expect(rounds, [1, 2]);
  });
}
