// [game_stage.dart] 는 ELEVEN 서버 상태를 태블릿 화면 단계로 번역하는 파일이다.
//
// - [Package] : ELEVEN
// - [Stage] : 계약 7절 T01–T13 대응, 시안 화면 ID T01–T13·T13-B([ElevenTabletScreen])
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

/// 태블릿 시안 화면 ID입니다(계약 7절 + docs/design/eleven README 화면 표).
enum ElevenTabletScreen {
  connecting(null),

  /// T01 첫 선공 뽑기 시작(고른 사람 0명).
  t01DrawStart('T01'),

  /// T02 첫 선공 뽑기 · 한 명이 고른 뒤 다음 차례.
  t02DrawSecondPick('T02'),

  /// T03 선공 뽑기 결과 동시 공개.
  t03DrawReveal('T03'),

  /// T04 라운드 진행 · 선공이 고르는 중.
  t04FirstChoosing('T04'),

  /// T05 라운드 진행 · 선공 제출 후 후공 차례.
  t05SecondChoosing('T05'),

  /// T06 시간 초과 자동 제출.
  t06AutoSubmitted('T06'),

  /// T07 라운드 결과 · 승리.
  t07RoundWin('T07'),

  /// T08 라운드 결과 · 동점.
  t08RoundTie('T08'),

  /// T09 새 라운드·선후공 안내(`firstSubmit` 진입 직후 클라이언트 연출).
  t09RoundIntro('T09'),

  /// T10 조기 종료 안내.
  t10EarlyEnd('T10'),

  /// T11 최종 동점 뽑기.
  t11TieDraw('T11'),

  /// T12 최종 동점 뽑기 결과.
  t12TieReveal('T12'),

  /// T13 최종 결과(조기 종료·11라운드 종료).
  t13Final('T13'),

  /// T13-B 최종 결과 · 동점 뽑기로 승패 결정.
  t13bFinalTieDraw('T13-B'),

  /// 승부 없이 종료(수동·인원 부족).
  closing(null);

  const ElevenTabletScreen(this.id);

  /// 시안 화면 ID. 화면이 없는 상태는 null입니다.
  final String? id;
}

/// 서버 상태를 태블릿 시안 화면으로 번역합니다. 순수 함수입니다.
///
/// - [roundIntroActive]: `firstSubmit`에서 새 라운드 안내를 겹쳐 보이는 동안 true(T09).
///   1라운드는 뽑기 결과 뒤 “1라운드” 토스트만 있는 T04다(프로토타입 ①).
/// - [roundResultRevealed]: false면 `roundResult`에서 자동 제출이 있었을 때 T06을
///   먼저 보여 줍니다(프로토타입 ③ → ④). true면 T07/T08입니다.
/// - [gameEndRevealed]: false면 조기 종료에서 T10, true면 T13입니다(프로토타입 ⑥).
///
/// 라운드 승패는 `public.lastRoundResult`(현재 라운드)를 먼저 보고, 없으면 controller
/// 기록 마지막 항목을 봅니다. 둘 다 없으면 자동 제출이 있으면 T06, 아니면 T05입니다.
ElevenTabletScreen resolveElevenTabletScreen(
  ElevenGameState game, {
  bool roundIntroActive = false,
  bool roundResultRevealed = true,
  bool gameEndRevealed = true,
}) {
  final pub = game.public;
  final auto = pub.currentRound.autoSubmitted.isNotEmpty;
  switch (resolveElevenTabletStage(game)) {
    case ElevenTabletStage.connecting:
      return ElevenTabletScreen.connecting;
    case ElevenTabletStage.closing:
      return ElevenTabletScreen.closing;
    case ElevenTabletStage.firstDrawPick:
      return (pub.draw?.picks.isEmpty ?? true)
          ? ElevenTabletScreen.t01DrawStart
          : ElevenTabletScreen.t02DrawSecondPick;
    case ElevenTabletStage.firstDrawReveal:
      return ElevenTabletScreen.t03DrawReveal;
    case ElevenTabletStage.tieDrawPick:
      return ElevenTabletScreen.t11TieDraw;
    case ElevenTabletStage.tieDrawReveal:
      return ElevenTabletScreen.t12TieReveal;
    case ElevenTabletStage.firstSubmit:
      return roundIntroActive && pub.round > 1
          ? ElevenTabletScreen.t09RoundIntro
          : ElevenTabletScreen.t04FirstChoosing;
    case ElevenTabletStage.secondSubmit:
      return auto
          ? ElevenTabletScreen.t06AutoSubmitted
          : ElevenTabletScreen.t05SecondChoosing;
    case ElevenTabletStage.roundResult:
      if (auto && !roundResultRevealed) {
        return ElevenTabletScreen.t06AutoSubmitted;
      }
      final last = game.lastHistory;
      final tie = switch (game.currentRoundResult) {
        final result? => result.isTie,
        null when last != null && last.round == pub.round => last.isTie,
        null => null,
      };
      return switch (tie) {
        true => ElevenTabletScreen.t08RoundTie,
        false => ElevenTabletScreen.t07RoundWin,
        null =>
          auto
              ? ElevenTabletScreen.t06AutoSubmitted
              : ElevenTabletScreen.t05SecondChoosing,
      };
    case ElevenTabletStage.result:
      return switch (pub.finishDetail) {
        'tieDraw' => ElevenTabletScreen.t13bFinalTieDraw,
        'earlyEnd' when !gameEndRevealed => ElevenTabletScreen.t10EarlyEnd,
        _ => ElevenTabletScreen.t13Final,
      };
  }
}
