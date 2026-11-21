part of '../tablet_board.dart';

// ============================================================================
// 포카드 CALL 정산 연출
// ============================================================================
//
// 같은 숫자 4장으로 CALL하면 서버는 다른 사람의 마지막 교체·최종 제출 없이
// 바로 정산합니다(roundResult.callerFourOfAKind == true). 그래서 평소처럼
// 모두의 패를 한 명씩 열어 비교하는 대신, 선언자의 네 장만 가운데에 펼치고
// 상대팀 전원의 하트를 한꺼번에 깨뜨린 뒤 다음 라운드로 넘어갑니다.
//
// 시간표(ms)
//   0      흰 번쩍 + 화면 흔들림, 금빛 빛살이 퍼짐
//   250    FOUR CARD CALL! 글자가 튀어나옴
//   700    선언자 자리에서 네 장이 가운데로 날아옴(장마다 140ms 간격)
//   1300   한 장씩 앞면으로 뒤집힘
//   2150   "7 × 4 · 포카드" 꼬리표
//   2350   "사라 포카드 CALL · 상대 팀 전원 하트 -1" 안내(한 줄)
//   2600   상대팀 하트가 깨짐(1500ms), 같은 팀은 '안전'
//   5600   끝 → 다음 라운드(또는 결과 화면)

const int _fourCardTotalMs = 5600;
const double _fourCardTitleStart = 250;
const double _fourCardFlyStart = 700;
const double _fourCardFlyMs = 650;
const double _fourCardStagger = 140;
const double _fourCardFlipStart = 1300;
const double _fourCardFlipMs = 420;
const double _fourCardComboStart = 2150;
const double _fourCardBannerStart = 2350;
const double _fourCardHeartStart = 2600;
const double _fourCardHeartMs = 1500;
const double _fourCardFadeOutStart = 5000;

class _FourCardRevealTable extends StatefulWidget {
  const _FourCardRevealTable({
    super.key,
    required this.controller,
    required this.result,
    required this.onCompleted,
  });

  final FinalCallController controller;
  final FinalCallRoundResult result;
  final VoidCallback onCompleted;

  @override
  State<_FourCardRevealTable> createState() => _FourCardRevealTableState();
}

class _FourCardRevealTableState extends State<_FourCardRevealTable> {
  static const double _heartShatterProgress = 0.22;
  final _heartbreakCue = ProgressSoundCue();

  double _phase(double elapsed, double start, double duration) =>
      ((elapsed - start) / duration).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final result = widget.result;
    final callerUid = result.callerUid;
    final caller = callerUid == null ? null : controller.players[callerUid];
    final cards = callerUid == null
        ? const <FinalCallCard>[]
        : result.revealedHands[callerUid] ?? const <FinalCallCard>[];
    final players = controller.players.values.toList(growable: false)
      ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.biggest;
        final scale = finalCallTabletScale(boardSize);
        final center = boardSize.center(Offset.zero);
        final centers = finalCallSeatCenters(
          playerCount: players.length,
          boardSize: boardSize,
        );
        final cardWidth = (104 * scale).clamp(72.0, 132.0).toDouble();
        final cardHeight = cardWidth * finalCallCardHeightRatio;
        final callerCenter = caller == null || caller.seatIndex >= centers.length
            ? center
            : centers[caller.seatIndex];

