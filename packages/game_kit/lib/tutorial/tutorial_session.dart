// [tutorial_session.dart] 는 자리 배치 뒤 첫 플레이 튜토리얼의 공유 상태를
// RTDB(`rooms/{roomCode}/tutorial`)에 읽고 쓰는 파일이다.
//
// - [TutorialSession] : 태블릿(진행자)만 쓰는 진행 상태(단계·라운드·결과)
// - [TutorialEntry] : 휴대폰마다 자기 칸에만 쓰는 응답(확인·연습·건너뛰기·선택)
// - [GameTutorialService] : 위 두 값을 구독하고 쓰는 통신 도구
// - [TutorialSeenStore] : 이 기기에서 그 게임 튜토리얼을 끝까지 봤는지 기억
//
// 튜토리얼은 실제 게임 상태(`game/`)를 건드리지 않습니다. 게임 시작 명령은
// 튜토리얼이 끝난 뒤 기존 자리 배치 흐름이 그대로 보냅니다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================

//==========[ 진행 상태(태블릿이 씀) ]==========
class TutorialSession {
  const TutorialSession({
    required this.id,
    required this.gameId,
    required this.round,
    required this.step,
    required this.phase,
    required this.ended,
    required this.result,
    required this.players,
  });

  /// 튜토리얼을 열 때마다 새로 만드는 식별자입니다. 지난 튜토리얼의 응답과 섞이지 않게 합니다.
  final String id;
  final String gameId;

  /// '튜토리얼 다시 보기'를 고를 때마다 1씩 늘어납니다. 이전 회차 응답을 무시합니다.
  final int round;
  final int step;

  /// 한 단계 안의 세부 장면 번호입니다(예: LIAR를 모두 누른 뒤 공개 장면).
  final int phase;

  /// 모두 건너뛰기를 눌러 끝 화면(게임 시작/다시 보기)으로 간 상태입니다.
  final bool ended;

  /// `start`면 튜토리얼이 끝나 게임을 시작합니다. null이면 진행 중입니다.
  final String? result;

  /// 튜토리얼에 참여하는 플레이어 uid(자리 배치 순서)입니다.
  final List<String> players;

  bool get running => result == null;

  static TutorialSession? fromValue(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final gameId = value['gameId'];
    if (id is! String || gameId is! String) return null;
    final rawPlayers = value['players'];
    final players = <String>[
      if (rawPlayers is List)
        for (final uid in rawPlayers)
          if (uid is String) uid,
      if (rawPlayers is Map)
        for (final uid in rawPlayers.values)
          if (uid is String) uid,
    ];
    return TutorialSession(
      id: id,
      gameId: gameId,
      round: _int(value['round']),
      step: _int(value['step']),
      phase: _int(value['phase']),
      ended: value['ended'] == true,
      result: value['result'] is String ? value['result'] as String : null,
      players: List.unmodifiable(players),
    );
  }
}

//==========[ 플레이어 응답(휴대폰이 자기 칸에 씀) ]==========
class TutorialEntry {
  const TutorialEntry({
    required this.uid,
    this.gameId,
    this.seen = false,
    this.sid,
    this.round = 0,
    this.step = -1,
    this.phase = 0,
    this.done = false,
    this.value = '',
    this.memo = '',
    this.skip = false,
    this.choice,
  });

  final String uid;
  final String? gameId;

  /// 이 기기에서 그 게임 튜토리얼을 이미 끝까지 봤는지입니다.
  final bool seen;
  final String? sid;
  final int round;
  final int step;
  final int phase;

  /// [step]·[phase]에서 해야 할 일(확인·연습)을 마쳤는지입니다.
  final bool done;

  /// 연습 결과(예: 낸 카드 번호 `0,2`, `fold`)입니다.
  final String value;

  /// 한 회차 동안 남겨 두는 값입니다(예: 3단계에서 낸 카드). 다음 단계로 가도 지우지 않습니다.
  final String memo;
  final bool skip;

  /// 끝 화면에서 고른 값(`start`·`replay`)입니다.
  final String? choice;

  /// 지금 진행 중인 [session]의 같은 회차 응답인지입니다.
  bool belongsTo(TutorialSession session) =>
      sid == session.id && round == session.round;

  /// 지금 단계·장면을 마쳤는지입니다.
  bool doneAt(TutorialSession session) =>
      belongsTo(session) &&
      step == session.step &&
      phase == session.phase &&
      done;

  static TutorialEntry fromValue(String uid, Object? value) {
    if (value is! Map) return TutorialEntry(uid: uid);
    return TutorialEntry(
      uid: uid,
      gameId: value['gameId'] is String ? value['gameId'] as String : null,
      seen: value['seen'] == true,
      sid: value['sid'] is String ? value['sid'] as String : null,
      round: _int(value['round']),
      step: value['step'] == null ? -1 : _int(value['step']),
      phase: _int(value['phase']),
      done: value['done'] == true,
      value: value['value'] is String ? value['value'] as String : '',
      memo: value['memo'] is String ? value['memo'] as String : '',
      skip: value['skip'] == true,
      choice: value['choice'] is String ? value['choice'] as String : null,
    );
  }

