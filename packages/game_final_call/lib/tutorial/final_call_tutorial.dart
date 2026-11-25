// [final_call_tutorial.dart] 파이널콜 '1분 요약' 튜토리얼(태블릿 + 휴대폰)이다.
//
// 장면이 정해진 시간마다 저절로 넘어갑니다(GameTutorial.autoPlay). 태블릿은
// 그림, 휴대폰은 설명 문구와 실제 게임 조작 화면(손패·조작 패널)을 보여 줍니다.
// 휴대폰에서 볼 게 없는 장면은 '태블릿을 봐 주세요!'에 설명 문구를 붙입니다.
//
// 단계
//  0 시작 · 1 팀 · 2 카드 4장 · 3 점수 계산 · 4 내 차례 · 5 바꾸기 · 6 CALL
//  7 나머지 한 번씩 교체 · 8 카드 공개 · 9 포카드 완성 · 10 포카드 CALL
//  11 다른 사람이 먼저 CALL · 12 팀 탈락 · 13 승리 · 14 팀원 생존 · 15 끝

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';
import 'package:game_kit/tutorial/game_tutorial.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/widgets/card_view.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';

// ============================================================

String _t(String ko, String en, String zhHans, String zhHant) =>
    GameLocale.select(ko: ko, en: en, zhHans: zhHans, zhHant: zhHant);

Duration _ms(num ms) => Duration(milliseconds: ms.round());

const _ink = FinalCallColors.ink;
const _lilac = FinalCallColors.lilac;
const _violet = FinalCallColors.violet;
const _muted = FinalCallColors.muted;
const _red = FinalCallColors.red;
const _blue = FinalCallColors.blue;
const _green = FinalCallColors.green;
const _yellow = FinalCallColors.yellow;

FinalCallCard _c(String color, int value) =>
    FinalCallCard(id: '$color$value', color: color, value: value);

Widget _card(String color, int value, double width) =>
    FinalCallCardFace(card: _c(color, value), width: width);

Widget _back(double width) => FinalCallCardBack(width: width);

/// 튜토리얼 예시 손패(빨강7 빨강3 파랑7 노랑2)입니다.
const _hand = [('red', 7), ('red', 3), ('blue', 7), ('yellow', 2)];

/// 자리 번호로 정한 팀입니다(서버와 같은 규칙: seat % (인원/2)).
int _teamOf(int seat, int count) => seat % math.max(1, count ~/ 2);

Color _teamColor(int team) => switch (team) {
  0 => _red,
  1 => _blue,
  _ => _green,
};

String _teamName(int team) => switch (team) {
  0 => _t('빨강 팀', 'Red team', '红队', '紅隊'),
  1 => _t('파랑 팀', 'Blue team', '蓝队', '藍隊'),
  _ => _t('초록 팀', 'Green team', '绿队', '綠隊'),
};

class FinalCallTutorial extends GameTutorial {
  const FinalCallTutorial();

  static const _durations = [
    2600, 4600, 4600, 7200, 6400, 7600, 4600, 5600, //
    7800, 6200, 5800, 6600, 5000, 2800, 5400,
  ];

  @override
  String get gameId => 'final_call';

  @override
  String get title => GameLocale.select(
    ko: '파이널콜',
    en: 'Final Call',
    zhHans: '最终宣告',
    zhHant: '最終宣告',
  );

  @override
  int get stepCount => _durations.length + 1;

  @override
  bool isInfo(int step, int phase) => true;

  @override
  bool get autoPlay => true;

  /// 파이널콜 휴대폰 게임 화면은 가로라서 튜토리얼도 가로로 보여 줍니다.
  @override
  bool get phoneLandscape => true;

  @override
  Size get phoneDesignSize => const Size(844, 390);

  @override
  Duration autoDuration(int step) =>
      _ms(_durations[step.clamp(0, _durations.length - 1)]);

  @override
  Widget buildTabletBackground(BuildContext context) =>
      const FinalCallPopBackground();

  @override
  Widget buildPhoneBackground(BuildContext context) =>
      const FinalCallPopBackground();

  @override
  Widget buildTablet(BuildContext context, TutorialTabletView view) =>
      _FcTablet(view: view);

  @override
  Widget buildPhone(BuildContext context, TutorialPhoneView view) =>
      _FcPhone(view: view);

  @override
  Widget buildPhoneEnd(BuildContext context, TutorialPhoneView view) =>
      TutorialLookAtTablet(
        titleStyle: finalCallPopText(
          34,
          color: _lilac,
          shadows: finalCallPopOutline(3),
        ),
        body: Text(
          _t(
            '곧 카드를 4장씩 나눠 줘요\n내 카드는 이 휴대폰에만 보여요',
            'Cards are dealt soon\nYour cards show only on this phone',
            '马上发4张牌\n你的牌只显示在这部手机上',
            '馬上發4張牌\n你的牌只顯示在這支手機上',
          ),
          textAlign: TextAlign.center,
          style: finalCallPopText(18, color: _lilac, height: 1.5),
        ),
      );

  @override
  Widget buildAutoEndSlogan(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: _t('팀과 함께\n', 'With your team,\n', '和队友一起\n', '和隊友一起\n'),
          style: const TextStyle(color: _red),
        ),
        TextSpan(
          text: _t(
            '마지막까지 하트를 지키세요!',
            'protect your hearts to the end!',
            '守护爱心到最后！',
            '守護愛心到最後！',
          ),
        ),
      ],
    ),
    textAlign: TextAlign.center,
    style: finalCallPopText(
      60,
      color: _lilac,
      height: 1.25,
      shadows: finalCallPopOutline(4),
    ),
  );
}

//======================================================================
// 공용 조각
//======================================================================
class _Chip extends StatelessWidget {
  const _Chip(
    this.text, {
    this.color = Colors.white,
    this.textColor = _ink,
    this.size = 20,
  });

  final String text;
  final Color color;
  final Color textColor;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: _ink, width: 3),
      boxShadow: const [BoxShadow(color: _ink, offset: Offset(0, 3))],
    ),
    child: Text(text, style: finalCallPopText(size, color: textColor)),
  );
}

/// 한 점에서 다른 점으로 날아갑니다(중심 좌표).
class _Fly extends StatefulWidget {
  const _Fly({
    required this.from,
    required this.to,
    required this.child,
    this.fromAngle = 0,
    this.toAngle = 0,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 600),
    this.hideAt,
  });

  final Offset from;
  final Offset to;
  final double fromAngle;
  final double toAngle;
  final Duration delay;
  final Duration duration;
  final Duration? hideAt;
  final Widget child;

  @override
  State<_Fly> createState() => _FlyState();
}

