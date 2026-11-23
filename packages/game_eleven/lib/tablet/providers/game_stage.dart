// [game_stage.dart] 는 ELEVEN 서버 상태를 태블릿 화면 단계로 번역하는 파일이다.
//
// - [Package] : ELEVEN
// - [Stage] : 계약 7절 T01–T13 대응
//
// 서버 status/phase 문자열은 [resolveElevenTabletStage] 한곳에서만 해석한다.
// T06(자동 제출)·T09(새 라운드 안내)는 단계가 아니라 위에 겹치는 표시다.

// ========================[ import ]==========================
import 'package:game_kit/game_flow/game_finish.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';

// ============================================================

enum ElevenTabletStage {
  connecting,

  /// T01/T02 첫 선공 뽑기 (`drawPick`, purpose firstPlayer).
  firstDrawPick,

  /// T03 뽑기 결과 (`drawReveal`, purpose firstPlayer).
  firstDrawReveal,

  /// T04 선공이 고르는 중 (`firstSubmit`).
  firstSubmit,

  /// T05 선공 제출 후 후공 차례 (`secondSubmit`).
  secondSubmit,

  /// T07/T08 라운드 결과 (`roundResult`). 승자·동점은 controller 기록 마지막 항목.
  roundResult,

  /// T11 최종 동점 뽑기 (`drawPick`, purpose finalTie).
  tieDrawPick,

  /// T12 동점 뽑기 결과 (`drawReveal`, purpose finalTie).
  tieDrawReveal,

  /// T10/T13 최종 결과 (정상 승부 종료).
  result,

  /// 승부 없이 종료(수동·인원 부족).
  closing;

  bool get isDrawPick =>
      this == ElevenTabletStage.firstDrawPick ||
      this == ElevenTabletStage.tieDrawPick;

  bool get isDrawReveal =>
      this == ElevenTabletStage.firstDrawReveal ||
      this == ElevenTabletStage.tieDrawReveal;

  /// 연출 뒤 `complete_phase`를 보내야 하는 단계입니다.
  bool get completesPhase =>
      isDrawReveal || this == ElevenTabletStage.roundResult;

  /// 제출 마감이 있는 단계입니다.
  bool get hasDeadline =>
      this == ElevenTabletStage.firstSubmit ||
      this == ElevenTabletStage.secondSubmit;
}

ElevenTabletStage resolveElevenTabletStage(ElevenGameState game) {
  final pub = game.public;
  if (game.loading) return ElevenTabletStage.connecting;
  if (pub.isFinished) {
    final natural = isNaturalGameResult(
      isFinished: true,
      winnerUid: pub.winnerUid,
      finishReason: pub.finishReason,
    );
    return natural ? ElevenTabletStage.result : ElevenTabletStage.closing;
  }
  final tie = pub.draw?.purpose == ElevenDrawPurpose.finalTie;
  return switch (pub.phase) {
    'drawPick' when pub.draw != null =>
      tie ? ElevenTabletStage.tieDrawPick : ElevenTabletStage.firstDrawPick,
    'drawReveal' when pub.draw != null =>
      tie ? ElevenTabletStage.tieDrawReveal : ElevenTabletStage.firstDrawReveal,
    'firstSubmit' => ElevenTabletStage.firstSubmit,
    'secondSubmit' => ElevenTabletStage.secondSubmit,
    'roundResult' => ElevenTabletStage.roundResult,
    _ => ElevenTabletStage.connecting,
  };
}
