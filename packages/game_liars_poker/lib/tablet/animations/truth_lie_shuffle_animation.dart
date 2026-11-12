// [truth_lie_shuffle_animation.dart] 카드를 나눠 주기 직전에 이번 판의 진실 카드를
// 앞면으로 전시하고 덱을 섞는 라이어스 태블릿 연출이다.
//
// 동작은 game_kit의 [DeckShowcaseShuffleAnimation]이 맡고, 이 파일은 라이어스
// 카드 그림·전시 구성·머무는 시간만 정한다. 진실 카드만 세기 쉽게 여러 줄
// (한 줄 최대 6장)로 크게 세워 보여 준 뒤, 거짓 카드가 양옆에서 빠르게 들어와
// 함께 뒷면으로 뒤집혀 섞인다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/tablet/animations/deck_showcase_shuffle_animation.dart';
import 'package:game_liars_poker/shared/widgets/card_face_view.dart';

// ============================================================

class TruthLieShuffleAnimation extends StatelessWidget {
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

  /// 진실 카드를 모두 뒤집은 뒤 그대로 보여 주는 시간입니다.
  static const showcaseHold = Duration(milliseconds: 1800);

  /// 덱 등장 뒤 전시·섞기가 끝날 때까지의 시간입니다.
  static Duration get shuffleDuration =>
      DeckShowcaseShuffleAnimation.shuffleDurationFor(showcaseHold);

  @override
  Widget build(BuildContext context) => DeckShowcaseShuffleAnimation(
    rowCounts: DeckShowcaseShuffleAnimation.balancedRows(truthCardCount),
    hiddenCardCount: lieCardCount,
    hiddenFaceBuilder: (context, index) =>
        const LiarsPokerCardView(face: LiarsCardFace.lie, rounded: true),
    faceBuilder: (context, row, index) =>
        const LiarsPokerCardView(face: LiarsCardFace.truth, rounded: true),
    backBuilder: (context) =>
        const LiarsPokerCardView(face: LiarsCardFace.back, rounded: true),
    cardWidth: cardWidth,
    cardAspectRatio: liarsCardAspectRatio,
    cardRadius: cardRadius,
    cardColor: const Color(0xFF252027),
    title: GameLocale.select(
      ko: '이번 판 진실 카드',
      en: 'TRUTH CARDS THIS ROUND',
      zhHans: '本局真话牌',
      zhHant: '本局真話牌',
    ),
    showcaseHold: showcaseHold,
    play: play,
    onCompleted: onCompleted,
  );
}
