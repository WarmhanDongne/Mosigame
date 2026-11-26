// [tutorial.dart] 러시안 룰렛 '1분 요약' 튜토리얼(태블릿 + 휴대폰)이다.
//
// 캔버스 시안(RussianRouletteQuick.dc.html)을 그대로 옮긴 화면입니다. 시안이
// 실제 게임 판(1180×820)과 휴대폰(390×844) 좌표로 그려져 있어, 태블릿은 실제
// 게임의 판 위젯([RouletteStage])에 장면별 상태를 넣어 그립니다.
// 등장인물은 시안과 같은 4명(택배·냄비·후드·수박)으로 고정합니다.
//
// 단계와 길이(시안 DUR)
//  0 시작 3.6초 · 1 총구 5.6초 · 2 버튼 설명 13.8초 · 3 몰래 고르기 5.6초
//  4 공개·회전·발포 9.4초 · 5 방패 비교 7.2초 · 6 건너뛰기 5.4초
//  7 최후의 1인 3.4초 · 8 끝

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/tutorial/game_tutorial.dart';
import 'package:game_russian_roulette/src/stage.dart';
import 'package:game_russian_roulette/src/theme.dart';
import 'package:game_russian_roulette/src/widgets.dart';

// ============================================================

String _t(String ko, String en, String zhHans, String zhHant) =>
    GameLocale.select(ko: ko, en: en, zhHans: zhHans, zhHant: zhHant);

Duration _ms(num ms) => Duration(milliseconds: ms.round());

Duration _sec(num seconds) => _ms(seconds * 1000);

const _ink = RouletteColors.ink;
const _cream = RouletteColors.cream;
const _red = RouletteColors.red;
const _sub = RouletteColors.sub;

/// 시안과 같은 등장인물입니다(이름, 캐릭터 아이디).
const _cast = [
  ('택배', 'kindbear'),
  ('냄비', 'bee'),
  ('후드', 'hedgehog'),
  ('수박', 'whale'),
];

/// 첫 총구 대상입니다(실제 게임은 무작위, 시안은 냄비).
const _start = 1;

/// 4단계에서 각자 고른 행동입니다(시안 기본값).
const _picks = ['spin', 'shield', 'spin', 'none'];

/// 4단계 시간표(초)입니다.
const _r0 = .6, _rs = .6, _sum = 3.2, _rt = 4.2;
const _spins = 2;
const _spinTurn = 1.1; // max(0.8, 돌리기 수 × 0.55)
const _fire = _rt + _spinTurn + .5; // 5.8
const _final3 = (_start + _spins) % 4; // 3 · 총구가 멈추는 자리
const _order3 = [1, 2, 3, 0]; // 공개 순서((시작 + k) % 4)

/// 총이 도는 easing입니다(시안 cubic-bezier(.45,.05,.3,1)).
const _gunCurve = Cubic(.45, .05, .3, 1);

double _theta(int i) => RouletteStageGeometry.seatAngle(i, 4);

double _aim(int i) => RouletteStageGeometry.aimAngle(_theta(i));

double _revealAt(int i) => _r0 + _order3.indexOf(i) * _rs;

/// [from] 자리에서 시계 방향으로 [steps]칸 간 총구 각도입니다([skip]은 건너뜁니다).
double _pathAngle(int from, int steps, int skip) {
  var current = _aim(from);
  var index = from;
  for (var j = 0; j < steps; j++) {
    index = (index + 1) % 4;
    if (index == skip) index = (index + 1) % 4;
    var next = _aim(index);
    while (next <= current + 1e-6) {
      next += math.pi * 2;
    }
    current = next;
  }
  return current;
}

/// [a]에서 [b]로 [duration]초 동안 도는 중간 각도입니다.
double _turn(double t, double from, double to, double at, double duration) {
  if (t <= at) return from;
  final k = ((t - at) / duration).clamp(0.0, 1.0);
  return from + (to - from) * _gunCurve.transform(k);
}

/// 시안 flicker입니다(붉은 빔이 깜빡이며 들어옵니다).
double _flicker(double t, double at) {
  if (t < at) return 0;
  return rouletteKeys((t - at) / .7, const [
    (0.0, 0.0),
    (.08, 1.0),
    (.16, .15),
    (.26, 1.0),
    (.36, .4),
    (.48, 1.0),
    (1.0, 1.0),
  ]);
}

