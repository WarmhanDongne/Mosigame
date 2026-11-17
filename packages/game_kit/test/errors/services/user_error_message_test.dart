import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/errors/services/user_error_message.dart';

void main() {
  test('stale game command is shown as a completed-turn status', () {
    final error = FirebaseFunctionsException(
      code: 'failed-precondition',
      message: '이전 게임 단계의 요청입니다.',
      details: const {'reason': 'staleContext'},
    );

    expect(
      userErrorMessage(error, context: UserErrorContext.gameCommand),
      '턴이 이미 종료되어 다음 차례로 넘어갔어요.',
    );
  });

  test('stale-context mapping does not rewrite non-game commands', () {
    final error = FirebaseFunctionsException(
      code: 'failed-precondition',
      message: '이전 게임 단계의 요청입니다.',
      details: const {'reason': 'staleContext'},
    );

    expect(
      userErrorMessage(error, context: UserErrorContext.roomCommand),
      '이전 게임 단계의 요청입니다.',
    );
  });
}
