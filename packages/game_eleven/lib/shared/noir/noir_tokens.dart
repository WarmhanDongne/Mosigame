// [noir_tokens.dart] 는 ELEVEN 시안 A(느와르 카드룸)의 색·간격·반경·테두리·그림자·글꼴 토큰 파일이다.
//
// - [Package] : ELEVEN
// - [Design] : docs/design/eleven/screens.md 1절 공통 토큰 표의 값만 옮긴다.
//
// 화면(lib/phone, lib/tablet)은 색·글꼴·TextStyle을 직접 만들지 않고 이 파일을 쓴다
// (test/shared/design_guard_test.dart가 검사). 표에 없는 값은 추가하지 않는다.
// 값이 필요하면 screens.md 근거를 먼저 확인하고 이 파일에 출처와 함께 둔다.

// ========================[ import ]==========================
import 'package:flutter/painting.dart';

// ============================================================

/// screens.md 1-1 색. 이름은 그 문서가 붙인 이름을 따른다.
abstract final class ElevenNoirColors {
  /// 잉크: 굵은 테두리, 단단한 그림자, 기본 글자, 태그·타이머 배경, 토스트 외곽 획.
  static const ink = Color(0xFF141414);

  /// 크림: 칩·pill·메뉴 버튼·휴대폰 패널, 백 타일 바탕, 흑 타일·빨강 위 글자, 기본 토스트 글자.
  static const cream = Color(0xFFF7F0E4);

  /// 크림-카드: 태블릿 중앙 카드, P05 요약줄.
  static const creamCard = Color(0xFFEFE6D6);

  /// 아바타 크림: 휴대폰 상단 아바타 원.
  static const avatarCream = Color(0xFFE7DCCB);

  /// 비활성 크림: 잠긴 제출 버튼 바탕.
  static const disabledCream = Color(0xFFECE3D3);

  /// 밝은 회크림: 태블릿 legend/note, P10/P11 하단 안내.
  static const lightGreyCream = Color(0xFFE9E1D3);

  /// 회베이지: 빈 슬롯·빈 전적칸·대시 상자 점선, 잠긴 버튼 테두리, fhLabel, “—”.
  static const greyBeige = Color(0xFFB9AE9C);

  /// 보조 글자: resRn/colHead/resTie, 휴대폰 안내 본문·라벨, “vs”.
  static const mutedText = Color(0xFF6E655A);

  /// 테이블 배경: `.stage` 바탕.
  static const table = Color(0xFF262524);

  /// 흑 타일/슬롯/전적칸 바탕.
  static const blackTile = Color(0xFF1B1B1B);

  /// 백 타일 바탕(크림과 같은 값).
  static const whiteTile = cream;

  /// 주 빨강: pillOn, 휴대폰 “내 차례” 칩, 점수 숫자, 선 배지, A/B 표식, 제출하기 버튼.
  static const red = Color(0xFFC9242A);

  /// 강조 빨강: cToastOn 글자, 승리·선택 외곽선, `+1`, 선택 배지, 왕관, WINNER.
  static const accentRed = Color(0xFFE23A3A);

  /// 경고 빨강: pillWarn, 자동 제출·제출 완료 배지, 카드 모서리 점, 다시하기 버튼,
  /// 시간 바 기본색(S5-0b 결정 3).
  static const warnRed = Color(0xFFD42A2F);

  /// 진한 빨강: 시간 바 “남은 10초부터” 색.
  static const deepRed = Color(0xFF8E1A1F);

  /// 카드 뒷면 사선 두 색(`repeating-linear-gradient(45deg,#7d1d22 0 8px,#9b262c 8px 16px)`).
  static const backStripeDark = Color(0xFF7D1D22);
  static const backStripeLight = Color(0xFF9B262C);

  /// `.stage` 사선 무늬 `rgba(255,255,255,.035)`.
  static const stageStripe = Color(0x09FFFFFF);

  /// 빈 슬롯 바탕 `rgba(255,255,255,.08)`.
  static const emptySlot = Color(0x14FFFFFF);

  /// 승리 번짐 `rgba(226,58,58,.22)`.
  static const winGlow = Color(0x38E23A3A);

  /// 타일 안쪽 1px 선 `color-mix(in srgb,#141414 55%,transparent)`.
  static const innerLineOnLight = Color(0x8C141414);

  /// 흑 타일 안쪽 1px 선 `color-mix(in srgb,#f7f0e4 45%,transparent)`.
  static const innerLineOnDark = Color(0x73F7F0E4);
}

/// screens.md 1-2 글꼴.
///
/// 숫자 글꼴 StardosStencil(700)은 루트 pubspec에 등록되어 있다. 생성 상수
/// `FontFamily.stardosStencil`(lib/gen)은 앱 소유라 게임 package가 import할 수 없으므로
/// 같은 이름을 문자열로 둔다(tool/check_package_boundaries.py).
///
/// 본문 “Noto Sans KR”은 앱에 번들되어 있지 않다. 기기에 있으면 그 글꼴을, 없으면
/// 시스템 한글 글꼴을 쓴다. 번들 추가는 새 asset이라 승인 대상이다(S5-0b 보고).
abstract final class ElevenNoirFonts {
  static const number = 'StardosStencil';
  static const numberWeight = FontWeight.w700;
  static const body = 'Noto Sans KR';
  static const bodyFallback = [
    'Noto Sans CJK KR',
    'Apple SD Gothic Neo',
    'sans-serif',
  ];
}

