// [tablet_game_tutorial.dart] 는 자리 배치가 끝난 뒤, 게임 시작 명령을 보내기
// 전에 첫 플레이 튜토리얼을 띄울지 정하고 띄우는 파일이다.
//
// - 게임이 [TemplateGame.tutorial]을 주지 않으면 아무것도 하지 않습니다.
// - 참가자 중 그 게임 튜토리얼을 아직 끝까지 보지 않은 사람이 한 명이라도
//   있으면 튜토리얼을 엽니다. 모두 본 사람이면 바로 게임을 시작합니다.
// - 튜토리얼에서 '게임 시작'이 정해지면 true, 화면이 닫히면 false입니다.

// ========================[ import ]==========================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/template_game.dart';
import 'package:game_kit/tutorial/game_tutorial.dart';

// ============================================================

/// 휴대폰의 '튜토리얼을 봤는지' 응답을 기다리는 최대 시간입니다.
const _seenWait = Duration(seconds: 2);

Future<bool> runTabletTutorialIfNeeded({
  required BuildContext context,
  required TemplateGame game,
  required String roomCode,
  required PlayerLayoutModel layout,
}) async {
  final tutorial = game.tutorial;
  if (tutorial == null || layout.players.isEmpty) return true;
  final service = GameTutorialService(roomCode);
  final uids = [for (final player in layout.players) player.uid];

  final bool needed;
  try {
    needed = await _needsTutorial(service, tutorial.gameId, uids);
  } catch (error) {
    // 튜토리얼 상태를 읽지 못해도 게임 시작은 막지 않습니다.
    debugPrint('튜토리얼 상태를 읽지 못해 건너뜁니다: $error');
    return true;
  }
  if (!needed) return true;
  if (!context.mounted) return false;

  try {
    await service.open(gameId: tutorial.gameId, players: uids);
  } catch (error) {
    debugPrint('튜토리얼을 열지 못해 건너뜁니다: $error');
    return true;
  }
  if (!context.mounted) return false;

  final players = [
    for (final player in layout.players)
      TutorialPlayer(
        uid: player.uid,
        nickname: player.nickname,
        characterId: player.characterId,
        seatIndex: player.seatIndex,
      ),
  ];
  final started = await Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (routeContext, _, _) => PopScope(
        // 뒤로 가기 한 번으로 모두의 튜토리얼이 사라지지 않게 막습니다.
        canPop: false,
        child: GameTutorialTabletHost(
          tutorial: tutorial,
          service: service,
          players: players,
          onFinished: (start) {
            if (routeContext.mounted) Navigator.of(routeContext).pop(start);
          },
        ),
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
  if (started != true) {
    unawaited(service.close().catchError((Object _) {}));
    return false;
  }
  return true;
}

/// 한 명이라도 아직 안 봤으면 true입니다. 응답이 늦은 휴대폰은 안 본 것으로 봅니다.
Future<bool> _needsTutorial(
  GameTutorialService service,
  String gameId,
  List<String> uids,
) async {
  bool? decide(TutorialSnapshot snapshot) {
    var allSeen = true;
    for (final uid in uids) {
      final entry = snapshot.entries[uid];
      if (entry == null || entry.gameId != gameId) {
        allSeen = false;
        continue;
      }
      if (!entry.seen) return true;
    }
    return allSeen ? false : null;
  }

  final first = decide(await service.read());
  if (first != null) return first;
  try {
    final snapshot = await service
        .watch()
        .firstWhere((snapshot) => decide(snapshot) != null)
        .timeout(_seenWait);
    return decide(snapshot) ?? true;
  } on TimeoutException {
    return true;
  }
}
