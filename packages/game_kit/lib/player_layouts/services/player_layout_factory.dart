// [player_layout_factory.dart] 는 인원과 게임 규칙에 맞는 자리 배치를 생성하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [PlayerLayout] : 태블릿의 플레이어 자리 배치와 편집 규칙을 관리함
//
// 즉, 인원과 기기 크기에 맞춰 자리를 안정적으로 배치하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/models/game_room_context.dart';

// ============================================================

//==========[ 기본 자리 배치 생성 ]==========
class PlayerLayoutFactory {
  //[순서배치] 방 참가자 순서를 좌석 번호로 사용해 기본 배치 생성
  static PlayerLayoutModel create(List<GameRoomPlayer> players) {
    return PlayerLayoutModel(
      players: List<PlayerLayoutPlayer>.unmodifiable(
        Iterable.generate(players.length, (index) {
          final player = players[index];

          return PlayerLayoutPlayer(
            uid: player.uid,
            nickname: player.nickname,
            characterId: player.characterId,

            //[좌석번호] 참가자 목록의 현재 순서를 그대로 사용
            seatIndex: index,
          );
        }),
      ),
    );
  }

  //[이전배치] 지난 게임 시작 때 저장한 좌석 순서를 지금 참가자에게 다시 적용
  //
  // 서버는 게임을 시작할 때마다 각 참가자의 seatIndex를 저장하고 대기실로
  // 돌아와도 지우지 않습니다. 새로 들어온 사람(-1)이 있거나 번호가 겹치면
  // 지난 배치를 그대로 쓸 수 없으므로 null입니다. 누가 나가 번호가 비면
  // 남은 사람의 순서만 유지해 0부터 다시 매깁니다.
  static PlayerLayoutModel? fromSavedSeats(List<GameRoomPlayer> players) {
    final seats = players.map((player) => player.seatIndex).toSet();
    if (players.length < 2 ||
        seats.length != players.length ||
        seats.any((seat) => seat < 0)) {
      return null;
    }
    final bySeat = [...players]
      ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
    final seatByUid = {
      for (var seat = 0; seat < bySeat.length; seat++) bySeat[seat].uid: seat,
    };
    return PlayerLayoutModel(
      players: List<PlayerLayoutPlayer>.unmodifiable(
        players.map(
          (player) => PlayerLayoutPlayer(
            uid: player.uid,
            nickname: player.nickname,
            characterId: player.characterId,
            seatIndex: seatByUid[player.uid]!,
          ),
        ),
      ),
    );
  }

  /// 저장 당시 명단과 현재 명단이 달라도 남아 있는 참가자의 자리를 최대한
  /// 유지하고, 새 참가자는 빈 자리에 순서대로 배치합니다.
  ///
  /// 인원 감소로 예전 좌석 번호가 현재 범위를 벗어나면 남아 있는 참가자의
  /// 상대 순서를 유지한 채 0부터 다시 매깁니다. 저장 명단과 겹치는 참가자가
  /// 없거나 기존 참가자의 좌석 기록이 손상됐으면 안전하게 기본 배치로
  /// 돌아갈 수 있도록 null을 반환합니다.
  static PlayerLayoutModel? mergeSavedRoster(
    List<GameRoomPlayer> players, {
    required Set<String> savedPlayerUids,
  }) {
    if (players.length < 2 || savedPlayerUids.isEmpty) return null;

    final returningPlayers = players
        .where((player) => savedPlayerUids.contains(player.uid))
        .toList(growable: false);
    if (returningPlayers.isEmpty ||
        returningPlayers.any((player) => player.seatIndex < 0) ||
        returningPlayers.map((player) => player.seatIndex).toSet().length !=
            returningPlayers.length) {
      return null;
    }

    final seatByUid = <String, int>{};
    final canKeepExactSeats = returningPlayers.every(
      (player) => player.seatIndex < players.length,
    );
    if (canKeepExactSeats) {
      for (final player in returningPlayers) {
        seatByUid[player.uid] = player.seatIndex;
      }
    } else {
      final byPreviousSeat = [...returningPlayers]
        ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
      for (final (seatIndex, player) in byPreviousSeat.indexed) {
        seatByUid[player.uid] = seatIndex;
      }
    }

    final occupiedSeats = seatByUid.values.toSet();
    final availableSeats = [
      for (var seat = 0; seat < players.length; seat++)
        if (!occupiedSeats.contains(seat)) seat,
    ].iterator;
    for (final player in players) {
      if (seatByUid.containsKey(player.uid)) continue;
      if (!availableSeats.moveNext()) return null;
      seatByUid[player.uid] = availableSeats.current;
    }

    return PlayerLayoutModel(
      players: List<PlayerLayoutPlayer>.unmodifiable(
        players.map(
          (player) => PlayerLayoutPlayer(
            uid: player.uid,
            nickname: player.nickname,
            characterId: player.characterId,
            seatIndex: seatByUid[player.uid]!,
          ),
        ),
      ),
    );
  }
}