class _FlyState extends State<_Fly> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  final List<Timer> _timers = [];
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _timers.add(
      Timer(widget.delay, () {
        if (mounted) _c.forward();
      }),
    );
    final hideAt = widget.hideAt;
    if (hideAt != null) {
      _timers.add(
        Timer(hideAt, () {
          if (mounted) setState(() => _hidden = true);
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(_c.value);
      final p = Offset.lerp(widget.from, widget.to, t)!;
      return Positioned(
        left: p.dx,
        top: p.dy,
        child: FractionalTranslation(
          translation: const Offset(-.5, -.5),
          child: Opacity(
            opacity: _c.value == 0 || _hidden ? 0 : 1,
            child: Transform.rotate(
              angle: widget.fromAngle + (widget.toAngle - widget.fromAngle) * t,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// 뒷면에서 앞면으로 뒤집힙니다.
class _Flip extends StatefulWidget {
  const _Flip({
    required this.front,
    required this.width,
    this.delay = Duration.zero,
  });

  final Widget front;
  final double width;
  final Duration delay;

  @override
  State<_Flip> createState() => _FlipState();
}

class _FlipState extends State<_Flip> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _ms(420),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
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
      final v = Curves.easeInOut.transform(_c.value);
      final front = v >= .5;
      final angle = front ? math.pi * (1 - v) : math.pi * v;
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0015)
          ..rotateY(angle),
        child: front ? widget.front : _back(widget.width),
      );
    },
  );
}

/// 자리 프로필입니다: 팀 색 테두리 아바타와 하트 3개.
class _Seat extends StatelessWidget {
  const _Seat({
    required this.player,
    required this.color,
    required this.lives,
    this.breakAt,
    this.out = false,
  });

  final TutorialPlayer player;
  final Color color;
  final int lives;

  /// 이 시각에 하트 하나가 깨집니다.
  final Duration? breakAt;
  final bool out;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: out ? .35 : 1,
            child: FinalCallPopAvatar(
              characterId: player.characterId,
              color: color,
              size: 84,
              borderWidth: 5,
            ),
          ),
          if (out)
            const TutorialAppear(
              fromScale: .5,
              offset: Offset.zero,
              child: Icon(Icons.close_rounded, color: _red, size: 96),
            ),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var k = 0; k < 3; k++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: k == lives - 1 && breakAt != null
                  ? _BreakingHeart(color: color, at: breakAt!)
                  : FinalCallPopHeart(
                      color: color,
                      filled: k < lives,
                      size: 22,
                    ),
            ),
        ],
      ),
    ],
  );
}

class _BreakingHeart extends StatefulWidget {
  const _BreakingHeart({required this.color, required this.at});

  final Color color;
  final Duration at;

  @override
  State<_BreakingHeart> createState() => _BreakingHeartState();
}

