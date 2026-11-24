// [stage.dart] 는 러시안 룰렛 태블릿 판(B안)을 그리는 파일이다.
//
// - [Package] : 러시안 룰렛
// - [Widget] : 자리표, 조준 빔, 실린더 원판과 위에서 본 총, 세워 둔 방패, 도장
//
// 태블릿 게임 화면과 로비 상세의 플레이 미리보기가 같은 판을 씁니다.
// 시안 크기(1180×820) 좌표를 그대로 쓰고, 화면에는 비율을 유지해 맞춥니다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_russian_roulette/src/theme.dart';
import 'package:game_russian_roulette/src/timing.dart';
import 'package:game_russian_roulette/src/widgets.dart';

abstract final class RouletteStageGeometry {
  static const width = 1180.0;
  static const height = 820.0;
  static const center = Offset(590, 410);
  static const rx = width * defaultPlayerRingRadiusX;
  static const ry = height * defaultPlayerRingRadiusY;

  /// 자리 배치 화면과 같은 좌석 중심을 가리키는 타원 각도입니다.
  ///
  /// 특히 2명은 좌우, 4명은 대각선에서 시작하는 공통 규칙까지 그대로
  /// 따라야 프로필과 총구의 조준 위치가 진입 화면에서 게임 안으로 이어집니다.
  static double seatAngle(int seatIndex, int count, {SeatLayoutMode? mode}) {
    final normalized = normalizedSeatCenters(
      math.max(1, count),
      mode: mode,
    )[seatIndex];
    return math.atan2(
      (normalized.dy - .5) / defaultPlayerRingRadiusY,
      (normalized.dx - .5) / defaultPlayerRingRadiusX,
    );
  }

  /// 자리 배치 화면에서 선택한 형태의 좌석 중심을 게임 판 좌표로 옮깁니다.
  static Offset seatCenter(int seatIndex, int count, {SeatLayoutMode? mode}) {
    final normalized = normalizedSeatCenters(
      math.max(1, count),
      mode: mode,
    )[seatIndex];
    return Offset(normalized.dx * width, normalized.dy * height);
  }

  static Offset onEllipse(double theta, [double rx = rx, double ry = ry]) =>
      center + Offset(rx * math.cos(theta), ry * math.sin(theta));

  /// 자리 중심을 향하는 조준 방향(라디안)입니다.
  static double aimAngle(double theta) {
    final p = onEllipse(theta) - center;
    return math.atan2(p.dy, p.dx);
  }

  /// 중앙에서 [aim] 방향으로 뻗은 선이 타원과 만나는 점입니다.
  static Offset alongAim(double aim, double rx, double ry) {
    final c = math.cos(aim);
    final s = math.sin(aim);
    final r = 1 / math.sqrt(c * c / (rx * rx) + s * s / (ry * ry));
    return center + Offset(c * r, s * r);
  }

  /// [from]에서 시계 방향으로 [to]까지 가는 연속 각도로 바꿉니다.
  static double clockwiseFrom(double from, double to) {
    var value = to;
    while (value < from - 1e-6) {
      value += math.pi * 2;
    }
    while (value - from >= math.pi * 2 - 1e-6) {
      value -= math.pi * 2;
    }
    return value;
  }
}

/// 자리표 오른쪽 칸에 무엇을 보일지입니다.
enum RouletteSeatState {
  waiting,
  locked,
  target,
  hidden,
  spin,
  shield,
  none,
  blocked,
  dead,
  out,
  rank,
}

@immutable
class RouletteSeatModel {
  const RouletteSeatModel({
    required this.key,
    required this.characterId,
    required this.theta,
    required this.state,
    this.center,
    this.rank,
    this.shield = 0,
    this.shieldHit = false,
    this.badge,
    this.badgeOn = false,
    this.flip = 1,
    this.dim = false,
    this.glow = 1,
    this.hitMs,
  });

  /// 총에 맞은 자리라면 발포 뒤 흐른 시간(ms)입니다. 맞음 연출에 씁니다.
  final int? hitMs;

  final String key;
  final String characterId;
  final double theta;
  final Offset? center;
  final RouletteSeatState state;
  final int? rank;

