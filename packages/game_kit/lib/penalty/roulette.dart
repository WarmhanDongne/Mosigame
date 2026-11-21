// [roulette.dart] 는 라이어스의 벌칙 룰렛을 그리고 돌리는 파일이다.
//
// - 디자인: 'C · 살롱 전구 간판' 시안. 철제 테두리에 전구가 번갈아 반짝이고,
//   탈락 칸은 붉은 네온과 X로 빛나며, 가운데에 LIAR WHEEL 간판이 있습니다.
//   멈추면 가운데 간판이 결과에 따라 '생존'(초록) 또는 '탈락'(빨강)으로 바뀝니다.
// - 조작: 레버 대신 손가락으로 원판을 잡고 휙 돌립니다. 끄는 동안 원판이
//   손가락을 따라오고, 손을 떼는 속도로 돌기 시작합니다.
// - 결과: 클라이언트가 정하지 않습니다. 돌기 시작하면 서버 추첨을 기다리며
//   같은 속도로 돌고, 결과가 오면 그 칸에 맞춰 천천히 멈춥니다.

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:game_kit/core/diagnostics/game_communication_log.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/sound/app_sounds.dart';
import 'package:game_kit/sound/providers/sound_provider.dart';
import 'package:game_kit/sound/sound_effects.dart';

// ============================================================

enum RouletteResult { safe, eliminated }

class PenaltyRoulette extends StatefulWidget {
  const PenaltyRoulette({
    super.key,
    required this.attemptCount,
    required this.onPrepareResult,
    required this.onResult,
    this.centerCharacterId,
  });

  final int attemptCount;
  final Future<RouletteResult?> Function() onPrepareResult;
  final ValueChanged<RouletteResult> onResult;
  final String? centerCharacterId;

  /// 서버 결과를 기다리며 도는 가장 빠른 속도입니다(초당 약 3.3바퀴).
  static const double maxSpinSpeed = 2 * math.pi / 0.3;

  /// 살살 돌려도 이 속도보다 느리게 돌지는 않습니다(초당 2바퀴).
  static const double minSpinSpeed = 2 * math.pi * 2;

  /// 손을 뗀 속도가 이보다 느리면 돌지 않고 '더 세게' 안내를 보입니다.
  static const double flickThreshold = 2 * math.pi * 1.2;

  @override
  State<PenaltyRoulette> createState() => _PenaltyRouletteState();
}

enum _Phase { idle, weak, dragging, spinning, settling }

