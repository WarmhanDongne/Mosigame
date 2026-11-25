// [turn_timeout_record.dart] 는 서버가 시간 초과로 대신 처리한 일을 휴대폰이
// 읽는 작은 기록이다. 라이어스·파이널콜 공개 상태의 `lastTimeout` 값을 담는다.
//
// 진행 판정에는 쓰지 않고, "방금 내 시간이 다 돼서 이렇게 처리됐어요" 안내를
// 한 번 띄우는 데만 씁니다. 재접속했을 때 오래된 기록이 다시 뜨지 않도록
// 서버 시각 기준으로 막 일어난 기록만 새것으로 봅니다.

// ========================[ import ]==========================
import 'package:game_kit/core/time/server_clock.dart';

// ============================================================

class TurnTimeoutRecord {
  const TurnTimeoutRecord({
    required this.uid,
    required this.kind,
    required this.at,
  });

  /// 시간이 다 된 플레이어입니다.
  final String uid;

  /// 서버가 대신 한 일입니다. 게임마다 값이 다릅니다.
  final String kind;

  /// 서버가 처리한 시각(ms)입니다. 같은 기록을 두 번 띄우지 않는 열쇠입니다.
  final int at;

  /// 안내로 띄울 만큼 최근 기록으로 보는 시간입니다.
  static const freshWindow = Duration(seconds: 6);

  static TurnTimeoutRecord? fromValue(Object? value) {
    if (value is! Map) return null;
    final uid = value['uid']?.toString();
    final kind = value['kind']?.toString();
    final at = value['at'];
    if (uid == null || uid.isEmpty || kind == null || at is! num) return null;
    return TurnTimeoutRecord(uid: uid, kind: kind, at: at.toInt());
  }

  /// [myUid]의 시간 초과이고 방금 일어난 일인지입니다.
  bool isFreshFor(String myUid) =>
      uid == myUid &&
      ServerClock.nowMillis() - at <= freshWindow.inMilliseconds;
}
