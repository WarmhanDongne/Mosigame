import 'package:game_kit/services/game_command_service.dart';
import 'package:game_kit/services/game_query_service.dart';

class RussianRouletteCommandService extends GameCommandService {
  Future<Map<String, dynamic>> startGame(
    String roomCode, {
    bool restart = false,
  }) => invoke('game_russian_roulette_start_game', {
    'roomCode': roomCode,
    'commandId': commandId('start'),
    if (restart) 'restart': true,
  });

  Future<Map<String, dynamic>> submitAction(String roomCode, String action) =>
      invoke('game_russian_roulette_submit_action', {
        'roomCode': roomCode,
        'action': action,
        'commandId': commandId('action'),
      }, retryTransientFailure: true);

  Future<Map<String, dynamic>> timeout(String roomCode) => invoke(
    'game_russian_roulette_timeout_turn',
    {'roomCode': roomCode, 'commandId': commandId('timeout')},
    retryTransientFailure: true,
  );

  Future<Map<String, dynamic>> completePhase(String roomCode) => invoke(
    'game_russian_roulette_complete_phase',
    {'roomCode': roomCode, 'commandId': commandId('phase')},
    retryTransientFailure: true,
  );

  Future<Map<String, dynamic>> endGame(String roomCode) => invoke(
    'game_russian_roulette_end_game',
    {'roomCode': roomCode, 'commandId': commandId('end')},
    retryTransientFailure: true,
  );
}

class RussianRouletteQueryService extends GameQueryService {}

class RussianRouletteService {
  RussianRouletteService({
    RussianRouletteCommandService? command,
    RussianRouletteQueryService? query,
  }) : command = command ?? RussianRouletteCommandService(),
       query = query ?? RussianRouletteQueryService();

  final RussianRouletteCommandService command;
  final RussianRouletteQueryService query;
}