class _PenaltyRouletteState extends State<PenaltyRoulette>
    with TickerProviderStateMixin {
  /// ============================================================
  /// 기준 디자인 사이즈
  ///
  /// 정사각형 1000 × 1000 캔버스를 기준으로 전체 룰렛 UI가 같은 비율로
  /// 확대/축소됩니다. 정사각형이라 게임이 대상 플레이어 쪽으로 통째로
  /// 돌려도 잘리지 않습니다. 포인터는 캔버스 위쪽(대상 쪽)에 있습니다.
  /// ============================================================
  static const double _designSize = 1000;
  static const Offset _center = Offset(_designSize / 2, _designSize / 2);

  static const List<bool> _firstAttemptSections = [
    true, false, false, false, //
    true, false, false, false, //
    true, false, false, false, //
    true, false, false, false, //
  ];
  static const List<bool> _secondAttemptSections = [
    true, false, false, //
    true, false, false, //
    true, false, false, //
    true, false, false, //
    true, false, false, //
  ];
  static const List<bool> _finalAttemptSections = [
    false, true, true, true, true, true, //
    true, true, true, true, true, true, //
  ];

  /// 서버 응답이 빠를 때의 전체 연출 시간입니다. 효과음 재생 구간도 함께 늘어납니다.
  static const Duration _spinDuration = Duration(seconds: 6);

  /// 서버가 늦게 응답해도 마지막 감속을 급하게 압축하지 않습니다.
  /// 결과 수신 후 최소 4초 동안 감속합니다.
  static const Duration _minimumSettleDuration = Duration(seconds: 4);

  /// 서버 결과가 없을 때 원판을 세우는 시간입니다.
  static const Duration _abortSettleDuration = Duration(milliseconds: 250);

  final math.Random _random = math.Random.secure();

  /// 원판 회전 각도(라디안, 시계 방향 +)입니다. 그리기와 테스트가 함께 읽습니다.
  final ValueNotifier<double> _angle = ValueNotifier<double>(0);

  late final Ticker _ticker = createTicker(_onTick);

  /// 전구 깜빡임과 안내 손가락 움직임입니다.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  _Phase _phase = _Phase.idle;

  /// 멈춘 뒤 가운데 간판에 보일 결과입니다. 다시 잡으면 비웁니다.
  RouletteResult? _shownResult;

  /// 간판이 결과로 바뀌며 튀어나오는(탈락은 흔들리는) 연출입니다.
  late final AnimationController _signPop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  // 끄는 중
  double? _dragPointerAngle;

  // 서버를 기다리며 도는 중
  double _velocity = 0;
  Duration _lastTick = Duration.zero;

  // 결과 칸으로 감속하는 중
  double _settleFrom = 0;
  double _settleDistance = 0;
  Duration _settleDuration = Duration.zero;
  Duration? _settleStart;
  Completer<bool>? _settleDone;

  /// dispose에서도 사운드를 멈춰야 해서 미리 잡아 둡니다.
  SoundProvider? _sound;

  bool get _isBusy =>
      _phase == _Phase.spinning || _phase == _Phase.settling;

  List<bool> get _sections => switch (widget.attemptCount) {
    0 => _firstAttemptSections,
    1 => _secondAttemptSections,
    _ => _finalAttemptSections,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sound ??= SoundEffects.of(context);
  }

  @override
  void dispose() {
    // 회전 도중 화면이 사라져도 긴 사운드가 남지 않도록 정지시킵니다.
    _sound?.stopSustainedEffect();
    final done = _settleDone;
    if (done != null && !done.isCompleted) done.complete(false);
    _ticker.dispose();
    _ambient.dispose();
    _signPop.dispose();
    _angle.dispose();
    super.dispose();
  }

  // ============================================================
  // 손가락으로 돌리기
  // ============================================================

  double _pointerAngle(Offset local) {
    final d = local - _center;
    return math.atan2(d.dy, d.dx);
  }

  void _onPanStart(DragStartDetails details) {
    if (_isBusy) return;
    // 원판 바깥(전구 테두리 밖)을 잡으면 돌리지 않습니다.
    if ((details.localPosition - _center).distance > _WheelGeometry.outer) {
      return;
    }
    setState(() {
      _phase = _Phase.dragging;
      _shownResult = null;
      _dragPointerAngle = _pointerAngle(details.localPosition);
    });
    _signPop.value = 0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final previous = _dragPointerAngle;
    if (_phase != _Phase.dragging || previous == null) return;
    final next = _pointerAngle(details.localPosition);
    var delta = next - previous;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    _dragPointerAngle = next;
    _angle.value += delta;
  }

  void _onPanEnd(DragEndDetails details) {
    if (_phase != _Phase.dragging) return;
    final pointer = _dragPointerAngle;
    _dragPointerAngle = null;
    // 손을 뗀 자리에서 손가락 속도의 회전 성분(접선 방향)만 각속도로 바꿉니다.
    final r = pointer == null
        ? const Offset(0, -1)
        : Offset(math.cos(pointer), math.sin(pointer)) * _WheelGeometry.wheel;
    final v = details.velocity.pixelsPerSecond;
    final omega = (r.dx * v.dy - r.dy * v.dx) / r.distanceSquared;
    if (omega.abs() < PenaltyRoulette.flickThreshold) {
      setState(() => _phase = _Phase.weak);
      return;
    }
    unawaited(_spin(omega));
  }

  void _onPanCancel() {
    if (_phase != _Phase.dragging) return;
    setState(() {
      _phase = _Phase.idle;
      _dragPointerAngle = null;
    });
  }

  // ============================================================
  // 회전
  // ============================================================

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (_phase == _Phase.spinning) {
      _angle.value += _velocity * dt;
      return;
    }
    if (_phase == _Phase.settling) {
      _settleStart ??= elapsed;
      final total = _settleDuration.inMicroseconds;
      final t = total <= 0
          ? 1.0
          : ((elapsed - _settleStart!).inMicroseconds / total).clamp(0.0, 1.0);
      _angle.value =
          _settleFrom + _settleDistance * _SuspenseDecelerationCurve.at(t);
      if (t >= 1) {
        _ticker.stop();
        final done = _settleDone;
        if (done != null && !done.isCompleted) done.complete(true);
      }
    }
  }

  void _startTicker() {
    if (_ticker.isActive) _ticker.stop();
    _lastTick = Duration.zero;
    _ticker.start();
  }

  Future<bool> _settle(double distance, Duration duration) {
    _settleFrom = _angle.value;
    _settleDistance = distance;
    _settleDuration = duration;
    _settleStart = null;
    final done = Completer<bool>();
    _settleDone = done;
    setState(() => _phase = _Phase.settling);
    if (!_ticker.isActive) _startTicker();
    return done.future;
  }

  Future<void> _spin(double omega) async {
    if (_isBusy) return;
    final direction = omega.isNegative ? -1.0 : 1.0;
    _velocity =
        direction *
        omega.abs().clamp(
          PenaltyRoulette.minSpinSpeed,
          PenaltyRoulette.maxSpinSpeed,
        );

    GameCommunicationLog.instance.add(
      level: GameCommunicationLevel.info,
      title: '룰렛 시작',
      detail: '손가락으로 돌린 속도로 회전하며 서버 추첨 결과를 기다립니다.',
      operation: 'liars_poker_roulette',
    );
    setState(() => _phase = _Phase.spinning);
    _startTicker();

    // 룰렛 사운드는 파일이 회전보다 깁니다. 앞부분을 건너뛰어 회전이 끝나는
    // 시점에 소리도 자연스럽게 끝나도록 맞춥니다.
    _sound?.playSustainedEffect(AppSounds.roulette, window: _spinDuration);

    // 서버가 추첨할 때까지 같은 속도로 돕니다. 결과를 기다리는 동안에는
    // 임의의 칸에서 멈추거나 클라이언트가 생존/탈락을 결정하지 않습니다.
    final spinElapsed = Stopwatch()..start();
    final result = await widget.onPrepareResult();
    if (!mounted) return;

    if (result == null) {
      spinElapsed.stop();
      GameCommunicationLog.instance.add(
        level: GameCommunicationLevel.failure,
        title: '룰렛 추첨 중단',
        detail: '서버 추첨 결과를 받지 못해 원판을 세우고 다시 돌릴 수 있게 했습니다.',
        operation: 'liars_poker_roulette',
      );
      _sound?.stopSustainedEffect();
      // 같은 감속 곡선으로 짧게 세웁니다(시작 속도 = 지금 속도).
      final seconds = _abortSettleDuration.inMicroseconds / 1e6;
      await _settle(_velocity * seconds / 3, _abortSettleDuration);
      if (!mounted) return;
      setState(() => _phase = _Phase.idle);
      return;
    }

    spinElapsed.stop();
    GameCommunicationLog.instance.add(
      level: GameCommunicationLevel.success,
      title: '룰렛 추첨 결과 수신',
      detail:
          '결과=${result.name} · 응답 ${spinElapsed.elapsedMilliseconds}ms · '
          '목표 칸 감속 시작',
      operation: 'liars_poker_roulette',
    );

    final remaining = _spinDuration - spinElapsed.elapsed;
    final settleDuration = remaining > _minimumSettleDuration
        ? remaining
        : _minimumSettleDuration;
    final distance = _distanceTo(result, settleDuration);
    final completed = await _settle(distance, settleDuration);

    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      if (completed) _shownResult = result;
    });
    if (completed) unawaited(_signPop.forward(from: 0));

    if (!completed) {
      GameCommunicationLog.instance.add(
        level: GameCommunicationLevel.warning,
        title: '룰렛 회전 취소',
        detail: '애니메이션 완료 신호가 없어 결과 반영 요청을 보내지 않았습니다.',
        operation: 'liars_poker_roulette',
      );
      return;
    }

    GameCommunicationLog.instance.add(
      level: GameCommunicationLevel.info,
      title: '룰렛 회전 완료',
      detail: '서버에 결과 반영 요청을 전달합니다.',
      operation: 'liars_poker_roulette',
    );
    widget.onResult(result);
  }

  /// 서버 결과 칸에 멈추도록, 지금 각도에서 같은 방향으로 더 돌 거리입니다.
  ///
  /// 감속 곡선의 시작 기울기는 3이므로 거리 D를 시간 T 동안 돌면 시작 속도가
  /// 3D/T입니다. 이 값이 지금 회전 속도를 넘지 않도록 바퀴 수를 고릅니다.
  /// 그래야 결과를 받은 순간 다시 빨라지지 않고 끝까지 같은 방향으로 느려집니다.
  double _distanceTo(RouletteResult result, Duration duration) {
    final sections = _sections;
    final eliminate = result == RouletteResult.eliminated;
    final matching = <int>[
      for (var index = 0; index < sections.length; index++)
        if (sections[index] == eliminate) index,
    ];
    final index = matching[_random.nextInt(matching.length)];
    final slot = 2 * math.pi / sections.length;
    final within = .15 + _random.nextDouble() * .7;
    // 포인터(위쪽) 아래에 [index] 칸이 오는 원판 각도입니다.
    final target = -(index + within) * slot;
    final direction = _velocity.isNegative ? -1.0 : 1.0;
    final turn = 2 * math.pi;
    final base = (((target - _angle.value) * direction) % turn + turn) % turn;
    final desired = _velocity.abs() * (duration.inMicroseconds / 1e6) / 3;
    final extraTurns = math.max(0, ((desired - base) / turn).floor());
    return direction * (base + extraTurns * turn);
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // 결과 간판이 떠 있는 동안에는 안내를 숨깁니다.
    final showHint =
        (_phase == _Phase.idle || _phase == _Phase.weak) && _shownResult == null;
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        // 내부 UI는 1000 × 1000으로 만들고 기기 크기에 맞춰 통째로 확대/축소합니다.
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox.square(
            dimension: _designSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: RouletteWheel(
                    angle: _angle,
                    sections: _sections,
                    ambient: reduceMotion ? null : _ambient,
                    result: _shownResult,
                    resultAnimation: _signPop,
                  ),
                ),
                if (showHint)
                  Positioned.fill(
                    key: const Key('roulette-drag-hint'),
                    child: IgnorePointer(
                      child: _DragHint(
                        animation: reduceMotion ? null : _ambient,
                      ),
                    ),
                  ),
                // 원판 전체가 손가락 영역입니다. 도는 동안에는 막습니다.
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _isBusy,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      onPanCancel: _onPanCancel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 진행률 1 - (1 - t)³: 속도가 3(1 - t)²로 줄어드는 감속 전용 곡선입니다.
///
/// 마지막 몇 칸을 천천히 지나는 긴장감을 만듭니다. 끝에 별도 정지 시간을
/// 붙이지 않아 결과를 보여 준 채 callback만 지연시키는 연출이 되지 않습니다.
abstract final class _SuspenseDecelerationCurve {
  static double at(double t) {
    final remaining = 1 - t;
    return 1 - remaining * remaining * remaining;
  }
}

// ================================================================
// 룰렛 원판 (C · 살롱 전구 간판)
// ================================================================

/// 1000 × 1000 캔버스 기준 크기입니다(시안 좌표 × 1.3).
abstract final class _WheelGeometry {
  static const double k = 1.3;

  /// 철제 테두리 바깥 반지름입니다. 이 안을 잡아야 돌릴 수 있습니다.
  static const double outer = 332 * k;
  static const double bulbRing = 304 * k;
  static const double bulb = 12 * k;
  static const double inner = 284 * k;

  /// 칸이 그려지는 원판 반지름입니다.
  static const double wheel = 276 * k;
  static const double hub = 92 * k;
}

/// 원판을 그립니다. [angle]이 바뀌면 칸만 돌고 테두리·포인터·간판은 그대로입니다.
class RouletteWheel extends StatelessWidget {
  const RouletteWheel({
    super.key,
    required this.angle,
    required this.sections,
    this.ambient,
    this.result,
    this.resultAnimation,
  });

  /// 원판 회전 각도(라디안, 시계 방향 +)입니다.
  final ValueListenable<double> angle;

  /// 위쪽(포인터)부터 시계 방향으로 각 칸이 탈락 칸인지입니다.
  final List<bool> sections;

  /// 전구 깜빡임 진행(0 → 1 반복)입니다. null이면 깜빡이지 않습니다.
  final Animation<double>? ambient;

  /// 멈춘 뒤 가운데 간판에 보일 결과입니다. null이면 LIAR WHEEL입니다.
  final RouletteResult? result;

  /// 간판이 결과로 바뀌는 연출 진행(0 → 1)입니다.
  final Animation<double>? resultAnimation;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _SaloonWheelPainter(
        angle: angle,
        sections: sections,
        ambient: ambient,
        result: result,
        resultAnimation: resultAnimation,
      ),
    ),
  );
}

