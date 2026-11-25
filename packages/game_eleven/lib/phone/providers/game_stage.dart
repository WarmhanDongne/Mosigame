// [game_stage.dart] 는 ELEVEN 서버 상태를 휴대폰 화면 단계로 번역하는 파일이다.
//
// - [Package] : ELEVEN
// - [Stage] : 계약 7절 P01–P11 대응, 시안 화면 ID P01–P11·G1–G8([ElevenPhoneScreen])
//
// 서버 status/phase 문자열은 [resolveElevenPhoneStage] 한곳에서만 해석한다.
// [resolveElevenPhoneScreen]은 그 결과와 뽑기·제출·직전 결과 공개 값으로 시안 화면을 고른다.

// ========================[ import ]==========================
import 'package:game_kit/game_flow/game_finish.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';

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

/// 휴대폰 시안 화면 ID입니다(계약 7절 + docs/design/eleven README 화면 표).
/// [ElevenPhoneStage]는 입력 가능 여부, 이 값은 어느 시안 화면을 그릴지를 정합니다.
enum ElevenPhoneScreen {
  /// 첫 공개 상태 대기 또는 알 수 없는 phase.
  connecting(null),

  /// P01 선공 뽑기 안내. 뽑기 데이터가 아직 없을 때의 기본 화면.
  p01DrawWait('P01'),

  /// P02 선공 · 타일 선택 중.
  p02FirstChoosing('P02'),

  /// P03 후공 · 미리 선택, 제출 잠김.
  p03SecondPreselect('P03'),

  /// P04 선공 · 제출 완료, 상대 차례.
  p04FirstSubmitted('P04'),

  /// P05 후공 · 제출 가능.
  p05SecondChoosing('P05'),

  /// P06 시간 초과 자동 제출(본인 `submission.auto`).
  p06AutoSubmitted('P06'),

  /// P07 후공 · 제출 완료, 결과 대기.
  p07SecondSubmitted('P07'),

  /// P08 결과·다음 라운드 전환(`lastRoundResult`로 승·패·동점).
  p08RoundResult('P08'),

  /// P09 마지막 타일 1개(제출할 수 있을 때).
  p09LastTile('P09'),

  /// P10 게임 종료 · 이긴 사람.
  p10Winner('P10'),

  /// P11 게임 종료 · 진 사람(승자 표시는 그대로, 결정 10).
  p11Loser('P11'),

  /// G1 선공 뽑기 · 내 차례(P01과 같은 화면, 결정 9).
  g1DrawMyTurn('G1'),

  /// G2 선공 뽑기 · 상대가 먼저 뽑는 중.
  g2DrawOtherFirst('G2'),

  /// G3 선공 뽑기 · 뽑은 뒤 대기.
  g3DrawPicked('G3'),

  /// G4 선공 뽑기 결과 · 내가 선공.
  g4DrawResultFirst('G4'),

  /// G5 선공 뽑기 결과 · 상대가 선공.
  g5DrawResultSecond('G5'),

  /// G6 라운드 결과 확인 안내(T07–T09 동안, 결과 공개 전).
  g6RoundResultWait('G6'),

  /// G7 조기 종료 안내(T10 동안).
  g7EarlyEnd('G7'),

  /// G8 최종 동점 뽑기 안내(T11–T12).
  g8TieDraw('G8'),

  /// 승부 없이 종료(수동·인원 부족). 상위 라우트가 화면을 닫습니다.
  closing(null);

  const ElevenPhoneScreen(this.id);

  /// 시안 화면 ID. 화면이 없는 상태는 null입니다.
  final String? id;
}

