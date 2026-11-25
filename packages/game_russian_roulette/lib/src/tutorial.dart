// [roulette_tutorial.dart] 러시안 룰렛 '1분 요약' 튜토리얼(태블릿 + 휴대폰)이다.
//
// 장면이 정해진 시간마다 저절로 넘어갑니다(GameTutorial.autoPlay). 태블릿은
// 실제 총(paintRouletteGun)과 자리, 휴대폰은 설명 문구와 실제 행동 버튼입니다.
//
// 단계
//  0 시작 · 1 총구 · 2 버튼 세 개(돌리기 → 방패 → 안 함) · 3 몰래 고르기
//  4 공개·회전·발사 · 5 방패 · 6 탈락 자리 건너뛰기 · 7 승리 · 8 끝

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';
import 'package:game_kit/tutorial/game_tutorial.dart';
import 'package:game_russian_roulette/src/theme.dart';
import 'package:game_russian_roulette/src/widgets.dart';

// ============================================================

String _t(String ko, String en, String zhHans, String zhHant) =>
    GameLocale.select(ko: ko, en: en, zhHans: zhHans, zhHant: zhHant);

Duration _ms(num ms) => Duration(milliseconds: ms.round());

const _red = RouletteColors.red;
const _ink = RouletteColors.ink;
const _cream = RouletteColors.cream;
const _gold = RouletteColors.gold;
const _sun = Color(0xFFF2E14C);

class RussianRouletteTutorial extends GameTutorial {
  const RussianRouletteTutorial();

  static const _durations = [3600, 5600, 13800, 5600, 9400, 7200, 5400, 3400];

  @override
  String get gameId => 'russian_roulette';

  @override
  String get title => RouletteCopy.title;

  @override
  int get stepCount => _durations.length + 1;

  @override
  bool isInfo(int step, int phase) => true;

  @override
  bool get autoPlay => true;

  @override
  Duration autoDuration(int step) =>
      _ms(_durations[step.clamp(0, _durations.length - 1)]);

  @override
  Widget buildTabletBackground(BuildContext context) =>
      const ColoredBox(color: _red);

  @override
  Widget buildPhoneBackground(BuildContext context) =>
      const ColoredBox(color: _ink);

  @override
  Widget buildTablet(BuildContext context, TutorialTabletView view) =>
      _RrTablet(view: view);

  @override
  Widget buildPhone(BuildContext context, TutorialPhoneView view) =>
      _RrPhone(view: view);

  @override
  Widget buildPhoneEnd(BuildContext context, TutorialPhoneView view) =>
      TutorialLookAtTablet(
        titleStyle: RouletteType.display(34, _cream),
        glow: _red,
        body: Text(
          _lookBody,
          textAlign: TextAlign.center,
          style: RouletteType.body(18, _gold, weight: FontWeight.w700),
        ),
      );

  @override
  Widget buildAutoEndSlogan(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: _t('총구를 피해\n', 'Dodge the barrel\n', '躲开枪口\n', '躲開槍口\n'),
          style: const TextStyle(color: Color(0xFFFF5A5F)),
        ),
        TextSpan(
          text: _t(
            '마지막 1명으로 살아남으세요!',
            'and be the last one standing!',
            '成为最后的幸存者！',
            '成為最後的倖存者！',
          ),
        ),
      ],
    ),
    textAlign: TextAlign.center,
    style: RouletteType.display(58, _cream, height: 1.3),
  );
}

String get _lookBody => _t(
  '총구가 누구를 겨누는지 꼭 확인하세요',
  'Always check who the gun is aiming at',
  '一定要看清枪口对准了谁',
  '一定要看清槍口對準了誰',
);

/// [from]에서 시계 방향으로 [to]까지 돌아가는 각도입니다(되감지 않게).
double _forward(double from, double to) {
  var d = (to - from) % (2 * math.pi);
  if (d < 0) d += 2 * math.pi;
  return from + d;
}

/// 정해진 시각마다 [angles]로 돌아가는 총입니다. 바뀔 때 부드럽게 돕니다.
class _TimedGun extends StatefulWidget {
  const _TimedGun({required this.size, required this.keys});

  final double size;

  /// (시각, 각도) 목록입니다. 첫 항목은 0초의 시작 각도입니다.
  final List<(Duration, double)> keys;

