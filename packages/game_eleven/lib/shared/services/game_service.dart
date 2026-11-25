// [game_service.dart] 는 ELEVEN 조회·명령 서비스를 묶어 제공하는 파일이다.

// ========================[ import ]==========================
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';

import 'command_service.dart';
import 'query_service.dart';

// ============================================================

class ElevenService {
  ElevenService({
    ElevenCommandService? command,
    ElevenQueryService? query,
    GameInterruptionCommandService? interruption,
  }) : command = command ?? ElevenCommandService(),
       query = query ?? ElevenQueryService(),
       interruption = interruption ?? GameInterruptionCommandService();

  final ElevenCommandService command;
  final ElevenQueryService query;
  final GameInterruptionCommandService interruption;
}