class _SaloonWheelPainter extends CustomPainter {
  _SaloonWheelPainter({
    required this.angle,
    required this.sections,
    required this.ambient,
    required this.result,
    required this.resultAnimation,
  }) : super(repaint: Listenable.merge([angle, ?ambient, ?resultAnimation]));

  final ValueListenable<double> angle;
  final List<bool> sections;
  final Animation<double>? ambient;
  final RouletteResult? result;
  final Animation<double>? resultAnimation;

  static const _k = _WheelGeometry.k;
  static const _gold = Color(0xFFC9A25B);
  static const _goldLight = Color(0xFFFFF1C2);
  static const _goldDeep = Color(0xFF7A5A22);
  static const _abyss = Color(0xFF0D0912);
  static const _neon = Color(0xFFFF3B4E);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 1000;
    canvas.save();
    canvas.scale(scale);
    const c = Offset(500, 500);
    const outerRect = Rect.fromLTWH(500 - _WheelGeometry.outer, 500 - _WheelGeometry.outer, _WheelGeometry.outer * 2, _WheelGeometry.outer * 2);
    final goldShader = const RadialGradient(
      center: Alignment(-.3, -.5),
      radius: .9,
      colors: [_goldLight, Color(0xFFE2C27E), _goldDeep],
      stops: [0, .4, 1],
    ).createShader(outerRect);