  @override
  State<_TimedGun> createState() => _TimedGunState();
}

class _TimedGunState extends State<_TimedGun> {
  late double _angle = widget.keys.first.$2;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    for (final (at, angle) in widget.keys.skip(1)) {
      _timers.add(
        Timer(at, () {
          if (mounted) setState(() => _angle = _forward(_angle, angle));
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: widget.keys.first.$2, end: _angle),
    duration: _ms(900),
    curve: Curves.easeInOutCubic,
    builder: (context, angle, _) =>
        RouletteRevolver(size: widget.size, angle: angle),
  );
}

/// [at]에 켜지는 값입니다.
class _Switch extends StatefulWidget {
  const _Switch({required this.at, required this.builder});

  final Duration? at;
  final Widget Function(bool on) builder;

  @override
  State<_Switch> createState() => _SwitchState();
}

class _SwitchState extends State<_Switch> {
  bool _on = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final at = widget.at;
    if (at == Duration.zero) {
      _on = true;
    } else if (at != null) {
      _timer = Timer(at, () {
        if (mounted) setState(() => _on = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_on);
}

class _Tag extends StatelessWidget {
  const _Tag(
    this.text, {
    super.key,
    this.color = _cream,
    this.textColor = _ink,
    this.size = 18,
  });

  final String text;
  final Color color;
  final Color textColor;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
    ),
    child: Text(text, style: RouletteType.display(size, textColor)),
  );
}

String _spinLabel() => _t('돌리기', 'Spin', '转动', '轉動');
String _shieldLabel() => _t('방패', 'Shield', '护盾', '護盾');
String _noneLabel() => _t('안 함', 'Nothing', '不行动', '不行動');

//======================================================================
// 태블릿
//======================================================================
class _RrTablet extends StatelessWidget {
  const _RrTablet({required this.view});

  final TutorialTabletView view;

  Size get _size => view.size;
  Offset get _center => _size.center(Offset.zero);
  int get _n => math.max(1, view.playerCount);

  List<Offset> get _seats {
    final normalized = normalizedPlayerCenters(_n);
    return [
      for (final player in view.players)
        Offset(
          normalized[player.seatIndex.clamp(0, _n - 1)].dx * _size.width,
          normalized[player.seatIndex.clamp(0, _n - 1)].dy * _size.height,
        ),
    ];
  }

  Offset _toward(Offset seat, double k) => _center + (seat - _center) * k;

  double _aim(List<Offset> seats, int i) {
    if (seats.isEmpty) return -math.pi / 4;
    final d = seats[i % seats.length] - _center;
    return math.atan2(d.dy, d.dx);
  }

  double _facing(Offset seat) {
    final d = seat - _center;
    return math.atan2(d.dy, d.dx) + math.pi / 2;
  }

  /// 공개·발사 장면에서 돌리기를 고른 사람 수입니다.
  int get _spins => _n >= 3 ? 2 : 1;

  @override
  Widget build(BuildContext context) {
    final seats = _seats;
    final step = view.step;
    final n = view.players.length;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 테이블
        Positioned(
          left: _center.dx - 250,
          top: _center.dy - 250,
          width: 500,
          height: 500,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: RouletteColors.deepRed,
              shape: BoxShape.circle,
            ),
          ),
        ),
        if (step == 0)
          Positioned.fill(
            child: Center(
              child: TutorialAppear(
                fromScale: .6,
                offset: Offset.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _TimedGun(
                      size: 300,
                      keys: [(Duration.zero, -math.pi / 4)],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      RouletteCopy.title,
                      style: RouletteType.display(64, _cream),
                    ),
                    const SizedBox(height: 8),
                    _Tag(
                      _t('규칙 1분 요약', '1-minute rules', '1分钟规则', '1分鐘規則'),
                      color: _sun,
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          Positioned(
            left: _center.dx - 150,
            top: _center.dy - 150,
            width: 300,
            height: 300,
            child: _TimedGun(size: 300, keys: _gunKeys(seats)),
          ),
          for (var i = 0; i < n; i++) _seat(seats, i),
          ..._extras(seats),
        ],
      ],
    );
  }

  List<(Duration, double)> _gunKeys(List<Offset> seats) {
    double a(int i) => _aim(seats, i);
    final next = _n >= 2 ? 1 : 0;
    return switch (view.step) {
      1 => [(Duration.zero, a(0) - math.pi), (_ms(400), a(0))],
      2 => [(Duration.zero, a(0)), (_ms(800), a(next))],
      4 => [
        (Duration.zero, a(0)),
        for (var k = 1; k <= _spins; k++) (_ms(2200 + (k - 1) * 1100), a(k)),
      ],
      6 => [(Duration.zero, a(0)), (_ms(1400), a(_n >= 3 ? 2 : 0))],
      _ => [(Duration.zero, a(0))],
    };
  }

  Widget _seat(List<Offset> seats, int i) {
    final step = view.step;
    final p = view.players[i];
    final out = switch (step) {
      6 => i == 1 && _n >= 3,
      7 => i != 0,
      _ => false,
    };
    final crossAt = switch (step) {
      4 when i == _spins % _n => _ms(5000),
      _ => null,
    };
    final ring = switch (step) {
      1 when i == 0 => _ms(1300),
      _ => null,
    };
    return Positioned(
      left: seats[i].dx - 60,
      top: seats[i].dy - 60,
      width: 120,
      height: 120,
      child: Center(
        child: _Switch(
          at: crossAt,
          builder: (shot) => _Switch(
            at: ring,
            builder: (aimed) => AnimatedContainer(
              duration: _ms(300),
              decoration: BoxDecoration(
                border: Border.all(
                  color: aimed ? _sun : Colors.transparent,
                  width: 5,
                ),
                boxShadow: [
                  if (aimed)
                    BoxShadow(
                      color: _sun.withValues(alpha: .6),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                ],
              ),
              child: RouletteProfile(
                characterId: p.characterId,
                size: 92,
                gray: out || shot,
                crossed: out || shot,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 자리와 가운데 사이(방패·행동 표시)에 놓는 조각입니다.
  Widget _between(
    Offset seat,
    double k,
    Widget child, {
    bool rotate = false,
    Size box = const Size(200, 90),
  }) {
    final at = _toward(seat, k);
    return Positioned(
      left: at.dx - box.width / 2,
      top: at.dy - box.height / 2,
      width: box.width,
      height: box.height,
      child: Center(
        child: rotate
            ? Transform.rotate(angle: _facing(seat), child: child)
            : child,
      ),
    );
  }

  Widget _shield(Offset seat, Duration at) => _between(
    seat,
    .7,
    TutorialAppear(
      delay: at,
      offset: const Offset(0, 24),
      fromScale: .4,
      child: const RouletteShieldTop(width: 130),
    ),
    rotate: true,
  );

  Widget _bang(Offset seat, Duration at) => _between(
    seat,
    .45,
    TutorialAppear(
      delay: at,
      fromScale: .3,
      offset: Offset.zero,
      child: Text('BANG!', style: RouletteType.display(48, _sun)),
    ),
  );

  Widget _stamp(Offset seat, String text, Color color, Duration at) => _between(
    seat,
    1,
    TutorialAppear(
      delay: at,
      fromScale: 1.7,
      offset: Offset.zero,
      duration: _ms(380),
      curve: Curves.easeOutCubic,
      child: Transform.rotate(
        angle: -.12,
        child: _Tag(text, color: color, textColor: _cream, size: 26),
      ),
    ),
  );

  Widget _chipAt(
    Offset seat,
    String text,
    Color color,
    Color textColor,
    Duration at,
  ) => _between(
    seat,
    .74,
    TutorialAppear(
      delay: at,
      fromScale: .5,
      offset: Offset.zero,
      child: _Tag(text, color: color, textColor: textColor, size: 17),
    ),
  );

  List<Widget> _extras(List<Offset> seats) {
    if (seats.isEmpty) return const [];
    final n = seats.length;
    final next = n >= 2 ? 1 : 0;
    switch (view.step) {
      case 1:
        return [
          _between(
            seats[0],
            .5,
            TutorialAppear(
              delay: _ms(1500),
              child: _Tag(
                _t('총구가 겨눈 사람', 'The target', '被瞄准的人', '被瞄準的人'),
                color: _sun,
                size: 18,
              ),
            ),
            box: const Size(240, 60),
          ),
        ];
      case 2:
        return [
          // 돌리기: 0–3.2초
          Positioned.fill(
            child: TutorialTimed(
              to: _ms(3200),
              child: Stack(
                children: [
                  _chipAt(
                    seats[0],
                    '${_spinLabel()} → +1',
                    _red,
                    _cream,
                    _ms(200),
                  ),
                ],
              ),
            ),
          ),
          // 방패: 3.4–7.8초
          Positioned.fill(
            child: TutorialTimed(
              from: _ms(3400),
              to: _ms(7800),
              child: Stack(children: [_shield(seats[next], _ms(4000))]),
            ),
          ),
          // 안 함: 8초부터
          Positioned.fill(
            child: TutorialTimed(
              from: _ms(8000),
              child: Stack(
                children: [
                  _between(
                    seats[next],
                    .45,
                    _Tag(_t('총구 그대로', 'Gun stays', '枪口不动', '槍口不動'), size: 18),
                    box: const Size(220, 60),
                  ),
                ],
              ),
            ),
          ),
        ];
      case 3:
        return [
          for (var i = 0; i < n; i++)
            _between(
              seats[i],
              .74,
              _Switch(
                at: _ms(700 + i * 500),
                builder: (done) => AnimatedSwitcher(
                  duration: _ms(250),
                  child: _Tag(
                    done ? '✓' : '?',
                    key: ValueKey(done),
                    color: done ? _cream : RouletteColors.panel,
                    textColor: done ? _ink : _cream,
                    size: 22,
                  ),
                ),
              ),
            ),
        ];
      case 4:
        final target = _spins % n;
        return [
          for (var i = 0; i < n; i++)
            i >= 1 && i <= _spins
                ? _chipAt(seats[i], _spinLabel(), _red, _cream, _ms(800))
                : _chipAt(
                    seats[i],
                    _noneLabel(),
                    RouletteColors.panel,
                    _cream,
                    _ms(800),
                  ),
          _bang(seats[target], _ms(4900)),
          _stamp(
            seats[target],
            _t('탈락!', 'Out!', '淘汰！', '淘汰！'),
            _ink,
            _ms(5600),
          ),
        ];
      case 5:
        return [
          _chipAt(seats[0], _shieldLabel(), _cream, _ink, _ms(500)),
          _shield(seats[0], _ms(1100)),
          _bang(seats[0], _ms(2700)),
          _stamp(
            seats[0],
            _t('생존!', 'Safe!', '存活！', '存活！'),
            RouletteColors.grey,
            _ms(3500),
          ),
        ];
      case 6:
        if (n < 3) return const [];
        return [
          _chipAt(seats[0], _spinLabel(), _red, _cream, _ms(400)),
          _between(
            seats[1],
            .5,
            TutorialAppear(
              delay: _ms(1600),
              child: _Tag(_t('건너뛰기', 'Skipped', '跳过', '跳過'), size: 18),
            ),
          ),
        ];
      case 7:
        return [
          _stamp(seats[0], _t('승리!', 'Winner!', '获胜！', '獲勝！'), _gold, _ms(500)),
        ];
    }
    return const [];
  }
}

//======================================================================
// 휴대폰
//======================================================================
class _RrPhone extends StatelessWidget {
  const _RrPhone({required this.view});

  final TutorialPhoneView view;

  static const _uiSteps = {2, 3};

  (List<(String, Duration)>, String?) _caption(int step) {
    (String, Duration) p(
      String ko,
      String en,
      String zh,
      String zt, [
      num at = 0,
    ]) => (_t(ko, en, zh, zt), _ms(at));
    return switch (step) {
      0 => (
        [
          p(
            '러시안 룰렛 1분 요약',
            'Russian Roulette in 1 minute',
            '1分钟看懂俄罗斯轮盘',
            '1分鐘看懂俄羅斯輪盤',
          ),
        ],
        _t('태블릿과 함께 봐요', 'Watch with the tablet', '和平板一起看', '和平板一起看'),
      ),
      1 => (
        [
          p(
            '총구가 겨눈 사람이 총에 맞아요',
            'The gun shoots whoever it aims at',
            '枪口对准的人会中弹',
            '槍口對準的人會中彈',
          ),
          p(
            '마지막 1명이 살아남으면 승리!',
            'The last one standing wins!',
            '最后存活的1人获胜！',
            '最後存活的1人獲勝！',
            2600,
          ),
        ],
        null,
      ),
      2 => (
        [
          p(
            '돌리기: 총구가 다음 사람으로 1칸 돌아가요',
            'Spin: the gun turns 1 seat',
            '转动：枪口转到下一个人',
            '轉動：槍口轉到下一個人',
          ),
          p(
            '방패: 방패를 들면 총에 맞아도 살아남아요',
            'Shield: survive even if you’re shot',
            '护盾：举起护盾中弹也能存活',
            '護盾：舉起護盾中彈也能存活',
            3400,
          ),
          p(
            '단, 방패는 2턴 연속 못 써요',
            'But not 2 turns in a row',
            '但护盾不能连续2回合使用',
            '但護盾不能連續2回合使用',
            5800,
          ),
          p(
            '안 함: 아무것도 하지 않아요 · 총구 그대로',
            'Nothing: the gun stays put',
            '不行动：枪口不动',
            '不行動：槍口不動',
            8000,
          ),
          p(
            '시간 안에 못 고르면 “안 함”이 자동 선택돼요',
            'No pick in time → “Nothing” is chosen',
            '超时未选会自动选择“不行动”',
            '超時未選會自動選擇「不行動」',
            10800,
          ),
        ],
        null,
      ),
      3 => (
        [
          p(
            '모두 30초 안에 몰래 하나를 골라요',
            'Everyone picks secretly within 30s',
            '所有人在30秒内秘密选择',
            '所有人在30秒內秘密選擇',
          ),
          p(
            '다 고르면 한꺼번에 공개!',
            'Then all picks are revealed!',
            '全部选完后一起公开！',
            '全部選完後一起公開！',
            2600,
          ),
        ],
        null,
      ),
      4 => (
        [
          p(
            '돌리기를 고른 수만큼 총구가 돌아가요',
            'The gun turns once per Spin',
            '选择转动的人数决定枪口转几格',
            '選擇轉動的人數決定槍口轉幾格',
          ),
          p(
            '멈춘 곳의 사람이 총에 맞아요',
            'Whoever it stops at is shot',
            '停在谁那里谁就中弹',
            '停在誰那裡誰就中彈',
            4600,
          ),
        ],
        null,
      ),
      5 => (
        [
          p(
            '방패를 든 사람은 맞아도 생존!',
            'A raised shield survives the shot!',
            '举着护盾的人中弹也能存活！',
            '舉著護盾的人中彈也能存活！',
          ),
        ],
        null,
      ),
      6 => (
        [
          p(
            '탈락한 자리는 건너뛰어요',
            'Eliminated seats are skipped',
            '淘汰的座位会被跳过',
            '淘汰的座位會被跳過',
          ),
        ],
        null,
      ),
      _ => (
        [
          p(
            '마지막까지 살아남은 1명이 승리!',
            'The last survivor wins!',
            '最后存活的1人获胜！',
            '最後存活的1人獲勝！',
          ),
        ],
        null,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final step = view.step;
    final (phases, sub) = _caption(step);
    final ui = _uiSteps.contains(step);
    final caption = TutorialPhaseCaption(
      phases: phases,
      sub: sub,
      style: RouletteType.display(ui ? 23 : 22, _cream, height: 1.35),
      subStyle: RouletteType.body(18, _gold, weight: FontWeight.w700),
    );
    return Stack(
      children: [
        if (ui)
          Positioned(
            left: 18,
            right: 18,
            top: 40,
            bottom: 140,
            child: Column(
              children: [
                SizedBox(height: 96, child: Center(child: caption)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 210,
                  child: Center(
                    child: step == 2
                        ? _ButtonVisual(view: view)
                        : const _SecretVisual(),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: step == 2
                      ? const _Buttons.intro()
                      : const _Buttons.picked(),
                ),
              ],
            ),
          )
        else
          Positioned(
            left: 0,
            right: 0,
            top: 40,
            bottom: 140,
            child: TutorialLookAtTablet(
              tabletWidth: 190,
              glow: _red,
              titleStyle: RouletteType.display(34, _cream),
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  caption,
                  if (step >= 4) ...[
                    const SizedBox(height: 14),
                    Text(
                      _lookBody,
                      textAlign: TextAlign.center,
                      style: RouletteType.body(
                        15,
                        _gold,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 56,
          child: Center(
            child: TutorialAutoSkipButton(
              on: view.skipOn,
              onPressed: view.toggleSkip,
              color: _cream,
              onColor: _sun,
              radius: 0,
            ),
          ),
        ),
      ],
    );
  }
}

/// 버튼 설명 장면 위쪽 그림: 돌리기(총구 +1칸) → 방패(프로필 앞에 세움) → 안 함.
class _ButtonVisual extends StatelessWidget {
  const _ButtonVisual({required this.view});

  final TutorialPhoneView view;

  @override
  Widget build(BuildContext context) {
    final players = view.players.isEmpty ? [view.me] : view.players;
    final shown = players.take(4).toList();
    final n = shown.length;
    double aim(int i) => -math.pi / 2 + 2 * math.pi * i / math.max(1, n);
    const r = 86.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        // 돌리기: 작은 원판과 자리, 총구 한 칸 회전
        TutorialTimed(
          to: _ms(3200),
          child: SizedBox(
            width: 220,
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _TimedGun(
                  size: 120,
                  keys: [
                    (Duration.zero, aim(0)),
                    (_ms(900), aim(n >= 2 ? 1 : 0)),
                  ],
                ),
                for (var i = 0; i < n; i++)
                  Transform.translate(
                    offset: Offset(math.cos(aim(i)) * r, math.sin(aim(i)) * r),
                    child: RouletteProfile(
                      characterId: shown[i].characterId,
                      size: 40,
                    ),
                  ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: TutorialAppear(
                    delay: _ms(1900),
                    child: _Tag(
                      _t('총구 +1칸', 'Gun +1 seat', '枪口 +1格', '槍口 +1格'),
                      color: _red,
                      textColor: _cream,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 방패: 프로필 앞에 방패가 세워짐, 연속 사용 불가
        TutorialTimed(
          from: _ms(3400),
          to: _ms(7800),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 160,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 0,
                      child: RouletteProfile(
                        characterId: view.me.characterId,
                        size: 96,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: TutorialAppear(
                        delay: _ms(4000),
                        offset: const Offset(0, 40),
                        fromScale: .5,
                        child: const RouletteShield(size: 92),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TutorialAppear(
                delay: _ms(5900),
                fromScale: .6,
                offset: Offset.zero,
                child: _Tag(
                  _t(
                    '2턴 연속 사용 불가',
                    'Not 2 turns in a row',
                    '不能连续2回合',
                    '不能連續2回合',
                  ),
                  color: RouletteColors.panel,
                  textColor: _cream,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
        // 안 함: 총구 그대로, 시간 초과 시 자동 선택
        TutorialTimed(
          from: _ms(8000),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RouletteRevolver(size: 120),
              const SizedBox(height: 12),
              _Tag(
                _t(
                  '총구 그대로 · 방어 없음',
                  'Gun stays · no defense',
                  '枪口不动 · 无防御',
                  '槍口不動 · 無防禦',
                ),
                size: 16,
              ),
              const SizedBox(height: 10),
              TutorialAppear(
                delay: _ms(10900),
                fromScale: .6,
                offset: Offset.zero,
                child: _Tag(
                  _t(
                    '⏱ 시간 초과 → 자동 선택',
                    '⏱ Time out → auto pick',
                    '⏱ 超时 → 自动选择',
                    '⏱ 超時 → 自動選擇',
                  ),
                  color: _sun,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 몰래 고르기 장면 위쪽 그림입니다.
class _SecretVisual extends StatelessWidget {
  const _SecretVisual();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.lock_rounded, color: _cream, size: 64),
      const SizedBox(height: 12),
      Text(
        _t(
          '내 선택은 공개 전까지 아무도 몰라요',
          'No one sees your pick until the reveal',
          '公开前没人知道你的选择',
          '公開前沒人知道你的選擇',
        ),
        textAlign: TextAlign.center,
        style: RouletteType.body(
          16,
          RouletteColors.sub,
          weight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// 실제 게임 행동 버튼(돌리기·방패 반쪽 + 아무것도 안 하기)입니다.
class _Buttons extends StatelessWidget {
  /// 버튼 설명: 돌리기 → 방패 → 안 함 순서로 불이 들어옵니다.
  const _Buttons.intro() : picked = false;

  /// 몰래 고르기: 돌리기를 고릅니다.
  const _Buttons.picked() : picked = true;

  final bool picked;

  /// 강조 구간(시작, 끝)입니다.
  (Duration, Duration?) _window(int i) => switch (i) {
    0 => (Duration.zero, _ms(3200)),
    1 => (_ms(3400), _ms(7800)),
    _ => (_ms(8000), null),
  };

  Widget _lit(int i, Widget child) {
    if (picked) {
      return _Switch(
        at: _ms(1400),
        builder: (on) => AnimatedOpacity(
          duration: _ms(250),
          opacity: on && i != 0 ? .35 : 1,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: child),
              if (on && i == 0)
                Positioned(
                  right: -6,
                  top: -10,
                  child: TutorialAppear(
                    fromScale: .5,
                    offset: Offset.zero,
                    child: _Tag(
                      _t('선택함', 'Picked', '已选择', '已選擇'),
                      color: _cream,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    final (from, to) = _window(i);
    return _Window(from: from, to: to, child: child);
  }

  Widget _half(bool spin) {
    final bg = spin ? _red : _cream;
    final fg = spin ? _cream : _ink;
    final sub = spin ? _cream : RouletteColors.line;
    final lines = spin
        ? [
            _t('총구 +1칸', 'Gun +1 seat', '枪口 +1格', '槍口 +1格'),
            _t('이번 턴 방어 불가', 'No defense this turn', '本回合无法防御', '本回合無法防禦'),
          ]
        : [
            _t('총구 그대로', 'Gun stays', '枪口不动', '槍口不動'),
            _t('맞아도 생존', 'Survive a hit', '中弹也能存活', '中彈也能存活'),
            _t('다음 턴 사용 불가', 'Not next turn', '下回合不可用', '下回合不可用'),
          ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      color: bg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(spin ? Icons.rotate_right : Icons.shield, color: fg, size: 34),
          const SizedBox(height: 4),
          Text(
            spin ? _spinLabel() : _shieldLabel(),
            style: RouletteType.display(26, fg),
          ),
          const SizedBox(height: 4),
          for (final line in lines)
            Text(line, style: RouletteType.body(12, sub, height: 1.4)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _lit(0, _half(true))),
            const SizedBox(width: 10),
            Expanded(child: _lit(1, _half(false))),
          ],
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 56,
        child: _lit(
          2,
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: RouletteColors.dash, width: 2),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: RouletteCopy.action(RouletteLabel.none)),
                  TextSpan(
                    text:
                        '  ${_t('총구 그대로 · 방어 없음', 'Gun stays · no defense', '枪口不动 · 无防御', '槍口不動 · 無防禦')}',
                    style: RouletteType.body(12, RouletteColors.sub),
                  ),
                ],
              ),
              style: RouletteType.display(18, _cream),
            ),
          ),
        ),
      ),
    ],
  );
}

/// [from]~[to] 동안 불이 들어오고, 나머지 시간에는 흐려지는 버튼입니다.
class _Window extends StatefulWidget {
  const _Window({required this.from, required this.to, required this.child});

  final Duration from;
  final Duration? to;
  final Widget child;

  @override
  State<_Window> createState() => _WindowState();
}

class _WindowState extends State<_Window> {
  bool _on = false;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    _on = widget.from == Duration.zero;
    if (!_on) {
      _timers.add(Timer(widget.from, () => _set(true)));
    }
    final to = widget.to;
    if (to != null) _timers.add(Timer(to, () => _set(false)));
  }

  void _set(bool on) {
    if (mounted) setState(() => _on = on);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: _ms(250),
    opacity: _on ? 1 : .3,
    child: AnimatedContainer(
      duration: _ms(250),
      decoration: BoxDecoration(
        boxShadow: [
          if (_on)
            BoxShadow(
              color: _sun.withValues(alpha: .7),
              blurRadius: 22,
              spreadRadius: 3,
            ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: _on ? _sun : Colors.transparent, width: 4),
      ),
      child: widget.child,
    ),
  );
}
