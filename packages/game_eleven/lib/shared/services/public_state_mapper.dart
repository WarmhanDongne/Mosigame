// [public_state_mapper.dart] 는 ELEVEN의 `game/public` snapshot을 불변 값으로 바꾸는 순수 파서다.
//
// - [Package] : ELEVEN
// - [Mapper] : 공개 상태 → ElevenPublicSnapshot
//
// 구독과 상태 발행은 controller가 맡는다. 필드 이름은
// docs/engineering/ELEVEN_GAME_CONTRACT.md 4.1과 functions/src/eleven/types.ts를 따른다.
// 공개 상태에는 실제 숫자·합·판정 유형이 없다(뽑기 공개값 `draw.revealed`만 예외).
// `lastRoundResult`도 직전 라운드의 승자 또는 동점만 담는다(계약 4.1, 2026-11-25).

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_eleven/shared/models/tiles.dart';

// ============================================================

Map<Object?, Object?> _map(Object? raw) =>
    raw is Map ? Map<Object?, Object?>.from(raw) : const {};

int? _int(Object? raw) => raw is num ? raw.toInt() : null;

String? _string(Object? raw) => raw is String && raw.isNotEmpty ? raw : null;

/// RTDB는 배열을 List로, 빈 칸이 있는 배열을 Map으로 돌려줄 수 있습니다.
List<Object?> elevenList(Object? raw) {
  if (raw is List) return List<Object?>.from(raw);
  if (raw is Map) {
    final entries =
        raw.entries
            .map((entry) => (int.tryParse('${entry.key}'), entry.value))
            .where((entry) => entry.$1 != null)
            .toList()
          ..sort((a, b) => a.$1!.compareTo(b.$1!));
    return [for (final entry in entries) entry.$2];
  }
  return const [];
}

Map<String, int> _intMap(Object? raw) => {
  for (final entry in _map(raw).entries) '${entry.key}': ?_int(entry.value),
};

@immutable
class ElevenPlayerView {
  const ElevenPlayerView({
    required this.uid,
    required this.nickname,
    required this.characterId,
    required this.seatIndex,
    required this.eliminated,
  });

  final String uid;
  final String nickname;
  final String characterId;
  final int seatIndex;
  final bool eliminated;

  @override
  bool operator ==(Object other) =>
      other is ElevenPlayerView &&
      uid == other.uid &&
      nickname == other.nickname &&
      characterId == other.characterId &&
      seatIndex == other.seatIndex &&
      eliminated == other.eliminated;

  @override
  int get hashCode =>
      Object.hash(uid, nickname, characterId, seatIndex, eliminated);
}

/// 현재 라운드의 공개 정보입니다. 색은 제출 즉시 공개되고 숫자는 없습니다.
@immutable
class ElevenRoundView {
  const ElevenRoundView({
    required this.round,
    this.firstColor,
    this.secondColor,
    this.autoSubmitted = const {},
  });

  final int round;
  final ElevenTileColor? firstColor;
  final ElevenTileColor? secondColor;
  final Set<String> autoSubmitted;

  @override
  bool operator ==(Object other) =>
      other is ElevenRoundView &&
      round == other.round &&
      firstColor == other.firstColor &&
      secondColor == other.secondColor &&
      setEquals(autoSubmitted, other.autoSubmitted);

  @override
  int get hashCode => Object.hash(
    round,
    firstColor,
    secondColor,
    Object.hashAllUnordered(autoSubmitted),
  );
}

enum ElevenDrawPurpose { firstPlayer, finalTie }

/// 공용 타일 뽑기 공개 상태입니다. 공개 전 배치는 서버에만 있습니다.
@immutable
class ElevenDrawView {
  const ElevenDrawView({
    required this.purpose,
    required this.order,
    required this.picks,
    required this.nextPickerUid,
    this.revealed = const {},
    this.winnerUid,
  });

  final ElevenDrawPurpose purpose;

  /// 뽑는 순서입니다. [0]이 먼저 고릅니다.
  final List<String> order;

  /// uid → 고른 칸(0–8).
  final Map<String, int> picks;
  final String? nextPickerUid;

  /// 두 사람이 모두 고른 뒤에만 채워지는 uid → 뽑은 숫자.
  final Map<String, int> revealed;
  final String? winnerUid;

  bool isTaken(int slotIndex) => picks.containsValue(slotIndex);

