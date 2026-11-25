// [noir_tile.dart] 는 ELEVEN 시안 A 카드 타일 한 장을 그리는 공통 위젯이다.
//
// - [Package] : ELEVEN
// - [Widget] : 휴대폰 손패·패널 타일, 태블릿 슬롯·뽑기 카드·전적칸, 안내 카드 그림 타일
//
// 크기·반경·테두리·그림자·흐림 값은 docs/design/eleven/screens.md 1절·2절 원문이다.
// 숫자는 이미 공개된 값(본인 손패, 공개된 뽑기 카드)만 넘긴다. 태블릿 본 게임 슬롯과
// 전적칸은 색만 그린다(계약 4절 누출 금지 값).

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:game_eleven/shared/noir/noir_text.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';
import 'package:game_eleven/shared/models/tiles.dart';
import 'package:game_eleven/shared/widgets/noir_dashed_box.dart';

// ============================================================

/// 타일 앞면 종류입니다.
enum ElevenTileFace {
  /// 흑 `blk` (#1b1b1b, 크림 글자).
  black,

  /// 백 `wht` (#f7f0e4, 잉크 글자).
  white,

  /// 뒷면 `back` (빨강 사선).
  back,

  /// 빈 자리 `empty` (회베이지 점선, “?”). 어두운 태블릿 판 위의 빈 슬롯·전적칸.
  empty,

  /// 크림 패널 안의 빈 타일 자리(프로토타입 ②: 크림-카드 바탕 + 회베이지 점선, 글자 없음).
  /// 휴대폰 패널에서 아직 고르지 않았을 때 쓴다.
  placeholder;

  static ElevenTileFace of(ElevenTileColor color) => switch (color) {
    ElevenTileColor.black => ElevenTileFace.black,
    ElevenTileColor.white => ElevenTileFace.white,
  };

  /// 값의 색으로 앞면을 고릅니다. 공용 뽑기 카드도 같은 규칙입니다(결정 4).
  static ElevenTileFace ofValue(int value) => of(ElevenTileColor.of(value));
}

/// 타일 상태입니다(screens.md 1-4 흐림·외곽선).
enum ElevenTileState {
  normal,

  /// 휴대폰 `sel`: 빨간 외곽선 4px(offset 4) + 8px 들림 + −3° 기울임 + 선택 배지.
  selected,

  /// 쓴 타일 `.used`: opacity .28, 그림자 없음.
  used,

  /// 잠김(대기) `.wait`: opacity .6. 제출 뒤나 차례가 아닐 때.
  locked,

  /// 뽑기 후 남은 카드 `.dim`: opacity .35, 그림자 없음.
  dim,

  /// 승리 `winT`: 빨간 외곽선 4px(offset 2) + 번짐 7px. 전적행 안은 3px/1px/6px.
  win,

  /// 진 전적칸 `.loseT`: opacity .38.
  lose,

  /// 뽑기에서 고른 카드 `pickA`: 빨간 외곽선 5px(offset 3).
  picked,

  /// 안내 카드 그림 줄의 이긴 타일(G4·G5): 빨간 외곽선 4px(offset 3), 번짐 없음.
  guideWin,

  /// 안내 카드 그림 줄의 진 타일(G4·G5): opacity .45. G6은 [ElevenNoirOpacity.guideLoserRoundResult].
  guideLose,
}

/// 부품별 크기 변형입니다. 값은 screens.md 2절 원문입니다.
@immutable
class ElevenTileSpec {
  const ElevenTileSpec({
    required this.size,
    required this.radius,
    required this.numberSize,
    this.border = ElevenNoirBorder.regular,
    this.shadow = ElevenNoirShadow.regular,
    this.innerInset,
    this.innerRadius,
    this.cornerNumberSize,
    this.dotRadius,
    this.dotAnchor,
    this.inHistoryRow = false,
  });