/// 서버 상태를 휴대폰 시안 화면으로 번역합니다. 순수 함수입니다.
///
/// - [locallySubmittedRound]: [resolveElevenPhoneStage]와 같습니다(P07).
/// - [roundResultRevealed]: false면 `roundResult`에서 결과 공개 전 안내 G6을,
///   true면 P08을 돌려줍니다. 프로토타입 ④는 0초 G6 → 1.4초 P08입니다.
/// - [gameEndRevealed]: false면 조기 종료(`finishDetail: earlyEnd`)에서 G7을,
///   true면 P10/P11을 돌려줍니다. 프로토타입 ⑥은 G7 → 3.7초 P10/P11입니다.
///   11라운드 종료·동점 뽑기 종료는 바로 P10/P11입니다(프로토타입 ⑦·⑧).
ElevenPhoneScreen resolveElevenPhoneScreen(
  ElevenGameState game, {
  required String uid,
  int? locallySubmittedRound,
  bool roundResultRevealed = true,
  bool gameEndRevealed = true,
}) {
  final pub = game.public;
  final stage = resolveElevenPhoneStage(
    game,
    uid: uid,
    locallySubmittedRound: locallySubmittedRound,
  );
  ElevenPhoneScreen endFor(String? winnerUid) => winnerUid == uid
      ? ElevenPhoneScreen.p10Winner
      : ElevenPhoneScreen.p11Loser;
  final submission = game.private.submissionFor(pub.round);
  final lastTile = game.private.tiles.length == 1;
  switch (stage) {
    case ElevenPhoneStage.connecting:
      return ElevenPhoneScreen.connecting;
    case ElevenPhoneStage.closing:
      return ElevenPhoneScreen.closing;
    case ElevenPhoneStage.finished:
      if (pub.finishDetail == 'earlyEnd' && !gameEndRevealed) {
        return ElevenPhoneScreen.g7EarlyEnd;
      }
      return endFor(pub.winnerUid);
    case ElevenPhoneStage.drawWaiting:
      final draw = pub.draw;
      if (draw == null) return ElevenPhoneScreen.p01DrawWait;
      if (draw.purpose == ElevenDrawPurpose.finalTie) {
        // 프로토타입 ⑧: 공개되면 휴대폰은 바로 게임 종료 화면(왕관은 아직 없음).
        final winner = draw.winnerUid;
        return pub.phase == 'drawReveal' && winner != null
            ? endFor(winner)
            : ElevenPhoneScreen.g8TieDraw;
      }
      if (pub.phase == 'drawReveal') {
        final winner = draw.winnerUid;
        if (winner == null) return ElevenPhoneScreen.g3DrawPicked;
        return winner == uid
            ? ElevenPhoneScreen.g4DrawResultFirst
            : ElevenPhoneScreen.g5DrawResultSecond;
      }
      if (draw.picks.containsKey(uid)) return ElevenPhoneScreen.g3DrawPicked;
      if (draw.nextPickerUid == uid) return ElevenPhoneScreen.g1DrawMyTurn;
      return ElevenPhoneScreen.g2DrawOtherFirst;
    case ElevenPhoneStage.firstChoosing:
      return lastTile
          ? ElevenPhoneScreen.p09LastTile
          : ElevenPhoneScreen.p02FirstChoosing;
    case ElevenPhoneStage.secondPreselect:
      return ElevenPhoneScreen.p03SecondPreselect;
    case ElevenPhoneStage.firstSubmitted:
      return submission?.auto == true
          ? ElevenPhoneScreen.p06AutoSubmitted
          : ElevenPhoneScreen.p04FirstSubmitted;
    case ElevenPhoneStage.secondChoosing:
      return lastTile
          ? ElevenPhoneScreen.p09LastTile
          : ElevenPhoneScreen.p05SecondChoosing;
    case ElevenPhoneStage.secondSubmitted:
      return submission?.auto == true
          ? ElevenPhoneScreen.p06AutoSubmitted
          : ElevenPhoneScreen.p07SecondSubmitted;
    case ElevenPhoneStage.roundResult:
      return roundResultRevealed && game.currentRoundResult != null
          ? ElevenPhoneScreen.p08RoundResult
          : ElevenPhoneScreen.g6RoundResultWait;
  }
}
