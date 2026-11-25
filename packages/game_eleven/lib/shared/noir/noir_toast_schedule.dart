// [noir_toast_schedule.dart] 는 태블릿 중앙 토스트의 문구·유지 시간·색 시간표 파일이다.
//
// - [Package] : ELEVEN
// - [Design] : docs/design/eleven/motion.md 2절(정적 화면 tq*)·4절(프로토타입 토스트 표)
//
// 한 묶음 안의 단계는 0.2초 공백으로 이어진다([ElevenToastSequence]). 뽑기 공개처럼
// 사이에 뒤집기 연출이 끼는 경우는 묶음을 나누고, 시작 시점은 noir_motion.dart의
// `ElevenDrawMotion.revealToastAt`/`resultToastAt`을 쓴다.
// 유지 시간: “타일 자동 제출” 0.9초(결정 5), 게임 승패 1.5초.

// ========================[ import ]==========================
import 'package:game_eleven/game_copy.dart';
import 'package:game_eleven/shared/noir/noir_motion.dart';
import 'package:game_eleven/shared/widgets/noir_toast.dart';

// ============================================================

abstract final class ElevenToastSchedule {
  /// T01·T02 뽑기 차례, T11 세 번째 단계: “타일 선택”(빨강, 0.7초).
  static List<ElevenToastStep> pickTile() => [
    ElevenToastStep(
      text: ElevenScreenCopy.toastPickTile,
      hold: ElevenToastHold.action,
      accent: true,
    ),
  ];

  /// T03 공개 신호: “숫자 공개”(크림, 0.5초).
  static List<ElevenToastStep> revealNumbers() => [
    ElevenToastStep(
      text: ElevenScreenCopy.toastRevealNumbers,
      hold: ElevenToastHold.reveal,
    ),
  ];

  /// T03 뽑기 결과: “A 선공”(빨강, 1.0초).
  static List<ElevenToastStep> firstPlayer(String who) => [
    ElevenToastStep(
      text: ElevenScreenCopy.toastFirstPlayer(who),
      hold: ElevenToastHold.announce,
      accent: true,
    ),
  ];

  /// T04 1라운드 시작: “1라운드”(빨강, 0.8초). 이후 라운드는 [roundIntro].
  static List<ElevenToastStep> firstRound() => [
    ElevenToastStep(
      text: ElevenScreenCopy.toastRound(1),
      hold: ElevenToastHold.round,
      accent: true,
    ),
  ];

  /// T09 새 라운드: “6라운드 / A 선공”(빨강, 1.0초).
  static List<ElevenToastStep> roundIntro(int round, String who) => [
    ElevenToastStep(
      text: ElevenScreenCopy.toastRoundIntro(round, who),
      hold: ElevenToastHold.announce,
      accent: true,
    ),
  ];

  /// T05 선공 제출: “제출 완료”(빨강, 0.6초).
  static List<ElevenToastStep> submitted() => [
    ElevenToastStep(
      text: ElevenScreenCopy.toastSubmitted,
      hold: ElevenToastHold.short,
      accent: true,
    ),
  ];

  /// T06 시간 초과: “타일 자동 제출”(빨강, 0.9초, 결정 5).
  static List<ElevenToastStep> autoSubmitted() => [
    ElevenToastStep(
      text: ElevenScreenCopy.toastAutoSubmitted,
      hold: ElevenToastHold.roundResult,
      accent: true,
    ),
  ];

  /// T07 라운드 승리: “A 승리”(빨강, 0.9초).
  static List<ElevenToastStep> roundWinner(String who) => [
    ElevenToastStep(
      text: ElevenScreenCopy.toastWinner(who),
      hold: ElevenToastHold.roundResult,
      accent: true,
    ),
  ];

  /// T08 라운드 동점: “동점”(빨강, 0.9초).
  static List<ElevenToastStep> roundTie() => [
    ElevenToastStep(
      text: ElevenScreenCopy.toastTie,
      hold: ElevenToastHold.roundResult,
      accent: true,
    ),
  ];

  /// T10 조기 종료: “게임 조기 종료”(크림, 0.8초) → “승자 / A”(빨강, 1.5초).
  static List<ElevenToastStep> earlyEnd(String winner) => [
    ElevenToastStep(
      text: ElevenScreenCopy.toastEarlyEnd,
      hold: ElevenToastHold.round,
    ),
    ElevenToastStep(
      text: ElevenScreenCopy.toastGameWinner(winner),
      hold: ElevenToastHold.gameResult,
      accent: true,
    ),
  ];

  /// 프로토타입 ⑦ 11라운드 정상 종료: “게임 종료”(크림, 0.8초) → “승자 / A”(빨강, 1.5초).
  static List<ElevenToastStep> allRoundsEnd(String winner) => [
    ElevenToastStep(
      text: ElevenScreenCopy.toastGameOver,
      hold: ElevenToastHold.round,
    ),
    ElevenToastStep(
      text: ElevenScreenCopy.toastGameWinner(winner),
      hold: ElevenToastHold.gameResult,
      accent: true,
    ),
  ];

  /// T11 최종 동점 뽑기 시작: “동점”(크림, 0.6초) → “최종 승부”(크림, 0.8초)
  /// → “타일 선택”(빨강, 0.7초).
  static List<ElevenToastStep> tieDrawStart() => [
    ElevenToastStep(
      text: ElevenScreenCopy.toastTie,
      hold: ElevenToastHold.short,
    ),
    ElevenToastStep(
      text: ElevenScreenCopy.toastFinalBout,
      hold: ElevenToastHold.round,
    ),
    ...pickTile(),
  ];

  /// T12 공개 신호: “타일 공개”(크림, 0.5초).
  static List<ElevenToastStep> revealTiles() => [
    ElevenToastStep(
      text: ElevenScreenCopy.toastRevealTiles,
      hold: ElevenToastHold.reveal,
    ),
  ];

  /// T12 동점 뽑기 결과: “B 승리”(빨강, 1.5초, 게임 승패).
  static List<ElevenToastStep> tieDrawWinner(String who) => [
    ElevenToastStep(
      text: ElevenScreenCopy.toastWinner(who),
      hold: ElevenToastHold.gameResult,
      accent: true,
    ),
  ];
}