class _BreakingHeartState extends State<_BreakingHeart> {
  bool _broken = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.at, () {
      if (mounted) setState(() => _broken = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedScale(
    duration: _ms(400),
    curve: Curves.easeOutBack,
    scale: _broken ? .8 : 1,
    child: FinalCallPopHeart(color: widget.color, filled: !_broken, size: 22),
  );
}

//======================================================================
// 태블릿
//======================================================================
class _FcTablet extends StatelessWidget {
  const _FcTablet({required this.view});

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

  double _facing(Offset seat) {
    final d = seat - _center;
    return math.atan2(d.dy, d.dx) - math.pi / 2;
  }

  Offset _toward(Offset seat, double k) => _center + (seat - _center) * k;

  int _team(int i) => _teamOf(view.players[i].seatIndex, _n);

  /// 예시의 나(자리 배치 첫 번째)입니다.
  static const _me = 0;

  @override
  Widget build(BuildContext context) {
    final seats = _seats;
    final step = view.step;
    final myTeam = view.players.isEmpty ? 0 : _team(_me);
    final rivals = [
      for (var i = 0; i < view.players.length; i++)
        if (_team(i) != myTeam) i,
    ];
    // 팀 탈락(12)·승리(13·14)에서는 우리 팀이 아닌 쪽이 탈락한 모습입니다.
    final endGame = step >= 12;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 둥근 테이블
        Positioned(
          left: _center.dx - 230,
          top: _center.dy - 230,
          width: 460,
          height: 460,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: _lilac,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(BorderSide(color: _ink, width: 5)),
              boxShadow: [BoxShadow(color: _ink, offset: Offset(0, 10))],
            ),
          ),
        ),
        for (var i = 0; i < view.players.length; i++)
          Positioned(
            left: seats[i].dx - 70,
            top: seats[i].dy - 70,
            width: 140,
            height: 140,
            child: Transform.rotate(
              angle: _facing(seats[i]),
              child: Center(
                child: _Seat(
                  player: view.players[i],
                  color: step >= 1 ? _teamColor(_team(i)) : _ink,
                  lives: endGame && rivals.contains(i) ? 0 : 3,
                  out: endGame && rivals.contains(i),
                  breakAt: step == 10 && rivals.contains(i) ? _ms(2300) : null,
                ),
              ),
            ),
          ),
        ..._middle(seats, myTeam, rivals),
      ],
    );
  }

  Widget _seatDim(Offset seat, Duration from, Duration? to) => Positioned(
    left: seat.dx - 80,
    top: seat.dy - 80,
    width: 160,
    height: 160,
    child: TutorialTimed(
      from: from,
      to: to,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xC7140E30),
          shape: BoxShape.circle,
        ),
      ),
    ),
  );

  Widget _seatGlow(Offset seat, Color color, Duration from, Duration? to) =>
      Positioned(
        left: seat.dx - 50,
        top: seat.dy - 62,
        width: 100,
        height: 100,
        child: IgnorePointer(
          child: TutorialTimed(
            from: from,
            to: to,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color, spreadRadius: 6),
                  BoxShadow(
                    color: color.withValues(alpha: .7),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _centered(Widget child, {Offset offset = Offset.zero}) => Positioned(
    left: _center.dx + offset.dx - 400,
    top: _center.dy + offset.dy - 300,
    width: 800,
    height: 600,
    child: Center(child: child),
  );

  List<Widget> _middle(List<Offset> seats, int myTeam, List<int> rivals) {
    final n = view.players.length;
    final teamCount = math.max(1, _n ~/ 2);
    switch (view.step) {
      case 0:
        return [
          _centered(
            TutorialAppear(
              fromScale: .6,
              offset: Offset.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (k, color) in [
                        (0, 'red'),
                        (1, 'blue'),
                        (2, 'green'),
                        (3, 'yellow'),
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Transform.rotate(
                            angle: (k - 1.5) * .12,
                            child: _card(color, 7, 76),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'FINAL CALL',
                    style: finalCallPopText(
                      64,
                      color: _red,
                      shadows: finalCallPopRing(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      case 1:
        // 팀마다 차례로 다른 팀을 어둡게 하고 같은 팀만 빛나게 합니다.
        final slot = 4600 / teamCount;
        return [
          for (var team = 0; team < teamCount; team++) ...[
            for (var i = 0; i < n; i++)
              if (_team(i) != team)
                _seatDim(
                  seats[i],
                  _ms(300 + team * slot),
                  team == teamCount - 1 ? null : _ms((team + 1) * slot),
                )
              else
                _seatGlow(
                  seats[i],
                  _teamColor(team),
                  _ms(300 + team * slot),
                  team == teamCount - 1 ? null : _ms((team + 1) * slot),
                ),
            _centered(
              TutorialTimed(
                from: _ms(300 + team * slot),
                to: team == teamCount - 1 ? null : _ms((team + 1) * slot),
                child: _Chip(
                  '${_teamName(team)} · ${[for (var i = 0; i < n; i++)
                    if (_team(i) == team) view.players[i].nickname].join(' + ')}',
                  color: _teamColor(team),
                  textColor: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ],
        ];
      case 2:
        return [
          _centered(_back(80)),
          for (var k = 0; k < n * 4; k++)
            _Fly(
              from: _center,
              to: _toward(seats[k % n], .7),
              toAngle: _facing(seats[k % n]),
              delay: _ms(300 + k * 90),
              duration: _ms(450),
              child: _back(48),
            ),
        ];
      case 3:
        return [_centered(const _ScoreDemo())];
      case 4:
        return [_centered(const _TurnDemo())];
      case 5:
        return [_centered(const _SwapDemo())];
      case 6:
        final mySeat = seats.isEmpty ? _center : seats[_me];
        return [
          Positioned.fill(
            child: Stack(
              children: [
                Positioned(
                  left: _toward(mySeat, .4).dx - 150,
                  top: _toward(mySeat, .4).dy - 50,
                  width: 300,
                  child: TutorialAppear(
                    delay: _ms(2000),
                    fromScale: .5,
                    offset: Offset.zero,
                    child: Center(
                      child: Text(
                        'CALL!',
                        style: finalCallPopText(
                          72,
                          color: _red,
                          shadows: finalCallPopRing(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      case 7:
        // 나를 뺀 사람이 자리 순서대로 한 장 가져가고 한 장 버립니다.
        final others = [
          for (var i = 0; i < n; i++)
            if (i != _me) i,
        ];
        const discards = [
          ('red', 1),
          ('yellow', 4),
          ('blue', 2),
          ('green', 3),
          ('yellow', 9),
        ];
        final deck = _center + const Offset(-44, 0);
        final open = _center + const Offset(44, 0);
        return [
          Positioned(left: deck.dx - 32, top: deck.dy - 47, child: _back(64)),
          Positioned(
            left: open.dx - 32,
            top: open.dy - 47,
            child: _card('yellow', 2, 64),
          ),
          for (var j = 0; j < others.length; j++) ...[
            _Fly(
              from: deck,
              to: _toward(seats[others[j]], .62),
              toAngle: _facing(seats[others[j]]),
              delay: _ms(500 + j * 1200),
              hideAt: _ms(1400 + j * 1200),
              child: _back(64),
            ),
            _Fly(
              from: _toward(seats[others[j]], .62),
              to: open,
              fromAngle: _facing(seats[others[j]]),
              delay: _ms(1200 + j * 1200),
              child: _card(
                discards[j % discards.length].$1,
                discards[j % discards.length].$2,
                64,
              ),
            ),
          ],
          if (seats.isNotEmpty)
            Positioned(
              left: _toward(seats[_me], .55).dx - 120,
              top: _toward(seats[_me], .55).dy - 20,
              width: 240,
              child: Center(
                child: _Chip(
                  _t(
                    'CALL · 교체 없음',
                    'CALL · no swap',
                    'CALL · 不换牌',
                    'CALL · 不換牌',
                  ),
                  color: _red,
                  textColor: Colors.white,
                  size: 18,
                ),
              ),
            ),
          _centered(
            TutorialAppear(
              delay: _ms(600 + others.length * 1200),
              child: _Chip(
                _t('모두 공개!', 'Reveal!', '全部公开！', '全部公開！'),
                color: _violet,
                textColor: Colors.white,
                size: 24,
              ),
            ),
            offset: const Offset(0, -130),
          ),
        ];
      case 8:
        return _reveal(seats);
      case 9:
        return [
          _centered(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TutorialAppear(
                  child: _Chip(
                    _t('★ 특별 규칙 ★', '★ Special rule ★', '★ 特别规则 ★', '★ 特別規則 ★'),
                    color: _yellow,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 18),
                const _Sevens(width: 70),
                const SizedBox(height: 14),
                TutorialAppear(
                  delay: _ms(1000),
                  fromScale: .5,
                  offset: Offset.zero,
                  child: Text(
                    'FOUR CARD!',
                    style: finalCallPopText(
                      44,
                      color: _yellow,
                      shadows: finalCallPopRing(2.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      case 10:
        return [
          _centered(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Sevens(width: 64),
                const SizedBox(height: 12),
                TutorialAppear(
                  delay: _ms(1100),
                  fromScale: .5,
                  offset: Offset.zero,
                  child: Text(
                    _t('포카드 CALL!', 'Four-card CALL!', '四条 CALL！', '四條 CALL！'),
                    style: finalCallPopText(
                      44,
                      color: _red,
                      shadows: finalCallPopRing(2.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 상대 팀 자리만 남기고 어둡게 덮습니다.
          Positioned.fill(
            child: IgnorePointer(
              child: TutorialTimed(
                from: _ms(1800),
                child: CustomPaint(
                  painter: _SpotlightPainter(
                    holes: [for (final i in rivals) seats[i]],
                    radius: 96,
                  ),
                ),
              ),
            ),
          ),
          for (final i in rivals)
            _seatGlow(seats[i], _teamColor(_team(i)), _ms(1900), null),
        ];
      case 11:
        final rival = rivals.isEmpty ? _me : rivals.first;
        return [
          if (seats.isNotEmpty)
            Positioned(
              left: _toward(seats[rival], .55).dx - 100,
              top: _toward(seats[rival], .55).dy - 40,
              width: 200,
              child: TutorialAppear(
                delay: _ms(1400),
                fromScale: .5,
                offset: Offset.zero,
                child: Center(
                  child: Transform.rotate(
                    angle: _facing(seats[rival]),
                    child: Text(
                      'CALL!',
                      style: finalCallPopText(
                        40,
                        color: _red,
                        shadows: finalCallPopRing(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          _centered(const _FourIgnored()),
        ];
      case 12:
        final rivalTeam = rivals.isEmpty ? 1 : _team(rivals.first);
        return [
          _centered(
            TutorialAppear(
              delay: _ms(600),
              child: _Chip(
                _t(
                  '팀원 하트 0개 → ${_teamName(rivalTeam)} 둘 다 탈락',
                  'A teammate hit 0 hearts → ${_teamName(rivalTeam)} is out',
                  '队友爱心归零 → ${_teamName(rivalTeam)} 两人都淘汰',
                  '隊友愛心歸零 → ${_teamName(rivalTeam)} 兩人都淘汰',
                ),
                size: 22,
              ),
            ),
          ),
        ];
      default:
        return [
          _centered(
            TutorialAppear(
              fromScale: .6,
              offset: Offset.zero,
              child: Text(
                _t(
                  '${_teamName(myTeam)} 승리!',
                  '${_teamName(myTeam)} wins!',
                  '${_teamName(myTeam)} 获胜！',
                  '${_teamName(myTeam)} 獲勝！',
                ),
                style: finalCallPopText(
                  60,
                  color: _teamColor(myTeam),
                  shadows: finalCallPopRing(3),
                ),
              ),
            ),
          ),
        ];
    }
  }

  /// 자리 순서대로 최종 조합을 한 장씩 뒤집고 점수를 띄웁니다. 가장 낮은 사람은 하트 −1.
  List<Widget> _reveal(List<Offset> seats) {
    const hands = [
      [('red', 7), ('blue', 7), ('green', 7)],
      [('blue', 9), ('blue', 6)],
      [('green', 4), ('green', 5), ('green', 8)],
      [('yellow', 10), ('yellow', 3)],
      [('red', 8), ('blue', 8)],
      [('yellow', 6), ('yellow', 9)],
    ];
    const scores = [21, 15, 17, 13, 16, 15];
    final n = view.players.length;
    var lowest = 0;
    for (var i = 1; i < n; i++) {
      if (scores[i % scores.length] < scores[lowest % scores.length]) {
        lowest = i;
      }
    }
    var cursor = 800.0;
    final out = <Widget>[];
    for (var i = 0; i < n; i++) {
      final hand = hands[i % hands.length];
      final score = scores[i % scores.length];
      final start = cursor;
      cursor += 300.0 * hand.length + 400;
      final pos = _toward(seats[i], .55);
      out.add(
        Positioned(
          left: pos.dx - 130,
          top: pos.dy - 90,
          width: 260,
          height: 180,
          child: Transform.rotate(
            angle: _facing(seats[i]),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TutorialAppear(
                  delay: _ms(start + hand.length * 300 + 100),
                  fromScale: .6,
                  offset: Offset.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (i == _me)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: FinalCallPopTag(
                            label: 'CALL',
                            color: _red,
                            textColor: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      FinalCallPopBox(
                        radius: 16,
                        borderWidth: 4,
                        shadowDepth: 4,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          '$score',
                          style: finalCallPopText(
                            30,
                            color: score <= 13 ? _red : _violet,
                          ),
                        ),
                      ),
                      if (i == lowest) ...[
                        const SizedBox(width: 6),
                        TutorialAppear(
                          delay: _ms(cursor + 600),
                          child: const FinalCallPopTag(
                            label: '♥ −1',
                            color: _red,
                            textColor: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var k = 0; k < hand.length; k++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: TutorialAppear(
                          offset: const Offset(0, 60),
                          duration: _ms(420),
                          curve: Curves.easeOutCubic,
                          delay: _ms(100 + i * 80 + k * 90),
                          child: _Flip(
                            delay: _ms(start + k * 300),
                            width: 44,
                            front: _card(hand[k].$1, hand[k].$2, 44),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return out;
  }
}

/// 다른 곳은 어둡게, [holes]만 동그랗게 비춥니다.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.holes, required this.radius});

  final List<Offset> holes;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()..addRect(Offset.zero & size);
    for (final hole in holes) {
      path = Path.combine(
        PathOperation.difference,
        path,
        Path()..addOval(Rect.fromCircle(center: hole, radius: radius)),
      );
    }
    canvas.drawPath(path, Paint()..color = const Color(0xCC0E0928));
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) => false;
}

/// 금빛으로 빛나는 7 네 장입니다.
class _Sevens extends StatelessWidget {
  const _Sevens({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (k, color) in [
        (0, 'red'),
        (1, 'blue'),
        (2, 'green'),
        (3, 'yellow'),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: TutorialAppear(
            delay: _ms(300 + k * 120),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(width * .14),
                boxShadow: [
                  const BoxShadow(color: _yellow, spreadRadius: 4),
                  BoxShadow(
                    color: _yellow.withValues(alpha: .7),
                    blurRadius: 18,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: _card(color, 7, width),
            ),
          ),
        ),
    ],
  );
}

/// 점수 계산 예시: 같은 색 7+3=10, 같은 숫자 7+7=14 → 14점.
class _ScoreDemo extends StatelessWidget {
  const _ScoreDemo();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var k = 0; k < _hand.length; k++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TutorialAppear(
                delay: _ms(200 + k * 120),
                child: _Ringed(
                  color: _red,
                  on: _hand[k].$1 == 'red' ? _ms(1000) : null,
                  off: _ms(2900),
                  second: _hand[k].$2 == 7 ? _ms(3100) : null,
                  child: _card(_hand[k].$1, _hand[k].$2, 96),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 26),
      SizedBox(
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TutorialTimed(
              from: _ms(1500),
              to: _ms(2900),
              child: _Chip(
                _t(
                  '같은 색 7 + 3 = 10',
                  'Same color 7 + 3 = 10',
                  '同色 7 + 3 = 10',
                  '同色 7 + 3 = 10',
                ),
                color: _red,
                textColor: Colors.white,
                size: 24,
              ),
            ),
            TutorialTimed(
              from: _ms(3400),
              to: _ms(4900),
              child: _Chip(
                _t(
                  '같은 숫자 7 + 7 = 14',
                  'Same number 7 + 7 = 14',
                  '同数字 7 + 7 = 14',
                  '同數字 7 + 7 = 14',
                ),
                color: _yellow,
                size: 24,
              ),
            ),
            TutorialTimed(
              from: _ms(5100),
              child: FinalCallPopBox(
                radius: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 2,
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '10 vs 14 → '),
                      TextSpan(
                        text: _t('14점', '14 pts', '14分', '14分'),
                        style: const TextStyle(color: _red),
                      ),
                    ],
                  ),
                  style: finalCallPopText(34),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// 카드 둘레의 강조 테두리입니다. [on]~[off]는 빨강, [second]부터는 노랑입니다.
class _Ringed extends StatefulWidget {
  const _Ringed({
    required this.child,
    required this.color,
    this.on,
    this.off,
    this.second,
  });

  final Widget child;
  final Color color;
  final Duration? on;
  final Duration? off;
  final Duration? second;

  @override
  State<_Ringed> createState() => _RingedState();
}

class _RingedState extends State<_Ringed> {
  Color? _ring;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    final on = widget.on;
    if (on != null) {
      _timers.add(Timer(on, () => _set(widget.color)));
      final off = widget.off;
      if (off != null) _timers.add(Timer(off, () => _set(null)));
    }
    final second = widget.second;
    if (second != null) _timers.add(Timer(second, () => _set(_yellow)));
  }

  void _set(Color? color) {
    if (mounted) setState(() => _ring = color);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: _ms(200),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _ring ?? Colors.transparent, width: 5),
    ),
    child: widget.child,
  );
}

/// 내 차례: 덱·공개 카드가 점선으로 빛나고, 그다음 CALL!이 뜹니다.
class _TurnDemo extends StatelessWidget {
  const _TurnDemo();

  Widget _pile(Widget card, String label, Duration ring) => Stack(
    clipBehavior: Clip.none,
    children: [
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          card,
          const SizedBox(height: 6),
          Text(label, style: finalCallPopText(17, color: _muted)),
        ],
      ),
      Positioned(
        left: -12,
        right: -12,
        top: -12,
        bottom: -12,
        child: TutorialTimed(
          from: ring,
          to: _ms(3000),
          child: const _DashedBox(),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pile(_back(96), _t('덱', 'Deck', '牌堆', '牌堆'), _ms(1000)),
          const SizedBox(width: 44),
          _pile(
            _card('green', 7, 96),
            _t('공개 카드', 'Open card', '明牌', '明牌'),
            _ms(1200),
          ),
        ],
      ),
      const SizedBox(height: 24),
      TutorialAppear(
        delay: _ms(3300),
        fromScale: .5,
        offset: Offset.zero,
        child: Text(
          'CALL!',
          style: finalCallPopText(
            54,
            color: _red,
            shadows: finalCallPopRing(2.5),
          ),
        ),
      ),
    ],
  );
}

class _DashedBox extends StatelessWidget {
  const _DashedBox();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: const _DashedPainter());
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      );
    final paint = Paint()
      ..color = _violet
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 10), paint);
        d += 17;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter oldDelegate) => false;
}

/// 공개 카드 초록 7을 가져와 노랑 2와 바꿉니다: 14 → 21점.
class _SwapDemo extends StatelessWidget {
  const _SwapDemo();

  @override
  Widget build(BuildContext context) {
    const w = 88.0;
    final h = w * finalCallCardHeightRatio;
    const gap = 14.0;
    const handLeft = 0.0;
    final handTop = h + 50;
    const openLeft = 3 * (w + gap);
    return SizedBox(
      width: 4 * w + 3 * gap,
      height: handTop + h + 10,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 2 * (w + gap),
            top: 0,
            child: Column(
              children: [
                _back(w),
                Text(
                  _t('덱', 'Deck', '牌堆', '牌堆'),
                  style: finalCallPopText(16, color: _muted),
                ),
              ],
            ),
          ),
          Positioned(
            left: openLeft,
            top: 0,
            child: SizedBox(width: w, height: h, child: const _DashedBox()),
          ),
          for (var k = 0; k < 3; k++)
            Positioned(
              left: handLeft + k * (w + gap),
              top: handTop,
              child: _card(_hand[k].$1, _hand[k].$2, w),
            ),
          // 노랑 2: 손패 → 공개 자리
          _Fly(
            from: Offset(openLeft + w / 2, handTop + h / 2),
            to: Offset(openLeft + w / 2, h / 2),
            delay: _ms(2600),
            duration: _ms(800),
            child: _card('yellow', 2, w),
          ),
          TutorialTimed(
            to: _ms(2600),
            child: Stack(
              children: [
                Positioned(
                  left: openLeft,
                  top: handTop,
                  child: _card('yellow', 2, w),
                ),
              ],
            ),
          ),
          // 초록 7: 공개 자리 → 손패
          _Fly(
            from: Offset(openLeft + w / 2, h / 2),
            to: Offset(openLeft + w / 2, handTop + h / 2),
            delay: _ms(1000),
            duration: _ms(900),
            child: _card('green', 7, w),
          ),
          TutorialTimed(
            to: _ms(1000),
            child: Stack(
              children: [
                Positioned(left: openLeft, top: 0, child: _card('green', 7, w)),
              ],
            ),
          ),
          Positioned(
            left: openLeft + w + 20,
            top: 10,
            child: TutorialAppear(
              delay: _ms(4200),
              child: FinalCallPopBox(
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '14 → '),
                      TextSpan(
                        text: _t('21점', '21 pts', '21分', '21分'),
                        style: const TextStyle(color: _green),
                      ),
                    ],
                  ),
                  style: finalCallPopText(28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 포카드를 들고 있어도 다른 사람이 먼저 CALL하면 점수(7 × 4 = 28점)로만 겨룹니다.
class _FourIgnored extends StatefulWidget {
  const _FourIgnored();

  @override
  State<_FourIgnored> createState() => _FourIgnoredState();
}

class _FourIgnoredState extends State<_FourIgnored> {
  bool _plain = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_ms(2400), () {
      if (mounted) setState(() => _plain = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TutorialTimed(
              from: _ms(400),
              to: _ms(2400),
              child: const _Chip('FOUR CARD!', color: _yellow, size: 20),
            ),
            TutorialTimed(
              from: _ms(2600),
              child: _Chip(
                _t('포카드 효과 없음', 'No four-card effect', '四条无效', '四條無效'),
                color: _red,
                textColor: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AnimatedOpacity(
        duration: _ms(400),
        opacity: _plain ? .6 : 1,
        child: const _Sevens(width: 66),
      ),
      const SizedBox(height: 14),
      TutorialAppear(
        delay: _ms(3200),
        child: FinalCallPopBox(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _t('7 × 4 = 28점', '7 × 4 = 28 pts', '7 × 4 = 28分', '7 × 4 = 28分'),
            style: finalCallPopText(30),
          ),
        ),
      ),
    ],
  );
}

//======================================================================
// 휴대폰
//======================================================================
class _FcPhone extends StatelessWidget {
  const _FcPhone({required this.view});

  final TutorialPhoneView view;

  /// 휴대폰에서 실제 조작 화면을 보여 주는 단계입니다.
  static const _uiSteps = {2, 3, 4, 5, 6, 9, 14};

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
        [p('파이널콜 1분 요약', 'Final Call in 1 minute', '1分钟看懂最终宣告', '1分鐘看懂最終宣告')],
        _t('태블릿과 함께 봐요', 'Watch with the tablet', '和平板一起看', '和平板一起看'),
      ),
      1 => (
        [
          p(
            '마주 앉은 사람이 내 팀이에요',
            'The player across is your teammate',
            '坐在对面的人是你的队友',
            '坐在對面的人是你的隊友',
          ),
          p(
            '팀원과 함께 하트 3개를 지켜요',
            'Protect 3 hearts together',
            '和队友一起守护3颗爱心',
            '和隊友一起守護3顆愛心',
            2400,
          ),
        ],
        null,
      ),
      2 => (
        [
          p('카드는 4장씩 받아요', 'Everyone gets 4 cards', '每人拿4张牌', '每人拿4張牌'),
          p(
            '내 카드는 내 휴대폰에만 보여요',
            'Your cards show only on your phone',
            '你的牌只显示在你的手机上',
            '你的牌只顯示在你的手機上',
            2400,
          ),
        ],
        null,
      ),
      3 => (
        [
          p('같은 색끼리 더하거나', 'Add cards of the same color', '把同色的牌相加', '把同色的牌相加'),
          p(
            '같은 숫자끼리 더해요 · 큰 쪽이 내 점수',
            'or the same number · the bigger is your score',
            '或把同数字相加 · 大的是你的分数',
            '或把同數字相加 · 大的是你的分數',
            3600,
          ),
        ],
        null,
      ),
      4 => (
        [
          p(
            '내 차례: 덱이나 공개 카드에서 1장',
            'Your turn: take 1 from the deck or open card',
            '轮到你：从牌堆或明牌拿1张',
            '輪到你：從牌堆或明牌拿1張',
          ),
          p(
            '또는 점수가 높으면 바로 CALL!',
            'or CALL right away if your score is high!',
            '分数高就直接 CALL！',
            '分數高就直接 CALL！',
            3200,
          ),
        ],
        null,
      ),
      5 => (
        [
          p(
            '가져온 카드는 내 카드 1장과 바꿔요',
            'Swap the new card with 1 of yours',
            '拿来的牌和你的1张牌交换',
            '拿來的牌和你的1張牌交換',
          ),
          p(
            '4장 중 아무거나 · 필요 없으면 버려요',
            'Any of the 4 · or discard it',
            '4张中任意一张 · 不需要就丢掉',
            '4張中任意一張 · 不需要就丟掉',
            4400,
          ),
        ],
        null,
      ),
      6 => (
        [
          p(
            'CALL은 꾹 눌러서 선언해요',
            'Hold to declare CALL',
            '长按宣布 CALL',
            '長按宣布 CALL',
          ),
          p(
            '점수가 제일 높을 것 같을 때!',
            'When you think your score is the highest!',
            '觉得自己分数最高的时候！',
            '覺得自己分數最高的時候！',
            2400,
          ),
        ],
        null,
      ),
      7 => (
        [
          p(
            'CALL하면 나를 뺀 모두가',
            'After a CALL, everyone else',
            'CALL 之后除了你以外的人',
            'CALL 之後除了你以外的人',
          ),
          p(
            '딱 한 번씩 카드를 더 바꿀 수 있어요',
            'gets exactly one more swap',
            '都能再换一次牌',
            '都能再換一次牌',
            2200,
          ),
        ],
        null,
      ),
      8 => (
        [
          p(
            '자리 순서대로 카드를 공개해요',
            'Cards are revealed seat by seat',
            '按座位顺序公开牌',
            '按座位順序公開牌',
          ),
          p(
            '가장 낮은 점수가 하트 1개를 잃어요 · CALL한 사람이 가장 낮으면 2개!',
            'Lowest loses 1 heart · 2 if the caller is lowest!',
            '最低分失去1颗爱心 · CALL 的人最低就失去2颗！',
            '最低分失去1顆愛心 · CALL 的人最低就失去2顆！',
            5200,
          ),
        ],
        null,
      ),
      9 => (
        [
          p(
            '★ 특별 규칙: 같은 숫자 4장 = 포카드!',
            '★ Special rule: 4 of a number = four card!',
            '★ 特别规则：同数字4张 = 四条！',
            '★ 特別規則：同數字4張 = 四條！',
          ),
          p(
            '포카드면 카드를 가져오지 말고 바로 CALL!',
            'With a four card, don’t draw — CALL now!',
            '有四条就别拿牌，直接 CALL！',
            '有四條就別拿牌，直接 CALL！',
            2800,
          ),
        ],
        null,
      ),
      10 => (
        [
          p('포카드로 CALL하면', 'A four-card CALL', '用四条 CALL', '用四條 CALL'),
          p(
            '점수 비교 없이 상대 팀 모두 하트 −1!',
            'makes every rival lose a heart!',
            '不比分数，对手全员爱心 −1！',
            '不比分數，對手全員愛心 −1！',
            1800,
          ),
        ],
        null,
      ),
      11 => (
        [
          p(
            '포카드를 모아도 다른 사람이 먼저 CALL하면',
            'If someone else calls first,',
            '就算凑成四条，别人先 CALL 的话',
            '就算湊成四條，別人先 CALL 的話',
          ),
          p(
            '포카드 효과 없이 점수로만 겨뤄요 (7 × 4 = 28점)',
            'it only counts as points (7 × 4 = 28)',
            '四条无效，只比分数（7 × 4 = 28分）',
            '四條無效，只比分數（7 × 4 = 28分）',
            2600,
          ),
        ],
        null,
      ),
      12 => (
        [
          p(
            '팀원 하트가 0이 되면',
            'When a teammate hits 0 hearts',
            '队友的爱心归零时',
            '隊友的愛心歸零時',
          ),
          p('두 사람 모두 탈락이에요', 'both of you are out', '两人都会被淘汰', '兩人都會被淘汰', 1800),
        ],
        null,
      ),
      13 => (
        [
          p(
            '마지막까지 남은 팀이 이겨요',
            'The last team standing wins',
            '坚持到最后的队伍获胜',
            '堅持到最後的隊伍獲勝',
          ),
        ],
        null,
      ),
      _ => (
        [
          p(
            '잊지 마세요! 점수 모으기도 중요하지만',
            'Remember! Scoring matters, but',
            '别忘了！拿分很重要',
            '別忘了！拿分很重要',
          ),
          p(
            '팀원이 살아남아야 우리 팀이 이겨요',
            'your teammate must survive for your team to win',
            '但队友活下来你们才能赢',
            '但隊友活下來你們才能贏',
            2400,
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
      style: finalCallPopText(ui ? 23 : 21, color: _lilac, height: 1.3),
      subStyle: finalCallPopText(17, color: _yellow),
    );
    return Stack(
      children: [
        if (ui) ...[
          // 위: 설명 문구(건너뛰기 버튼 자리는 비워 둡니다)
          Positioned(
            left: 20,
            right: 210,
            top: 8,
            height: 78,
            child: Center(child: caption),
          ),
          // 아래: 실제 게임처럼 왼쪽 손패, 오른쪽 조작 패널
          Positioned(
            left: 14,
            right: 14,
            top: 92,
            bottom: 12,
            child: _ui(step),
          ),
        ] else
          Positioned(
            left: 20,
            right: 20,
            top: 8,
            bottom: 8,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 560,
                child: TutorialLookAtTablet(
                  tabletWidth: 150,
                  titleStyle: finalCallPopText(
                    32,
                    color: _lilac,
                    shadows: finalCallPopOutline(3),
                  ),
                  body: caption,
                ),
              ),
            ),
          ),
        // 건너뛰기는 모든 장면에서 같은 자리(오른쪽 위)입니다.
        Positioned(
          right: 16,
          top: 16,
          child: TutorialAutoSkipButton(
            on: view.skipOn,
            onPressed: view.toggleSkip,
            color: _lilac,
            onColor: _yellow,
          ),
        ),
      ],
    );
  }

  Widget _ui(int step) => switch (step) {
    2 => const _PhoneHand(
      appearAt: Duration(milliseconds: 1000),
      bracket: (0, 2, '7 + 7 = 14점'),
    ),
    3 => const _PhoneScore(),
    4 => const _PhoneTurn(),
    5 => const _PhoneSwap(),
    6 => const _PhoneCall(),
    9 => const _PhoneFour(),
    _ => _PhoneTeam(players: view.players, me: view.me),
  };
}

/// 실제 게임 손패(카드 4장)와 아래 노란 괄호·계산식입니다.
class _PhoneHand extends StatelessWidget {
  const _PhoneHand({
    this.cards = _hand,
    this.appearAt,
    this.bracket,
    this.dimmed = const {},
    this.selected,
  });

  final List<(String, int)> cards;
  final Duration? appearAt;

  /// (첫 번호, 끝 번호, 계산식)입니다.
  final (int, int, String)? bracket;
  final Set<int> dimmed;
  final int? selected;

  static const w = 86.0;
  static const gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final h = w * finalCallCardHeightRatio;
    final b = bracket;
    return SizedBox(
      width: 4 * w + 3 * gap,
      height: h + 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var k = 0; k < cards.length; k++)
            Positioned(
              left: k * (w + gap),
              top: selected == k ? -14 : 0,
              child: TutorialAppear(
                delay: (appearAt ?? Duration.zero) + _ms(k * 120),
                child: AnimatedOpacity(
                  duration: _ms(300),
                  opacity: dimmed.contains(k) ? .35 : 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected == k ? _yellow : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: _card(cards[k].$1, cards[k].$2, w),
                  ),
                ),
              ),
            ),
          if (b != null)
            Positioned(
              left: b.$1 * (w + gap),
              width: (b.$2 - b.$1) * (w + gap) + w,
              top: h + 10,
              height: 40,
              child: TutorialAppear(
                delay: (appearAt ?? Duration.zero) + _ms(900),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned.fill(
                      bottom: 26,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: _yellow, width: 3),
                            right: BorderSide(color: _yellow, width: 3),
                            bottom: BorderSide(color: _yellow, width: 3),
                          ),
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Positioned(top: 8, child: FinalCallPopTag(label: b.$3)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 실제 조작 패널(흰 상자)입니다.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.height = 240});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) => FinalCallPopBox(
    width: 230,
    height: height,
    padding: const EdgeInsets.all(14),
    child: child,
  );
}

Widget _scorePanel(int score, String name) => _Panel(
  // 다국어 글꼴의 실제 행 높이가 기준값보다 커져도 점수 설명이 잘리지 않게
  // 휴대폰 가로 화면 안에서 여유 높이를 둡니다.
  height: 180,
  child: Column(
    children: [
      Text(
        _t('내 점수', 'My score', '我的分数', '我的分數'),
        style: finalCallPopText(16, color: _muted),
      ),
      Text(
        '$score',
        style: finalCallPopText(
          66,
          color: _violet,
          height: 1,
          shadows: finalCallPopOutline(3),
        ),
      ),
      const SizedBox(height: 4),
      Text(name, style: finalCallPopText(16)),
    ],
  ),
);

/// 시간에 맞춰 A → B로 바뀌는 자리입니다.
Widget _swapAt(Duration at, Widget a, Widget b) => Stack(
  alignment: Alignment.topCenter,
  children: [
    TutorialTimed(to: at, child: a),
    TutorialTimed(from: at, child: b),
  ],
);

class _PhoneScore extends StatelessWidget {
  const _PhoneScore();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _swapAt(
        _ms(3600),
        const _PhoneHand(bracket: (0, 1, '7 + 3 = 10점'), dimmed: {2, 3}),
        const _PhoneHand(bracket: (0, 2, '7 + 7 = 14점'), dimmed: {1, 3}),
      ),
      const SizedBox(width: 14),
      _swapAt(
        _ms(3600),
        _scorePanel(
          10,
          _t(
            '같은 색 빨강 7 + 3',
            'Same color red 7 + 3',
            '同色 红 7 + 3',
            '同色 紅 7 + 3',
          ),
        ),
        _scorePanel(
          14,
          _t('같은 숫자 7 × 2', 'Same number 7 × 2', '同数字 7 × 2', '同數字 7 × 2'),
        ),
      ),
    ],
  );
}

Widget _sourceButton(Widget card, String label, {double height = 100}) =>
    Expanded(
      child: FinalCallPopBox(
        color: _lilac,
        radius: 18,
        shadowDepth: 4,
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            card,
            const SizedBox(height: 4),
            Text(label, style: finalCallPopText(16)),
          ],
        ),
      ),
    );

Widget _callButton({double height = 67}) => FinalCallPopBox(
  color: _red,
  radius: 18,
  height: height,
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        'CALL!',
        style: finalCallPopText(
          30,
          color: Colors.white,
          height: 1.05,
          shadows: finalCallPopOutline(),
        ),
      ),
      Text(
        _t('꾹 눌러서 선언', 'Hold to call', '长按宣布 CALL', '長按宣布 CALL'),
        style: finalCallPopText(12, color: Colors.white),
      ),
    ],
  ),
);

class _PhoneTurn extends StatelessWidget {
  const _PhoneTurn();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const _PhoneHand(bracket: (0, 2, '7 + 7 = 14점'), dimmed: {0, 1, 2, 3}),
      const SizedBox(width: 14),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t('어디서 가져올까요?', 'Where will you draw from?', '从哪里抽牌？', '從哪裡抽牌？'),
              textAlign: TextAlign.center,
              style: finalCallPopText(15, color: _muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _sourceButton(_back(40), _t('덱', 'Deck', '牌堆', '牌堆')),
                const SizedBox(width: 10),
                _sourceButton(
                  _card('green', 7, 40),
                  _t('공개 카드', 'Open card', '明牌', '明牌'),
                ),
              ],
            ),
            const Spacer(),
            _PulseFrom(at: _ms(3200), child: _callButton()),
          ],
        ),
      ),
    ],
  );
}

/// [at]부터 노란 고리가 퍼지는 강조입니다.
class _PulseFrom extends StatelessWidget {
  const _PulseFrom({required this.at, required this.child});

  final Duration at;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      Positioned.fill(
        child: TutorialLater(
          at: at,
          child: IgnorePointer(
            child: TutorialPulse(child: const SizedBox.expand()),
          ),
        ),
      ),
    ],
  );
}

class _PhoneSwap extends StatelessWidget {
  const _PhoneSwap();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _swapAt(
        _ms(3900),
        _swapAt(_ms(1600), const _PhoneHand(), const _PhoneHand(selected: 3)),
        const _PhoneHand(
          cards: [('red', 7), ('red', 3), ('blue', 7), ('green', 7)],
          bracket: (0, 3, '7 × 3 = 21점'),
        ),
      ),
      const SizedBox(width: 14),
      _swapAt(
        _ms(4000),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _card('green', 7, 62),
                      const Positioned(
                        right: -10,
                        top: -12,
                        child: FinalCallPopTag(
                          label: 'NEW',
                          color: _red,
                          textColor: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _swapAt(
                      _ms(1700),
                      Text(
                        _t(
                          '바꿀 카드를 고르면\n점수를 미리 보여 줘요',
                          'Pick a card to preview\nyour new score',
                          '选择要替换的牌\n即可预览分数',
                          '選擇要替換的牌\n即可預覽分數',
                        ),
                        style: finalCallPopText(13, color: _muted),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('바꾸면', 'After replacing', '替换后', '替換後'),
                            style: finalCallPopText(13, color: _muted),
                          ),
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: '14 → '),
                                const TextSpan(
                                  text: '21',
                                  style: TextStyle(color: _green),
                                ),
                              ],
                            ),
                            style: finalCallPopText(28),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _swapAt(
                _ms(1700),
                Opacity(
                  opacity: .45,
                  child: FinalCallPopBox(
                    color: _violet,
                    radius: 18,
                    height: 50,
                    child: Center(
                      child: Text(
                        _t(
                          '바꿀 카드를 고르세요',
                          'Choose a card to replace',
                          '选择要替换的牌',
                          '選擇要替換的牌',
                        ),
                        style: finalCallPopText(17, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                FinalCallPopBox(
                  color: _violet,
                  radius: 18,
                  height: 50,
                  child: Center(
                    child: Text(
                      _t('노랑 2랑 바꾸기', 'Replace yellow 2', '换成 黄 2', '換成 黃 2'),
                      style: finalCallPopText(17, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FinalCallPopBox(
                radius: 14,
                height: 40,
                shadowDepth: 4,
                child: Center(
                  child: Text(
                    _t('새 카드 버리기', 'Discard new card', '丢弃新牌', '丟棄新牌'),
                    style: finalCallPopText(15),
                  ),
                ),
              ),
            ],
          ),
        ),
        _scorePanel(
          21,
          _t('같은 숫자 7 × 3', 'Same number 7 × 3', '同数字 7 × 3', '同數字 7 × 3'),
        ),
      ),
    ],
  );
}

/// CALL 버튼을 꾹 눌러 게이지가 차면 CALL!이 터집니다.
class _PhoneCall extends StatelessWidget {
  const _PhoneCall();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const _PhoneHand(
        cards: [('red', 7), ('red', 3), ('blue', 7), ('green', 7)],
        bracket: (0, 3, '7 × 3 = 21점'),
        dimmed: {0, 1, 2, 3},
      ),
      const SizedBox(width: 14),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t('어디서 가져올까요?', 'Where will you draw from?', '从哪里抽牌？', '從哪裡抽牌？'),
              textAlign: TextAlign.center,
              style: finalCallPopText(15, color: _muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _sourceButton(_back(40), _t('덱', 'Deck', '牌堆', '牌堆')),
                const SizedBox(width: 10),
                _sourceButton(
                  _card('green', 7, 40),
                  _t('공개 카드', 'Open card', '明牌', '明牌'),
                ),
              ],
            ),
            const Spacer(),
            const _HoldCall(),
          ],
        ),
      ),
    ],
  );
}

class _HoldCall extends StatefulWidget {
  const _HoldCall();

  @override
  State<_HoldCall> createState() => _HoldCallState();
}

class _HoldCallState extends State<_HoldCall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _ms(1400),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_ms(600), () {
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
    builder: (context, _) => Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              _callButton(),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 202 * _c.value,
                child: const ColoredBox(color: Color(0x591B1530)),
              ),
            ],
          ),
        ),
        if (_c.isCompleted)
          TutorialAppear(
            fromScale: .5,
            offset: Offset.zero,
            child: Text(
              'CALL!',
              style: finalCallPopText(
                52,
                color: _yellow,
                shadows: finalCallPopRing(2.5),
              ),
            ),
          ),
      ],
    ),
  );
}

/// 포카드 완성: 금빛 7 네 장, FOUR CARD! 도장, 실제 포카드 차례 패널(큰 CALL).
class _PhoneFour extends StatelessWidget {
  const _PhoneFour();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          const _PhoneHand(
            cards: [('red', 7), ('blue', 7), ('green', 7), ('yellow', 7)],
            bracket: (0, 3, '7 × 4 · 포카드'),
          ),
          Positioned(
            top: -40,
            child: TutorialAppear(
              delay: _ms(900),
              fromScale: .5,
              offset: Offset.zero,
              child: Transform.rotate(
                angle: -.1,
                child: Text(
                  'FOUR CARD!',
                  style: finalCallPopText(
                    30,
                    color: _yellow,
                    shadows: finalCallPopRing(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(width: 14),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t(
                '카드를 가져오면\n포카드가 깨질 수 있어요',
                'Drawing a card may\nbreak your four of a kind',
                '抽牌可能会\n拆散四条',
                '抽牌可能會\n拆散四條',
              ),
              textAlign: TextAlign.center,
              style: finalCallPopText(13, color: _muted, height: 1.35),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: .55,
              child: Row(
                children: [
                  _sourceButton(
                    const SizedBox.shrink(),
                    _t('덱', 'Deck', '牌堆', '牌堆'),
                    height: 40,
                  ),
                  const SizedBox(width: 8),
                  _sourceButton(
                    const SizedBox.shrink(),
                    _t('공개 카드', 'Open card', '明牌', '明牌'),
                    height: 40,
                  ),
                ],
              ),
            ),
            const Spacer(),
            _PulseFrom(at: _ms(1800), child: _callButton(height: 100)),
          ],
        ),
      ),
    ],
  );
}

/// 마지막 당부: 나와 팀원 프로필(하트)을 보여 줍니다.
class _PhoneTeam extends StatelessWidget {
  const _PhoneTeam({required this.players, required this.me});

  final List<TutorialPlayer> players;
  final TutorialPlayer me;

  Widget _chip(
    TutorialPlayer p,
    Color color,
    int lives, {
    bool warn = false,
  }) => FinalCallPopBox(
    radius: 14,
    borderWidth: 3,
    shadowDepth: 3,
    padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FinalCallPopAvatar(characterId: p.characterId, color: color, size: 38),
        const SizedBox(width: 6),
        Text(p.nickname, style: finalCallPopText(15)),
        const SizedBox(width: 4),
        for (var k = 0; k < 3; k++)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: k == lives - 1 && warn
                ? TutorialPulse(
                    radius: 10,
                    child: FinalCallPopHeart(color: color, size: 20),
                  )
                : FinalCallPopHeart(color: color, filled: k < lives, size: 20),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final n = math.max(1, players.length);
    final myIndex = math.max(0, players.indexWhere((p) => p.uid == me.uid));
    final mateIndex = (myIndex + n ~/ 2) % n;
    final mate = players.isEmpty ? me : players[mateIndex];
    final team = _teamOf(me.seatIndex, n);
    final color = _teamColor(team);
    return Column(
      children: [
        const SizedBox(height: 20),
        _Chip(_teamName(team), color: color, textColor: Colors.white, size: 16),
        const SizedBox(height: 14),
        _chip(me, color, 3),
        const SizedBox(height: 10),
        Text('+', style: finalCallPopText(28, color: _lilac)),
        const SizedBox(height: 10),
        _chip(mate, color, 1, warn: true),
      ],
    );
  }
}
