// [game_stage.dart] 는 ELEVEN 서버 상태를 휴대폰 화면 단계로 번역하는 파일이다.
//
// - [Package] : ELEVEN
// - [Stage] : 계약 7절 P01–P11 대응
//
// 서버 status/phase 문자열은 [resolveElevenPhoneStage] 한곳에서만 해석한다.

// ========================[ import ]==========================
import 'package:game_kit/game_flow/game_finish.dart';
import 'package:game_eleven/shared/models/game_state.dart';

// ============================================================

enum ElevenPhoneStage {
  /// 첫 공개 상태 대기 또는 알 수 없는 phase.
  connecting,

  /// P01 뽑기 중 대기 (`drawPick`, `drawReveal`).
  drawWaiting,

  /// P02 선공 선택 중 (`firstSubmit`, 본인 = 선공).
  firstChoosing,

  /// P03 후공 미리 선택 (`firstSubmit`, 본인 = 후공). 로컬 초안만 허용.
  secondPreselect,

  /// P04 선공 제출 완료 (`secondSubmit`, 본인 = 선공).
  firstSubmitted,

  /// P05 후공 제출 가능 (`secondSubmit`, 본인 = 후공, 아직 제출 전).
  secondChoosing,

  /// P07 후공 제출 완료 (`secondSubmit`, 본인 제출 접수 후 `roundResult` 수신 전).
  secondSubmitted,

  /// P08 결과·다음 라운드 전환 (`roundResult`).
  roundResult,

  /// P10/P11 게임 종료 (정상 승부).
  finished,

  /// 승부 없이 종료(수동·인원 부족). 상위 라우트가 화면을 닫습니다.
  closing;

  /// 이 단계에서 타일을 눌러 서버에 제출할 수 있는지입니다.
  bool get canSubmit =>
      this == ElevenPhoneStage.firstChoosing ||
      this == ElevenPhoneStage.secondChoosing;

  /// 타일을 고를 수 있는지입니다(P03 미리 선택 포함).
  bool get canSelect => canSubmit || this == ElevenPhoneStage.secondPreselect;
}

/// [locallySubmittedRound]는 제출 응답이 성공한 라운드입니다. 개인 상태
/// `submission`이 오기 전에도 P07 완료 표시를 하기 위해 씁니다(서버 거절 시 null).
ElevenPhoneStage resolveElevenPhoneStage(
  ElevenGameState game, {
  required String uid,
  int? locallySubmittedRound,
}) {
  final pub = game.public;
  if (game.loading) return ElevenPhoneStage.connecting;
  if (pub.isFinished) {
    final natural = isNaturalGameResult(
      isFinished: true,
      winnerUid: pub.winnerUid,
      finishReason: pub.finishReason,
    );
    return natural ? ElevenPhoneStage.finished : ElevenPhoneStage.closing;
  }
  final submitted =
      game.private.submissionFor(pub.round) != null ||
      locallySubmittedRound == pub.round;
  final isFirst = pub.firstUid == uid;
  final isSecond = pub.secondUid == uid;
  return switch (pub.phase) {
    'drawPick' || 'drawReveal' => ElevenPhoneStage.drawWaiting,
    'firstSubmit' when isFirst => ElevenPhoneStage.firstChoosing,
    'firstSubmit' when isSecond => ElevenPhoneStage.secondPreselect,
    'secondSubmit' when isFirst => ElevenPhoneStage.firstSubmitted,
    'secondSubmit' when isSecond =>
      submitted
          ? ElevenPhoneStage.secondSubmitted
          : ElevenPhoneStage.secondChoosing,
    'roundResult' => ElevenPhoneStage.roundResult,
    _ => ElevenPhoneStage.connecting,
  };
}
