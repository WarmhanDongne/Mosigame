// [truth_lie_shuffle_animation.dart] 카드를 나눠 주기 직전에 이번 판의 진실·거짓
// 구성을 보여 주고 덱을 섞는 태블릿 연출이다.
//
// 덱 등장 → 진실·거짓 줄로 실제 장수만큼 앞면 공개 → 다시 뒷면 → 덱으로 모으기 →
// 세 번 섞기 순서로
// 이어지며, 마지막 프레임은 CardDealAnimation의 시작 덱과 위치·크기·겹침이 같다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/shared/animations/curve_intervals.dart';
import 'package:game_kit/tablet/animations/card_deal_animation.dart';
import 'package:game_liars_poker/shared/widgets/card_face_view.dart';

// ============================================================

/// 카드 종류별 장수는 공개 정보라 그대로 깔아 보여 주지만, 실제 순서와 남겨 둔
/// 카드의 정체는 클라이언트에 없으므로 섞기 결과는 연출일 뿐입니다.
class TruthLieShuffleAnimation extends StatefulWidget {
  const TruthLieShuffleAnimation({
    super.key,
    required this.truthCardCount,
    required this.lieCardCount,
    required this.cardWidth,
    required this.cardRadius,
    this.play = true,
    this.onCompleted,
  });

  final int truthCardCount;
  final int lieCardCount;

  /// [CardDealAnimation]에 넘기는 값과 같아야 분배로 끊김 없이 이어집니다.
  final double cardWidth;
  final double cardRadius;

  /// false인 동안에는 덱만 중앙에 놓아 두고 ROUND 안내가 끝나기를 기다립니다.
  final bool play;

  final VoidCallback? onCompleted;

  @override
  State<TruthLieShuffleAnimation> createState() =>
      _TruthLieShuffleAnimationState();
}