        return OneShotTimeline(
          duration: const Duration(milliseconds: _fourCardTotalMs),
          onCompleted: widget.onCompleted,
          builder: (context, progress) {
            final elapsed = progress * _fourCardTotalMs;
            final heartProgress = _phase(
              elapsed,
              _fourCardHeartStart,
              _fourCardHeartMs,
            );
            _playHeartbreakSound(context, elapsed);
            final fadeOut = 1 - _phase(elapsed, _fourCardFadeOutStart, 600);

            // 선언 순간 화면이 짧게 흔들립니다.
            final shakeT = _phase(elapsed, 120, 600);
            final shake = shakeT <= 0 || shakeT >= 1
                ? Offset.zero
                : Offset(
                    math.sin(shakeT * math.pi * 9) * 12 * (1 - shakeT) * scale,
                    math.cos(shakeT * math.pi * 7) * 6 * (1 - shakeT) * scale,
                  );

            final raysIn = Curves.easeOut.transform(_phase(elapsed, 100, 500));
            final raysSize = boardSize.shortestSide * 1.2;
            final titleT = _phase(elapsed, _fourCardTitleStart, 520);
            final comboT = Curves.easeOut.transform(
              _phase(elapsed, _fourCardComboStart, 300),
            );
            final bannerT = _phase(elapsed, _fourCardBannerStart, 420);

            return Transform.translate(
              offset: shake,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 금빛 빛살
                  Positioned(
                    left: center.dx - raysSize / 2,
                    top: center.dy - raysSize / 2,
                    width: raysSize,
                    height: raysSize,
                    child: Opacity(
                      opacity: raysIn * fadeOut * .9,
                      child: Transform.rotate(
                        angle: elapsed / 1000 * .22,
                        child: FinalCallBurstRays(size: raysSize),
                      ),
                    ),
                  ),
                  // 선언자의 네 장
                  for (var index = 0; index < cards.length; index++)
                    _buildCard(
                      card: cards[index],
                      index: index,
                      count: cards.length,
                      elapsed: elapsed,
                      center: center,
                      from: callerCenter,
                      cardWidth: cardWidth,
                      scale: scale,
                      opacity: fadeOut,
                    ),
                  // FOUR CARD CALL!
                  Positioned(
                    left: 0,
                    right: 0,
                    top: center.dy - cardHeight / 2 - 120 * scale,
                    child: Opacity(
                      opacity: (titleT * 3).clamp(0.0, 1.0) * fadeOut,
                      child: Transform.scale(
                        scale: titleT <= 0
                            ? .4
                            : .4 + .6 * Curves.elasticOut.transform(titleT),
                        child: Text(
                          FinalCallCopy.fourCardCall,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: finalCallPopText(
                            64 * scale,
                            color: FinalCallColors.yellow,
                            height: 1,
                            shadows: finalCallPopRing(3 * scale),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 7 × 4 · 포카드
                  if (cards.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: center.dy + cardHeight / 2 + 12 * scale,
                      child: Opacity(
                        opacity: comboT * fadeOut,
                        child: Center(
                          child: Transform.scale(
                            scale: scale,
                            child: FinalCallPopTag(
                              label: FinalCallCopy.fourCardCombo(
                                cards.first.value,
                              ),
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // 정산 안내
                  if (caller != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      // 아래 좌석 프로필과 겹치지 않도록 한 줄로 짧게 둡니다.
                      top: center.dy + cardHeight / 2 + 46 * scale,
                      child: Opacity(
                        opacity: (bannerT * 2).clamp(0.0, 1.0) * fadeOut,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - bannerT) * scale),
                          child: Center(
                            child: Transform.scale(
                              scale: scale,
                              child: FinalCallPopBox(
                                radius: 18,
                                borderWidth: 4,
                                shadowDepth: 5,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 6,
                                ),
                                child: Text(
                                  FinalCallCopy.fourCardSettle(caller.nickname),
                                  style: finalCallPopText(20),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // 좌석: 프로필 + 하트(상대팀은 깨짐, 같은 팀은 안전)
                  for (final player in players)
                    if (player.seatIndex < centers.length)
                      Positioned(
                        left:
                            centers[player.seatIndex].dx -
                            _FourCardSeat.size.width / 2,
                        top:
                            centers[player.seatIndex].dy -
                            _FourCardSeat.size.height / 2,
                        width: _FourCardSeat.size.width,
                        height: _FourCardSeat.size.height,
                        child: Transform.rotate(
                          angle: finalCallSeatRotationForCenter(
                            center: centers[player.seatIndex],
                            boardSize: boardSize,
                          ),
                          child: Transform.scale(
                            scale: scale,
                            child: _FourCardSeat(
                              player: player,
                              isCaller: player.uid == callerUid,
                              safe:
                                  caller != null &&
                                  player.team == caller.team &&
                                  player.uid != callerUid,
                              loss: result.lifeLosses[player.uid] ?? 0,
                              heartProgress: heartProgress,
                              tagIn: _phase(
                                elapsed,
                                _fourCardHeartStart + 120,
                                300,
                              ),
                            ),
                          ),
                        ),
                      ),
                  // 흰 번쩍
                  IgnorePointer(
                    child: ColoredBox(
                      color: Colors.white.withValues(
                        alpha: .85 * (1 - _phase(elapsed, 0, 450)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCard({
    required FinalCallCard card,
    required int index,
    required int count,
    required double elapsed,
    required Offset center,
    required Offset from,
    required double cardWidth,
    required double scale,
    required double opacity,
  }) {
    final cardHeight = cardWidth * finalCallCardHeightRatio;
    final middle = (count - 1) / 2;
    final offsetFromMiddle = index - middle;
    final target =
        center +
        Offset(
          offsetFromMiddle * cardWidth * .92,
          offsetFromMiddle.abs() * 12 * scale,
        );
    final fly = Curves.easeOutCubic.transform(
      _phase(elapsed, _fourCardFlyStart + index * _fourCardStagger, _fourCardFlyMs),
    );
    final flip = _phase(
      elapsed,
      _fourCardFlipStart + index * _fourCardStagger,
      _fourCardFlipMs,
    );
    // 네 장이 다 뒤집히면 한 번 통통 튑니다.
    final bounceT = _phase(
      elapsed,
      _fourCardFlipStart + (count - 1) * _fourCardStagger + _fourCardFlipMs +
          index * 70,
      360,
    );
    final bounce = math.sin(bounceT * math.pi) * 18 * scale;
    final position = Offset.lerp(from, target, fly)! - Offset(0, bounce);
    final rotation = offsetFromMiddle * .16 * fly + (1 - fly) * .8;
    final showFront = flip >= .5;
    final rotationY = showFront ? (flip - 1) * math.pi : flip * math.pi;
    return Positioned(
      left: position.dx - cardWidth / 2,
      top: position.dy - cardHeight / 2,
      child: Opacity(
        opacity: (fly * 4).clamp(0.0, 1.0) * opacity,
        child: Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: .55 + .45 * fly,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(rotationY),
              child: FinalCallCardView(
                card: card,
                faceDown: !showFront,
                width: cardWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _playHeartbreakSound(BuildContext context, double elapsedMs) {
    if (!widget.result.lifeLosses.values.any((loss) => loss > 0)) return;
    _heartbreakCue.maybePlay(
      context,
      FinalCallSounds.heartbreak,
      value: elapsedMs,
      threshold:
          _fourCardHeartStart +
          _fourCardHeartMs * _heartShatterProgress -
          ProgressSoundCue.lead.inMilliseconds,
    );
  }
}

/// 포카드 정산 동안 좌석에 보이는 프로필과 하트입니다.
class _FourCardSeat extends StatelessWidget {
  const _FourCardSeat({
    required this.player,
    required this.isCaller,
    required this.safe,
    required this.loss,
    required this.heartProgress,
    required this.tagIn,
  });

  /// 태블릿 배율 적용 전 논리 크기입니다.
  static const Size size = Size(160, 182);
  static const double _avatar = 84;

  final FinalCallPlayer player;
  final bool isCaller;
  final bool safe;
  final int loss;
  final double heartProgress;
  final double tagIn;

  @override
  Widget build(BuildContext context) {
    final teamColor = finalCallTeamColor(player.team);
    final losing = loss > 0;
    // 하트가 깨지는 동안 상대팀 프로필이 빨갛게 빛납니다.
    final glow = losing ? math.sin(heartProgress * math.pi) : 0.0;
    final Widget? tag = isCaller
        ? const FinalCallPopTag(
            label: 'FOUR CARD',
            color: FinalCallColors.yellow,
            textColor: FinalCallColors.ink,
            fontSize: 14,
            borderWidth: 2.5,
          )
        : safe
        ? FinalCallPopTag(
            label: FinalCallCopy.fourCardSafe,
            color: FinalCallColors.green,
            textColor: Colors.white,
            fontSize: 13,
            borderWidth: 2.5,
          )
        : losing
        ? FinalCallPopTag(
            label: '-$loss',
            color: FinalCallColors.red,
            textColor: Colors.white,
            fontSize: 15,
            borderWidth: 2.5,
          )
        : null;
    return Opacity(
      opacity: player.status == 'eliminated' && loss == 0 ? .5 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 30,
            child: tag == null
                ? null
                : Opacity(
                    opacity: isCaller ? 1.0 : tagIn,
                    child: Transform.scale(
                      scale: isCaller
                          ? 1.0
                          : .6 + .4 * Curves.easeOutBack.transform(tagIn),
                      child: FittedBox(fit: BoxFit.scaleDown, child: tag),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCaller ? FinalCallColors.yellow : Colors.transparent,
              boxShadow: [
                if (isCaller)
                  BoxShadow(
                    color: FinalCallColors.yellow.withValues(alpha: .6),
                    blurRadius: 16,
                    spreadRadius: 3,
                  ),
                if (glow > 0)
                  BoxShadow(
                    color: FinalCallColors.red.withValues(alpha: .8 * glow),
                    blurRadius: 26,
                    spreadRadius: 8 * glow,
                  ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: FinalCallColors.ink, width: 3),
              ),
              child: FinalCallPopAvatar(
                characterId: player.characterId,
                color: teamColor,
                size: _avatar,
                borderWidth: 8,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _FinalCallLifeRow(
            player: player,
            loss: loss,
            lossProgress: heartProgress,
          ),
        ],
      ),
    );
  }
}
