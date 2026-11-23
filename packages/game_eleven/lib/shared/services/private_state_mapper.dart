// [private_state_mapper.dart] 는 ELEVEN의 `game/private/{uid}`를 불변 값으로 바꾸는 순수 파서다.
//
// - [Package] : ELEVEN
// - [Mapper] : 본인 손패·본인 제출
//
// 휴대폰만 이 값을 구독한다. 태블릿은 개인 상태를 받지 않는다(계약 4.2).

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';
import 'package:game_eleven/shared/models/tiles.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';

// ============================================================

/// 현재 라운드에 본인이 낸 타일입니다. 다음 라운드 시작 때 서버가 지웁니다.
@immutable
class ElevenSubmission {
  const ElevenSubmission({
    required this.round,
    required this.value,
    required this.auto,
  });

  final int round;
  final int value;

  /// 시간 초과로 서버가 무작위 제출했는지입니다(P06).
  final bool auto;

  @override
  bool operator ==(Object other) =>
      other is ElevenSubmission &&
      round == other.round &&
      value == other.value &&
      auto == other.auto;

  @override
  int get hashCode => Object.hash(round, value, auto);
}

@immutable
class ElevenPrivateSnapshot {
  const ElevenPrivateSnapshot({required this.tiles, this.submission});

  static const empty = ElevenPrivateSnapshot(tiles: []);

  /// RTDB는 빈 배열을 저장하지 않으므로 `tiles`가 없으면 남은 타일 0개입니다.
  factory ElevenPrivateSnapshot.fromValue(Object? value) {
    final map = value is Map
        ? Map<Object?, Object?>.from(value)
        : const <Object?, Object?>{};
    final rawSubmission = map['submission'];
    ElevenSubmission? submission;
    if (rawSubmission is Map) {
      final round = rawSubmission['round'];
      final tile = rawSubmission['value'];
      if (round is num && tile is num) {
        submission = ElevenSubmission(
          round: round.toInt(),
          value: tile.toInt(),
          auto: rawSubmission['auto'] == true,
        );
      }
    }
    final tiles = [
      for (final tile in elevenList(map['tiles']))
        if (tile is num && elevenTiles.contains(tile.toInt())) tile.toInt(),
    ]..sort();
    return ElevenPrivateSnapshot(tiles: tiles, submission: submission);
  }

  /// 남은 타일(오름차순)입니다.
  final List<int> tiles;
  final ElevenSubmission? submission;

  /// 이미 쓴 타일입니다. 화면에서 흐리게 표시합니다.
  Set<int> get usedTiles => elevenTiles.toSet().difference(tiles.toSet());

  /// 이번 라운드 제출 기록입니다. 지난 라운드 값이 남아 있으면 무시합니다.
  ElevenSubmission? submissionFor(int round) =>
      submission?.round == round ? submission : null;

  @override
  bool operator ==(Object other) =>
      other is ElevenPrivateSnapshot &&
      listEquals(tiles, other.tiles) &&
      submission == other.submission;

  @override
  int get hashCode => Object.hash(Object.hashAll(tiles), submission);
}