  /// 태블릿이 이 위치를 고를 수 있게 보여 줄지입니다. 범위(0–8) 밖이거나 이미
  /// 고른 위치는 고를 수 없습니다. 차례 검증은 서버가 합니다.
  bool canPick(int slotIndex) =>
      elevenIsDrawSlot(slotIndex) && !isTaken(slotIndex);

  @override
  bool operator ==(Object other) =>
      other is ElevenDrawView &&
      purpose == other.purpose &&
      listEquals(order, other.order) &&
      mapEquals(picks, other.picks) &&
      nextPickerUid == other.nextPickerUid &&
      mapEquals(revealed, other.revealed) &&
      winnerUid == other.winnerUid;

  @override
  int get hashCode => Object.hash(
    purpose,
    Object.hashAll(order),
    Object.hashAllUnordered(
      picks.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    nextPickerUid,
    Object.hashAllUnordered(
      revealed.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    winnerUid,
  );
}

/// 직전 라운드 결과를 본인 기준으로 본 값입니다(P08).
enum ElevenRoundOutcome { win, lose, tie }

/// `public.lastRoundResult`: 직전 1라운드의 승자 또는 동점만 있습니다(계약 4.1).
/// 숫자·합·판정 유형은 없고, 이 모델에도 그런 필드를 두지 않습니다.
@immutable
class ElevenRoundResult {
  const ElevenRoundResult({required this.round, this.winnerUid});

  /// 키가 없거나 형식이 맞지 않으면 null(첫 판정 전)입니다.
  /// `winnerUid`가 없거나 null·빈 값이면 동점입니다(RTDB는 null을 저장하지 않음).
  static ElevenRoundResult? tryParse(Object? raw) {
    final map = _map(raw);
    final round = _int(map['round']);
    if (round == null) return null;
    return ElevenRoundResult(
      round: round,
      winnerUid: _string(map['winnerUid']),
    );
  }

  final int round;

  /// null이면 동점입니다.
  final String? winnerUid;

  bool get isTie => winnerUid == null;

  ElevenRoundOutcome outcomeFor(String uid) => switch (winnerUid) {
    null => ElevenRoundOutcome.tie,
    final winner when winner == uid => ElevenRoundOutcome.win,
    _ => ElevenRoundOutcome.lose,
  };

  @override
  bool operator ==(Object other) =>
      other is ElevenRoundResult &&
      round == other.round &&
      winnerUid == other.winnerUid;

  @override
  int get hashCode => Object.hash(round, winnerUid);
}

/// T10 조기 종료 안내용 공개 값입니다.
@immutable
class ElevenEarlyEnd {
  const ElevenEarlyEnd({
    required this.remainingRounds,
    required this.leaderUid,
    required this.gap,
  });

  final int remainingRounds;
  final String leaderUid;
  final int gap;

  @override
  bool operator ==(Object other) =>
      other is ElevenEarlyEnd &&
      remainingRounds == other.remainingRounds &&
      leaderUid == other.leaderUid &&
      gap == other.gap;

  @override
  int get hashCode => Object.hash(remainingRounds, leaderUid, gap);
}

@immutable
class ElevenPublicSnapshot {
  const ElevenPublicSnapshot({
    required this.status,
    required this.phase,
    required this.round,
    required this.revision,
    this.players = const {},
    this.scores = const {},
    this.firstUid,
    this.secondUid,
    this.turnUid,
    this.turnDeadlineAt,
    this.currentRound = const ElevenRoundView(round: 1),
    this.draw,
    this.winnerUid,
    this.finishReason,
    this.finishDetail,
    this.earlyEnd,
    this.lastRoundResult,
    this.startedAt,
    this.interruption,
  });

  static const initial = ElevenPublicSnapshot(
    status: 'waiting',
    phase: 'waiting',
    round: 1,
    revision: 0,
  );

  factory ElevenPublicSnapshot.fromValue(Object? value) {
    final map = _map(value);
    final draw = _map(map['draw']);
    final round = _map(map['currentRound']);
    final early = _map(map['earlyEnd']);
    final interruption = map['interruption'];
    final purpose = switch (draw['purpose']) {
      'firstPlayer' => ElevenDrawPurpose.firstPlayer,
      'finalTie' => ElevenDrawPurpose.finalTie,
      _ => null,
    };
    final players = <String, ElevenPlayerView>{};
    for (final entry in _map(map['players']).entries) {
      final player = _map(entry.value);
      final uid = _string(player['uid']) ?? '${entry.key}';
      players[uid] = ElevenPlayerView(
        uid: uid,
        nickname: _string(player['nickname']) ?? 'Player',
        characterId: player['characterId']?.toString() ?? '',
        seatIndex: _int(player['seatIndex']) ?? 0,
        eliminated: player['status'] == 'eliminated',
      );
    }
    final leaderUid = _string(early['leaderUid']);
    return ElevenPublicSnapshot(
      status: _string(map['status']) ?? 'waiting',
      phase: _string(map['phase']) ?? 'waiting',
      round: _int(map['round']) ?? 1,
      revision: _int(map['revision']) ?? 0,
      players: players,
      scores: _intMap(map['scores']),
      firstUid: _string(map['firstUid']),
      secondUid: _string(map['secondUid']),
      turnUid: _string(map['turnUid']),
      turnDeadlineAt: _int(map['turnDeadlineAt']),
      currentRound: ElevenRoundView(
        round: _int(round['round']) ?? _int(map['round']) ?? 1,
        firstColor: ElevenTileColor.tryParse(round['firstColor']),
        secondColor: ElevenTileColor.tryParse(round['secondColor']),
        autoSubmitted: {
          for (final entry in _map(round['autoSubmitted']).entries)
            if (entry.value == true) '${entry.key}',
        },
      ),
      draw: purpose == null
          ? null
          : ElevenDrawView(
              purpose: purpose,
              order: [
                for (final uid in elevenList(draw['order'])) ?_string(uid),
              ],
              picks: _intMap(draw['picks']),
              nextPickerUid: _string(draw['nextPickerUid']),
              revealed: _intMap(draw['revealed']),
              winnerUid: _string(draw['winnerUid']),
            ),
      winnerUid: _string(map['winnerUid']),
      finishReason: _string(map['finishReason']),
      finishDetail: _string(map['finishDetail']),
      earlyEnd: leaderUid == null
          ? null
          : ElevenEarlyEnd(
              remainingRounds: _int(early['remainingRounds']) ?? 0,
              leaderUid: leaderUid,
              gap: _int(early['gap']) ?? 0,
            ),
      lastRoundResult: ElevenRoundResult.tryParse(map['lastRoundResult']),
      startedAt: _int(map['startedAt']),
      interruption: interruption is Map
          ? GameInterruption.fromMap(Map<Object?, Object?>.from(interruption))
          : null,
    );
  }

  final String status;
  final String phase;
  final int round;
  final int revision;
  final Map<String, ElevenPlayerView> players;
  final Map<String, int> scores;
  final String? firstUid;
  final String? secondUid;
  final String? turnUid;
  final int? turnDeadlineAt;
  final ElevenRoundView currentRound;
  final ElevenDrawView? draw;
  final String? winnerUid;
  final String? finishReason;

  /// `earlyEnd` | `allRounds` | `tieDraw`. 정상 승부 종료에만 있습니다.
  final String? finishDetail;
  final ElevenEarlyEnd? earlyEnd;

  /// 직전 라운드 결과입니다. 첫 판정 전에는 null입니다.
  final ElevenRoundResult? lastRoundResult;
  final int? startedAt;
  final GameInterruption? interruption;

  bool get isFinished => status == 'finished';

  /// 좌석 순서로 정렬한 참가자입니다.
  List<ElevenPlayerView> get seatedPlayers =>
      players.values.toList()
        ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));