class RussianRouletteTutorial extends GameTutorial {
  const RussianRouletteTutorial();

  /// 시안 DUR입니다(밀리초).
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
      const ColoredBox(color: _ink);

  @override
  Widget buildPhoneBackground(BuildContext context) =>
      const ColoredBox(color: _ink);

  @override
  Widget buildTablet(BuildContext context, TutorialTabletView view) =>
      _RrTablet(step: view.step);

  @override
  Widget buildPhone(BuildContext context, TutorialPhoneView view) =>
      _RrPhone(view: view);

  @override
  TutorialEndStyle get autoEndStyle => TutorialEndStyle(
    ink: _ink,
    cream: _cream,
    accent: _red,
    goBg: _cream,
    shade: const Color(0xD90A0908),
    numStyle: RouletteType.display(26, _cream),
    labelStyle: RouletteType.body(20, _ink, weight: FontWeight.w700),
    goStyle: RouletteType.display(38, _ink, height: 1.2),
  );

  @override
  Widget buildAutoEndSlogan(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: _t('총구를 피해\n', 'Dodge the barrel\n', '躲开枪口\n', '躲開槍口\n'),
          style: const TextStyle(color: Color(0xFFE0463F)),
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
    style: RouletteType.display(50, _cream, height: 1.25).copyWith(
      shadows: const [Shadow(color: _ink, offset: Offset(0, 4))],
    ),
  );