/// screens.md 1-3 모서리 반경(px).
abstract final class ElevenNoirRadius {
  // 태블릿
  static const tabletCard = 28.0;
  static const pill = 18.0;
  static const menuButton = 18.0;
  static const tabletButton = 18.0;
  static const slot = 18.0;
  static const slotInner = 9.0;
  static const drawCard = 12.0;
  static const historyRow = 12.0;
  static const historyCell = 8.0;
  static const historyCellInner = 4.0;
  static const tag = 8.0;
  static const firstBadge = 8.0;
  static const firstBadgeInRow = 6.0;
  static const plusBadge = 8.0;
  static const timeBar = 8.0;
  static const timeBarFill = 5.0;

  // 휴대폰
  static const chip = 16.0;
  static const phonePanel = 24.0;
  static const guideCard = 32.0;
  static const tile = 12.0;
  static const tileInner = 6.0;
  static const phoneButton = 16.0;
  static const badge = 8.0;
  static const timer = 10.0;
  static const avatar = 19.0;
  static const dashedBox = 16.0;
  static const summaryRow = 12.0;
}

/// screens.md 1-4 테두리 두께(px).
abstract final class ElevenNoirBorder {
  /// 칩·pill·타일·슬롯·버튼·메뉴.
  static const regular = 3.0;

  /// 중앙 카드·아바타 링.
  static const heavy = 4.0;

  /// 선 배지·`+1`·배지·휴대폰 아바타·전적칸.
  static const thin = 2.0;

  /// 타일 안쪽선.
  static const inner = 1.0;
}

/// screens.md 1-4 단단한 그림자(블러 0, 아래로만).
abstract final class ElevenNoirShadow {
  /// `0 5px 0`: pill·메뉴버튼·휴대폰 칩·타일·휴대폰 버튼.
  static const regular = [
    BoxShadow(color: ElevenNoirColors.ink, offset: Offset(0, 5)),
  ];

  /// `0 6px 0`: 슬롯·태블릿 버튼.
  static const raised = [
    BoxShadow(color: ElevenNoirColors.ink, offset: Offset(0, 6)),
  ];

  /// `0 8px 0`: 중앙 카드.
  static const card = [
    BoxShadow(color: ElevenNoirColors.ink, offset: Offset(0, 8)),
  ];

  /// 전적칸: 플레이어 쪽으로만 `-3px 0 0`(A) / `3px 0 0`(B).
  static List<BoxShadow> historyCell({required bool towardLeft}) => [
    BoxShadow(
      color: ElevenNoirColors.ink,
      offset: Offset(towardLeft ? -3 : 3, 0),
    ),
  ];

  /// 승리 번짐 `0 0 0 7px rgba(226,58,58,.22)`(전적행 6px).
  static List<BoxShadow> winGlow({bool inHistoryRow = false}) => [
    BoxShadow(
      color: ElevenNoirColors.winGlow,
      spreadRadius: inHistoryRow ? 6 : 7,
    ),
  ];
}

/// screens.md 1-4 흐림 값.
abstract final class ElevenNoirOpacity {
  /// 쓴 타일 `.used`.
  static const used = 0.28;

  /// 대기(잠김) `.wait`.
  static const wait = 0.6;

  /// 진 전적칸 `.loseT`.
  static const lose = 0.38;

  /// 뽑기 후 남은 카드 `.dim`.
  static const dim = 0.35;
}

/// screens.md 1-5 간격과 부품 고정 크기(px).
abstract final class ElevenNoirSpacing {
  // 휴대폰 stage
  static const phoneStagePadding = EdgeInsets.symmetric(
    vertical: 16,
    horizontal: 20,
  );
  static const phoneStageGap = 16.0;
  static const phoneTopBarHeight = 56.0;
  static const phoneTopBarGap = 14.0;
  static const playerChipPadding = EdgeInsets.fromLTRB(6, 6, 14, 6);
  static const playerChipGap = 10.0;
  static const chipHeight = 52.0;
  static const statusChipPadding = EdgeInsets.fromLTRB(16, 0, 8, 0);
  static const statusChipGap = 12.0;
  static const phoneBodyGap = 20.0;
  static const handRowGap = 22.0;
  static const handTileGap = 10.0;
  static const phonePanelWidth = 268.0;
  static const phonePanelPadding = 18.0;
  static const phonePanelGap = 14.0;
  static const guideCardSize = Size(680, 240);
  static const guideCardPadding = EdgeInsets.symmetric(
    vertical: 16,
    horizontal: 40,
  );

  // 태블릿
  static const tabletSideSize = Size(760, 320);
  static const tabletSideTop = 257.0;
  static const tabletSideGap = 8.0;
  static const tabletSideGapFinal = 10.0;
  static const pillPadding = EdgeInsets.symmetric(horizontal: 20);
  static const pillGap = 12.0;
  static const pillHeight = 66.0;
  static const slotRowGap = 40.0;
  static const scoreWidth = 116.0;
  static const historyCardRect = Rect.fromLTWH(342, 16, 510, 802);
  static const historyCardPadding = EdgeInsets.symmetric(
    vertical: 12,
    horizontal: 18,
  );
  static const historyCardGap = 3.0;
  static const drawCardRect = Rect.fromLTWH(357, 182, 480, 470);
  static const drawCardPadding = EdgeInsets.symmetric(
    vertical: 30,
    horizontal: 20,
  );
  static const historyRowHeight = 64.0;
  static const historyRowCenterWidth = 110.0;
  static const menuInset = 20.0;
  static const menuGap = 8.0;
  static const menuButtonSize = 72.0;
  static const finalButtonsRect = Rect.fromLTWH(357, 267, 480, 300);
  static const finalButtonsGap = 22.0;
  static const toastRect = Rect.fromLTWH(77, 278, 1040, 278);
  static const timeBarSize = Size(360, 16);
}
