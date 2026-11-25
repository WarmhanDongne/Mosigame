// [mosi_game_modal.dart] 는 게임 안 공용 모달(설정·규칙)의 시안 판을 그리는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Design] : 1040×680 흰 판 + 굵은 테두리 + 강조색 오프셋 그림자
//
// 기존 [TabletGameModalFrame]은 게임별 전용 모달도 쓰고 있어 그대로 두고,
// 시안을 입힌 설정·룰북만 이 판을 씁니다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

// ============================================================

/// 게임 안 모달의 강조색 묶음입니다.
@immutable
class MosiGameModalTheme {
  const MosiGameModalTheme({
    required this.accent,
    required this.accentFg,
    required this.deep,
    this.surface = MosiColors.white,
    this.surfaceStripes = false,
    this.frameShadowColor,
    this.frameShadowOffset = const Offset(12, 12),
    this.onSurface = MosiColors.navy,
    this.panel = MosiColors.cream,
    this.panelBorderWidth = 2,
    this.panelRadius = 14,
    this.panelShadow = false,
    this.tabIdle = MosiColors.white,
    this.dotIdle = const Color(0x400E0A3D),
    this.media,
    this.tileCodeChips = false,
    this.secondaryButton = MosiColors.sky,
    this.secondaryButtonFg = MosiColors.white,
    this.soundIcons = const [
      MosiColors.sun,
      MosiColors.lime,
      Color(0xFF9CC3FF),
    ],
  });

  final Color accent;
  final Color accentFg;
  final Color deep;

  /// 판 바탕색입니다. 기본은 흰 판입니다.
  final Color surface;

  /// 판에 게임 테이블 같은 사선 무늬를 깝니다(ELEVEN 느와르 카드룸).
  final bool surfaceStripes;

  /// 판 그림자 색입니다. null이면 [accent]를 씁니다.
  final Color? frameShadowColor;
  final Offset frameShadowOffset;

  /// 판 위(칸 밖)에 놓이는 제목·라벨 글자색입니다.
  final Color onSurface;

  /// 설정 칸·규칙 본문 카드의 바탕과 테두리·모서리·그림자입니다.
  final Color panel;
  final double panelBorderWidth;
  final double panelRadius;
  final bool panelShadow;

  /// 선택되지 않은 규칙 탭 바탕과 쪽 점 색입니다.
  final Color tabIdle;
  final Color dotIdle;

  /// 규칙 영상 칸 바탕입니다. null이면 [deep]을 씁니다.
  final Color? media;

  /// 방 코드 글자를 흑·백 타일로 번갈아 그립니다(ELEVEN).
  final bool tileCodeChips;

  /// 설정의 '게임 재시작' 단추 색입니다.
  final Color secondaryButton;
  final Color secondaryButtonFg;

  /// 설정의 전체·효과·배경 소리 아이콘 바탕 세 색입니다.
  final List<Color> soundIcons;

  Color get mediaColor => media ?? deep;
  Color get shadowColor => frameShadowColor ?? accent;

  List<BoxShadow> get panelShadows => panelShadow
      ? const [BoxShadow(color: MosiColors.ink, offset: Offset(0, 8))]
      : const [];

  static const liarsPoker = MosiGameModalTheme(
    accent: Color(0xFFF2C14E),
    accentFg: Color(0xFF1B1022),
    deep: Color(0xFF6E2A82),
  );

  static const finalCall = MosiGameModalTheme(
    accent: Color(0xFFE5DB00),
    accentFg: Color(0xFF141414),
    deep: Color(0xFF141414),
  );

  static const mafia = MosiGameModalTheme(
    accent: Color(0xFFFF4D4D),
    accentFg: MosiColors.white,
    deep: Color(0xFF10131A),
  );

  /// ELEVEN 시안 A(느와르 카드룸): 먹색 사선 테이블 판, 크림 카드 칸,
  /// 두꺼운 잉크 테두리와 단단한 그림자, 빨간 선택·주 단추.
  static const eleven = MosiGameModalTheme(
    accent: Color(0xFFC9242A),
    accentFg: Color(0xFFF7F0E4),
    deep: Color(0xFFC9242A),
    surface: Color(0xFF262524),
    surfaceStripes: true,
    frameShadowColor: Color(0xFF000000),
    frameShadowOffset: Offset(0, 10),
    onSurface: Color(0xFFF7F0E4),
    panel: Color(0xFFEFE6D6),
    panelBorderWidth: 4,
    panelRadius: 22,
    panelShadow: true,
    tabIdle: Color(0xFFF7F0E4),
    dotIdle: Color(0xFF6E655A),
    media: Color(0xFF1B1B1B),
    tileCodeChips: true,
    secondaryButton: Color(0xFFF7F0E4),
    secondaryButtonFg: Color(0xFF141414),
    soundIcons: [Color(0xFFF7F0E4), Color(0xFFE9E1D3), Color(0xFFC9242A)],
  );

