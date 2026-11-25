// [session_provider.dart] 는 ELEVEN 컨트롤러를 화면에 연결하는 Provider 파일이다.
//
// 방·사용자·기기 역할당 컨트롤러 하나를 만들고 화면이 사라지면 정리한다.

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/providers/game_controller.dart';
import 'package:game_eleven/shared/services/game_service.dart';

// ============================================================

/// Provider 열쇠입니다. 값만 담고 콜백을 넣지 않습니다.
@immutable
class ElevenSessionArgs {
  const ElevenSessionArgs({
    required this.roomCode,
    required this.uid,
    required this.service,
    required this.isController,
  });

  final String roomCode;
  final String uid;
  final ElevenService service;
  final bool isController;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElevenSessionArgs &&
          roomCode == other.roomCode &&
          uid == other.uid &&
          identical(service, other.service) &&
          isController == other.isController;

  @override
  int get hashCode =>
      Object.hash(roomCode, uid, identityHashCode(service), isController);
}

final elevenSessionProvider = NotifierProvider.autoDispose
    .family<ElevenController, ElevenGameState, ElevenSessionArgs>((args) {
      return ElevenController(
        roomCode: args.roomCode,
        uid: args.uid,
        service: args.service,
        isController: args.isController,
      );
    });