  /// 휴대폰 손패 `.tile` 64×84, 반경 12, 숫자 32, 모서리 숫자 11, 모서리 점 1.5.
  static const phoneHand = ElevenTileSpec(
    size: Size(64, 84),
    radius: ElevenNoirRadius.tile,
    numberSize: 32,
    innerInset: 5,
    innerRadius: ElevenNoirRadius.tileInner,
    cornerNumberSize: 11,
    dotRadius: 1.5,
    dotAnchor: Offset(8, 12),
  );

  /// 휴대폰 오른쪽 패널 큰 타일 78×104, 숫자 40 (P09 11은 [phoneLastTile]).
  static const phonePanel = ElevenTileSpec(
    size: Size(78, 104),
    radius: ElevenNoirRadius.tile,
    numberSize: 40,
    innerInset: 5,
    innerRadius: ElevenNoirRadius.tileInner,
    cornerNumberSize: 11,
    dotRadius: 1.5,
    dotAnchor: Offset(8, 12),
  );

  /// P09 마지막 타일 78×104, 숫자 36.
  static const phoneLastTile = ElevenTileSpec(
    size: Size(78, 104),
    radius: ElevenNoirRadius.tile,
    numberSize: 36,
    innerInset: 5,
    innerRadius: ElevenNoirRadius.tileInner,
    cornerNumberSize: 11,
    dotRadius: 1.5,
    dotAnchor: Offset(8, 12),
  );

  /// P05 요약줄 타일 66×88, 숫자 36.
  static const phoneSummary = ElevenTileSpec(
    size: Size(66, 88),
    radius: ElevenNoirRadius.tile,
    numberSize: 36,
    innerInset: 5,
    innerRadius: ElevenNoirRadius.tileInner,
    cornerNumberSize: 11,
    dotRadius: 1.5,
    dotAnchor: Offset(8, 12),
  );

  /// 안내 카드 그림 타일 50×66, 테두리 3, 그림자 없음, 숫자 30, 모서리 숫자 11, 모서리 점 없음.
  static const phoneGuide = ElevenTileSpec(
    size: Size(50, 66),
    radius: ElevenNoirRadius.tile,
    numberSize: 30,
    shadow: [],
    innerInset: 5,
    innerRadius: ElevenNoirRadius.tileInner,
    cornerNumberSize: 11,
  );

  /// P05 요약줄 작은 타일 22×30, 테두리 2, 그림자·안쪽선·모서리 장식 없음(색만).
  static const phoneSummaryMini = ElevenTileSpec(
    size: Size(22, 30),
    radius: ElevenNoirRadius.tile,
    numberSize: 0,
    border: ElevenNoirBorder.thin,
    shadow: [],
  );

  /// 태블릿 슬롯 `.slot` 124×166(회전 전), 반경 18, 그림자 `0 6px 0`, 숫자 68,
  /// 안쪽선 inset 9 r9, 모서리 점 2.4. 뽑기 화면은 [tabletDrawSlot](점 없음).
  static const tabletSlot = ElevenTileSpec(
    size: Size(124, 166),
    radius: ElevenNoirRadius.slot,
    numberSize: 68,
    shadow: ElevenNoirShadow.raised,
    innerInset: 9,
    innerRadius: ElevenNoirRadius.slotInner,
    dotRadius: 2.4,
    dotAnchor: Offset(15, 21),
  );

  /// 뽑기 화면(T01–T03, T11–T12) 슬롯: `.slot::after{display:none}`.
  static const tabletDrawSlot = ElevenTileSpec(
    size: Size(124, 166),
    radius: ElevenNoirRadius.slot,
    numberSize: 68,
    shadow: ElevenNoirShadow.raised,
    innerInset: 9,
    innerRadius: ElevenNoirRadius.slotInner,
  );

  /// 뽑기 카드 `.ptile` 92×68, 반경 12, 숫자 36, 모서리 점 없음(MotionKit 4).
  static const drawCard = ElevenTileSpec(
    size: Size(92, 68),
    radius: ElevenNoirRadius.drawCard,
    numberSize: 36,
  );

