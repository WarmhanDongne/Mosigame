// [deck_showcase_shuffle_animation.dart] 카드를 나눠 주기 직전에 이번 판에
// 공개할 카드를 앞면으로 줄지어 보여 준 뒤, 나머지 카드와 함께 뒷면으로 섞는
// 태블릿 공용 연출이다.
//
// 1. 전시할 카드 덱이 화면 가운데에 은은하게 나타난다.
// 2. 전시 카드를 세기 쉬운 줄로 깔며 앞면을 공개하고 [showcaseHold] 동안 머문다.
// 3. 전시하지 않는 카드([hiddenCardCount])가 양옆에서 빠르게 들어와 전시 카드
//    사이에 흩어져 놓인다.
// 4. 모든 카드가 함께 뒷면으로 뒤집혀 가운데로 모이고 세 번 섞인다.
//
// 마지막 프레임은 [CardDealAnimation]의 시작 덱과 위치·크기·겹침이 같아
// 분배로 끊김 없이 넘어간다. 카드 그림은 게임이 [faceBuilder]·
// [hiddenFaceBuilder]·[backBuilder]로 넘긴다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/shared/animations/curve_intervals.dart';
import 'package:game_kit/tablet/animations/card_deal_animation.dart';

// ============================================================

/// 전시 줄의 [row]번째 줄, 줄 안 [index]번째 카드의 앞면을 그립니다.
typedef DeckShowcaseFaceBuilder =
    Widget Function(BuildContext context, int row, int index);

/// 나중에 합류하는 [index]번째 카드의 앞면을 그립니다.
typedef DeckShowcaseHiddenFaceBuilder =
    Widget Function(BuildContext context, int index);

/// 카드 종류별 장수는 공개 정보라 그대로 보여 주지만, 실제 순서와 남겨 둔
/// 카드의 정체는 클라이언트가 모르므로 섞기 결과는 연출일 뿐입니다.
class DeckShowcaseShuffleAnimation extends StatefulWidget {
  const DeckShowcaseShuffleAnimation({
    super.key,
    required this.rowCounts,
    required this.faceBuilder,
    required this.backBuilder,
    required this.cardWidth,
    required this.cardAspectRatio,
    required this.cardRadius,
    this.hiddenCardCount = 0,
    this.hiddenFaceBuilder,
    this.cardColor,
    this.title,
    this.titleStyle,
    this.showcaseHold = defaultShowcaseHold,
    this.play = true,
    this.onCompleted,
  });

  /// 위에서부터 앞면으로 전시할 줄별 장수입니다. 0장인 줄은 건너뜁니다.
  final List<int> rowCounts;

  /// 전시하지 않는 장수입니다. 전시가 끝난 뒤 양옆에서 들어와 함께 섞입니다.
  final int hiddenCardCount;

  final DeckShowcaseFaceBuilder faceBuilder;

  /// 합류하는 카드의 앞면입니다. 없으면 뒷면인 채로 들어옵니다.
  final DeckShowcaseHiddenFaceBuilder? hiddenFaceBuilder;
  final WidgetBuilder backBuilder;

  /// [CardDealAnimation]에 넘기는 값과 같아야 분배로 끊김 없이 이어집니다.
  final double cardWidth;
  final double cardAspectRatio;
  final double cardRadius;

  /// 카드 그림 뒤에 까는 바탕색입니다. 둥근 모서리 사이로 비치는 색입니다.
  final Color? cardColor;

  /// 전시하는 동안 위쪽에 띄우는 제목입니다.
  final String? title;
  final TextStyle? titleStyle;

  /// 앞면을 모두 공개한 뒤 그대로 보여 주는 시간입니다.
  final Duration showcaseHold;

  /// false인 동안에는 덱만 중앙에 놓아 두고 안내가 끝나기를 기다립니다.
  final bool play;

  final VoidCallback? onCompleted;