  /// 세워 둔 방패가 나타난 정도(0이면 없음, 1이면 다 섬)입니다.
  final double shield;
  final bool shieldHit;

  /// 프로필 왼쪽 위 원형 번호(회전 순서)입니다.
  final String? badge;
  final bool badgeOn;

  /// 공개 카드가 뒤집히는 정도(0 → 1)입니다.
  final double flip;

  /// 게임 시작 연출에서 아직 불이 안 들어온 자리입니다.
  final bool dim;

  /// 불이 들어오는 진행(0 → 1). 0.3 근처에서 붉게 번쩍입니다.
  final double glow;
}

@immutable
class RouletteStampModel {
  const RouletteStampModel({
    required this.theta,
    required this.blocked,
    this.center,
    this.progress = 1,
  });
  final double theta;
  final Offset? center;
  final bool blocked;
  final double progress;
}

@immutable
class RouletteStageModel {
  const RouletteStageModel({
    required this.seats,
    required this.gunAim,
    this.wedgeOpacity = 1,
    this.secondWedge = true,
    this.shot = false,
    this.trailFrom,
    this.trailTo,
    this.stepMarks = const [],
    this.timerFraction,
    this.label,
    this.labelTag,
    this.stamp,
    this.shake = Offset.zero,
    this.flash,
    this.showCylinder = true,
    this.rays = false,
    this.center,
    this.cylinderReveal = 1,
    this.banner,
    this.bannerProgress = 1,
  });

  final List<RouletteSeatModel> seats;
  final double gunAim;
  final double wedgeOpacity;
  final bool secondWedge;
  final bool shot;
  final double? trailFrom;
  final double? trailTo;
  final List<double> stepMarks;
  final double? timerFraction;
  final String? label;
  final String? labelTag;
  final RouletteStampModel? stamp;
  final Offset shake;

  /// 총구 섬광의 진행(0 → 1, 0.55초)입니다. null이면 그리지 않습니다.
  final double? flash;
  final bool showCylinder;
  final bool rays;

  /// 실린더 대신 가운데에 둘 위젯(우승자 프로필)입니다.
  final Widget? center;

  /// 실린더 원판·총이 나타난 정도(0 → 1)입니다. 게임 시작 연출에 씁니다.
  final double cylinderReveal;

  /// 판 위아래로 크게 찍히는 문구(예: 게임 시작)입니다.
  final String? banner;
  final double bannerProgress;
}

