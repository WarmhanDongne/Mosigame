// 게임 진입점 등록 정보(공유). S5-0b에서 test/widgets_test.dart를 소유 폴더별로 나눴다.
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_eleven/game_eleven.dart';
import 'package:game_eleven/shared/services/command_service.dart';

void main() {
  test('entrypoint exposes a fixed 2-player game with server names', () {
    const game = ElevenGame();
    expect(game.id, 'eleven');
    expect(game.fixedPlayerCount, 2);
    expect(game.supportedPlayerCounts, [2]);
    expect(game.leaveFunctionName, 'game_eleven_leave_game');
    // 노션 개발 계획: 휴대폰은 시안의 가로 플레이 화면.
    expect(game.phoneOrientation, PhoneGameOrientation.landscapeOnly);
    expect(ElevenFunctions.submitTile, 'game_eleven_submit_tile');
    expect(ElevenFunctions.timeoutTurn, 'game_eleven_timeout_turn');
    expect(ElevenFunctions.completePhase, 'game_eleven_complete_phase');
    expect(ElevenFunctions.pickDrawTile, 'game_eleven_pick_draw_tile');
    expect(ElevenFunctions.startGame, 'game_eleven_start_game');
    expect(ElevenFunctions.endGame, 'game_eleven_end_game');
  });
}