  @override
  Widget buildPhoneEnd(BuildContext context, TutorialPhoneView view) =>
      ColoredBox(
        color: _ink,
        child: TutorialLookAtTablet(
          tabletWidth: 300,
          glow: _red,
          titleGap: 44,
          bodyGap: 26,
          titleStyle: RouletteType.display(56, _cream, height: 1.2),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _t('총구가 누구를 겨누는지', 'Always check who', '一定要看清枪口', '一定要看清槍口'),
                textAlign: TextAlign.center,
                style: RouletteType.body(
                  30,
                  _cream.withValues(alpha: .82),
                  weight: FontWeight.w700,
                  height: 1.55,
                ),
              ),
              Container(
                color: _red,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  _t('꼭 확인하세요', 'the gun is aiming at', '对准了谁', '對準了誰'),
                  style: RouletteType.body(
                    30,
                    _cream,
                    weight: FontWeight.w700,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

//======================================================================
// 태블릿 · 실제 게임 판에 장면별 상태를 넣습니다
//======================================================================
class _RrTablet extends StatefulWidget {
  const _RrTablet({required this.step});

  final int step;

  @override
  State<_RrTablet> createState() => _RrTabletState();
}

class _RrTabletState extends State<_RrTablet>
    with SingleTickerProviderStateMixin {
  /// 장면이 시작한 뒤 흐른 시간을 재는 시계입니다.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final t = _c.value * 60;
      return Stack(
        children: [
          Positioned.fill(child: RouletteStage(model: _model(widget.step, t))),
          if (widget.step == 5) Positioned.fill(child: _ShieldDemo(t: t)),
        ],
      );
    },
  );

  RouletteSeatModel _seat(
    int i, {
    required RouletteSeatState state,
    double shield = 0,
    String? badge,
    bool badgeOn = false,
    double flip = 1,
    bool dim = false,
    double glow = 1,
    int? hitMs,
    int? rank,
  }) => RouletteSeatModel(
    key: 'q$i',
    characterId: _cast[i].$2,
    theta: _theta(i),
    state: state,
    shield: shield,
    badge: badge,
    badgeOn: badgeOn,
    flip: flip,
    dim: dim,
    glow: glow,
    hitMs: hitMs,
    rank: rank,
  );

  RouletteStageModel _model(int step, double t) {
    switch (step) {
      // 0 · 시작 연출: 자리에 하나씩 불이 들어오고 첫 대상이 잡힙니다.
      case 0:
        return RouletteStageModel(
          seats: [
            for (var i = 0; i < 4; i++)
              () {
                final on = .5 + ((i - _start + 3) % 4) * .35;
                return _seat(
                  i,
                  state: i == _start && t >= 1.9
                      ? RouletteSeatState.target
                      : RouletteSeatState.waiting,
                  dim: t < on,
                  glow: ((t - on) / .5).clamp(0.0, 1.0),
                );
              }(),
          ],
          gunAim: _aim(_start),
          wedgeOpacity: _flicker(t, 1.2),
          banner: t >= 1.9
              ? _t('튜토리얼 시작', 'Tutorial start', '教程开始', '教學開始')
              : null,
          bannerProgress: ((t - 1.9) / .55).clamp(0.0, 1.0),
        );
      // 1 · 총구 대상 · 2 · 버튼 설명(태블릿은 돌리기 한 칸을 보여 줍니다)
      case 1:
      case 2:
        final turning = step == 2;
        return RouletteStageModel(
          seats: [
            for (var i = 0; i < 4; i++)
              _seat(
                i,
                state: i == _start
                    ? RouletteSeatState.target
                    : RouletteSeatState.waiting,
                // 방패 설명에 맞춰 옆자리 방패가 섭니다(시안 3.9초).
                shield: turning && i == 2
                    ? ((t - 3.9) / .5).clamp(0.0, 1.0)
                    : 0,
              ),
          ],
          gunAim: turning
              ? _turn(t, _aim(_start), _aim(2), .8, .8)
              : _aim(_start),
        );
      // 3 · 모두 몰래 고르는 중(가운데 시간 띠가 줄어듭니다)
      case 3:
        return RouletteStageModel(
          seats: [
            for (var i = 0; i < 4; i++)
              _seat(
                i,
                state: i == _start
                    ? RouletteSeatState.target
                    : RouletteSeatState.waiting,
              ),
          ],
          gunAim: _aim(_start),
          timerFraction: 1 - .75 * (t / 30).clamp(0.0, 1.0),
          label: _t('선택 중', 'Choosing', '选择中', '選擇中'),
        );
      // 4 · 공개 → 집계 → 회전 → 발포
      case 4:
        return RouletteStageModel(
          seats: [for (var i = 0; i < 4; i++) _revealSeat(i, t)],
          gunAim: _turn(
            t,
            _aim(_start),
            _pathAngle(_start, _spins, -1),
            _rt,
            _spinTurn,
          ),
          wedgeOpacity: .35,
          secondWedge: false,
          label: _revealLabel(t).$1,
          labelTag: _revealLabel(t).$2,
          stamp: t >= _fire
              ? RouletteStampModel(
                  theta: _theta(_final3),
                  blocked: false,
                  progress: ((t - _fire) / .4).clamp(0.0, 1.0),
                )
              : null,
        );
      // 5 · 방패 비교(판은 가만히 있고 위에 비교 그림을 덮습니다)
      case 5:
        return RouletteStageModel(
          seats: [
            for (var i = 0; i < 4; i++)
              _seat(i, state: RouletteSeatState.waiting),
          ],
          gunAim: _aim(_start),
          wedgeOpacity: 0,
        );
      // 6 · 탈락한 자리는 건너뜁니다.
      case 6:
        return RouletteStageModel(
          seats: [
            for (var i = 0; i < 4; i++)
              _seat(
                i,
                state: i == 2
                    ? RouletteSeatState.out
                    : (i == 3 && t >= 2.2
                          ? RouletteSeatState.target
                          : RouletteSeatState.waiting),
              ),
          ],
          gunAim: _turn(t, _aim(1), _pathAngle(1, 1, 2), .9, 1.2),
          label: t >= .4 ? _t('회전', 'Spin', '转动', '轉動') : null,
          labelTag: t >= .4 ? '1 / 1' : null,
        );
      // 7 · 최후의 1인
      default:
        const ranks = [1, 3, 4, 2];
        return RouletteStageModel(
          seats: [
            for (var i = 0; i < 4; i++)
              _seat(i, state: RouletteSeatState.rank, rank: ranks[i]),
          ],
          gunAim: _aim(_start),
          showCylinder: false,
          rays: true,
          center: _Winner(t: t),
        );
    }
  }

  /// 4단계 자리입니다. 공개 → 회전 번호 → 발포 순으로 바뀝니다.
  RouletteSeatModel _revealSeat(int i, double t) {
    final at = _revealAt(i);
    final pick = _picks[i];
    final revealed = t >= at;
    final dead = i == _final3 && t >= _fire;
    final spinOrder = _order3.where((j) => _picks[j] == 'spin').toList();
    final number = spinOrder.indexOf(i) + 1;
    return _seat(
      i,
      state: dead
          ? RouletteSeatState.dead
          : !revealed
          ? RouletteSeatState.hidden
          : switch (pick) {
              'spin' => RouletteSeatState.spin,
              'shield' => RouletteSeatState.shield,
              _ => RouletteSeatState.none,
            },
      flip: revealed ? ((t - at) / .42).clamp(0.0, 1.0) : 0,
      shield: pick == 'shield' ? ((t - at - .2) / .5).clamp(0.0, 1.0) : 0,
      badge: pick == 'spin' && t >= _rt ? '$number' : null,
      badgeOn: pick == 'spin' && t >= _rt + number * (_spinTurn / _spins),
      hitMs: dead ? ((t - _fire) * 1000).round() : null,
    );
  }

  /// 4단계 가운데 문구입니다(선택 마감 → 공개 → 집계 → 회전 → 발포).
  (String?, String?) _revealLabel(double t) {
    if (t < _r0) return (_t('선택 마감', 'Locked in', '选择结束', '選擇結束'), null);
    if (t < _sum) return (_t('공개', 'Reveal', '公开', '公開'), null);
    if (t < _rt) {
      return (_t('돌리기 집계', 'Spin count', '转动统计', '轉動統計'), '$_spins');
    }
    final tag = _t('$_spins칸', '$_spins seats', '$_spins格', '$_spins格');
    if (t < _fire) return (_t('회전', 'Spin', '转动', '轉動'), tag);
    return (_t('발포', 'Fire', '开枪', '開槍'), tag);
  }
}

/// 최후의 1인 가운데 그림입니다.
class _Winner extends StatelessWidget {
  const _Winner({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final k = Curves.easeOutBack.transform((t / .5).clamp(0.0, 1.0));
    Widget tag({bool upside = false}) {
      final chip = Container(
        color: _ink,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Text(
          _t('최후의 1인', 'Last one standing', '最后的1人', '最後的1人'),
          style: RouletteType.display(34, _cream),
        ),
      );
      return upside ? Transform.rotate(angle: math.pi, child: chip) : chip;
    }

    return Opacity(
      opacity: (t / .2).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: .6 + .4 * k,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tag(upside: true),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(8),
              color: _cream,
              child: const RouletteProfile(characterId: 'kindbear', size: 204),
            ),
            const SizedBox(height: 14),
            tag(),
          ],
        ),
      ),
    );
  }
}

