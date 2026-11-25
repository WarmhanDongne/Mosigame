// [noir_text.dart] 는 ELEVEN 시안 A의 글자 스타일을 모아 두는 파일이다.
//
// - [Package] : ELEVEN
// - [Design] : docs/design/eleven/screens.md 1-2 글꼴·글자 크기 단계
//
// 숫자(슬롯·타일·전적칸·점수·최종 점수)는 StardosStencil 700만 쓴다. 점수 숫자의
// 인라인 900은 무시한다(S5-0b 결정 8). 본문은 Noto Sans KR 500/700/900이며, 굵기
// 지정이 없는 본문(소스 400)은 브라우저처럼 500으로 그린다(screens.md 1-2).

// ========================[ import ]==========================
import 'package:flutter/painting.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';

// ============================================================

abstract final class ElevenNoirText {
  /// 숫자 글꼴 스타일입니다. 굵기는 항상 700입니다.
  static TextStyle number(
    double size, {
    Color color = ElevenNoirColors.ink,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: ElevenNoirFonts.number,
    fontFamilyFallback: const [ElevenNoirFonts.body],
    fontWeight: ElevenNoirFonts.numberWeight,
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// 본문(한글·UI) 스타일입니다. 400은 500으로 올립니다.
  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = ElevenNoirColors.ink,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: ElevenNoirFonts.body,
    fontFamilyFallback: ElevenNoirFonts.bodyFallback,
    fontWeight: weight.value < FontWeight.w500.value ? FontWeight.w500 : weight,
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  // ---------------------------------------------------------------------------
  // 태블릿 (screens.md 1-2 크기 단계)
  // ---------------------------------------------------------------------------
  /// 중앙 토스트 72/900, line-height 1.8. 외곽 획·그림자는 토스트 위젯이 그린다.
  static TextStyle toast({Color color = ElevenNoirColors.cream}) =>
      body(72, weight: FontWeight.w900, color: color, height: 1.8);

  /// 점수 숫자 88, line-height 1.
  static TextStyle tabletScore({Color color = ElevenNoirColors.cream}) =>
      number(88, color: color, height: 1);

  /// 점수 라벨 “점수” 22/700.
  static TextStyle tabletScoreLabel({Color color = ElevenNoirColors.cream}) =>
      body(22, weight: FontWeight.w700, color: color);

  /// 최종 헤더 숫자 fhNum 84/700 자간 2.
  static TextStyle finalNumber() =>
      number(84, color: ElevenNoirColors.cream, letterSpacing: 2);

  /// 최종 헤더 이름 fhName 84/900 자간 2.
  static TextStyle finalName() => body(
    84,
    weight: FontWeight.w900,
    color: ElevenNoirColors.cream,
    letterSpacing: 2,
  );

  /// 최종 헤더 라벨 fhLabel 20/700 자간 2.
  static TextStyle finalLabel() => body(
    20,
    weight: FontWeight.w700,
    color: ElevenNoirColors.greyBeige,
    letterSpacing: 2,
  );

  /// 상태 pill 26/900 (T09 30, T10 28, T13 계열 26).
  static TextStyle pill({
    double size = 26,
    Color color = ElevenNoirColors.ink,
  }) => body(size, weight: FontWeight.w900, color: color);

  /// 태블릿 버튼 22/900.
  static TextStyle tabletButton() =>
      body(22, weight: FontWeight.w900, color: ElevenNoirColors.cream);

  /// 전적 결과 `◀ 승` 20/900.
  static TextStyle historyResult({Color color = ElevenNoirColors.ink}) =>
      body(20, weight: FontWeight.w900, color: color);

  /// 전적 동점 기호 `=` 24/900, line-height .8(`.resTie`, 보조 글자색).
  static TextStyle historyTieMark() => body(
    24,
    weight: FontWeight.w900,
    color: ElevenNoirColors.mutedText,
    height: 0.8,
  );

  /// 전적 동점 글자 “동점” 20/900 보조 글자색(`.resTie`).
  static TextStyle historyTie() =>
      body(20, weight: FontWeight.w900, color: ElevenNoirColors.mutedText);

  /// `+1` 배지 20/900.
  static TextStyle plusBadge() => body(20, weight: FontWeight.w900);

  /// 전적 라운드 번호 resRn 14/700.
  static TextStyle historyRound() =>
      body(14, weight: FontWeight.w700, color: ElevenNoirColors.mutedText);

  /// 열 머리 colHead 13/900.
  static TextStyle columnHead() =>
      body(13, weight: FontWeight.w900, color: ElevenNoirColors.mutedText);

  /// 선 배지 15/900 (전적행 12).
  static TextStyle firstBadge({bool inHistoryRow = false}) => body(
    inHistoryRow ? 12 : 15,
    weight: FontWeight.w900,
    color: ElevenNoirColors.cream,
  );

  /// A/B 표식 14/900.
  static TextStyle seatMark() =>
      body(14, weight: FontWeight.w900, color: ElevenNoirColors.cream);

  /// 태블릿 note 15/700 (T13 13).
  static TextStyle note({double size = 15}) => body(
    size,
    weight: FontWeight.w700,
    color: ElevenNoirColors.lightGreyCream,
  );

  // ---------------------------------------------------------------------------
  // 휴대폰
  // ---------------------------------------------------------------------------
  /// 상단 바·상태 칩 메시지 17/900.
  static TextStyle topBar({Color color = ElevenNoirColors.ink}) =>
      body(17, weight: FontWeight.w900, color: color);

  /// 상단 점수 “x : y” 17/900 주 빨강.
  static TextStyle topBarScore() =>
      body(17, weight: FontWeight.w900, color: ElevenNoirColors.red);

  /// 아바타 글자 16/900.
  static TextStyle avatar() => body(16, weight: FontWeight.w900);

  /// 태그 13/700 (크림 글자, 잉크 바탕은 위젯이 그린다).
  static TextStyle tag() =>
      body(13, weight: FontWeight.w700, color: ElevenNoirColors.cream);

  /// 안내 카드 제목 34/900, line-height 1.2.
  static TextStyle guideTitle() =>
      body(34, weight: FontWeight.w900, height: 1.2);

  /// 안내 카드 본문 19, line-height 1.35.
  static TextStyle guideBody() =>
      body(19, color: ElevenNoirColors.mutedText, height: 1.35);

  /// 안내 카드 보조 16.
  static TextStyle guideSub() => body(16, color: ElevenNoirColors.mutedText);

  /// 패널 라벨 13/700.
  static TextStyle panelLabel({Color color = ElevenNoirColors.mutedText}) =>
      body(13, weight: FontWeight.w700, color: color);

  /// 패널 값(흑 6) 22/900.
  static TextStyle panelValue() => body(22, weight: FontWeight.w900);

  /// 작은 안내 12.
  static TextStyle small() => body(12, color: ElevenNoirColors.mutedText);

  /// 제출 버튼 18/900 (잠김 15/900 보조 글자색).
  static TextStyle submitButton({bool locked = false}) => body(
    locked ? 15 : 18,
    weight: FontWeight.w900,
    color: locked ? ElevenNoirColors.mutedText : ElevenNoirColors.cream,
  );

  /// 대시 상자 15/700.
  static TextStyle dashedBox() =>
      body(15, weight: FontWeight.w700, color: ElevenNoirColors.mutedText);

  /// 배지(선택·자동 제출·제출 완료) 12/900.
  static TextStyle badge() =>
      body(12, weight: FontWeight.w900, color: ElevenNoirColors.cream);

  /// vs 20/900 (G6 22).
  static TextStyle versus({double size = 20}) =>
      body(size, weight: FontWeight.w900, color: ElevenNoirColors.mutedText);

  /// 승자 이름 26/900.
  static TextStyle winnerName() =>
      body(26, weight: FontWeight.w900, color: ElevenNoirColors.cream);

  /// WINNER 15/900 자간 3.
  static TextStyle winnerLabel() => body(
    15,
    weight: FontWeight.w900,
    color: ElevenNoirColors.accentRed,
    letterSpacing: 3,
  );

  /// 승자 아바타 글자 36/900.
  static TextStyle winnerAvatar() => body(36, weight: FontWeight.w900);

  /// P10/P11 하단 안내 13/700.
  static TextStyle endNote() =>
      body(13, weight: FontWeight.w700, color: ElevenNoirColors.lightGreyCream);

  /// G7 점수 46/900. 소스가 Noto Sans KR로 지정한 글자다(Stardos 대상 목록에 없음).
  static TextStyle earlyEndScore() =>
      body(46, weight: FontWeight.w900, color: ElevenNoirColors.red);

  /// P08 “6라운드” 30/900.
  static TextStyle nextRound() => body(30, weight: FontWeight.w900);
}
