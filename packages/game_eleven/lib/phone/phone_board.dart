/// ELEVEN 휴대폰 조율판.
///
/// 서버 phase → 화면 단계 번역은 `providers/game_stage.dart`, 세션 수명·제출·예비
/// 시간 초과는 `src/board_state.dart`가 맡는다. 실제 제한시간·승패는 서버가 정한다.
///
/// [PhoneGameShell]을 쓰지 않는 이유: 디자인 P01–P11에는 GAME START·ROUND N
/// 전면 안내가 없고(새 라운드 안내 T09는 태블릿 표시), 셸의 안내가 제출 화면을
/// 가리면 서버 deadline이 흐르는 동안 입력이 막힌다(계약 3절 "연출이 deadline을
/// 늦추지 않는다").
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/errors/widgets/leave_failure_notice.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/phone/widgets/exit_modal.dart';
import 'package:game_kit/recovery/widgets/game_recovery_layer.dart';
import 'package:game_kit/shared/widgets/game_route_exit.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown.dart';
import 'package:game_eleven/game_copy.dart';
import 'package:game_eleven/game_theme.dart';
import 'package:game_eleven/phone/providers/game_stage.dart';
import 'package:game_eleven/phone/widgets/tile_rack.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/models/tiles.dart';
import 'package:game_eleven/shared/models/timing.dart';
import 'package:game_eleven/shared/providers/game_controller.dart';
import 'package:game_eleven/shared/providers/session_provider.dart';
import 'package:game_eleven/shared/services/game_service.dart';

part 'src/board_state.dart';

class ElevenPhoneGame extends ConsumerStatefulWidget {
  const ElevenPhoneGame({
    super.key,
    required this.roomCode,
    required this.provider,
    required this.onExitRoom,
    this.service,
  });

  final String roomCode;
  final GameRoomContext provider;
  final Future<bool> Function() onExitRoom;

  /// 테스트에서 주입합니다. null이면 기본 서비스를 씁니다.
  final ElevenService? service;

  @override
  ConsumerState<ElevenPhoneGame> createState() => _ElevenPhoneGameState();
}

/// 단계별 안내 문구입니다. 화면 교체 지점은 board_state의 build입니다.
String elevenPhoneMessage(ElevenPhoneStage stage, ElevenGameState game) {
  final pub = game.public;
  return switch (stage) {
    ElevenPhoneStage.connecting => GameFlowCopy.waitingForGameData,
    ElevenPhoneStage.drawWaiting => ElevenCopy.waitingDraw,
    ElevenPhoneStage.firstChoosing => ElevenCopy.yourTurn,
    ElevenPhoneStage.secondPreselect => ElevenCopy.preselect,
    ElevenPhoneStage.firstSubmitted => ElevenCopy.submitted,
    ElevenPhoneStage.secondChoosing => switch (pub.currentRound.firstColor) {
      ElevenTileColor.black => ElevenCopy.firstColor(ElevenCopy.black),
      ElevenTileColor.white => ElevenCopy.firstColor(ElevenCopy.white),
      null => ElevenCopy.yourTurn,
    },
    ElevenPhoneStage.secondSubmitted => ElevenCopy.submitted,
    ElevenPhoneStage.roundResult => ElevenCopy.roundResultPhone,
    ElevenPhoneStage.finished => '',
    ElevenPhoneStage.closing => GameFlowCopy.gameFinished,
  };
}
