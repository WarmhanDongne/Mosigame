// [history_mapper.dart] 는 ELEVEN의 `game/controller/history`를 불변 값으로 바꾸는 순수 파서다.
//
// - [Package] : ELEVEN
// - [Mapper] : 태블릿 전용 지난 라운드 기록
//
// RTDB rules상 방의 controller UID만 읽는다. 휴대폰은 이 경로를 구독하지 않는다(계약 4.3).
// 기록에는 라운드·선공·양쪽 색·승자(또는 동점)만 있고 숫자·합·판정 유형은 없다.

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';
import 'package:game_eleven/shared/models/tiles.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';

// ============================================================

@immutable
class ElevenHistoryEntry {
  const ElevenHistoryEntry({
    required this.round,
    required this.firstUid,
    required this.colors,
    required this.winnerUid,
    this.autoSubmitted = const {},
  });

  final int round;
  final String firstUid;
  final Map<String, ElevenTileColor> colors;

  /// null이면 동점입니다(T08).
  final String? winnerUid;
  final Set<String> autoSubmitted;

  bool get isTie => winnerUid == null;

  @override
  bool operator ==(Object other) =>
      other is ElevenHistoryEntry &&
      round == other.round &&
      firstUid == other.firstUid &&
      mapEquals(colors, other.colors) &&
      winnerUid == other.winnerUid &&
      setEquals(autoSubmitted, other.autoSubmitted);

  @override
  int get hashCode => Object.hash(
    round,
    firstUid,
    Object.hashAllUnordered(
      colors.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    winnerUid,
    Object.hashAllUnordered(autoSubmitted),
  );
}

/// 라운드 순서로 정렬한 기록을 돌려줍니다. 형식이 맞지 않는 항목은 건너뜁니다.
List<ElevenHistoryEntry> parseElevenHistory(Object? value) {
  final entries = <ElevenHistoryEntry>[];
  for (final raw in elevenList(value)) {
    if (raw is! Map) continue;
    final round = raw['round'];
    final firstUid = raw['firstUid'];
    if (round is! num || firstUid is! String) continue;
    final colors = <String, ElevenTileColor>{};
    final rawColors = raw['colors'];
    if (rawColors is Map) {
      for (final entry in rawColors.entries) {
        final color = ElevenTileColor.tryParse(entry.value);
        if (color != null) colors['${entry.key}'] = color;
      }
    }
    final winner = raw['winnerUid'];
    final auto = raw['autoSubmitted'];
    entries.add(
      ElevenHistoryEntry(
        round: round.toInt(),
        firstUid: firstUid,
        colors: colors,
        winnerUid: winner is String && winner.isNotEmpty ? winner : null,
        autoSubmitted: {
          if (auto is Map)
            for (final entry in auto.entries)
              if (entry.value == true) '${entry.key}',
        },
      ),
    );
  }
  entries.sort((a, b) => a.round.compareTo(b.round));
  return List.unmodifiable(entries);
}