/// 판 전체입니다. 주어진 공간에 1180×820 비율로 맞춰 그립니다.
class RouletteStage extends StatelessWidget {
  const RouletteStage({super.key, required this.model});
  final RouletteStageModel model;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: ColoredBox(
      color: RouletteColors.ink,
      child: Center(
        child: FittedBox(
          child: SizedBox(
            width: RouletteStageGeometry.width,
            height: RouletteStageGeometry.height,
            child: Transform.translate(
              offset: model.shake,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _StagePainter(model)),
                  ),
                  if (model.center != null)
                    Positioned(
                      left: RouletteStageGeometry.center.dx - 200,
                      top: RouletteStageGeometry.center.dy - 200,
                      width: 400,
                      height: 400,
                      child: Center(child: model.center),
                    ),
                  if (model.label != null) ..._labels(),
                  if (model.banner != null) ..._banner(),
                  for (final seat in model.seats)
                    if (seat.shield > 0) _shield(seat),
                  for (final seat in model.seats) _plate(seat),
                  if (model.stamp != null) _stamp(model.stamp!),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _labels() {
    const c = RouletteStageGeometry.center;
    Widget text() => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          model.label!,
          style: RouletteType.display(18, RouletteColors.cream),
        ),
        if (model.labelTag != null) ...[
          const SizedBox(width: 8),
          Container(
            color: RouletteColors.red,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              model.labelTag!,
              style: RouletteType.number(18, RouletteColors.cream),
            ),
          ),
        ],
      ],
    );
    Widget fade(Widget child) => AnimatedSwitcher(
      duration: RussianRouletteTiming.plateFade,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .4),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(model.label), child: child),
    );
    return [
      Positioned(
        left: c.dx - 160,
        top: c.dy + 182,
        width: 320,
        child: fade(text()),
      ),
      Positioned(
        left: c.dx - 160,
        top: c.dy - 208,
        width: 320,
        child: Transform.rotate(angle: math.pi, child: fade(text())),
      ),
    ];
  }

  Widget _shield(RouletteSeatModel seat) {
    final seatCenter =
        seat.center ?? RouletteStageGeometry.onEllipse(seat.theta);
    const c = RouletteStageGeometry.center;
    final d = (seatCenter - c).distance;
    final p = c + (seatCenter - c) * ((d - 80) / d);
    final t = seat.shield.clamp(0.0, 1.0);
    final pop = Curves.easeOutBack.transform(t);
    return Positioned(
      left: p.dx - 80,
      top: p.dy - 32,
      width: 160,
      height: 64,
      child: Transform.rotate(
        angle: seat.theta - math.pi / 2,
        child: Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, -20 * (1 - t)),
            child: Transform.translate(
              // 맞으면 바깥쪽으로 밀렸다 출렁이며 돌아옵니다(시안 shieldHit 0.5초).
              offset: Offset(
                0,
                seat.hitMs == null
                    ? 0
                    : rouletteKeys(seat.hitMs! / 500, const [
                        (0.0, 0.0),
                        (.15, 10.0),
                        (.35, -5.0),
                        (.55, 4.0),
                        (.75, -2.0),
                        (1.0, 0.0),
                      ]),
              ),
              child: Transform.scale(
                scale: .3 + .7 * pop,
                child: RouletteShieldTop(
                  hit: seat.shieldHit && (seat.hitMs ?? 999) >= 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _plate(RouletteSeatModel seat) {
    final p = seat.center ?? RouletteStageGeometry.onEllipse(seat.theta);
    return Positioned(
      key: ValueKey('seat-${seat.key}'),
      left: p.dx - 90,
      top: p.dy - 43,
      width: 180,
      height: 86,
      child: Transform.rotate(
        angle: seat.theta - math.pi / 2,
        child: Transform.translate(
          offset: Offset(
            seat.state == RouletteSeatState.dead && seat.hitMs != null
                ? rouletteKeys(seat.hitMs! / 500, const [
                    (0.0, 0.0),
                    (.2, -8.0),
                    (.4, 8.0),
                    (.6, -5.0),
                    (.8, 3.0),
                    (1.0, 0.0),
                  ])
                : 0,
            0,
          ),
          child: _lit(seat, RouletteSeatPlate(seat: seat)),
        ),
      ),
    );
  }

  /// 시작 연출: 꺼진 자리는 어둡게, 켜지는 순간 붉게 번쩍이며 살짝 커집니다.
  Widget _lit(RouletteSeatModel seat, Widget plate) {
    if (seat.dim) {
      return Opacity(
        opacity: .55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.07, 0.24, 0.02, 0, 0, //
            0.07, 0.24, 0.02, 0, 0, //
            0.07, 0.24, 0.02, 0, 0, //
            0, 0, 0, 1, 0, //
          ]),
          child: plate,
        ),
      );
    }
    final g = seat.glow.clamp(0.0, 1.0);
    if (g >= 1) return plate;
    final peak = g < .3 ? g / .3 : 1 - (g - .3) / .7;
    return Transform.scale(
      scale: .96 + .04 * (g / .3).clamp(0.0, 1.0) + .07 * peak,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: RouletteColors.red.withValues(alpha: .85 * peak),
              blurRadius: 48 * peak,
              spreadRadius: 10 * peak,
            ),
            BoxShadow(
              color: RouletteColors.red.withValues(alpha: peak),
              spreadRadius: 5 * peak,
            ),
          ],
        ),
        child: plate,
      ),
    );
  }

  List<Widget> _banner() {
    const c = RouletteStageGeometry.center;
    final t = model.bannerProgress.clamp(0.0, 1.0);
    final scale = t < .5 ? 2.4 - 2.96 * t : .92 + .16 * (t - .5);
    Widget text() => Opacity(
      opacity: (t * 2.5).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: Center(
          child: Container(
            color: RouletteColors.red,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Text(
              model.banner!,
              style: RouletteType.display(30, RouletteColors.cream),
            ),
          ),
        ),
      ),
    );
    return [
      Positioned(left: c.dx - 200, top: c.dy + 178, width: 400, child: text()),
      Positioned(
        left: c.dx - 200,
        top: c.dy - 224,
        width: 400,
        child: Transform.rotate(angle: math.pi, child: text()),
      ),
    ];
  }

  Widget _stamp(RouletteStampModel stamp) {
    const c = RouletteStageGeometry.center;
    final seatCenter =
        stamp.center ?? RouletteStageGeometry.onEllipse(stamp.theta);
    final p = c + (seatCenter - c) * (stamp.blocked ? .52 : .70);
    final t = rouletteSlam(stamp.progress);
    final scale = t < .55
        ? 2.6 + (.9 - 2.6) * (t / .55)
        : .9 + .1 * ((t - .55) / .45);
    final bg = stamp.blocked ? RouletteColors.red : RouletteColors.ink;
    final fg = stamp.blocked ? RouletteColors.cream : RouletteColors.red;
    return Positioned(
      left: p.dx - 115,
      top: p.dy - 46,
      width: 230,
      height: 92,
      child: Transform.rotate(
        angle: stamp.theta - math.pi / 2 - 8 * math.pi / 180,
        child: Opacity(
          opacity: (t / .55).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: fg, width: 4),
                boxShadow: const [
                  BoxShadow(color: Color(0xB3000000), offset: Offset(10, 10)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    stamp.blocked ? Icons.shield : Icons.close,
                    color: fg,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    stamp.blocked
                        ? rouletteText('막아냄', 'BLOCKED', '挡住', '擋住')
                        : rouletteText('탈락', 'OUT', '淘汰', '淘汰'),
                    style: RouletteType.display(42, fg, height: 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

//=======================자리표==============================
/// 180×86 자리표입니다. 프로필 80 + 상태 칸.
class RouletteSeatPlate extends StatelessWidget {
  const RouletteSeatPlate({super.key, required this.seat});
  final RouletteSeatModel seat;

  @override
  Widget build(BuildContext context) {
    final state = seat.state;
    if (state == RouletteSeatState.out) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: RouletteColors.dash),
        ),
        child: Row(
          children: [
            RouletteProfile(
              characterId: seat.characterId,
              size: 80,
              gray: true,
            ),
            Expanded(
              child: _Block(
                color: Colors.transparent,
                children: [
                  const Icon(Icons.close, color: RouletteColors.dim, size: 20),
                  _line(
                    rouletteText('탈락', 'Out', '淘汰', '淘汰'),
                    RouletteColors.dim,
                    13,
                  ),
                  _line(
                    rouletteText('건너뜀', 'Skipped', '跳过', '跳過'),
                    RouletteColors.dim,
                    11,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final dead = state == RouletteSeatState.dead;
    final grayRank = state == RouletteSeatState.rank && seat.rank != 1;
    final frame = dead ? RouletteColors.red : RouletteColors.cream;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: frame,
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), offset: Offset(8, 8)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 80,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                RouletteProfile(
                  characterId: seat.characterId,
                  size: 80,
                  gray: dead || grayRank,
                  crossed: dead,
                  // 시안처럼 0.15초 뒤 한 줄, 0.4초 뒤 둘째 줄을 긋습니다.
                  crossProgress: seat.hitMs == null
                      ? 1
                      : ((seat.hitMs! - 150) / 500).clamp(0.0, 1.0),
                ),
                if (seat.badge != null)
                  Positioned(
                    left: -12,
                    top: -12,
                    child: _Badge(text: seat.badge!, on: seat.badgeOn),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            // 상태 칸은 바뀔 때 겹쳐 사라지고 살짝 커지며 나타납니다.
            child: AnimatedSwitcher(
              duration: RussianRouletteTiming.plateFade,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, animation) {
                // 막아냄·탈락 칸은 겹침 대신 자기 등장(튀어나옴·내리꽂힘)으로 바로 나옵니다.
                final key = child.key;
                if (key is ValueKey<RouletteSeatState> &&
                    (key.value == RouletteSeatState.dead ||
                        key.value == RouletteSeatState.blocked)) {
                  return child;
                }
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: .9, end: 1.0).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(state),
                child: _hitEntry(_flipped(_right(state))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 맞은 순간의 상태 칸 등장입니다. 탈락은 크게 내리꽂히고(slam 0.4초),
  /// 막아냄은 튀어나옵니다(pop 0.45초).
  Widget _hitEntry(Widget child) {
    final ms = seat.hitMs;
    if (ms == null) return child;
    if (seat.state == RouletteSeatState.dead) {
      final t = rouletteSlam(ms / 400);
      final scale = t < .55
          ? 2.6 + (.9 - 2.6) * (t / .55)
          : .9 + .1 * ((t - .55) / .45);
      return Opacity(
        opacity: (t / .55).clamp(0.0, 1.0),
        child: Transform.scale(scale: scale, child: child),
      );
    }
    if (seat.state == RouletteSeatState.blocked) {
      final t = (ms / 450).clamp(0.0, 1.0);
      final scale = t < .65 ? .3 + (1.18 - .3) * (t / .65) : 1.18 - .18 * ((t - .65) / .35);
      return Opacity(
        opacity: (t / .65).clamp(0.0, 1.0),
        child: Transform.scale(scale: scale, child: child),
      );
    }
    return child;
  }

  Widget _flipped(Widget child) {
    if (seat.flip >= 1) return child;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .003)
        ..rotateY((1 - seat.flip) * math.pi / 2),
      child: Opacity(opacity: seat.flip.clamp(0.0, 1.0), child: child),
    );
  }

  Widget _right(RouletteSeatState state) {
    const cream = RouletteColors.cream;
    const ink = RouletteColors.ink;
    const red = RouletteColors.red;
    switch (state) {
      case RouletteSeatState.waiting:
        return _Block(
          color: cream,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in const [
                  RouletteColors.grey,
                  RouletteColors.grey,
                  Color(0xFFC9BFAD),
                ])
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: c,
                  ),
              ],
            ),
            _line(
              rouletteText('선택 중', 'Choosing', '选择中', '選擇中'),
              RouletteColors.grey,
              12,
            ),
          ],
        );
      case RouletteSeatState.locked:
        return Stack(
          children: [
            _Block(
              color: cream,
              children: [
                const Icon(Icons.remove_moderator, color: ink, size: 20),
                _line(rouletteText('잠김', 'Locked', '锁定', '鎖定'), ink, 13),
                _line(
                  rouletteText('방패 불가', 'No shield', '不能用护盾', '不能用護盾'),
                  RouletteColors.grey,
                  11,
                ),
              ],
            ),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 9,
              child: CustomPaint(painter: _StripePainter(ink)),
            ),
          ],
        );
      case RouletteSeatState.target:
        return _Block(
          color: red,
          children: [
            Text(
              rouletteText('조준', 'AIM', '瞄准', '瞄準'),
              style: RouletteType.display(20, cream, height: 1.2),
            ),
            _line(rouletteText('총구 대상', 'Target', '枪口对象', '槍口對象'), cream, 11),
          ],
        );
      case RouletteSeatState.hidden:
        return Container(
          decoration: const BoxDecoration(
            color: ink,
            border: Border(left: BorderSide(color: cream, width: 3)),
          ),
          child: _Block(
            color: Colors.transparent,
            children: [
              Text('?', style: RouletteType.display(34, cream, height: 1)),
              _line(
                rouletteText('공개 대기', 'Hidden', '待公开', '待公開'),
                RouletteColors.sub,
                11,
              ),
            ],
          ),
        );
      case RouletteSeatState.spin:
        return _Block(
          color: red,
          children: [
            const Icon(Icons.rotate_right, color: cream, size: 24),
            Text(
              rouletteText('돌리기', 'Spin', '转动', '轉動'),
              style: RouletteType.display(15, cream),
            ),
          ],
        );
      case RouletteSeatState.shield:
        return _Block(
          color: cream,
          children: [
            const Icon(Icons.shield, color: ink, size: 24),
            Text(
              rouletteText('방패', 'Shield', '护盾', '護盾'),
              style: RouletteType.display(15, ink),
            ),
          ],
        );
      case RouletteSeatState.none:
        return Container(
          decoration: BoxDecoration(
            color: ink,
            border: Border.all(color: cream, width: 1.5),
          ),
          child: _Block(
            color: Colors.transparent,
            children: [
              const Icon(Icons.remove_circle_outline, color: cream, size: 22),
              Text(
                rouletteText('안 함', 'Pass', '不行动', '不行動'),
                style: RouletteType.display(15, cream),
              ),
            ],
          ),
        );
      case RouletteSeatState.blocked:
        return _Block(
          color: red,
          children: [
            const Icon(Icons.shield, color: cream, size: 24),
            Text(
              rouletteText('막아냄', 'Blocked', '挡住', '擋住'),
              style: RouletteType.display(16, cream),
            ),
          ],
        );
      case RouletteSeatState.dead:
        return Container(
          decoration: const BoxDecoration(
            color: ink,
            border: Border(left: BorderSide(color: red, width: 3)),
          ),
          child: _Block(
            color: Colors.transparent,
            children: [
              const Icon(Icons.close, color: red, size: 26),
              Text(
                rouletteText('탈락', 'Out', '淘汰', '淘汰'),
                style: RouletteType.display(18, red),
              ),
            ],
          ),
        );
      case RouletteSeatState.rank:
        final win = seat.rank == 1;
        return _Block(
          color: win ? red : cream,
          children: [
            Text(
              seat.rank == null
                  ? '–'
                  : rouletteText(
                      '${seat.rank}위',
                      '#${seat.rank}',
                      '第${seat.rank}名',
                      '第${seat.rank}名',
                    ),
              style: RouletteType.display(26, win ? cream : ink, height: 1.1),
            ),
            _line(
              win
                  ? rouletteText('최후의 1인', 'Last one', '最后一人', '最後一人')
                  : rouletteText('탈락', 'Out', '淘汰', '淘汰'),
              win ? cream : RouletteColors.grey,
              11,
            ),
          ],
        );
      case RouletteSeatState.out:
        return const SizedBox.shrink();
    }
  }

  static Widget _line(String text, Color color, double size) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: RouletteType.body(size, color, weight: FontWeight.w700, height: 1.2),
  );
}

class _Block extends StatelessWidget {
  const _Block({required this.color, required this.children});
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    color: color,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          children[i],
        ],
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.on});
  final String text;
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: on ? RouletteColors.red : RouletteColors.ink,
      border: Border.all(
        color: on ? RouletteColors.cream : RouletteColors.grey,
        width: 2,
      ),
    ),
    child: Text(
      text,
      style: RouletteType.number(
        14,
        on ? RouletteColors.cream : RouletteColors.sub,
      ),
    ),
  );
}

