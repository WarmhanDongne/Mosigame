// [preview.dart] 는 로비 게임 상세의 '플레이 미리보기'와 '구성품' 판을 그리는 파일이다.
//
// - [Package] : 러시안 룰렛
// - [Widget] : 10초 반복 연출(선택 → 차례로 공개 → 한 칸씩 회전 → 발포·막아냄),
//              구성품(리볼버 1정 · 방패 1인 1개 · 행동 카드 1인 3장)과 세 줄 규칙
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_russian_roulette/src/stage.dart';
import 'package:game_russian_roulette/src/theme.dart';
import 'package:game_russian_roulette/src/timing.dart';
import 'package:game_russian_roulette/src/widgets.dart';
import 'package:game_russian_roulette/src/view.dart';

//=======================플레이 미리보기==============================
class RoulettePlayPreview extends StatefulWidget {
  const RoulettePlayPreview({super.key});

  @override
  State<RoulettePlayPreview> createState() => _RoulettePlayPreviewState();
}

class _RoulettePlayPreviewState extends State<RoulettePlayPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => RouletteStage(
      model: roulettePreviewModel((_controller.value * 10000).round()),
    ),
  );
}

const _previewFaces = ['frog', 'cat', 'bear', 'bee', 'whale', 'penguin'];

/// 자리 0~5 중 2번은 이미 탈락, 3번은 방패 잠김, 4번이 첫 총구 대상입니다.
/// 공개 순서 4(방패) 5(돌리기) 0(돌리기) 1(방패) 3(돌리기) → 3칸 돌아 1번이
/// 방패로 막아냅니다.
const _previewActions = <int, RouletteAction>{
  4: RouletteAction.shield,
  5: RouletteAction.spin,
  0: RouletteAction.spin,
  1: RouletteAction.shield,
  3: RouletteAction.spin,
};
const _revealOrder = [4, 5, 0, 1, 3];
const _path = [4, 5, 0, 1];

RouletteStageModel roulettePreviewModel(int ms) {
  double theta(int i) => RouletteStageGeometry.seatAngle(i, 6);
  double aim(int i) => RouletteStageGeometry.aimAngle(theta(i));

  // 총 각도: 시계 방향 연속 각도로 경로를 만들고 단계마다 0.55초 동안 돕니다.
  final aims = <double>[aim(_path.first)];
  for (final seat in _path.skip(1)) {
    aims.add(RouletteStageGeometry.clockwiseFrom(aims.last, aim(seat)));
  }
  const stepAt = [5200, 6000, 6800];
  var gun = aims.first;
  var done = 0;
  for (var i = 0; i < stepAt.length; i++) {
    if (ms >= stepAt[i]) {
      final t = ((ms - stepAt[i]) / 550).clamp(0.0, 1.0);
      gun =
          aims[i] +
          (aims[i + 1] - aims[i]) *
              RussianRouletteTiming.gunTurnCurve.transform(t);
      done = i + 1;
    }
  }

  const revealStart = 1600;
  const revealStep = 700;
  final selecting = ms < 1400;
  final revealing = ms >= 1400 && ms < 5000;
  final shownCount = revealing
      ? ((ms - revealStart) ~/ revealStep + 1).clamp(0, 5)
      : (selecting ? 0 : 5);
  final outcome = ms >= 8200;
  final outcomeMs = ms - 8200;

  RouletteSeatModel seat(int i) {
    if (i == 2) {
      return RouletteSeatModel(
        key: '$i',
        characterId: _previewFaces[i],
        theta: theta(i),
        state: RouletteSeatState.out,
      );
    }
    final order = _revealOrder.indexOf(i);
    final shown = order >= 0 && order < shownCount;
    final action = _previewActions[i];
    var state = RouletteSeatState.waiting;
    if (selecting) {
      state = i == 4
          ? RouletteSeatState.target
          : (i == 3 ? RouletteSeatState.locked : RouletteSeatState.waiting);
    } else if (!shown) {
      state = RouletteSeatState.hidden;
    } else {
      state = switch (action) {
        RouletteAction.spin => RouletteSeatState.spin,
        RouletteAction.shield => RouletteSeatState.shield,
        _ => RouletteSeatState.none,
      };
    }
    if (outcome && i == 1) state = RouletteSeatState.blocked;
    final revealMs = ms - revealStart - order * revealStep;
    final spinBadge = switch (i) {
      5 => 1,
      0 => 2,
      3 => 3,
      _ => null,
    };
    return RouletteSeatModel(
      key: '$i',
      characterId: _previewFaces[i],
      theta: theta(i),
      state: state,
      flip: revealing && shown ? (revealMs / 260).clamp(0.0, 1.0) : 1.0,
      shield: shown && action == RouletteAction.shield
          ? (revealing ? ((revealMs - 120) / 360).clamp(0.0, 1.0) : 1.0)
          : 0.0,
      shieldHit: outcome && i == 1,
      badge: ms >= 5000 && ms < 9800 && spinBadge != null ? '$spinBadge' : null,
      badgeOn: spinBadge != null && done >= spinBadge,
    );
  }

  final t = (outcomeMs / 500).clamp(0.0, 1.0);
  final strength = 1 - t;
  String? label;
  String? tag;
  if (revealing) {
    label = rouletteText('공개', 'Reveal', '公开', '公開');
    tag = '$shownCount / 5';
  } else if (ms >= 5000 && ms < 7600) {
    label = rouletteText('회전', 'Spin', '转动', '轉動');
    tag = '$done / 3';
  } else if (ms >= 7600) {
    label = rouletteText('발포', 'Fire', '开枪', '開槍');
    tag = rouletteText('3칸', '3 steps', '3格', '3格');
  }
  return RouletteStageModel(
    seats: [for (var i = 0; i < 6; i++) seat(i)],
    gunAim: gun,
    wedgeOpacity: revealing ? .35 : 1,
    secondWedge: !revealing,
    timerFraction: selecting ? 1 - ms / 1400 * .6 : null,
    trailFrom: ms >= 5000 && ms < 9800 ? aims.first : null,
    trailTo: done == 0 ? null : aims[done],
    stepMarks: ms >= 5000 && ms < 9800 ? aims.sublist(1, done + 1) : const [],
    label: label,
    labelTag: tag,
    shot: outcome && outcomeMs < 700,
    shake: outcome
        ? Offset(
            math.sin(t * math.pi * 6) * 9 * strength,
            math.cos(t * math.pi * 5) * 5 * strength,
          )
        : Offset.zero,
    stamp: outcome
        ? RouletteStampModel(
            theta: theta(1),
            blocked: true,
            progress: (outcomeMs / 420).clamp(0.0, 1.0),
          )
        : null,
  );
}