  String nicknameOf(String? uid) => players[uid]?.nickname ?? '';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElevenPublicSnapshot &&
          status == other.status &&
          phase == other.phase &&
          round == other.round &&
          revision == other.revision &&
          mapEquals(players, other.players) &&
          mapEquals(scores, other.scores) &&
          firstUid == other.firstUid &&
          secondUid == other.secondUid &&
          turnUid == other.turnUid &&
          turnDeadlineAt == other.turnDeadlineAt &&
          currentRound == other.currentRound &&
          draw == other.draw &&
          winnerUid == other.winnerUid &&
          finishReason == other.finishReason &&
          finishDetail == other.finishDetail &&
          earlyEnd == other.earlyEnd &&
          lastRoundResult == other.lastRoundResult &&
          startedAt == other.startedAt &&
          interruption == other.interruption;

  @override
  int get hashCode => Object.hashAll([
    status,
    phase,
    round,
    revision,
    Object.hashAllUnordered(players.values),
    Object.hashAllUnordered(
      scores.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    firstUid,
    secondUid,
    turnUid,
    turnDeadlineAt,
    currentRound,
    draw,
    winnerUid,
    finishReason,
    finishDetail,
    earlyEnd,
    lastRoundResult,
    startedAt,
    interruption,
  ]);
}