class _StripePainter extends CustomPainter {
  const _StripePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final p = Paint()
      ..color = color
      ..strokeWidth = 3.5;
    for (var x = -size.height; x < size.width + size.height; x += 10) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter old) => old.color != color;
}

//=======================바닥 그림==============================
class _StagePainter extends CustomPainter {
  const _StagePainter(this.model);
  final RouletteStageModel model;

  @override
  void paint(Canvas canvas, Size size) {
    const c = RouletteStageGeometry.center;
    final red = Paint()..color = RouletteColors.red;

    if (model.rays) {
      for (var i = 0; i < 12; i++) {
        final a = -math.pi / 2 + i * math.pi / 6;
        _wedge(
          canvas,
          a,
          5 * math.pi / 180,
          Paint()
            ..color = RouletteColors.red.withValues(alpha: i.isEven ? .9 : .45),
        );
      }
      canvas.drawCircle(c, 170, Paint()..color = RouletteColors.ink);
    }

    if (model.showCylinder && model.wedgeOpacity > 0) {
      _wedge(
        canvas,
        model.gunAim,
        11 * math.pi / 180,
        Paint()
          ..color = RouletteColors.red.withValues(alpha: model.wedgeOpacity),
      );
      if (model.secondWedge) {
        final path = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(
            c.dx + math.cos(model.gunAim + 15 * math.pi / 180) * 1100,
            c.dy + math.sin(model.gunAim + 15 * math.pi / 180) * 1100,
          )
          ..lineTo(
            c.dx + math.cos(model.gunAim + 17 * math.pi / 180) * 1100,
            c.dy + math.sin(model.gunAim + 17 * math.pi / 180) * 1100,
          )
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = RouletteColors.red.withValues(
              alpha: .55 * model.wedgeOpacity,
            ),
        );
      }
    }