  /// [count]장을 세기 쉽게 한 줄 최대 [maxPerRow]장, 줄마다 비슷한 장수로
  /// 나눈 [rowCounts]입니다. 예: 9장 → [5, 4], 12장 → [6, 6], 15장 → [5, 5, 5].
  static List<int> balancedRows(int count, {int maxPerRow = 6}) {
    if (count <= 0) return const [];
    final rows = (count + maxPerRow - 1) ~/ maxPerRow;
    final base = count ~/ rows;
    final extra = count % rows;
    return [for (var row = 0; row < rows; row++) base + (row < extra ? 1 : 0)];
  }

  /// 덱이 화면 가운데에 은은하게 나타나는 시간입니다.
  static const entryDuration = Duration(milliseconds: 620);

  /// 기본 머무는 시간입니다.
  static const defaultShowcaseHold = Duration(milliseconds: 980);

  /// 덱 등장 뒤 전시·합류·섞기까지 걸리는 시간입니다.
  static Duration shuffleDurationFor(Duration showcaseHold) =>
      const Duration(milliseconds: _moveMs) + showcaseHold;

  /// 머무름을 뺀 움직임 구간의 길이입니다.
  static const int _moveMs = 4200;

  @override
  State<DeckShowcaseShuffleAnimation> createState() =>
      _DeckShowcaseShuffleAnimationState();
}

