import 'package:flutter/foundation.dart';

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value))
    : <String, dynamic>{};
int _int(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

enum RouletteAction { spin, shield, none }

RouletteAction? actionFromWire(Object? value) => switch (value) {
  'spin' => RouletteAction.spin,
  'shield' => RouletteAction.shield,
  'none' => RouletteAction.none,
  _ => null,
};

@immutable
class RoulettePlayerView {
  const RoulettePlayerView({
    required this.uid,
    required this.nickname,
    required this.characterId,
    required this.seatIndex,
    required this.alive,
    required this.shieldLocked,
    required this.rank,
  });

  final String uid;
  final String nickname;
  final String characterId;
  final int seatIndex;
  final bool alive;
  final bool shieldLocked;
  final int? rank;
}

@immutable
class RussianRouletteView {
  const RussianRouletteView({
    required this.loaded,
    required this.status,
    required this.phase,
    required this.round,
    required this.targetUid,
    required this.deadlineAt,
    required this.choiceCount,
    required this.spinCount,
    required this.players,
    required this.actions,
    required this.winnerUid,
    required this.shotBlocked,
    required this.eliminatedUid,
    required this.paused,
  });

  factory RussianRouletteView.fromPublic(Map<String, dynamic> pub) {
    final players = <String, RoulettePlayerView>{};
    _map(pub['players']).forEach((uid, raw) {
      final player = _map(raw);
      players[uid] = RoulettePlayerView(
        uid: uid,
        nickname: '${player['nickname'] ?? ''}',
        characterId: '${player['characterId'] ?? ''}',
        seatIndex: _int(player['seatIndex']),
        alive: player['status'] != 'eliminated',
        shieldLocked: player['shieldLocked'] == true,
        rank: player['rank'] is num ? (player['rank'] as num).toInt() : null,
      );
    });
    return RussianRouletteView(
      loaded: pub.isNotEmpty,
      status: '${pub['status'] ?? ''}',
      phase: '${pub['phase'] ?? ''}',
      round: _int(pub['round'], 1),
      targetUid: pub['targetUid'] as String?,
      deadlineAt: _int(pub['turnDeadlineAt']),
      choiceCount: _int(pub['choiceCount']),
      spinCount: _int(pub['spinCount']),
      players: players,
      actions: _map(pub['revealedActions']).map(
        (uid, value) =>
            MapEntry(uid, actionFromWire(value) ?? RouletteAction.none),
      ),
      winnerUid: pub['winnerUid'] as String?,
      shotBlocked: pub['shotBlocked'] as bool?,
      eliminatedUid: pub['eliminatedUid'] as String?,
      paused: _map(pub['recovery'])['paused'] == true,
    );
  }

  final bool loaded;
  final String status;
  final String phase;
  final int round;
  final String? targetUid;
  final int deadlineAt;
  final int choiceCount;
  final int spinCount;
  final Map<String, RoulettePlayerView> players;
  final Map<String, RouletteAction> actions;
  final String? winnerUid;
  final bool? shotBlocked;
  final String? eliminatedUid;
  final bool paused;

  bool get finished => status == 'finished';
  List<RoulettePlayerView> get orderedPlayers =>
      players.values.toList()
        ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
  int get aliveCount => players.values.where((player) => player.alive).length;
}