class _TruthLieShuffleAnimationState extends State<TruthLieShuffleAnimation>
    with TickerProviderStateMixin {
  static const _entryDuration = Duration(milliseconds: 620);
  static const _shuffleDuration = Duration(milliseconds: 4600);

  static const _passCount = 3;
  static const _passSpread = [.66, .58, .5];

  // 전체 진행도에서 각 구간이 차지하는 위치입니다.
  static const _dealOutEnd = .14;
  static const _flipInStart = .045;
  static const _flipOutStart = .413;
  static const _flipLength = .05;
  static const _gatherStart = .49;
  static const _shuffleStart = .6;
  static const _shuffleEnd = .975;

  // 줄 배치 치수입니다. 6인 게임(한 줄 최대 18장)도 한 줄에 들어가게 줄입니다.
  static const _maxRowCardWidth = 104.0;
  static const _rowSidePadding = 56.0;
  static const _rowCardGap = 10.0;
  static const _rowGap = 24.0;
  static const _rowVerticalPadding = 110.0;

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
    _entry = AnimationController(vsync: this, duration: _entryDuration)
      ..addStatusListener(_onEntryStatus)
      ..forward();
    _shuffle = AnimationController(vsync: this, duration: _shuffleDuration)
      ..addStatusListener(_onShuffleStatus);
    _animation = Listenable.merge([_entry, _shuffle]);
  }

  @override
  void didUpdateWidget(TruthLieShuffleAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  bool get _hasDeck => widget.truthCardCount + widget.lieCardCount > 0;

  int get _cardCount => _hasDeck
      ? widget.truthCardCount + widget.lieCardCount
      : _fallbackCardCount;

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
          builder: (context, _) => _buildScene(size, cardWidth),
        );
      },
    );
  }

  Widget _buildScene(Size size, double cardWidth) {
    final progress = _shuffle.value;
    final cardHeight = cardWidth * liarsCardAspectRatio;
    final poses = [
      for (var card = 0; card < _cardCount; card++)
        _poseOf(card, progress, size, cardWidth),
    ]..sort((a, b) => a.paintOrder.compareTo(b.paintOrder));
    final center = size.center(Offset.zero);
    final entryDrop =
        (size.height / 2 + cardHeight) *
        (1 - Curves.easeOutCubic.transform(_entry.value));
    final labelOpacity =
        intervalProgress(progress, .06, .15) *
        (1 - intervalProgress(progress, .42, .5));

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        for (final pose in poses)
          Positioned(
            key: ValueKey(pose.card),
            left: center.dx + pose.offset.dx - cardWidth / 2,
            top: center.dy + pose.offset.dy - entryDrop - cardHeight / 2,
            width: cardWidth,
            height: cardHeight,
            child: ExcludeSemantics(
              child: Transform.rotate(
                angle: pose.angle,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(
                    pose.scaleX * pose.scale,
                    pose.scale,
                    1,
                  ),
                  child: _buildCard(pose.face),
                ),
              ),
            ),
          ),
        Positioned(
          top: 42,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: labelOpacity,
            child: Text(
              GameLocale.select(
                ko: '이번 판 카드 구성',
                en: 'ROUND DECK',
                zhHans: '本局牌组',
                zhHant: '本局牌組',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
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

  _CardPose _poseOf(int card, double progress, Size size, double cardWidth) {
    if (progress >= _shuffleStart) {
      return _shufflePose(card, progress, cardWidth);
    }

    // 맨 위 카드(진실 줄 첫 장)부터 차례로 깔고, 맨 아래 카드부터 다시 모읍니다.
    final sequence = _cardCount <= 1 ? 0.0 : card / (_cardCount - 1);
    final dealOutStart = .09 * sequence;
    final dealOut = _hasDeck
        ? intervalProgress(
            progress,
            dealOutStart,
            dealOutStart + (_dealOutEnd - .09),
            Curves.easeOutCubic,
          )
        : 0.0;
    final gatherStart = _gatherStart + .06 * (1 - sequence);
    final gather = intervalProgress(
      progress,
      gatherStart,
      math.min(gatherStart + .05, _shuffleStart),
      Curves.easeInOutCubic,
    );
    final spread = dealOut * (1 - gather);

    final flipInStart = _flipInStart + .1 * sequence;
    final flipIn = intervalProgress(
      progress,
      flipInStart,
      flipInStart + _flipLength,
      Curves.easeInOut,
    );
    final flipOutStart = _flipOutStart + .05 * sequence;
    final flipOut = intervalProgress(
      progress,
      flipOutStart,
      flipOutStart + _flipLength,
      Curves.easeInOut,
    );
    final turned = _hasDeck ? flipIn - flipOut : 0.0;

    final rowCardWidth = _rowCardWidth(size, cardWidth);
    final slot = _rowSlot(card, rowCardWidth);
    final pile = Offset(0, _pileY(card));

    final LiarsCardFace face;
    if (turned <= .5) {
      face = LiarsCardFace.back;
    } else {
      face = card < widget.truthCardCount
          ? LiarsCardFace.truth
          : LiarsCardFace.lie;
    }

    return _CardPose(
      card: card,
      paintOrder: -card.toDouble(),
      offset: Offset.lerp(pile, slot, spread)!,
      // 손으로 놓은 느낌만 나도록 카드마다 정해진 만큼 살짝 기울입니다.
      angle: math.sin(card * 2.4 + 1) * .035 * spread,
      scaleX: math.cos(math.pi * turned).abs(),
      scale:
          (1 + (rowCardWidth / cardWidth - 1) * spread) *
          (1 + .06 * math.sin(math.pi * turned)),
      face: face,
    );
  }

  double _rowCardWidth(Size size, double cardWidth) {
    final longestRow = math.max(
      math.max(widget.truthCardCount, widget.lieCardCount),
      1,
    );
    final byWidth =
        (size.width - _rowSidePadding * 2 - _rowCardGap * (longestRow - 1)) /
        longestRow;
    final byHeight =
        (size.height - _rowVerticalPadding * 2 - _rowGap) /
        (2 * liarsCardAspectRatio);
    return math.min(
      cardWidth,
      math.min(_maxRowCardWidth, math.min(byWidth, byHeight)),
    );
  }

  /// 화면 중앙 기준의 줄 위치입니다. 윗줄이 진실, 아랫줄이 거짓입니다.
  Offset _rowSlot(int card, double rowCardWidth) {
    final truthCount = widget.truthCardCount;
    final lieCount = widget.lieCardCount;
    final isTruth = card < truthCount;
    final rowIndex = isTruth ? card : card - truthCount;
    final rowLength = isTruth ? truthCount : lieCount;
    final hasBothRows = truthCount > 0 && lieCount > 0;
    final rowOffset = (rowCardWidth * liarsCardAspectRatio + _rowGap) / 2;
    return Offset(
      (rowIndex - (rowLength - 1) / 2) * (rowCardWidth + _rowCardGap),
      (hasBothRows ? (isTruth ? -rowOffset : rowOffset) : 0) +
          math.sin(card * 1.7) * 3,
    );
  }

  _CardPose _shufflePose(int card, double progress, double cardWidth) {
    final overall = intervalProgress(progress, _shuffleStart, _shuffleEnd);
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
      face: LiarsCardFace.back,
    );
  }

  Widget _buildCard(LiarsCardFace face) => RepaintBoundary(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF252027),
        borderRadius: BorderRadius.circular(widget.cardRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: LiarsPokerCardView(face: face, rounded: true),
    ),
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
    required this.face,
  });

  final int card;

  /// 값이 클수록 위에 그려집니다.
  final double paintOrder;
  final Offset offset;
  final double angle;
  final double scaleX;
  final double scale;
  final LiarsCardFace face;
}
