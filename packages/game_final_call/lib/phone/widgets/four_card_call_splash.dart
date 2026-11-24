// [four_card_call_splash.dart] 는 포카드 CALL 정산 동안 휴대폰에 띄우는 연출이다.
//
// - [Package] : 파이널콜
// - [Widget] : 포카드 CALL 알림(선언자 · 상대팀 · 같은 팀 문구가 다름)
//
// 포카드 CALL은 서버가 다른 사람의 제출 없이 바로 정산하므로, 휴대폰에는
// 최종 조합 선택 화면 대신 이 알림이 뜨고 결과는 태블릿에서 함께 봅니다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_final_call/game_copy.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/shared/widgets/card_view.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';

// ============================================================

class FinalCallFourCardCallSplash extends StatelessWidget {
  const FinalCallFourCardCallSplash({super.key, required this.controller});

  final FinalCallController controller;

  /// 지금 포카드 정산 연출을 보여 줄 때인지 판단합니다.
  ///
  /// 중간 라운드는 다음 라운드가 열릴 때까지(phase == roundResult), 마지막
  /// 라운드는 태블릿 공개 연출이 끝날 때까지 보여 줍니다.
  static bool visibleFor(FinalCallController controller) {
    final result = controller.roundResult;
    if (result == null || !result.callerFourOfAKind) return false;
    if (controller.phase == 'roundResult') return true;
    return controller.isFinished && controller.resultRevealCompletedAt == null;
  }

  @override
  Widget build(BuildContext context) {
    if (!visibleFor(controller)) return const SizedBox.shrink();
    final result = controller.roundResult!;
    final callerUid = result.callerUid;
    final caller = callerUid == null ? null : controller.players[callerUid];
    final List<FinalCallCard> cards = callerUid == null
        ? const []
        : result.revealedHands[callerUid] ?? const [];
    final isCaller = callerUid == controller.uid;
    final myLoss = result.lifeLosses[controller.uid] ?? 0;
    final message = isCaller
        ? FinalCallCopy.fourCardMine
        : myLoss > 0
        ? FinalCallCopy.fourCardLost
        : FinalCallCopy.fourCardTeamSafe;
    final messageColor = isCaller
        ? FinalCallColors.ink
        : myLoss > 0
        ? FinalCallColors.red
        : FinalCallColors.green;

    return TweenAnimationBuilder<double>(
      key: ValueKey('four-card-splash-${controller.round}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      builder: (context, t, _) {
        final enter = Curves.easeOutBack.transform((t / .45).clamp(0.0, 1.0));
        final rest = ((t - .35) / .4).clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: FinalCallColors.ink.withValues(alpha: .62 * (t * 3).clamp(0.0, 1.0)),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final raysSize = constraints.biggest.longestSide * 1.1;
                return Center(
                  child: Opacity(
                    opacity: (t * 2).clamp(0.0, 1.0) * .85,
                    child: Transform.rotate(
                      angle: t * math.pi / 6,
                      child: FinalCallBurstRays(size: raysSize),
                    ),
                  ),
                );
              },
            ),
            SafeArea(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1) FOUR CARD CALL! 글자가 튕기듯 커집니다.
                        Transform.scale(
                          scale: .4 + .6 * enter,
                          child: Text(
                            FinalCallCopy.fourCardCall,
                            style: finalCallPopText(
                              58,
                              color: FinalCallColors.yellow,
                              height: 1,
                              shadows: finalCallPopRing(3),
                            ),
                          ),
                        ),
                        if (caller != null && !isCaller) ...[
                          const SizedBox(height: 6),
                          Opacity(
                            opacity: rest,
                            child: Text(
                              FinalCallCopy.fourCardBy(caller.nickname),
                              style: finalCallPopText(
                                15,
                                color: Colors.white,
                                shadows: finalCallPopOutline(),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        // 2) 네 장이 부채꼴로 펼쳐집니다.
                        SizedBox(
                          height: 150,
                          width: 360,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              for (var index = 0; index < cards.length; index++)
                                _fanCard(
                                  card: cards[index],
                                  index: index,
                                  count: cards.length,
                                  progress: rest,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 3) 나에게 무슨 일이 일어났는지 + 태블릿 보기
                        Opacity(
                          opacity: rest,
                          child: FinalCallPopBox(
                            radius: 16,
                            borderWidth: 3,
                            shadowDepth: 4,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  message,
                                  style: finalCallPopText(18, color: messageColor),
                                ),
                                Text(
                                  '  ·  ${FinalCallCopy.lookAtTablet}',
                                  style: finalCallPopText(18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 부채꼴로 펼쳐지는 한 장입니다. 가운데에서 바깥으로 벌어집니다.
  Widget _fanCard({
    required FinalCallCard card,
    required int index,
    required int count,
    required double progress,
  }) {
    final eased = Curves.easeOutBack.transform(progress);
    final offsetFromMiddle = index - (count - 1) / 2;
    return Transform.translate(
      offset: Offset(
        offsetFromMiddle * 78 * eased,
        offsetFromMiddle.abs() * 10 * eased + 30 * (1 - progress),
      ),
      child: Transform.rotate(
        angle: offsetFromMiddle * .2 * eased,
        child: Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: FinalCallCardView(card: card, width: 92),
        ),
      ),
    );
  }
}
