import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/tablet/providers/game_stage.dart';
import 'package:game_final_call/tablet/screens/seat_geometry.dart';
import 'package:game_final_call/tablet/tablet_board.dart';
import 'package:game_final_call/tablet/widgets/result_overlay.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';

class _BoardGame extends Fake implements FinalCallController {
  String currentPhase = 'playing';
  FinalCallRoundResult? currentRoundResult;
  @override
  final Map<String, FinalCallPlayer> players = {
    for (var i = 0; i < 6; i++)
      'p$i': FinalCallPlayer(
        uid: 'p$i',
        nickname: '참가자 $i',
        characterId: 'frog',
        seatIndex: i,
        team: FinalCallTeam.values[i % 3],
        status: 'alive',
        lives: 3,
      ),
  };
  @override
  int get round => 2;
  @override
  FinalCallCard get discardCard =>
      const FinalCallCard(id: 'red_5', color: 'red', value: 5);
  @override
  FinalCallDiscardEvent? get discardEvent => null;
  @override
  String? get pendingDrawUid => null;
  @override
  String? get pendingDrawSource => null;
  @override
  String? get turnUid => 'p1';
  @override
  FinalCallPlayer? get turnPlayer => players[turnUid];
  @override
  int? get turnDeadlineAt => null;
  @override
  String? get callerUid => null;
  @override
  String get phase => currentPhase;
  @override
  FinalCallRoundResult? get roundResult => currentRoundResult;
  @override
  int get deckRemainingCount => 17;
}

void main() {
  test('좌석 프로필은 가운데 테이블을 바라보도록 돌아간다', () {
    const boardSize = Size(1200, 800);
    double rotation(Offset center) =>
        finalCallSeatRotationForCenter(center: center, boardSize: boardSize);
    // 위·아래·좌·우 자리는 그 변의 사람이 똑바로 읽는 각도입니다.
    expect(rotation(const Offset(600, 80)), closeTo(math.pi, 1e-9));
    expect(rotation(const Offset(600, 720)), closeTo(0, 1e-9));
    expect(rotation(const Offset(1120, 400)), closeTo(-math.pi / 2, 1e-9));
    expect(rotation(const Offset(80, 400)), closeTo(math.pi / 2, 1e-9));
    // 모서리 자리는 테이블 중심을 향하는 대각선 각도입니다.
    const corner = Offset(1000, 100);
    final angle = rotation(corner);
    // 프로필의 위(0, -1)를 돌린 방향이 테이블 중심을 가리키고, 아래는 그
    // 자리에 앉은 사람 쪽입니다.
    final up = Offset(math.sin(angle), -math.cos(angle));
    final toCenter = boardSize.center(Offset.zero) - corner;
    final cosine =
        (up.dx * toCenter.dx + up.dy * toCenter.dy) / toCenter.distance;
    expect(cosine, closeTo(1, 1e-9));
  });

  test('게임 프로필은 공용 자리배치에서 확정한 좌석 중심을 그대로 쓴다', () {
    const boardSize = Size(1280, 800);
    final expected = normalizedPlayerCenters(4)
        .map(
          (center) => playerCenterFromNormalized(
            normalizedCenter: center,
            boardSize: boardSize,
          ),
        )
        .toList(growable: false);
    expect(
      finalCallSeatCenters(playerCount: 4, boardSize: boardSize),
      expected,
    );
  });

  testWidgets('팀 동반 탈락 문구는 카드 공개와 하트 연출이 끝난 뒤 표시한다', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = _BoardGame()..currentPhase = 'roundResult';
    for (final uid in ['p0', 'p3']) {
      final player = game.players[uid]!;
      game.players[uid] = FinalCallPlayer(
        uid: uid,
        nickname: player.nickname,
        characterId: player.characterId,
        seatIndex: player.seatIndex,
        team: player.team,
        status: 'eliminated',
        lives: uid == 'p0' ? 0 : 3,
      );
    }
    game.currentRoundResult = FinalCallRoundResult(
      scores: const {'p0': 20, 'p3': 10},
      lifeLosses: const {'p0': 1, 'p3': 0},
      revealedHands: const {
        'p0': [FinalCallCard(id: 'red_10', color: 'red', value: 10)],
        'p3': [FinalCallCard(id: 'blue_10', color: 'blue', value: 10)],
      },
      automaticCall: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FinalCallTabletGameLayer(
          controller: game,
          stage: FinalCallTabletStage.roundResult,
          flowConfig: buildFinalCallTabletFlowConfig(closingMessage: ''),
          onRoundRevealCompleted: () {},
          onDealingCompleted: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('레드팀 탈락'), findsNothing);
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('레드팀 탈락'), findsNWidgets(2));
  });

  testWidgets('6인 보드는 세 팀의 하트를 표시하고 탈락 팀은 하트 대신 탈락 표시를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = _BoardGame();
    Widget board() => MaterialApp(
      home: Scaffold(
        body: FinalCallTabletGameLayer(
          controller: game,
          stage: FinalCallTabletStage.playing,
          flowConfig: buildFinalCallTabletFlowConfig(closingMessage: ''),
          onRoundRevealCompleted: () {},
          onDealingCompleted: () {},
        ),
      ),
    );
    await tester.pumpWidget(board());
    await tester.pumpAndSettle();
    for (final team in FinalCallTeam.values) {
      for (var heart = 0; heart < 3; heart++) {
        expect(
          find.byKey(ValueKey('final-call-${team.name}-heart-$heart')),
          findsNWidgets(2),
        );
      }
    }
    for (final uid in ['p2', 'p5']) {
      final player = game.players[uid]!;
      game.players[uid] = FinalCallPlayer(
        uid: uid,
        nickname: player.nickname,
        characterId: player.characterId,
        seatIndex: player.seatIndex,
        team: player.team,
        status: 'eliminated',
        lives: uid == 'p2' ? 0 : 3,
      );
    }
    await tester.pumpWidget(board());
    await tester.pumpAndSettle();
    expect(find.text('그린팀 탈락'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('final-call-green-heart-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('final-call-blue-heart-0')),
      findsNWidgets(2),
    );
    // Party Pop 테이블: 차례 알약과 덱 장수, 라운드 안내를 표시합니다.
    expect(find.text('참가자 1 차례예요'), findsOneWidget);
    expect(find.text('덱 17'), findsOneWidget);
    expect(find.text('2라운드 · 같은 색 = 맞은편 짝꿍'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그린팀 우승 화면은 양쪽 팀원의 이름과 올바른 팀명을 표시한다', (tester) async {
    final winners = _BoardGame().players.values
        .where((p) => p.team == FinalCallTeam.green)
        .toList();
    await tester.pumpWidget(
      MaterialApp(
        home: FinalCallResultOverlay(
          winners: winners,
          winningTeam: FinalCallTeam.green,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('그린팀 승리'), findsOneWidget);
    expect(find.textContaining('참가자 2'), findsOneWidget);
    expect(find.textContaining('참가자 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