    // 그림자 · 철제 테두리
    canvas.drawCircle(
      c + const Offset(13, 21),
      340 * _k,
      Paint()
        ..color = const Color(0x8C000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 21),
    );
    canvas.drawCircle(
      c,
      _WheelGeometry.outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A2A22), Color(0xFF140C09)],
        ).createShader(outerRect),
    );
    canvas.drawCircle(
      c,
      _WheelGeometry.outer,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * _k,
    );
    canvas.drawCircle(c, _WheelGeometry.inner, Paint()..color = _abyss);

    // 전구 24개: 짝·홀이 번갈아 반짝입니다.
    final blink = ambient?.value ?? 0;
    final evenOn = ((blink * 2.2) % 1) < .5;
    for (var i = 0; i < 24; i++) {
      final a = -math.pi / 2 + i * math.pi / 12;
      final p = c + Offset(math.cos(a), math.sin(a)) * _WheelGeometry.bulbRing;
      final on = ambient == null || (i.isEven == evenOn);
      _bulb(canvas, p, _WheelGeometry.bulb, on ? 1 : .45);
    }

    // 회전하는 칸
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle.value);
    _paintSlots(canvas);
    canvas.restore();

    canvas.drawCircle(
      c,
      _WheelGeometry.inner,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * _k,
    );

    // 가운데 간판: 평소엔 LIAR WHEEL, 멈추면 결과(생존 초록 · 탈락 빨강)
    _paintSign(canvas, c, goldShader);

    // 위쪽 포인터: 어두운 칸 위에서도 잘 보이도록 크게, 밝은 노랑에 검은 테두리와 빛 번짐을 둡니다.
    final top = c + const Offset(0, -300 * _k);
    Path triangle(double tipY, double half, double baseY) => Path()
      ..moveTo(top.dx, top.dy + tipY * _k)
      ..lineTo(top.dx - half * _k, top.dy + baseY * _k)
      ..lineTo(top.dx + half * _k, top.dy + baseY * _k)
      ..close();
    canvas.drawPath(
      triangle(84, 38, -2),
      Paint()
        ..color = const Color(0x8CFFD84A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    final pointer = triangle(82, 34, 0);
    canvas.drawPath(pointer, Paint()..color = const Color(0xFFFFE27A));
    canvas.drawPath(
      pointer,
      Paint()
        ..color = const Color(0xFF17110F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * _k
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(triangle(62, 16, 16), Paint()..color = const Color(0xFFFFF6C8));
    final bulbCenter = top + const Offset(0, -8 * _k);
    _bulb(canvas, bulbCenter, 18 * _k, 1);
    canvas.drawCircle(
      bulbCenter,
      18 * _k,
      Paint()
        ..color = const Color(0xFF17110F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * _k,
    );

    canvas.restore();
  }

  void _paintSign(Canvas canvas, Offset c, Shader goldShader) {
    final out = result == RouletteResult.eliminated;
    final safe = result == RouletteResult.safe;
    final done = out || safe;
    final t = done ? (resultAnimation?.value ?? 1) : 1.0;
    // 0 → 0.5: 0.4배에서 1.15배로 튀어나왔다가 1배로, 탈락은 이어서 좌우로 흔들립니다.
    final pop = t < .3
        ? .4 + (1.15 - .4) * (t / .3)
        : t < .5
        ? 1.15 - .15 * ((t - .3) / .2)
        : 1.0;
    final shake = out && t > .5
        ? math.sin((t - .5) / .5 * math.pi * 4) * 8 * _k * (1 - (t - .5) / .5)
        : 0.0;
    canvas.save();
    canvas.translate(c.dx + shake, c.dy);
    canvas.scale(done ? pop : 1);

    canvas.drawCircle(
      Offset.zero,
      _WheelGeometry.hub,
      Paint()
        ..color = out
            ? const Color(0xFFB3141F)
            : safe
            ? const Color(0xFF0F2A1C)
            : _abyss,
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * _k;
    if (done) {
      final glowColor = out ? _neon : const Color(0xFFA4D65E);
      canvas.drawCircle(
        Offset.zero,
        _WheelGeometry.hub,
        Paint()
          ..color = glowColor.withValues(alpha: .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12 * _k
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      ring.color = glowColor;
    } else {
      // 금색 그라데이션은 원판 기준이라 가운데로 옮긴 좌표에 맞춰 다시 만듭니다.
      ring.shader = const RadialGradient(
        center: Alignment(-.3, -.5),
        radius: .9,
        colors: [_goldLight, Color(0xFFE2C27E), _goldDeep],
        stops: [0, .4, 1],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: _WheelGeometry.hub));
    }
    canvas.drawCircle(Offset.zero, _WheelGeometry.hub, ring);
    if (!done) _dashedCircle(canvas, Offset.zero, 80 * _k);

    if (out) {
      _text(canvas, GameLocale.select(ko: '탈락', en: 'OUT', zhHans: '淘汰', zhHant: '淘汰'), const Offset(0, -2 * _k), size: 54 * _k, color: const Color(0xFFFFF1F2), glow: _neon, family: 'BlackHanSans');
      _text(canvas, 'OUT', const Offset(0, 40 * _k), size: 16 * _k, color: const Color(0xFFFFD0D5), letterSpacing: 3 * _k, glow: _neon);
    } else if (safe) {
      _text(canvas, GameLocale.select(ko: '생존', en: 'SAFE', zhHans: '生存', zhHant: '生存'), const Offset(0, -2 * _k), size: 54 * _k, color: const Color(0xFFC8F08A), glow: const Color(0xFF6BBF3A), family: 'BlackHanSans');
      _text(canvas, 'SAFE', const Offset(0, 40 * _k), size: 16 * _k, color: const Color(0xFFA4D65E), letterSpacing: 3 * _k, glow: const Color(0xFF6BBF3A));
    } else {
      _text(canvas, 'LIAR', const Offset(0, -6 * _k), size: 38 * _k, color: const Color(0xFFE2C27E));
      _text(canvas, 'WHEEL', const Offset(0, 24 * _k), size: 16 * _k, color: const Color(0xFFFF8A96), letterSpacing: 3 * _k, glow: _neon);
    }
    canvas.restore();
  }

  void _paintSlots(Canvas canvas) {
    final n = sections.length;
    final sweep = 2 * math.pi / n;
    const r = _WheelGeometry.wheel;
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * sweep;
      final bad = sections[i];
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..color = bad
              ? const Color(0xFF3A0712)
              : (i.isEven ? const Color(0xFF160C1F) : const Color(0xFF22122F)),
      );
      final mid = start + sweep / 2;
      if (bad) {
        // 네온 테두리: 번진 빛을 먼저 그리고 선을 위에 그립니다.
        final inset = 2.2 * math.pi / 180;
        final outline = Path()
          ..addArc(Rect.fromCircle(center: Offset.zero, radius: 262 * _k), start + inset, sweep - inset * 2)
          ..arcTo(Rect.fromCircle(center: Offset.zero, radius: 96 * _k), start + sweep - inset, -(sweep - inset * 2), false)
          ..close();
        canvas.drawPath(
          outline,
          Paint()
            ..color = _neon.withValues(alpha: .8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9 * _k
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
        canvas.drawPath(
          outline,
          Paint()
            ..color = _neon
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * _k
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.save();
        canvas.translate(math.cos(mid) * 196 * _k, math.sin(mid) * 196 * _k);
        canvas.rotate(mid + math.pi / 2);
        _text(canvas, 'X', Offset.zero, size: 30 * _k, color: const Color(0xFFFFB3BC), glow: _neon);
        canvas.restore();
      } else {
        canvas.drawCircle(
          Offset(math.cos(mid), math.sin(mid)) * (196 * _k),
          4 * _k,
          Paint()..color = _gold.withValues(alpha: .55),
        );
      }
    }
    final divider = Paint()
      ..color = _gold.withValues(alpha: .55)
      ..strokeWidth = 2 * _k;
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + i * sweep;
      canvas.drawLine(Offset.zero, Offset(math.cos(a), math.sin(a)) * r, divider);
    }
  }

  void _bulb(Canvas canvas, Offset p, double r, double opacity) {
    canvas.drawCircle(
      p,
      r * 1.6,
      Paint()
        ..color = const Color(0xFFFFD27A).withValues(alpha: .55 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .9),
    );
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.2, -.3),
          colors: [
            Colors.white.withValues(alpha: opacity),
            const Color(0xFFFFE7A3).withValues(alpha: opacity),
            const Color(0xFFE2A43A).withValues(alpha: math.max(.6, opacity)),
          ],
          stops: const [0, .35, 1],
        ).createShader(Rect.fromCircle(center: p, radius: r)),
    );
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..color = const Color(0xFF3A2408)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _dashedCircle(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..color = _gold.withValues(alpha: .5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const count = 48;
    for (var i = 0; i < count; i++) {
      final a = i * 2 * math.pi / count;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * r,
        c + Offset(math.cos(a + .03), math.sin(a + .03)) * r,
        paint,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center, {
    required double size,
    required Color color,
    double letterSpacing = 0,
    Color? glow,
    String family = 'Rye',
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: family,
          fontSize: size,
          color: color,
          letterSpacing: letterSpacing,
          height: 1,
          shadows: glow == null
              ? null
              : [
                  Shadow(color: glow, blurRadius: size * .35),
                  Shadow(color: glow.withValues(alpha: .6), blurRadius: size * .8),
                ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SaloonWheelPainter oldDelegate) =>
      oldDelegate.sections != sections ||
      oldDelegate.angle != angle ||
      oldDelegate.ambient != ambient ||
      oldDelegate.result != result ||
      oldDelegate.resultAnimation != resultAnimation;
}

// ================================================================
// 끌어서 돌리기 안내
// ================================================================

/// 손가락이 원판 위쪽을 꾹 누른 뒤 호를 따라 휙 쓸고 지나가는 안내입니다.
///
/// 글자 없이 움직임만으로 알려 줍니다(시안 C). 움직임을 줄인 설정이면
/// 점선 호와 손가락을 멈춘 채로 보여 줍니다.
class _DragHint extends StatelessWidget {
  const _DragHint({required this.animation});

  final Animation<double>? animation;

  @override
  Widget build(BuildContext context) {
    final hand = animation;
    if (hand == null) {
      return const CustomPaint(painter: _SwipePainter(.3));
    }
    return AnimatedBuilder(
      animation: hand,
      builder: (context, _) => CustomPaint(painter: _SwipePainter(hand.value)),
    );
  }
}

/// 원판 위쪽 호를 따라 손가락이 왼쪽에서 오른쪽으로 쓸고 지나갑니다.
class _SwipePainter extends CustomPainter {
  const _SwipePainter(this.t);

  final double t;

  static const _k = _WheelGeometry.k;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 1000;
    canvas.save();
    canvas.scale(scale);
    const c = Offset(500, 500);

    // 점선 호(화살표 머리 없음)
    const arcRadius = 286 * _k;
    const half = 41.6 * math.pi / 180;
    final dash = Paint()
      ..color = const Color(0xBFF2EADB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * _k
      ..strokeCap = StrokeCap.round;
    const dashLength = 3 * _k / arcRadius;
    const gapLength = 16 * _k / arcRadius;
    for (var a = -math.pi / 2 - half; a < -math.pi / 2 + half; a += dashLength + gapLength) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: arcRadius), a, dashLength, false, dash);
    }

    // 0 → 0.1 나타남 · 0.1 → 0.22 꾹 누름 · 0.22 → 0.72 쓸기 · 0.72 → 0.88 사라짐
    double opacity;
    if (t < .1) {
      opacity = t / .1;
    } else if (t < .72) {
      opacity = 1;
    } else if (t < .88) {
      opacity = 1 - (t - .72) / .16;
    } else {
      opacity = 0;
    }
    final sweep = Curves.easeInOut.transform(((t - .22) / .5).clamp(0.0, 1.0));
    final rotation = (-40 + 80 * sweep + (t > .72 ? 6 * ((t - .72) / .28) : 0)) * math.pi / 180;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);
    // 누르는 자리의 노란 파동
    final tap = t < .08
        ? 0.0
        : t < .16
        ? (t - .08) / .08 * 1.15
        : t < .24
        ? 1.15 - (t - .16) / .08 * .25
        : .9;
    canvas.drawCircle(
      const Offset(0, -232 * _k),
      34 * _k * math.max(.4, tap),
      Paint()..color = const Color(0xFFF2E14C).withValues(alpha: .35 * opacity * (tap > 0 ? 1 : 0)),
    );
    final icon = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.touch_app.codePoint),
        style: TextStyle(
          fontFamily: Icons.touch_app.fontFamily,
          package: Icons.touch_app.fontPackage,
          fontSize: 96,
          color: Colors.white.withValues(alpha: opacity),
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: .8 * opacity), blurRadius: 4),
            Shadow(color: Colors.black.withValues(alpha: .5 * opacity), blurRadius: 12),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(canvas, Offset(-icon.width * .42, -232 * _k - icon.height * .08));
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SwipePainter oldDelegate) => oldDelegate.t != t;
}
