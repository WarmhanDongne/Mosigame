/// ELEVEN 태블릿 조율판.
///
/// 태블릿은 진행 기기다. 공용 뽑기 입력, 연출 뒤 `complete_phase`, 마감 뒤
/// `timeout_turn`(주 호출)을 맡는다. 서버 phase → 화면 단계 번역은
/// `providers/game_stage.dart`, 세션 수명·타이머는 `src/board_state.dart`에 있다.
/// 개인 상태는 구독하지 않고 controller 전용 기록만 추가로 읽는다(계약 4.3).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/recovery/services/game_progress_command.dart';
import 'package:game_kit/recovery/widgets/game_recovery_layer.dart';
import 'package:game_kit/shared/widgets/game_route_exit.dart';
import 'package:game_kit/tablet/widgets/game_settings_dialog.dart';
import 'package:game_kit/tablet/widgets/game_rulebook_dialog.dart';
import 'package:game_eleven/game_copy.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/models/timing.dart';
import 'package:game_eleven/shared/noir/noir_motion.dart';
import 'package:game_eleven/shared/noir/noir_text.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';
import 'package:game_eleven/shared/providers/game_controller.dart';
import 'package:game_eleven/shared/providers/session_provider.dart';
import 'package:game_eleven/shared/services/game_service.dart';
import 'package:game_eleven/tablet/providers/game_stage.dart';
import 'package:game_eleven/tablet/src/phase_clock.dart';
import 'package:game_eleven/tablet/widgets/noir_board.dart';

part 'src/board_state.dart';

class ElevenTabletGame extends ConsumerStatefulWidget {
  const ElevenTabletGame({
    super.key,
    required this.roomCode,
    required this.provider,
    this.service,
  });

  final String roomCode;
  final GameRoomContext provider;

  /// 테스트에서 주입합니다. null이면 기본 서비스를 씁니다.
  final ElevenService? service;

  @override
  ConsumerState<ElevenTabletGame> createState() => _ElevenTabletGameState();
}

/// 단계별 머리 문구입니다. 화면 교체 지점은 board_state의 build입니다.
(String title, String subtitle) elevenTabletHeadline(
  ElevenTabletStage stage,
  ElevenGameState game,
) {
  final pub = game.public;
  final draw = pub.draw;
  final last = game.lastHistory;
  return switch (stage) {
    ElevenTabletStage.connecting => (GameFlowCopy.waitingForGameData, ''),
    ElevenTabletStage.firstDrawPick => (
      ElevenCopy.firstPlayerDraw,
      ElevenCopy.pickTurn(pub.nicknameOf(draw?.nextPickerUid)),
    ),
    ElevenTabletStage.tieDrawPick => (
      ElevenCopy.tieDraw,
      ElevenCopy.pickTurn(pub.nicknameOf(draw?.nextPickerUid)),
    ),
    ElevenTabletStage.firstDrawReveal => (
      ElevenCopy.firstPlayerDraw,
      ElevenCopy.drawWinnerFirst(pub.nicknameOf(draw?.winnerUid)),
    ),
    ElevenTabletStage.tieDrawReveal => (
      ElevenCopy.tieDraw,
      ElevenCopy.winner(pub.nicknameOf(draw?.winnerUid)),
    ),
    ElevenTabletStage.firstSubmit => (
      ElevenCopy.round(pub.round),
      ElevenCopy.choosing(pub.nicknameOf(pub.firstUid)),
    ),
    ElevenTabletStage.secondSubmit => (
      ElevenCopy.round(pub.round),
      ElevenCopy.choosing(pub.nicknameOf(pub.secondUid)),
    ),
    // T07/T08: 이번 라운드 기록이 도착하기 전에는 승패 문구를 비워 둡니다.
    ElevenTabletStage.roundResult => (
      ElevenCopy.round(pub.round),
      last == null || last.round != pub.round
          ? ''
          : last.isTie
          ? ElevenCopy.roundTie
          : ElevenCopy.roundWinner(pub.nicknameOf(last.winnerUid)),
    ),
    ElevenTabletStage.result => (
      ElevenCopy.winner(pub.nicknameOf(pub.winnerUid)),
      switch ((pub.finishDetail, pub.earlyEnd)) {
        ('earlyEnd', final early?) => ElevenCopy.earlyEnd(
          early.remainingRounds,
          early.gap,
        ),
        _ => '',
      },
    ),
    ElevenTabletStage.closing => (
      pub.finishReason == 'insufficientPlayers'
          ? GameFlowCopy.insufficientPlayers
          : GameFlowCopy.gameFinished,
      '',
    ),
  };
}
