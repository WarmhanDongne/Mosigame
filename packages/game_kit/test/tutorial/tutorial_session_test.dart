import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/tutorial/tutorial_session.dart';

void main() {
  group('TutorialSnapshot', () {
    test('진행 상태와 플레이어 응답을 읽는다', () {
      final snapshot = TutorialSnapshot.fromValue({
        'session': {
          'id': 's1',
          'gameId': 'liars_poker',
          'round': 1,
          'step': 3,
          'phase': 0,
          'ended': false,
          'players': ['a', 'b'],
        },
        'players': {
          'a': {
            'gameId': 'liars_poker',
            'seen': false,
            'sid': 's1',
            'round': 1,
            'step': 3,
            'phase': 0,
            'done': true,
            'value': '0,2',
            'memo': '0,2',
          },
          'b': {'gameId': 'liars_poker', 'seen': true},
        },
      });

      final session = snapshot.session!;
      expect(session.players, ['a', 'b']);
      expect(session.running, isTrue);
      expect(snapshot.entryOf('a').doneAt(session), isTrue);
      expect(snapshot.entryOf('a').memo, '0,2');
      expect(snapshot.entryOf('b').doneAt(session), isFalse);
      expect(snapshot.entryOf('b').seen, isTrue);
      expect(snapshot.entryOf('c').belongsTo(session), isFalse);
    });

    test('다른 회차 응답은 지금 단계 완료로 보지 않는다', () {
      final snapshot = TutorialSnapshot.fromValue({
        'session': {'id': 's1', 'gameId': 'g', 'round': 2, 'step': 0, 'players': ['a']},
        'players': {
          'a': {'sid': 's1', 'round': 1, 'step': 0, 'phase': 0, 'done': true},
        },
      });
      expect(snapshot.entryOf('a').doneAt(snapshot.session!), isFalse);
    });

    test('RTDB가 숫자 키 맵으로 준 플레이어 목록도 읽는다', () {
      final session = TutorialSession.fromValue({
        'id': 's',
        'gameId': 'g',
        'players': {'0': 'a', '1': 'b'},
        'result': 'start',
      })!;
      expect(session.players, ['a', 'b']);
      expect(session.running, isFalse);
    });

    test('응답을 다시 쓰면 값이 보존된다', () {
      const entry = TutorialEntry(uid: 'a', gameId: 'g', sid: 's', memo: '1');
      final next = entry.copyWith(step: 4, done: true, value: 'ok');
      expect(next.memo, '1');
      expect(TutorialEntry.fromValue('a', next.toMap()).value, 'ok');
    });
  });
}
