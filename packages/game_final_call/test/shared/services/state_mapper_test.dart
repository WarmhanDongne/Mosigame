import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/game_sounds.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/services/private_state_mapper.dart';
import 'package:game_final_call/shared/services/public_state_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('파이널콜 전용 배경음은 패키지에 포함되고 모바일 용량으로 압축된다', () async {
    final audio = await rootBundle.load(FinalCallSounds.background);

    expect(audio.lengthInBytes, greaterThan(250 * 1024));
    expect(audio.lengthInBytes, lessThan(400 * 1024));
  });

  test('세 번째 팀과 승리 팀을 서버 값 그대로 읽는다', () {
    final players = parseFinalCallPlayers({
      'u3': {'seatIndex': 2, 'team': 'green', 'lives': 3},
      'u6': {'seatIndex': 5, 'team': 'green', 'lives': 3},
    });
    expect(players['u3']?.team, FinalCallTeam.green);
    expect(players['u6']?.team, FinalCallTeam.green);
    expect(parseFinalCallWinningTeam('green'), FinalCallTeam.green);
    expect(
      FinalCallSounds.resultVoiceFor(
        isDraw: false,
        winningTeam: FinalCallTeam.green,
      ),
      isNull,
    );
    expect(
      FinalCallSounds.resultVoiceFor(
        isDraw: false,
        winningTeam: FinalCallTeam.red,
      ),
      FinalCallSounds.voiceWinRed,
    );
    expect(
      FinalCallSounds.resultVoiceFor(
        isDraw: false,
        winningTeam: FinalCallTeam.blue,
      ),
      FinalCallSounds.voiceWinBlue,
    );
    expect(
      FinalCallSounds.resultVoiceFor(isDraw: true, winningTeam: null),
      FinalCallSounds.voiceDraw,
    );
  });

  test('공개 플레이어와 문자열 목록을 서버 값에서 변환한다', () {
    final players = parseFinalCallPlayers({
      'u1': {'nickname': '민호', 'seatIndex': 1, 'team': 'blue', 'lives': 2},
    });

    expect(players['u1']?.nickname, '민호');
    expect(players['u1']?.team.name, 'blue');
    expect(parseFinalCallStringCollection({0: 'u1', 1: 'u2'}), ['u1', 'u2']);
  });

  test('개인 snapshot을 손패와 대기 카드로 구분한다', () {
    final snapshot = FinalCallPrivateSnapshot.fromValue({
      'hand': {
        'c1': {'id': 'c1', 'color': 'red', 'value': 7},
      },
      'pendingDraw': {'id': 'c2', 'color': 'blue', 'value': 3},
    });

    expect(snapshot.hand.single.id, 'c1');
    expect(snapshot.pendingDraw?.id, 'c2');
  });

  test('포카드 CALL 결과는 선언자와 포카드 여부를 함께 읽는다', () {
    final result = parseFinalCallRoundResult({
      'scores': {'u1': 28},
      'lifeLosses': {'u2': 1, 'u4': 1},
      'revealedHands': {
        'u1': [
          {'id': 'a', 'color': 'red', 'value': 7},
          {'id': 'b', 'color': 'blue', 'value': 7},
          {'id': 'c', 'color': 'green', 'value': 7},
          {'id': 'd', 'color': 'yellow', 'value': 7},
        ],
      },
      'automaticCall': false,
      'callerUid': 'u1',
      'callerFourOfAKind': true,
    })!;

    expect(result.callerUid, 'u1');
    expect(result.callerFourOfAKind, isTrue);
    expect(result.revealedHands.keys, ['u1']);
    expect(result.lifeLosses, {'u2': 1, 'u4': 1});
  });

  test('이전 서버 결과처럼 포카드 값이 없으면 일반 CALL로 읽는다', () {
    final result = parseFinalCallRoundResult({
      'scores': {'u1': 10},
      'lifeLosses': {'u1': 1},
      'revealedHands': const {},
    })!;

    expect(result.callerUid, isNull);
    expect(result.callerFourOfAKind, isFalse);
  });

  test('같은 숫자 4장만 포카드로 본다', () {
    FinalCallCard c(String id, String color, int value) =>
        FinalCallCard(id: id, color: color, value: value);

    expect(
      isFinalCallFourOfAKind([
        c('a', 'red', 7),
        c('b', 'blue', 7),
        c('c', 'green', 7),
        c('d', 'yellow', 7),
      ]),
      isTrue,
    );
    expect(
      isFinalCallFourOfAKind([
        c('a', 'red', 7),
        c('b', 'blue', 7),
        c('c', 'green', 7),
        c('d', 'yellow', 2),
      ]),
      isFalse,
    );
    expect(
      isFinalCallFourOfAKind([
        c('a', 'red', 7),
        c('b', 'blue', 7),
        c('c', 'green', 7),
      ]),
      isFalse,
    );
  });
}