  /// 전적칸 `.mini` 높이 58, 비율 166/124(측정 77.6×58), 반경 8, 테두리 2,
  /// 안쪽선 inset 4, 모서리 점 1.2(측정: 오른쪽에서 7px·위 10.2px). 그림자는
  /// [ElevenNoirShadow.historyCell]로 플레이어 쪽만 준다.
  static const historyCell = ElevenTileSpec(
    size: Size(58 * 166 / 124, 58),
    radius: ElevenNoirRadius.historyCell,
    numberSize: 0,
    border: ElevenNoirBorder.thin,
    shadow: [],
    innerInset: 4,
    innerRadius: ElevenNoirRadius.historyCellInner,
    dotRadius: 1.2,
    dotAnchor: Offset(7, 10.2),
    inHistoryRow: true,
  );

  final Size size;
  final double radius;
  final double numberSize;
  final double border;
  final List<BoxShadow> shadow;
  final double? innerInset;
  final double? innerRadius;

  /// 왼쪽 위 작은 숫자 크기. null이면 그리지 않습니다.
  final double? cornerNumberSize;

  /// 모서리 빨간 점(#d42a2f) 반지름. null이면 그리지 않습니다.
  final double? dotRadius;

  /// 오른쪽 위 첫 점의 위치(오른쪽에서 x, 위에서 y). 왼쪽 아래는 점대칭입니다.
  final Offset? dotAnchor;

  /// 전적행 안 승리 외곽선(3px/offset 1/번짐 6)을 씁니다.
  final bool inHistoryRow;

  ElevenTileSpec copyWith({List<BoxShadow>? shadow}) => ElevenTileSpec(
    size: size,
    radius: radius,
    numberSize: numberSize,
    border: border,
    shadow: shadow ?? this.shadow,
    innerInset: innerInset,
    innerRadius: innerRadius,
    cornerNumberSize: cornerNumberSize,
    dotRadius: dotRadius,
    dotAnchor: dotAnchor,
    inHistoryRow: inHistoryRow,
  );
}

class ElevenNoirTile extends StatelessWidget {
  const ElevenNoirTile({
    super.key,
    required this.face,
    required this.spec,
    this.value,
    this.state = ElevenTileState.normal,
    this.badgeLabel,
    this.numberQuarterTurns = 0,
    this.semanticsLabel,
  });

  final ElevenTileFace face;
  final ElevenTileSpec spec;

  /// 앞면에 그릴 숫자입니다. null이면 색만 그립니다. 뒷면·빈 자리에서는 무시합니다.
  final int? value;
  final ElevenTileState state;

  /// [ElevenTileState.selected]일 때 아래에 붙는 배지 문구(“선택”).
  final String? badgeLabel;

  /// 숫자만 돌립니다. 태블릿 뽑기 카드 A쪽 1(90°), B쪽 3(−90°).
  final int numberQuarterTurns;
  final String? semanticsLabel;

  static const _selectedLift = -8.0;
  static const _selectedDegrees = ElevenNoirBadgeLayout.selectedDegrees;

  double get _opacity => switch (state) {
    ElevenTileState.used => ElevenNoirOpacity.used,
    ElevenTileState.locked => ElevenNoirOpacity.wait,
    ElevenTileState.dim => ElevenNoirOpacity.dim,
    ElevenTileState.lose => ElevenNoirOpacity.lose,
    ElevenTileState.guideLose => ElevenNoirOpacity.guideLoser,
    _ => 1,
  };

  bool get _dropsShadow =>
      state == ElevenTileState.used || state == ElevenTileState.dim;