  static const fallback = MosiGameModalTheme(
    accent: MosiColors.lime,
    accentFg: MosiColors.navy,
    deep: MosiColors.violet,
  );

  /// 게임 이름(한글·영문)으로 고릅니다. 모달이 게임 id를 모르기 때문입니다.
  static MosiGameModalTheme fromName(String? name) {
    final lower = (name ?? '').toLowerCase();
    if (lower.contains('liar') || lower.contains('라이어')) return liarsPoker;
    if (lower.contains('final') || lower.contains('파이널')) return finalCall;
    if (lower.contains('mafia') || lower.contains('마피아')) return mafia;
    if (lower.contains('eleven') || lower.contains('일레븐')) return eleven;
    return fallback;
  }
}

/// 시안 크기(1040×680)로 그린 판을 화면에 맞춰 줄입니다.
class MosiGameModalFrame extends StatelessWidget {
  const MosiGameModalFrame({
    super.key,
    required this.child,
    required this.theme,
    this.padding = const EdgeInsets.fromLTRB(34, 30, 34, 30),
    this.semanticLabel,
  });

  static const Size designSize = Size(1040, 680);

  final Widget child;
  final MosiGameModalTheme theme;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.sizeOf(context);
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : media.width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : media.height;
        // 1194×834 화면에서 시안과 같은 비율(약 87%·82%)이 되도록 맞춥니다.
        final scale = math.min(
          math.min(
            width * 0.87 / designSize.width,
            height * 0.82 / designSize.height,
          ),
          1.4,
        );
        return Semantics(
          scopesRoute: true,
          namesRoute: semanticLabel != null,
          label: semanticLabel,
          explicitChildNodes: true,
          child: SizedBox(
            width: (designSize.width + 12) * scale,
            height: (designSize.height + 12) * scale,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: designSize.width + 12,
                height: designSize.height + 12,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    width: designSize.width,
                    height: designSize.height,
                    padding: padding,
                    clipBehavior: theme.surfaceStripes
                        ? Clip.antiAlias
                        : Clip.none,
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(
                        theme.surfaceStripes ? 28 : 20,
                      ),
                      border: Border.all(
                        color: MosiColors.ink,
                        width: theme.surfaceStripes ? 4 : 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor,
                          offset: theme.frameShadowOffset,
                        ),
                      ],
                    ),
                    // Slider·InkWell이 Material을 찾을 수 있게 한 겹 둡니다.
                    child: CustomPaint(
                      painter: theme.surfaceStripes
                          ? const _ModalStripePainter()
                          : null,
                      child: Material(
                        type: MaterialType.transparency,
                        child: DefaultTextStyle(
                          style: MosiFonts.sans(color: MosiColors.navy),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 모달 오른쪽 위 네모 닫기 단추(✕).
class MosiSquareCloseButton extends StatelessWidget {
  const MosiSquareCloseButton({
    super.key,
    required this.onPressed,
    this.size = 48,
  });

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '닫기'.localized,
      child: Semantics(
        button: true,
        label: '닫기'.localized,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: MosiColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MosiColors.ink, width: 3),
            ),
            child: Icon(
              Icons.close_rounded,
              size: size * 0.5,
              color: MosiColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// 크림색 칸(설정 모달 안의 게임·방 정보·소리 칸).
class MosiCreamPanel extends StatelessWidget {
  const MosiCreamPanel({
    super.key,
    required this.child,
    this.title,
    this.theme = MosiGameModalTheme.fallback,
  });

  final Widget child;
  final String? title;

  /// 칸 바탕·테두리·그림자를 고르는 게임 테마입니다.
  final MosiGameModalTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(theme.panelRadius),
        border: Border.all(
          color: MosiColors.ink,
          width: theme.panelBorderWidth,
        ),
        boxShadow: theme.panelShadows,
      ),
      child: child,
    );
  }
}

/// 게임 테이블과 같은 135° 사선 무늬(흰색 3.5%, 2px 줄 · 14px 간격)입니다.
/// 패딩 안쪽에 그려지므로 판 가장자리 패딩만큼 바깥까지 넉넉히 그립니다.
class _ModalStripePainter extends CustomPainter {
  const _ModalStripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 40.0;
    final step = 14 * math.sqrt2;
    final width = 2 * math.sqrt2;
    final paint = Paint()..color = const Color(0x09FFFFFF);
    final h = size.height + pad * 2;
    for (var x = -pad; x < size.width + h + step; x += step) {
      canvas.drawPath(
        Path()
          ..moveTo(x, -pad)
          ..lineTo(x + width, -pad)
          ..lineTo(x + width - h, size.height + pad)
          ..lineTo(x - h, size.height + pad)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ModalStripePainter oldDelegate) => false;
}