  Map<String, Object?> toMap() => {
    'gameId': gameId,
    'seen': seen,
    'sid': sid,
    'round': round,
    'step': step,
    'phase': phase,
    'done': done,
    'value': value,
    'memo': memo,
    'skip': skip,
    'choice': choice,
  };

  TutorialEntry copyWith({
    String? gameId,
    bool? seen,
    String? sid,
    int? round,
    int? step,
    int? phase,
    bool? done,
    String? value,
    String? memo,
    bool? skip,
    String? choice,
    bool clearChoice = false,
  }) => TutorialEntry(
    uid: uid,
    gameId: gameId ?? this.gameId,
    seen: seen ?? this.seen,
    sid: sid ?? this.sid,
    round: round ?? this.round,
    step: step ?? this.step,
    phase: phase ?? this.phase,
    done: done ?? this.done,
    value: value ?? this.value,
    memo: memo ?? this.memo,
    skip: skip ?? this.skip,
    choice: clearChoice ? null : (choice ?? this.choice),
  );
}

//==========[ 한 번에 받은 튜토리얼 전체 ]==========
class TutorialSnapshot {
  const TutorialSnapshot({this.session, this.entries = const {}});

  final TutorialSession? session;
  final Map<String, TutorialEntry> entries;

  static TutorialSnapshot fromValue(Object? value) {
    if (value is! Map) return const TutorialSnapshot();
    final rawEntries = value['players'];
    return TutorialSnapshot(
      session: TutorialSession.fromValue(value['session']),
      entries: {
        if (rawEntries is Map)
          for (final entry in rawEntries.entries)
            if (entry.key is String)
              entry.key as String: TutorialEntry.fromValue(
                entry.key as String,
                entry.value,
              ),
      },
    );
  }

  TutorialEntry entryOf(String uid) =>
      entries[uid] ?? TutorialEntry(uid: uid);
}

//==========[ RTDB 통신 ]==========
class GameTutorialService {
  GameTutorialService(this.roomCode);

  final String roomCode;

  DatabaseReference get _root =>
      FirebaseBackend.database.ref('rooms/$roomCode/tutorial');

  Stream<TutorialSnapshot> watch() =>
      _root.onValue.map((event) => TutorialSnapshot.fromValue(event.snapshot.value));

  Future<TutorialSnapshot> read() async =>
      TutorialSnapshot.fromValue((await _root.get()).value);

  //[태블릿] 새 튜토리얼을 엽니다. 휴대폰 응답 칸(이미 본 기록 포함)은 그대로 둡니다.
  Future<String> open({
    required String gameId,
    required List<String> players,
  }) async {
    final random = math.Random();
    final id =
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
        '${random.nextInt(1 << 30).toRadixString(36)}';
    await _root.child('session').set({
      'id': id,
      'gameId': gameId,
      'round': 0,
      'step': 0,
      'phase': 0,
      'ended': false,
      'players': players,
      'updatedAt': ServerValue.timestamp,
    });
    return id;
  }

  //[태블릿] 단계·장면·건너뛰기·결과를 바꿉니다.
  Future<void> update(Map<String, Object?> values) => _root
      .child('session')
      .update({...values, 'updatedAt': ServerValue.timestamp});

  //[태블릿] 튜토리얼을 닫습니다(자리 배치 취소·참가자 변경).
  Future<void> close() => _root.child('session').remove();

  //[휴대폰] 자기 응답 칸을 통째로 씁니다.
  Future<void> writeEntry(TutorialEntry entry) =>
      _root.child('players').child(entry.uid).set(entry.toMap());
}

//==========[ 이미 본 튜토리얼 기억 ]==========
/// 같은 기기·같은 계정이 그 게임 튜토리얼을 끝까지 봤는지 기억합니다.
///
/// 서버 사용자 문서는 클라이언트가 쓸 수 없으므로 기기에 저장합니다.
/// 다른 기기로 바꾸면 한 번 더 보게 되며, 그때는 모두 건너뛰기로 넘길 수 있습니다.
abstract final class TutorialSeenStore {
  static String _key(String uid, String gameId) =>
      'mosigame.tutorialSeen.$uid.$gameId';

  static Future<bool> isSeen(String uid, String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(uid, gameId)) ?? false;
  }

  static Future<void> markSeen(String uid, String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(uid, gameId), true);
  }
}

int _int(Object? value) => switch (value) {
  final int v => v,
  final num v => v.toInt(),
  _ => 0,
};