class _DeckShowcaseShuffleAnimationState
    extends State<DeckShowcaseShuffleAnimation>
    with TickerProviderStateMixin {
  // 타임라인(ms)입니다. 머무름은 [_holdAt]에 끼워 넣으며 그동안은 멈춥니다.
  static const double _dealOutSpread = 414;
  static const double _dealOutLength = 230;
  static const double _flipInStart = 207;
  static const double _flipInSpread = 460;
  static const double _flipLength = 230;
  static const double _labelInStart = 276;
  static const double _labelInEnd = 690;
  static const double _holdAt = 920;
  static const double _joinSpread = 160;
  static const double _joinLength = 280;
  static const double _flipOutStart = 1400;
  static const double _flipOutSpread = 200;
  static const double _labelOutEnd = 1700;
  static const double _gatherStart = 1860;
  static const double _gatherSpread = 280;
  static const double _gatherLength = 240;
  static const double _shuffleStart = 2420;
  static const double _shuffleLength = 1725;

  static const _passCount = 3;
  static const _passSpread = [.66, .58, .5];

  // 줄 배치 치수입니다. 전시 카드는 덱 카드 크기까지 키워 세기 쉽게 합니다.
  static const _rowSidePadding = 56.0;
  static const _rowCardGap = 10.0;
  static const _rowGap = 24.0;
  static const _rowVerticalPadding = 92.0;

  /// 섞기 한 번에서 두 묶음으로 벌어지는 구간의 끝입니다.
  static const _splitEnd = .38;

  /// 맨 아래 카드부터 맨 위 카드까지 착지 시작이 퍼지는 폭입니다.
  static const _mergeStagger = .44;
  static const _mergeLength = .18;

  /// 장수를 아직 모를 때 뒷면으로 섞기만 보여 주는 카드 수입니다.
  static const _fallbackCardCount = 10;

  List<List<int>>? _cachedOrders;

  late final AnimationController _entry;
  late final AnimationController _shuffle;
  late final Listenable _animation;

  @override
  void initState() {
    super.initState();
    _entry =
        AnimationController(
            vsync: this,
            duration: DeckShowcaseShuffleAnimation.entryDuration,
          )
          ..addStatusListener(_onEntryStatus)
          ..forward();
    _shuffle = AnimationController(
      vsync: this,
      duration: DeckShowcaseShuffleAnimation.shuffleDurationFor(
        widget.showcaseHold,
      ),
    )..addStatusListener(_onShuffleStatus);
    _animation = Listenable.merge([_entry, _shuffle]);
  }

  @override
  void didUpdateWidget(DeckShowcaseShuffleAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showcaseHold != widget.showcaseHold) {
      _shuffle.duration = DeckShowcaseShuffleAnimation.shuffleDurationFor(
        widget.showcaseHold,
      );
    }
    _startWhenReady();
  }

  @override
  void dispose() {
    _entry
      ..removeStatusListener(_onEntryStatus)
      ..dispose();
    _shuffle
      ..removeStatusListener(_onShuffleStatus)
      ..dispose();
    super.dispose();
  }

  void _onEntryStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _startWhenReady();
  }

  void _onShuffleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onCompleted?.call();
  }

  void _startWhenReady() {
    if (widget.play && _entry.isCompleted && _shuffle.isDismissed) {
      _shuffle.forward();
    }
  }

  /// 컨트롤러 진행도를 머무름을 뺀 타임라인(ms)으로 옮깁니다.
  double get _time {
    final holdMs = widget.showcaseHold.inMicroseconds / 1000;
    final elapsed =
        _shuffle.value * (DeckShowcaseShuffleAnimation._moveMs + holdMs);
    if (elapsed <= _holdAt) return elapsed;
    if (elapsed <= _holdAt + holdMs) return _holdAt;
    return elapsed - holdMs;
  }

  static double _span(
    double time,
    double start,
    double length, [
    Curve curve = Curves.linear,
  ]) => intervalProgress(time, start, start + length, curve);

  /// 0장인 줄을 뺀 (원래 줄 번호, 장수) 목록입니다.
  List<(int, int)> get _rows => [
    for (final (row, count) in widget.rowCounts.indexed)
      if (count > 0) (row, count),
  ];

  int get _shownCount => _rows.fold<int>(0, (sum, row) => sum + row.$2);

  bool get _hasShowcase => _shownCount > 0;

  int get _hiddenCount => math.max<int>(widget.hiddenCardCount, 0);

  int get _cardCount {
    final count = _shownCount + _hiddenCount;
    return count > 0 ? count : _fallbackCardCount;
  }

  /// [pass]번째 섞기를 시작할 때의 순서입니다. 0번이 덱 맨 위입니다.
  List<List<int>> get _orders {
    final cached = _cachedOrders;
    if (cached != null && cached.first.length == _cardCount) return cached;
    return _cachedOrders = _buildOrders(_cardCount);
  }

  static List<List<int>> _buildOrders(int cardCount) {
    final orders = <List<int>>[
      [for (var card = 0; card < cardCount; card++) card],
    ];
    final half = cardCount ~/ 2;
    for (var pass = 0; pass < _passCount; pass++) {
      final current = orders.last;
      final first = pass.isEven
          ? current.sublist(half)
          : current.sublist(0, cardCount - half);
      final second = pass.isEven
          ? current.sublist(0, half)
          : current.sublist(cardCount - half);
      orders.add([
        for (var index = 0; index < first.length; index++) ...[
          first[index],
          if (index < second.length) second[index],
        ],
      ]);
    }
    return orders;
  }

  static double _pileY(int layer) => math.min(layer, 7) * 1.15;

  /// 카드마다 정해진 0~1 값입니다. 매 프레임 같은 자리에 놓이게 합니다.
  static double _hash(int seed, double salt) {
    final value = math.sin(seed * 12.9898 + salt) * 43758.5453;
    return value - value.floorToDouble();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final cardWidth = CardDealAnimation.effectiveCardWidth(
          size,
          widget.cardWidth,
        );
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, _) => _buildScene(context, size, cardWidth),
        );
      },
    );
  }

  Widget _buildScene(BuildContext context, Size size, double cardWidth) {
    final time = _time;
    final cardHeight = cardWidth * widget.cardAspectRatio;
    final layout = _RowLayout.of(
      rows: _rows,
      size: size,
      cardWidth: cardWidth,
      aspectRatio: widget.cardAspectRatio,
    );
    final poses = [
      for (var card = 0; card < _cardCount; card++)
        _poseOf(card, time, size, cardWidth, layout),
    ]..sort((a, b) => a.paintOrder.compareTo(b.paintOrder));
    final center = size.center(Offset.zero);
    // 위에서 떨어지지 않고 제자리에서 은은하게 나타납니다.
    final entry = Curves.easeOutCubic.transform(_entry.value);
    final labelOpacity =
        _span(time, _labelInStart, _labelInEnd - _labelInStart) *
        (1 - _span(time, _flipOutStart, _labelOutEnd - _flipOutStart));
    final title = widget.title;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Opacity(
          opacity: entry,
          child: Transform.scale(
            scale: .94 + .06 * entry,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                for (final pose in poses)
                  Positioned(
                    key: ValueKey(pose.card),
                    left: center.dx + pose.offset.dx - cardWidth / 2,
                    top: center.dy + pose.offset.dy - cardHeight / 2,
                    width: cardWidth,
                    height: cardHeight,
                    child: ExcludeSemantics(
                      child: Opacity(
                        opacity: pose.opacity,
                        child: Transform.rotate(
                          angle: pose.angle,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.diagonal3Values(
                              pose.scaleX * pose.scale,
                              pose.scale,
                              1,
                            ),
                            child: _buildCard(context, pose),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (title != null && _hasShowcase)
          Positioned(
            top: 42,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: labelOpacity,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style:
                    widget.titleStyle ??
                    const TextStyle(
                      color: Color(0xFFF2EADB),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
      ],
    );
  }

  _CardPose _poseOf(
    int card,
    double time,
    Size size,
    double cardWidth,
    _RowLayout layout,
  ) {
    if (time >= _shuffleStart) {
      return _shufflePose(card, time, cardWidth);
    }
    final shown = card < _shownCount;
    // 뒷면으로 뒤집기와 모으기는 전시 카드와 합류 카드가 섞인 순서로 거의
    // 동시에 합니다. 한쪽이 먼저 뒤집혀 종류가 구분되어 보이지 않게 합니다.
    final order = _hash(card, 5.3);
    final flipOut = _span(
      time,
      _flipOutStart + _flipOutSpread * order,
      _flipLength,
      Curves.easeInOut,
    );
    final gather = _span(
      time,
      _gatherStart + _gatherSpread * (1 - order),
      _gatherLength,
      Curves.easeInOutCubic,
    );
    final pile = Offset(0, _pileY(card));
    final rowScale = layout.cardWidth / cardWidth;

    if (shown) {
      // 맨 위 카드(첫 줄 첫 장)부터 차례로 깔고 뒤집습니다.
      final sequence = _shownCount <= 1 ? 0.0 : card / (_shownCount - 1);
      final dealOut = _span(
        time,
        _dealOutSpread * sequence,
        _dealOutLength,
        Curves.easeOutCubic,
      );
      final flipIn = _span(
        time,
        _flipInStart + _flipInSpread * sequence,
        _flipLength,
        Curves.easeInOut,
      );
      final spread = dealOut * (1 - gather);
      final turned = flipIn - flipOut;
      final slot = layout.slotOf(card);
      return _CardPose(
        card: card,
        paintOrder: -card.toDouble(),
        offset: Offset.lerp(pile, slot.offset, spread)!,
        // 손으로 놓은 느낌만 나도록 카드마다 정해진 만큼 살짝 기울입니다.
        angle: math.sin(card * 2.4 + 1) * .035 * spread,
        scaleX: math.cos(math.pi * turned).abs(),
        scale:
            (1 + (rowScale - 1) * spread) *
            (1 + .06 * math.sin(math.pi * turned)),
        faceUp: turned > .5,
        row: slot.row,
        index: slot.index,
      );
    }

    // 전시 카드가 없으면 처음부터 모든 카드가 뒷면 덱으로 있습니다.
    if (!_hasShowcase) {
      return _CardPose(
        card: card,
        paintOrder: -card.toDouble(),
        offset: pile,
        angle: 0,
        scaleX: 1,
        scale: 1,
        faceUp: false,
      );
    }

    // 전시하지 않는 카드: 머무름이 끝나면 양옆에서 빠르게 들어와 전시 카드
    // 사이에 흩어져 놓이고, 전시 카드와 함께 뒷면으로 뒤집혀 모입니다.
    final hidden = card - _shownCount;
    final hiddenSequence = _hiddenCount <= 1
        ? 0.0
        : hidden / (_hiddenCount - 1);
    final joinStart = _holdAt + _joinSpread * hiddenSequence;
    final join = _span(time, joinStart, _joinLength, Curves.easeOutCubic);
    final fromLeft = hidden.isEven;
    final scatter = layout.scatterOf(_hash(hidden, 1.3), _hash(hidden, 7.1));
    final entrySide = Offset(
      (fromLeft ? -1 : 1) * (size.width / 2 + layout.cardWidth),
      scatter.dy - 60,
    );
    final landed = Offset.lerp(entrySide, scatter, join)!;
    final hasFace = widget.hiddenFaceBuilder != null;
    final joined = join > 0;
    final turned = hasFace && joined ? 1 - flipOut : 0.0;
    final targetAngle = (_hash(hidden, 3.7) - .5) * .5;
    final angle =
        (targetAngle + (fromLeft ? -.6 : .6) * (1 - join)) * (1 - gather);
    return _CardPose(
      card: card,
      // 들어온 카드는 전시 카드 위에 놓이고, 모일 때는 덱 순서를 따릅니다.
      paintOrder: gather > 0 ? -card.toDouble() : 50.0 + hidden,
      offset: Offset.lerp(landed, pile, gather)!,
      angle: angle,
      scaleX: hasFace ? math.cos(math.pi * turned).abs() : 1,
      scale:
          (1 + (rowScale - 1) * (1 - gather)) *
          (1 + .06 * math.sin(math.pi * turned)),
      faceUp: turned > .5,
      opacity: joined ? 1 : 0,
      hiddenIndex: hidden,
    );
  }

  _CardPose _shufflePose(int card, double time, double cardWidth) {
    final overall = _span(time, _shuffleStart, _shuffleLength);
    final passProgress = overall * _passCount;
    final pass = math.min(passProgress.floor(), _passCount - 1);
    final local = ((passProgress - pass) / .94).clamp(0.0, 1.0);

    final before = _orders[pass].indexOf(card);
    final after = _orders[pass + 1].indexOf(card);
    final side = before < _cardCount / 2 ? -1.0 : 1.0;

    final split = intervalProgress(local, 0, _splitEnd, Curves.easeInOutCubic);
    final landingStart =
        _splitEnd + (_cardCount - 1 - after) / _cardCount * _mergeStagger;
    final landing = intervalProgress(
      local,
      landingStart,
      landingStart + _mergeLength,
      Curves.easeOutCubic,
    );
    final apart = split * (1 - landing);
    final tilt = pass.isEven ? 1.0 : -1.0;
    // 벌어진 묶음이 한 장처럼 보이지 않도록 아래 카드를 바깥쪽으로 조금 밀어 냅니다.
    final packetDepth = math.min(before % math.max(_cardCount ~/ 2, 1), 5);

    return _CardPose(
      card: card,
      // 착지를 시작한 카드는 벌어진 묶음보다 위에, 먼저 착지한 카드 위로 쌓입니다.
      paintOrder: landing > 0 ? 100.0 - after : 0.0 - before,
      offset: Offset(
        side * (cardWidth * _passSpread[pass] + packetDepth * 2.6) * apart,
        _pileY(before) +
            (_pileY(after) - _pileY(before)) * landing +
            packetDepth * 1.8 * apart,
      ),
      angle: side * tilt * .07 * apart,
      scaleX: 1,
      scale: 1 + .04 * math.sin(math.pi * landing),
      faceUp: false,
    );
  }

  Widget _buildCard(BuildContext context, _CardPose pose) {
    final row = pose.row;
    final index = pose.index;
    final hiddenIndex = pose.hiddenIndex;
    final hiddenFace = widget.hiddenFaceBuilder;
    final Widget child;
    if (pose.faceUp && row != null && index != null) {
      child = widget.faceBuilder(context, row, index);
    } else if (pose.faceUp && hiddenIndex != null && hiddenFace != null) {
      child = hiddenFace(context, hiddenIndex);
    } else {
      child = widget.backBuilder(context);
    }
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: BorderRadius.circular(widget.cardRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// 전시 줄의 카드 크기와 각 카드 자리입니다. 좌표는 화면 중앙 기준입니다.
@immutable
class _RowLayout {
  const _RowLayout._({
    required this.rows,
    required this.cardWidth,
    required this.cardHeight,
    required this.top,
    required this.blockWidth,
    required this.blockHeight,
  });

  factory _RowLayout.of({
    required List<(int, int)> rows,
    required Size size,
    required double cardWidth,
    required double aspectRatio,
  }) {
    const sidePadding = _DeckShowcaseShuffleAnimationState._rowSidePadding;
    const cardGap = _DeckShowcaseShuffleAnimationState._rowCardGap;
    const rowGap = _DeckShowcaseShuffleAnimationState._rowGap;
    const verticalPadding =
        _DeckShowcaseShuffleAnimationState._rowVerticalPadding;
    final rowCount = math.max(rows.length, 1);
    final longestRow = math.max(
      rows.fold<int>(0, (longest, row) => math.max(longest, row.$2)),
      1,
    );
    final byWidth =
        (size.width - sidePadding * 2 - cardGap * (longestRow - 1)) /
        longestRow;
    final gaps = rowGap * (rowCount - 1);
    final availableHeight = size.height - verticalPadding * 2;
    final byHeight = (availableHeight - gaps) / (rowCount * aspectRatio);
    final width = math.max(
      12.0,
      math.min(cardWidth, math.min(byWidth, byHeight)),
    );
    final height = width * aspectRatio;
    final blockHeight = height * rowCount + gaps;
    return _RowLayout._(
      rows: rows,
      cardWidth: width,
      cardHeight: height,
      top: -blockHeight / 2,
      blockWidth: width * longestRow + cardGap * (longestRow - 1),
      blockHeight: blockHeight,
    );
  }

  final List<(int, int)> rows;
  final double cardWidth;
  final double cardHeight;

  /// 첫 줄 윗변의 y입니다.
  final double top;
  final double blockWidth;
  final double blockHeight;

  /// 전시 카드 [card](0부터, 첫 줄부터 이어서 센 번호)의 자리입니다.
  ({Offset offset, int row, int index}) slotOf(int card) {
    const rowGap = _DeckShowcaseShuffleAnimationState._rowGap;
    const cardGap = _DeckShowcaseShuffleAnimationState._rowCardGap;
    var remaining = card;
    for (final (line, (row, count)) in rows.indexed) {
      if (remaining < count) {
        final y = top + line * (cardHeight + rowGap) + cardHeight / 2;
        return (
          offset: Offset(
            (remaining - (count - 1) / 2) * (cardWidth + cardGap),
            y + math.sin(card * 1.7) * 3,
          ),
          row: row,
          index: remaining,
        );
      }
      remaining -= count;
    }
    return (offset: Offset.zero, row: 0, index: 0);
  }

  /// 합류하는 카드가 놓일 자리입니다. 전시 줄이 차지한 영역 안에 흩어집니다.
  Offset scatterOf(double randomX, double randomY) => Offset(
    (randomX - .5) * blockWidth * .92,
    top + cardHeight / 2 + randomY * math.max(blockHeight - cardHeight, 0),
  );
}

@immutable
class _CardPose {
  const _CardPose({
    required this.card,
    required this.paintOrder,
    required this.offset,
    required this.angle,
    required this.scaleX,
    required this.scale,
    required this.faceUp,
    this.opacity = 1,
    this.row,
    this.index,
    this.hiddenIndex,
  });

  final int card;

  /// 값이 클수록 위에 그려집니다.
  final double paintOrder;
  final Offset offset;
  final double angle;
  final double scaleX;
  final double scale;
  final bool faceUp;
  final double opacity;

  /// 앞면으로 그릴 때 [DeckShowcaseShuffleAnimation.faceBuilder]에 넘길 위치입니다.
  final int? row;
  final int? index;

  /// 합류 카드라면 [DeckShowcaseShuffleAnimation.hiddenFaceBuilder]에 넘길 번호입니다.
  final int? hiddenIndex;
}