    final from = model.trailFrom;
    final to = model.trailTo;
    if (from != null && to != null && to > from) {
      const rx = RouletteStageGeometry.rx - 150;
      const ry = RouletteStageGeometry.ry - 120;
      for (var a = from + .28; a <= to - .1; a += .12) {
        canvas.drawCircle(RouletteStageGeometry.alongAim(a, rx, ry), 3.5, red);
      }
      for (final mark in model.stepMarks) {
        final p = RouletteStageGeometry.alongAim(mark, rx, ry);
        canvas.drawCircle(p, 9, Paint()..color = RouletteColors.ink);
        canvas.drawCircle(
          p,
          9,
          Paint()
            ..color = RouletteColors.red
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }

    if (!model.showCylinder || model.cylinderReveal <= 0) return;
    final reveal = model.cylinderReveal.clamp(0.0, 1.0);
    if (reveal < 1) {
      canvas.saveLayer(
        null,
        Paint()
          ..color = Colors.black.withValues(
            alpha: (reveal * 1.8).clamp(0.0, 1.0),
          ),
      );
      final discScale = .85 + .15 * Curves.easeOutBack.transform(reveal);
      canvas.translate(c.dx, c.dy);
      canvas.scale(discScale);
      canvas.translate(-c.dx, -c.dy);
    }
    canvas.drawCircle(
      c,
      166,
      Paint()
        ..color = RouletteColors.track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    final timer = model.timerFraction;
    if (timer != null && timer > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 166),
        -math.pi / 2,
        math.pi * 2 * timer.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = timer < .2 ? RouletteColors.red : RouletteColors.cream
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10,
      );
    }
    canvas.drawCircle(c, 152, Paint()..color = RouletteColors.cream);
    canvas.drawCircle(
      c,
      140,
      Paint()
        ..color = RouletteColors.ink.withValues(alpha: .18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(model.gunAim);
    if (reveal < 1) {
      // 총은 위에서 떨어지듯 크게 나타났다가 제자리에 놓입니다.
      final t = Curves.easeOutBack.transform(reveal);
      canvas.scale((1.7 - .7 * t) / (.85 + .15 * t));
    }
    paintRouletteGun(canvas, shot: model.shot);
    final flash = model.flash;
    if (flash != null && flash >= 0 && flash < 1) _muzzleFlash(canvas, flash);
    canvas.restore();
    if (reveal < 1) canvas.restore();
  }

  /// 총구 섬광(시안 flash 0.55초): 15%에 1.25배로 터졌다가 1.7배로 퍼지며 사라집니다.
  void _muzzleFlash(Canvas canvas, double t) {
    final scale = t < .15 ? .2 + (1.25 - .2) * (t / .15) : 1.25 + (1.7 - 1.25) * ((t - .15) / .85);
    final opacity = t < .15 ? t / .15 : 1 - (t - .15) / .85;
    Path star(List<double> p) {
      final path = Path()..moveTo(p[0], p[1]);
      for (var i = 2; i < p.length; i += 2) {
        path.lineTo(p[i], p[i + 1]);
      }
      return path..close();
    }

    canvas.save();
    // 총은 +x를 보고, 시안의 섬광은 총구 앞 163px에 놓입니다.
    canvas.translate(163, 0);
    canvas.rotate(-math.pi / 2);
    canvas.scale(scale);
    canvas.drawPath(
      star(const [0, -44, 9, -12, 40, -20, 14, 2, 34, 30, 2, 14, -18, 40, -12, 8, -42, 4, -14, -10]),
      Paint()..color = RouletteColors.red.withValues(alpha: opacity.clamp(0.0, 1.0)),
    );
    canvas.drawPath(
      star(const [0, -24, 5, -6, 20, -10, 8, 2, 16, 16, 0, 8, -10, 20, -6, 4, -22, 2, -8, -6]),
      Paint()..color = RouletteColors.cream.withValues(alpha: opacity.clamp(0.0, 1.0)),
    );
    canvas.restore();
  }

  void _wedge(Canvas canvas, double aim, double half, Paint paint) {
    const c = RouletteStageGeometry.center;
    const length = 1400.0;
    final path = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(
        c.dx + math.cos(aim - half) * length,
        c.dy + math.sin(aim - half) * length,
      )
      ..lineTo(
        c.dx + math.cos(aim + half) * length,
        c.dy + math.sin(aim + half) * length,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StagePainter old) => true;
}

//=======================회전 진행==============================
/// 회전 단계에서 [elapsedMs]만큼 지났을 때 총구가 어디까지 왔는지입니다.
@immutable
class RouletteRotation {
  const RouletteRotation({
    required this.startUid,
    required this.currentUid,
    required this.done,
    required this.total,
  });

  final String? startUid;
  final String? currentUid;
  final int done;
  final int total;

  /// 서버는 회전 단계에 들어가며 이미 최종 대상을 정해 두므로, 돌린 수만큼
  /// 거꾸로 세어 출발 자리를 찾습니다. 탈락한 자리는 건너뜁니다.
  factory RouletteRotation.of(
    List<String> aliveUidsInSeatOrder,
    String? finalUid,
    int spinCount,
    int elapsedMs,
    int stepMs,
  ) {
    final n = aliveUidsInSeatOrder.length;
    if (n == 0) {
      return RouletteRotation(
        startUid: finalUid,
        currentUid: finalUid,
        done: 0,
        total: spinCount,
      );
    }
    final finalIndex = math.max(
      0,
      aliveUidsInSeatOrder.indexOf(finalUid ?? ''),
    );
    final start = ((finalIndex - spinCount) % n + n) % n;
    final done = spinCount == 0
        ? 0
        : math.min(spinCount, elapsedMs ~/ math.max(1, stepMs) + 1);
    return RouletteRotation(
      startUid: aliveUidsInSeatOrder[start],
      currentUid: aliveUidsInSeatOrder[(start + done) % n],
      done: done,
      total: spinCount,
    );
  }
}

//=======================시안 키프레임 도우미==============================
/// (진행, 값) 키프레임 사이를 직선으로 잇습니다. CSS keyframes와 같습니다.
double rouletteKeys(double t, List<(double, double)> keys) {
  if (t <= keys.first.$1) return keys.first.$2;
  for (var i = 1; i < keys.length; i++) {
    if (t <= keys[i].$1) {
      final a = keys[i - 1];
      final b = keys[i];
      return a.$2 + (b.$2 - a.$2) * (t - a.$1) / (b.$1 - a.$1);
    }
  }
  return keys.last.$2;
}

/// 시안 도장·탈락 칸의 cubic-bezier(0.2, 1.2, 0.4, 1) 진행입니다.
double rouletteSlam(double t) =>
    const Cubic(.2, 1.2, .4, 1).transform(t.clamp(0.0, 1.0));

/// 시안 화면 흔들림(shake 0.5초)입니다. [t]는 0 → 1.
Offset rouletteShake(double t) {
  if (t <= 0 || t >= 1) return Offset.zero;
  const keys = [
    (0.0, 0.0, 0.0),
    (.12, -10.0, 6.0),
    (.24, 9.0, -7.0),
    (.36, -7.0, -4.0),
    (.48, 6.0, 5.0),
    (.62, -4.0, 2.0),
    (.80, 2.0, -2.0),
    (1.0, 0.0, 0.0),
  ];
  for (var i = 1; i < keys.length; i++) {
    if (t <= keys[i].$1) {
      final a = keys[i - 1];
      final b = keys[i];
      final k = (t - a.$1) / (b.$1 - a.$1);
      return Offset(a.$2 + (b.$2 - a.$2) * k, a.$3 + (b.$3 - a.$3) * k);
    }
  }
  return Offset.zero;
}