/// 5단계 방패 비교입니다(방패를 들었다면 / 방패가 없다면).
class _ShieldDemo extends StatelessWidget {
  const _ShieldDemo({required this.t});

  final double t;

  Widget _column({
    required String title,
    required bool shield,
    required int seat,
    required String foot,
    required double delay,
  }) {
    final rise = ((t - delay) / .45).clamp(0.0, 1.0);
    return Opacity(
      opacity: rise,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - Curves.easeOut.transform(rise))),
        child: SizedBox(
          width: 250,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: RouletteType.display(18, _cream)),
              const SizedBox(height: 12),
              if (shield)
                Opacity(
                  opacity: ((t - delay - .5) / .4).clamp(0.0, 1.0),
                  child: SizedBox(
                    width: 160,
                    height: 64,
                    child: Center(
                      child: Transform.rotate(
                        angle: math.pi,
                        child: const RouletteShieldTop(width: 160),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 64),
              const SizedBox(height: 12),
              SizedBox(
                width: 180,
                height: 86,
                child: RouletteSeatPlate(
                  seat: RouletteSeatModel(
                    key: 'demo$seat',
                    characterId: _cast[seat].$2,
                    theta: 0,
                    state: shield
                        ? RouletteSeatState.blocked
                        : RouletteSeatState.dead,
                    hitMs: shield ? null : ((t - 1.25) * 1000).round(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                foot,
                textAlign: TextAlign.center,
                style: RouletteType.body(
                  14,
                  _sub,
                  weight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _ink.withValues(alpha: .82),
    child: Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _column(
            title: _t('방패를 들었다면', 'With a shield', '举着护盾', '舉著護盾'),
            shield: true,
            seat: 3,
            foot: _t(
              '총구가 멈춰도 막아내고 살아남아요',
              'You block the shot and survive',
              '即使枪口停下也能挡住存活',
              '即使槍口停下也能擋住存活',
            ),
            delay: 0,
          ),
          const SizedBox(width: 46),
          _column(
            title: _t('방패가 없다면', 'Without a shield', '没有护盾', '沒有護盾'),
            shield: false,
            seat: 1,
            foot: _t(
              '총구가 멈춘 사람은 탈락해요',
              'Whoever it stops at is out',
              '枪口停下的人被淘汰',
              '槍口停下的人被淘汰',
            ),
            delay: 1.2,
          ),
        ],
      ),
    ),
  );
}

//======================================================================
// 휴대폰
//======================================================================
class _RrPhone extends StatelessWidget {
  const _RrPhone({required this.view});

  final TutorialPhoneView view;

  /// 설명 그림과 행동 버튼을 보여 주는 단계입니다.
  static const _introStep = 2;
  static const _pickStep = 3;

  /// 시안 CAP·MULTI입니다.
  static (List<(String, Duration)>, String?) _caption(int step) {
    (String, Duration) p(
      String ko,
      String en,
      String zh,
      String zt, [
      num at = 0,
    ]) => (_t(ko, en, zh, zt), _sec(at));
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
            '붉은 빔이 가리키는 사람이 총구 대상',
            'The red beam marks the target',
            '红色光束指向的人就是目标',
            '紅色光束指向的人就是目標',
          ),
          p(
            '마지막까지 살아남은 1명이 이겨요',
            'The last one standing wins',
            '坚持到最后的1人获胜',
            '堅持到最後的1人獲勝',
            2.8,
          ),
        ],
        null,
      ),
      2 => (
        [
          p(
            '돌리기: 총구가 다음 사람에게 넘어가요',
            'Spin: the gun moves to the next player',
            '转动：枪口转到下一个人',
            '轉動：槍口轉到下一個人',
          ),
          p(
            '방패: 총구가 멈춰도 살아남아요',
            'Shield: survive even if it stops at you',
            '护盾：枪口停下也能存活',
            '護盾：槍口停下也能存活',
            3.4,
          ),
          p(
            '단, 방패는 2턴 연속 못 써요',
            'But not two turns in a row',
            '但护盾不能连续2回合使用',
            '但護盾不能連續2回合使用',
            5.8,
          ),
          p(
            '안 함: 아무것도 바꾸지 않아요',
            'Nothing: nothing changes',
            '不行动：什么都不改变',
            '不行動：什麼都不改變',
            8.0,
          ),
          p(
            '시간 안에 못 고르면 “안 함”이 자동 선택돼요',
            'No pick in time → “Nothing” is chosen',
            '超时未选会自动选择“不行动”',
            '超時未選會自動選擇「不行動」',
            10.8,
          ),
        ],
        null,
      ),
      3 => (
        [
          p('모두 몰래 하나 골라요', 'Everyone picks in secret', '所有人秘密选择', '所有人秘密選擇'),
          p(
            '고른 건 공개 전까지 아무도 몰라요',
            'No one sees it until the reveal',
            '公开前没人知道',
            '公開前沒人知道',
            2.8,
          ),
        ],
        null,
      ),
      4 => (
        [
          p(
            '한꺼번에 공개! 돌리기 수만큼 총구가 돌아요',
            'All revealed! The gun turns once per Spin',
            '一起公开！枪口按转动人数移动',
            '一起公開！槍口按轉動人數移動',
          ),
          p(
            '방패 없이 총구가 멈춘 사람은 탈락!',
            'No shield where it stops → out!',
            '没有护盾又被枪口停下的人淘汰！',
            '沒有護盾又被槍口停下的人淘汰！',
            5.6,
          ),
        ],
        null,
      ),
      5 => (
        [
          p(
            '방패를 들었을 때 총구가 멈추면?',
            'What if it stops at a raised shield?',
            '举着护盾时枪口停下呢？',
            '舉著護盾時槍口停下呢？',
          ),
          p(
            '방패로 막아내고 살아남아요',
            'The shield blocks it and you survive',
            '用护盾挡住并存活',
            '用護盾擋住並存活',
            3.0,
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
        _t(
          '총구는 살아 있는 사람만 겨눠요',
          'The gun aims only at survivors',
          '枪口只对准存活的人',
          '槍口只對準存活的人',
        ),
      ),
      _ => (
        [
          p(
            '최후의 1인이 승리!',
            'The last one standing wins!',
            '最后的1人获胜！',
            '最後的1人獲勝！',
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
    final pick = step == _pickStep;
    return ColoredBox(
      color: _ink,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 비스듬한 붉은 띠
          Positioned(
            left: -60,
            top: 40,
            width: 560,
            height: 70,
            child: Transform.rotate(
              angle: -14 * math.pi / 180,
              child: const ColoredBox(color: _red),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 118,
            bottom: 186,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (step == _introStep) ...[
                    const SizedBox(
                      width: 318,
                      height: 180,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: _IntroVisual(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (step == _introStep || pick) ...[
                    _Buttons(intro: step == _introStep),
                    const SizedBox(height: 16),
                  ] else ...[
                    TutorialLookAtTablet(
                      tabletWidth: 220,
                      glow: _red,
                      titleGap: 20,
                      titleStyle: RouletteType.display(40, _cream, height: 1.2),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TutorialPhaseCaption(
                    phases: phases,
                    sub: sub,
                    riseOffset: 14,
                    style: RouletteType.display(
                      pick ? 40 : 36,
                      _cream,
                      height: 1.35,
                    ),
                    subStyle: RouletteType.display(28, _cream, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 70,
            child: Center(
              child: _RrSkip(on: view.skipOn, onPressed: view.toggleSkip),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2단계 설명 그림입니다(돌리기 → 방패).
class _IntroVisual extends StatelessWidget {
  const _IntroVisual();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 340,
    height: 214,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        // 돌리기: 총구가 옆 사람에게 한 칸 넘어갑니다.
        TutorialTimed(
          to: _sec(3.2),
          fade: _ms(300),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 60,
                top: 12,
                width: 190,
                height: 190,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _cream,
                    shape: BoxShape.circle,
                    border: Border.all(color: _ink, width: 6),
                    boxShadow: const [
                      BoxShadow(color: _cream, spreadRadius: 4),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 60,
                top: 12,
                width: 190,
                height: 190,
                child: const _IntroGun(),
              ),
              Positioned(left: 258, top: -4, child: _face(1, 68)),
              Positioned(left: 258, top: 148, child: _face(2, 68)),
              Positioned(
                left: 258,
                top: 84,
                child: TutorialAppear(
                  delay: _sec(1.8),
                  duration: _ms(300),
                  fromScale: .6,
                  offset: Offset.zero,
                  child: Container(
                    color: _red,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      _t('+1칸', '+1 seat', '+1格', '+1格'),
                      style: RouletteType.display(24, _cream),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 방패: 프로필 앞에 방패가 섭니다.
        TutorialTimed(
          from: _sec(3.4),
          to: _sec(7.8),
          fade: _ms(300),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(left: 115, top: 0, child: _face(2, 110)),
              Positioned(
                left: 70,
                top: 108,
                child: TutorialAppear(
                  delay: _sec(3.9),
                  duration: _ms(500),
                  fromScale: .3,
                  offset: const Offset(0, -20),
                  child: SizedBox(
                    width: 200,
                    height: 80,
                    child: Center(
                      child: Transform.rotate(
                        angle: math.pi,
                        child: const RouletteShieldTop(width: 200),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 178,
                child: Center(
                  child: TutorialAppear(
                    delay: _sec(5.9),
                    duration: _ms(350),
                    fromScale: .6,
                    offset: Offset.zero,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _red,
                        border: Border.all(color: _cream, width: 3),
                      ),
                      child: Text(
                        _t(
                          '2턴 연속 사용 불가',
                          'Not two turns in a row',
                          '不能连续2回合使用',
                          '不能連續2回合使用',
                        ),
                        style: RouletteType.display(24, _cream),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _face(int i, double size) => Container(
    padding: const EdgeInsets.all(4),
    color: _cream,
    child: RouletteProfile(characterId: _cast[i].$2, size: size),
  );
}

/// 설명 그림 속 총입니다(0.9초에 한 칸 돕니다).
class _IntroGun extends StatefulWidget {
  const _IntroGun();

  @override
  State<_IntroGun> createState() => _IntroGunState();
}

class _IntroGunState extends State<_IntroGun>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _ms(800),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_ms(900), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final k = _gunCurve.transform(_c.value);
      final deg = -40 + 80 * k;
      return RouletteRevolver(
        size: 190,
        angle: deg * math.pi / 180,
        disc: false,
      );
    },
  );
}

/// 행동 버튼 세 개입니다(돌리기·방패·안 함).
class _Buttons extends StatelessWidget {
  const _Buttons({required this.intro});

  /// 2단계면 순서대로 불이 들어오고, 3단계면 '돌리기'를 고릅니다.
  final bool intro;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _button(
          icon: Icons.rotate_right,
          label: _t('돌리기', 'Spin', '转动', '轉動'),
          desc: _t('총구 +1칸', 'Gun +1 seat', '枪口 +1格', '槍口 +1格'),
          descAt: .1,
          on: intro ? (_sec(.3), _sec(3.2)) : (_sec(.7), null),
        ),
        const SizedBox(width: 6),
        _button(
          icon: Icons.shield,
          label: _t('방패', 'Shield', '护盾', '護盾'),
          desc: _t('맞아도 생존', 'Survive a hit', '中弹也能存活', '中彈也能存活'),
          descAt: .25,
          on: intro ? (_sec(3.4), _sec(7.8)) : null,
        ),
        const SizedBox(width: 6),
        _button(
          icon: Icons.remove_circle_outline,
          label: _t('안 함', 'Nothing', '不行动', '不行動'),
          desc: _t('총구 그대로', 'Gun stays', '枪口不动', '槍口不動'),
          descAt: .4,
          on: intro ? (_sec(8.0), null) : null,
          auto: intro,
        ),
      ],
    ),
  );

  Widget _button({
    required IconData icon,
    required String label,
    required String desc,
    required double descAt,
    required (Duration, Duration?)? on,
    bool auto = false,
  }) {
    final box = _RrActionBox(icon: icon, label: label, on: on);
    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (auto)
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                box,
                Positioned(
                  top: -18,
                  child: TutorialTimed(
                    from: _sec(10.9),
                    fade: _ms(200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _red,
                        border: Border.all(color: _cream, width: 2),
                      ),
                      child: Text(
                        _t('자동 선택', 'Auto pick', '自动选择', '自動選擇'),
                        style: RouletteType.display(16, _cream),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            box,
          const SizedBox(height: 8),
          TutorialTimed(
            from: _sec(descAt),
            fade: _ms(300),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(desc, style: RouletteType.display(18, _cream)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 행동 버튼 한 칸입니다. [on] 구간에는 바탕이 밝아집니다.
class _RrActionBox extends StatelessWidget {
  const _RrActionBox({
    required this.icon,
    required this.label,
    required this.on,
  });

  final IconData icon;
  final String label;
  final (Duration, Duration?)? on;

  @override
  Widget build(BuildContext context) {
    final window = on;
    Widget box(bool lit) => AnimatedContainer(
      duration: _ms(200),
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: lit ? _cream : Colors.transparent,
        border: Border.all(color: _cream, width: 3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 38, color: lit ? _ink : _cream),
          const SizedBox(height: 6),
          Text(label, style: RouletteType.display(20, lit ? _ink : _cream)),
        ],
      ),
    );
    if (window == null) return box(false);
    return _Window(from: window.$1, to: window.$2, builder: box);
  }
}

/// [from]~[to] 동안 켜지는 값을 건네줍니다.
class _Window extends StatefulWidget {
  const _Window({required this.from, required this.to, required this.builder});

  final Duration from;
  final Duration? to;
  final Widget Function(bool on) builder;

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
    if (!_on) _timers.add(Timer(widget.from, () => _set(true)));
    final to = widget.to;
    if (to != null) _timers.add(Timer(to, () => _set(false)));
  }

  void _set(bool on) {
    if (mounted) setState(() => _on = on);
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_on);
}

/// 시안 건너뛰기 버튼입니다.
class _RrSkip extends StatelessWidget {
  const _RrSkip({required this.on, required this.onPressed});

  final bool on;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(minWidth: 260),
        height: 80,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: BoxDecoration(
          color: on ? _cream : Colors.transparent,
          border: Border.all(color: _cream, width: 4),
        ),
        child: Text(
          on
              ? _t('건너뛰기 취소', 'Cancel skip', '取消跳过', '取消跳過')
              : _t('건너뛰기', 'Skip', '跳过', '跳過'),
          style: RouletteType.display(32, on ? _ink : _cream),
        ),
      ),
    ),
  );
}