//=======================구성품==============================
class RoulettePartsBoard extends StatelessWidget {
  const RoulettePartsBoard({super.key});

  static const _navy = Color(0xFF0E0A3D);
  static const _navySub = Color(0xFF55527A);

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: RouletteColors.ink,
    child: FittedBox(
      child: SizedBox(
        width: 960,
        height: 680,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                flex: 11,
                child: _Panel(
                  title: rouletteText('구성품', 'CONTENTS', '配件', '配件'),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PartCell(
                          label: rouletteText('리볼버', 'Revolver', '左轮手枪', '左輪手槍'),
                          count: rouletteText('1정', '×1', '1把', '1把'),
                          child: Container(
                            width: 240,
                            height: 240,
                            decoration: _cardDecoration(RouletteColors.ink, 14),
                            alignment: Alignment.center,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: const BoxDecoration(
                                color: RouletteColors.red,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const RouletteRevolver(
                                size: 200,
                                angle: -math.pi / 6,
                                disc: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const _Divider(),
                      Expanded(
                        child: _PartCell(
                          label: rouletteText('방패', 'Shield', '护盾', '護盾'),
                          count: rouletteText('1인 1개', '1 each', '每人1个', '每人1個'),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RouletteShield(size: 114),
                              SizedBox(height: 18),
                              RouletteShieldTop(width: 150, shadowOpacity: .15),
                            ],
                          ),
                        ),
                      ),
                      const _Divider(),
                      Expanded(
                        child: _PartCell(
                          label: rouletteText('행동 카드', 'Action cards', '行动卡', '行動卡'),
                          count: rouletteText('1인 3장', '3 each', '每人3张', '每人3張'),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              RouletteActionCard(action: RouletteAction.spin, tilt: -8),
                              SizedBox(width: 4),
                              RouletteActionCard(action: RouletteAction.shield, tilt: 0),
                              SizedBox(width: 4),
                              RouletteActionCard(action: RouletteAction.none, tilt: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                flex: 5,
                child: _Panel(
                  title: rouletteText('이렇게 해요', 'HOW TO PLAY', '玩法', '玩法'),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Step(
                        number: 1,
                        title: rouletteText('몰래 고르기', 'Choose secretly', '秘密选择', '秘密選擇'),
                        body: rouletteText(
                          '돌리기·방패·아무것도 안 하기 중 하나를 동시에 골라요. 방패는 두 턴 연속 못 써요.',
                          'Everyone picks Spin, Shield or Do nothing at once. No shield two turns in a row.',
                          '所有人同时选择转动、护盾或什么都不做。护盾不能连续两回合使用。',
                          '所有人同時選擇轉動、護盾或什麼都不做。護盾不能連續兩回合使用。',
                        ),
                      ),
                      const SizedBox(width: 16),
                      _Step(
                        number: 2,
                        title: rouletteText('공개하고 돌리기', 'Reveal and spin', '公开并转动', '公開並轉動'),
                        body: rouletteText(
                          '총구 대상부터 차례로 공개하고, 돌린 사람 수만큼 총구가 한 칸씩 돌아요.',
                          'Reveal from the target, then the gun turns one seat per Spin.',
                          '从枪口对象开始依次公开，枪口按转动人数逐格转动。',
                          '從槍口對象開始依次公開，槍口按轉動人數逐格轉動。',
                        ),
                      ),
                      const SizedBox(width: 16),
                      _Step(
                        number: 3,
                        title: rouletteText('발포', 'Fire', '开枪', '開槍'),
                        body: rouletteText(
                          '멈춘 자리에 발포! 방패면 막고, 아니면 탈락. 최후의 1인이 이겨요.',
                          'Fire at the stop. A shield blocks it, otherwise out. Last one standing wins.',
                          '向停下的位置开枪！有护盾则挡住，否则淘汰。最后一人获胜。',
                          '向停下的位置開槍！有護盾則擋住，否則淘汰。最後一人獲勝。',
                        ),
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
  );

  static BoxDecoration _cardDecoration(Color color, double radius) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFF111111), width: 3),
    boxShadow: const [
      BoxShadow(color: RouletteColors.shadow, offset: Offset(5, 5)),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
    decoration: RoulettePartsBoard._cardDecoration(RouletteColors.paperLight, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: MosiFonts.sans(
            size: 13,
            weight: FontWeight.w700,
            color: RoulettePartsBoard._navySub,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: child),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
    width: 2,
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    color: const Color(0xFFE6E1D3),
  );
}

class _PartCell extends StatelessWidget {
  const _PartCell({required this.label, required this.count, required this.child});
  final String label;
  final String count;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: Center(child: FittedBox(child: child))),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: MosiFonts.sans(
              size: 15,
              weight: FontWeight.w700,
              color: RoulettePartsBoard._navy,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: RoulettePartsBoard._navy,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF111111), width: 2),
            ),
            child: Text(
              count,
              style: MosiFonts.grotesk(size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    ],
  );
}

/// 돌리기·방패·아무것도 안 하기 행동 카드 한 장입니다. 로비 구성품에서도 씁니다.
class RouletteActionCard extends StatelessWidget {
  const RouletteActionCard({super.key, required this.action, this.tilt = 0});
  final RouletteAction action;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (action) {
      RouletteAction.spin => (RouletteColors.red, RouletteColors.cream),
      RouletteAction.shield => (RouletteColors.cream, RouletteColors.ink),
      RouletteAction.none => (RouletteColors.ink, RouletteColors.cream),
    };
    final label = switch (action) {
      RouletteAction.spin => rouletteText('돌리기', 'Spin', '转动', '轉動'),
      RouletteAction.shield => rouletteText('방패', 'Shield', '护盾', '護盾'),
      RouletteAction.none => rouletteText('아무것도\n안 하기', 'Do\nnothing', '什么\n都不做', '什麼\n都不做'),
    };
    return Transform.rotate(
      angle: tilt * math.pi / 180,
      child: Container(
        width: 80,
        height: 122,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: RouletteColors.ink, width: 3),
          boxShadow: const [
            BoxShadow(color: RouletteColors.shadow, offset: Offset(4, 5)),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: action == RouletteAction.none
              ? BoxDecoration(
                  border: Border.all(color: RouletteColors.cream, width: 2),
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(rouletteActionIcon(action), color: fg, size: 34),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: RouletteType.display(
                  action == RouletteAction.none ? 14 : 18,
                  fg,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body});
  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: RouletteColors.red,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF111111), width: 2),
          ),
          child: Text(
            '$number',
            style: MosiFonts.grotesk(size: 14, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: MosiFonts.sans(
                  size: 17,
                  weight: FontWeight.w700,
                  color: RoulettePartsBoard._navy,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: MosiFonts.sans(
                  size: 14,
                  color: RoulettePartsBoard._navy,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
