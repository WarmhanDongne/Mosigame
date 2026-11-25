import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/game_flow/turn_timeout_record.dart';

void main() {
  test('서버 lastTimeout 값을 읽는다', () {
    final record = TurnTimeoutRecord.fromValue({
      'uid': 'me',
      'kind': 'liar',
      'at': 1000,
    });
    expect(record, isNotNull);
    expect(record!.uid, 'me');
    expect(record.kind, 'liar');
    expect(record.at, 1000);
  });

  test('모양이 다른 값은 무시한다', () {
    expect(TurnTimeoutRecord.fromValue(null), isNull);
    expect(TurnTimeoutRecord.fromValue('x'), isNull);
    expect(TurnTimeoutRecord.fromValue({'uid': 'me', 'kind': 'liar'}), isNull);
    expect(TurnTimeoutRecord.fromValue({'kind': 'liar', 'at': 1}), isNull);
  });

  test('내 기록이고 방금 일어난 일일 때만 새 안내로 본다', () {
    final now = ServerClock.nowMillis();
    final fresh = TurnTimeoutRecord(uid: 'me', kind: 'submit', at: now);
    final old = TurnTimeoutRecord(
      uid: 'me',
      kind: 'submit',
      at: now - TurnTimeoutRecord.freshWindow.inMilliseconds - 1000,
    );
    expect(fresh.isFreshFor('me'), isTrue);
    expect(fresh.isFreshFor('other'), isFalse);
    expect(old.isFreshFor('me'), isFalse);
  });
}