  /// (두께, 간격) 외곽선. 없으면 null.
  (double, double)? get _outline => switch (state) {
    ElevenTileState.selected => (4, 4),
    ElevenTileState.win => spec.inHistoryRow ? (3, 1) : (4, 2),
    ElevenTileState.picked => (5, 3),
    ElevenTileState.guideWin => (4, 3),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final background = switch (face) {
      ElevenTileFace.black => ElevenNoirColors.blackTile,
      ElevenTileFace.white => ElevenNoirColors.whiteTile,
      ElevenTileFace.back => ElevenNoirColors.backStripeDark,
      ElevenTileFace.empty => ElevenNoirColors.emptySlot,
      ElevenTileFace.placeholder => ElevenNoirColors.creamCard,
    };
    final foreground = face == ElevenTileFace.black
        ? ElevenNoirColors.cream
        : ElevenNoirColors.ink;
    final showsNumber =
        value != null &&
        (face == ElevenTileFace.black || face == ElevenTileFace.white);
    final radius = BorderRadius.circular(spec.radius);
    // `winT`의 box-shadow(번짐)는 타일 자체의 단단한 그림자를 대신한다(CSS 같은 속성).
    final dashed =
        face == ElevenTileFace.empty || face == ElevenTileFace.placeholder;
    final shadows = state == ElevenTileState.win
        ? ElevenNoirShadow.winGlow(inHistoryRow: spec.inHistoryRow)
        : _dropsShadow || dashed
        ? const <BoxShadow>[]
        : spec.shadow;

    Widget card = Container(
      width: spec.size.width,
      height: spec.size.height,
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: dashed
            ? null
            : Border.all(color: ElevenNoirColors.ink, width: spec.border),
        boxShadow: shadows,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (face == ElevenTileFace.back)
            ClipRRect(
              borderRadius: BorderRadius.circular(
                math.max(0, spec.radius - spec.border),
              ),
              child: const CustomPaint(painter: _BackStripePainter()),
            ),
          if (dashed)
            CustomPaint(
              painter: ElevenDashedBorderPainter(
                radius: spec.radius,
                width: spec.border,
              ),
            ),
          if (spec.innerInset case final inset?
              when face == ElevenTileFace.black || face == ElevenTileFace.white)
            Positioned.fill(
              left: inset - spec.border,
              top: inset - spec.border,
              right: inset - spec.border,
              bottom: inset - spec.border,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(spec.innerRadius ?? 0),
                  border: Border.all(
                    width: ElevenNoirBorder.inner,
                    color: face == ElevenTileFace.black
                        ? ElevenNoirColors.innerLineOnDark
                        : ElevenNoirColors.innerLineOnLight,
                  ),
                ),
              ),
            ),
          if (spec.dotRadius case final dot?
              when face == ElevenTileFace.black || face == ElevenTileFace.white)
            CustomPaint(
              painter: _CornerDotPainter(
                radius: dot,
                anchor: spec.dotAnchor ?? Offset.zero,
              ),
            ),
          if (spec.cornerNumberSize case final cornerSize? when showsNumber)
            Positioned(
              left: (spec.innerInset ?? 0) - spec.border + 3,
              top: (spec.innerInset ?? 0) - spec.border + 1,
              child: Text(
                '$value',
                style: ElevenNoirText.number(cornerSize, color: foreground),
              ),
            ),
          if (showsNumber)
            Center(
              child: RotatedBox(
                quarterTurns: numberQuarterTurns,
                child: Text(
                  '$value',
                  style: ElevenNoirText.number(
                    spec.numberSize,
                    color: foreground,
                  ),
                ),
              ),
            ),
          if (face == ElevenTileFace.empty)
            Center(
              child: Text(
                '?',
                style: ElevenNoirText.number(
                  spec.numberSize,
                  color: ElevenNoirColors.greyBeige,
                ),
              ),
            ),
        ],
      ),
    );

    final outline = _outline;
    if (outline != null) {
      final (width, gap) = outline;
      final grow = width + gap;
      card = Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            left: -grow,
            top: -grow,
            right: -grow,
            bottom: -grow,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(spec.radius + grow),
                  border: Border.all(
                    color: ElevenNoirColors.accentRed,
                    width: width,
                  ),
                ),
              ),
            ),
          ),
          if (state == ElevenTileState.selected && badgeLabel != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: ElevenNoirBadgeLayout.selectedBottom,
              child: Center(
                child: Transform.rotate(
                  angle: _selectedDegrees * math.pi / 180,
                  child: ElevenNoirBadge(
                    label: badgeLabel!,
                    color: ElevenNoirColors.accentRed,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (state == ElevenTileState.selected) {
      card = Transform.translate(
        offset: const Offset(0, _selectedLift),
        child: Transform.rotate(
          angle: _selectedDegrees * math.pi / 180,
          child: card,
        ),
      );
    }

    final opacity = _opacity;
    if (opacity < 1) card = Opacity(opacity: opacity, child: card);

    return Semantics(
      label: semanticsLabel,
      selected: state == ElevenTileState.selected,
      child: card,
    );
  }
}

/// 타일 왼쪽 위에 붙는 기울어진 배지(`.auto`: 자동 제출·제출 완료)입니다.
/// 타일과 함께 `Stack(clipBehavior: Clip.none)` 안에 넣습니다. P04는 [left]에
/// [ElevenNoirBadgeLayout.tiltedLeftP04]를 넘깁니다.
class ElevenNoirTiltedBadge extends StatelessWidget {
  const ElevenNoirTiltedBadge({
    super.key,
    required this.label,
    this.left = ElevenNoirBadgeLayout.tiltedLeft,
  });

  final String label;
  final double left;

  @override
  Widget build(BuildContext context) => Positioned(
    top: ElevenNoirBadgeLayout.tiltedTop,
    left: left,
    child: Transform.rotate(
      angle: ElevenNoirBadgeLayout.tiltedDegrees * math.pi / 180,
      child: ElevenNoirBadge(label: label),
    ),
  );
}

/// 작은 기울어진 배지(선택·자동 제출·제출 완료) 공통 모양입니다.
/// 12/900 크림 글자, 테두리 2px 잉크, 반경 8, `padding:1px 8px`.
class ElevenNoirBadge extends StatelessWidget {
  const ElevenNoirBadge({
    super.key,
    required this.label,
    this.color = ElevenNoirColors.warnRed,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(ElevenNoirRadius.badge),
      border: Border.all(
        color: ElevenNoirColors.ink,
        width: ElevenNoirBorder.thin,
      ),
    ),
    child: Text(label, style: ElevenNoirText.badge()),
  );
}

/// `repeating-linear-gradient(45deg,#7d1d22 0 8px,#9b262c 8px 16px)`.
class _BackStripePainter extends CustomPainter {
  const _BackStripePainter();

  static const _band = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = ElevenNoirColors.backStripeDark,
    );
    final light = Paint()..color = ElevenNoirColors.backStripeLight;
    // 45deg 그라디언트 축은 오른쪽 위를 향하므로 띠 경계선은 그와 수직인 `\` 방향
    // (왼쪽 위 → 오른쪽 아래)이다. 축 방향 간격 8px = 가로 간격 8√2px.
    final step = _band * math.sqrt2;
    final span = size.width + size.height;
    for (var start = -span + step; start < span; start += step * 2) {
      final path = Path()
        ..moveTo(start, 0)
        ..lineTo(start + step, 0)
        ..lineTo(start + step + size.height, size.height)
        ..lineTo(start + size.height, size.height)
        ..close();
      canvas.drawPath(path, light);
    }
  }

  @override
  bool shouldRepaint(_BackStripePainter oldDelegate) => false;
}

/// 모서리 점 6개: 오른쪽 위·왼쪽 아래 대각선으로 3개씩(#d42a2f).
class _CornerDotPainter extends CustomPainter {
  const _CornerDotPainter({required this.radius, required this.anchor});

  final double radius;

  /// 오른쪽 위 첫 점(오른쪽에서 x, 위에서 y).
  final Offset anchor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ElevenNoirColors.warnRed;
    final step = Offset(radius * 2.5, radius * 1.5);
    for (var i = 0; i < 3; i++) {
      final topRight =
          Offset(size.width - anchor.dx, anchor.dy) - step * i.toDouble();
      canvas.drawCircle(topRight, radius, paint);
      final bottomLeft = Offset(size.width, size.height) - topRight;
      canvas.drawCircle(bottomLeft, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_CornerDotPainter oldDelegate) =>
      radius != oldDelegate.radius || anchor != oldDelegate.anchor;
}
