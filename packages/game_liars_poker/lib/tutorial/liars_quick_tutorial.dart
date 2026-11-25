// [liars_quick_tutorial.dart] 라이어스 '1분 요약' 튜토리얼(태블릿 + 휴대폰)이다.
//
// 장면이 정해진 시간마다 저절로 넘어갑니다(GameTutorial.autoPlay).
// 태블릿은 그림만, 큰 설명 문구는 휴대폰에 보입니다. 모두 건너뛰면 바로 게임,
// 끝 화면은 5초 카운트 뒤 게임으로 들어갑니다(game_kit이 맡음).
//
// 단계
//  0 시작        2.5초
//  1 목표        4.2초  · 한 명씩 탈락, 마지막 1명 왕관
//  2 카드 내기    6.5초  · 뒷면으로 내고 “진실 2장!”
//  3 뒤집어 보면  9.5초  · 네 가지 경우 진실/거짓 도장
//  4 믿으면      6.0초  · LIAR 없이 내 카드 내기
//  5 LIAR·거짓   9.8초  · 낸 사람 벌칙(생존)
//  6 LIAR·진실   8.2초  · 외친 사람 벌칙(탈락)
//  7 끝          · 목표 문구 + 카운트

part of 'liars_tutorial.dart';

class LiarsPokerQuickTutorial extends GameTutorial {
  const LiarsPokerQuickTutorial();

  static const _durations = [2500, 4200, 6500, 9500, 6000, 9800, 8200];

  @override
  String get gameId => 'liars_poker';

  @override
  String get title =>
      GameLocale.select(ko: '라이어스', en: 'Liars', zhHans: '说谎者', zhHant: '說謊者');

  @override
  int get stepCount => _durations.length + 1;

  @override
  bool isInfo(int step, int phase) => true;

  @override
  bool get autoPlay => true;

  @override
  Duration autoDuration(int step) =>
      Duration(milliseconds: _durations[step.clamp(0, _durations.length - 1)]);

  @override
  Widget buildTabletBackground(BuildContext context) =>
      const LiarsPokerWoodTableBackground();

  @override
  Widget buildPhoneBackground(BuildContext context) =>
      const LiarsPokerWoodTableBackground();

  @override
  Widget buildTablet(BuildContext context, TutorialTabletView view) =>
      _QuickTablet(view: view);

  @override
  Widget buildPhone(BuildContext context, TutorialPhoneView view) =>
      _QuickPhone(view: view);

  @override
  Widget buildPhoneEnd(BuildContext context, TutorialPhoneView view) =>
      const Center(child: LiarsPokerTruthCountHint());

  @override
  Widget buildAutoEndSlogan(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: _t('상대를 속여\n', 'Fool your rivals\n', '骗过对手\n', '騙過對手\n'),
          style: const TextStyle(color: Color(0xFFFF5A5F)),
        ),
        TextSpan(
          text: _t(
            '마지막까지 살아남으세요!',
            'and be the last one standing!',
            '坚持到最后！',
            '堅持到最後！',
          ),
        ),
      ],
    ),
    textAlign: TextAlign.center,
    style: LiarsPokerFonts.headline(size: 64, color: _bone).copyWith(
      height: 1.25,
      shadows: const [Shadow(color: _ink, offset: Offset(0, 5))],
    ),
  );
}

Duration _ms(num ms) => Duration(milliseconds: ms.round());

//======================================================================
// 태블릿
//======================================================================
class _QuickTablet extends StatelessWidget {
  const _QuickTablet({required this.view});

  final TutorialTabletView view;

  Size get _size => view.size;
  Offset get _center => _size.center(Offset.zero);

  List<Offset> get _seats {
    final n = math.max(1, view.playerCount);
    final normalized = normalizedPlayerCenters(n);
    return [
      for (final player in view.players)
        Offset(
          normalized[player.seatIndex.clamp(0, n - 1)].dx * _size.width,
          normalized[player.seatIndex.clamp(0, n - 1)].dy * _size.height,
        ),
    ];
  }

  double _facing(Offset seat) {
    final d = seat - _center;
    return math.atan2(d.dy, d.dx) - math.pi / 2;
  }

  /// 예시에서 카드를 내는 사람(자리 배치 첫 번째)입니다.
  static const _owner = 0;

  /// 다음 차례(믿거나 LIAR를 외치는 사람)입니다.
  int get _next => view.playerCount < 2 ? 0 : 1;

  @override
  Widget build(BuildContext context) {
    final seats = _seats;
    final step = view.step;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (step != 3)
          for (var i = 0; i < view.players.length; i++)
            Positioned(
              left: seats[i].dx - 60,
              top: seats[i].dy - 60,
              width: 120,
              height: 120,
              child: Transform.rotate(
                angle: _facing(seats[i]),
                child: _QuickSeat(
                  player: view.players[i],
                  outAt: step == 1 && i != _owner
                      ? _ms(1000 + 500 * (i - 1))
                      : null,
                  crownAt: step == 1 && i == _owner ? _ms(2600) : null,
                  ring: switch (step) {
                    2 when i == _owner => _sun,
                    4 || 5 when i == _next => _sun,
                    6 when i == _next => const Color(0xFFE0465A),
                    _ => null,
                  },
                ),
              ),
            ),
        ..._middle(seats),
      ],
    );
  }

  /// 좌석과 가운데 사이 [k] 지점입니다(0 = 가운데, 1 = 좌석).
  Offset _toward(Offset seat, double k) => _center + (seat - _center) * k;

  List<Widget> _middle(List<Offset> seats) {
    final owner = view.players.isEmpty ? null : view.players[_owner];
    final next = view.players.isEmpty ? null : view.players[_next];
    switch (view.step) {
      case 0:
        return [
          Positioned.fill(
            child: Center(
              child: TutorialAppear(
                fromScale: .6,
                offset: Offset.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LIARS',
                      style: LiarsPokerFonts.western(
                        size: 110,
                        color: _bone,
                        letterSpacing: 8,
                        shadows: const [
                          Shadow(color: _ink, offset: Offset(0, 7)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _QuickPill(
                      text: _t('규칙 1분 요약', '1-minute rules', '1分钟规则', '1分鐘規則'),
                      color: _sun,
                      textColor: _ink,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ];
      case 1:
        return const [];
      case 2:
        return [
          ..._centerBacks(fromSeat: seats.isEmpty ? null : seats[_owner]),
          if (seats.isNotEmpty)
            _bubbleAt(
              _toward(seats[_owner], .45) + const Offset(-150, 0),
              _t('“진실 2장!”', '“2 truths!”', '“两张真话！”', '「兩張真話！」'),
              from: _ms(1200),
            ),
        ];
      case 3:
        return [
          Positioned.fill(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < _cases.length; c++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: _CaseColumn(
                        faces: _cases[c],
                        start: _ms(900 + c * 1300),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ];
      case 4:
        final nextSeat = seats.length > _next ? seats[_next] : _center;
        return [
          ..._centerBacks(),
          if (seats.isNotEmpty)
            _bubbleAt(
              _toward(seats[_owner], .45) + const Offset(-150, 0),
              _t('“진실 2장!”', '“2 truths!”', '“两张真话！”', '「兩張真話！」'),
              to: _ms(2600),
              dim: true,
            ),
          _choiceAt(nextSeat, pickLiar: false, until: _ms(2600)),
          _Fly(
            from: nextSeat,
            to: _center + const Offset(0, 14),
            fromAngle: _facing(nextSeat),
            toAngle: _facing(nextSeat),
            delay: _ms(2600),
            duration: _ms(600),
            child: const LiarsPokerCardView(
              face: LiarsCardFace.back,
              width: 104,
              rounded: true,
            ),
          ),
          _bubbleAt(
            _toward(nextSeat, .5) + const Offset(0, 90),
            _t('“진실 1장!”', '“1 truth!”', '“一张真话！”', '「一張真話！」'),
            from: _ms(3300),
          ),
        ];
      case 5:
        final nextSeat = seats.length > _next ? seats[_next] : _center;
        return [
          ..._flipPair('tl', _ms(3000)),
          _choiceAt(nextSeat, pickLiar: true, until: _ms(3000)),
          if (owner != null)
            _PenaltyOverlay(player: owner, at: _ms(4800), survive: true),
        ];
      case 6:
        final nextSeat = seats.length > _next ? seats[_next] : _center;
        return [
          ..._flipPair('tt', _ms(1200)),
          _bubbleAt(
            _toward(nextSeat, .5) + const Offset(0, -80),
            'LIAR!',
            to: _ms(3400),
            color: _lie,
          ),
          if (next != null)
            _PenaltyOverlay(player: next, at: _ms(3600), survive: false),
        ];
    }
    return const [];
  }

  static const _cases = ['t', 'tl', 'ttt', 'ltl'];

  /// 가운데 뒷면 카드 두 장입니다. [fromSeat]를 주면 그 자리에서 밀려 나옵니다.
  List<Widget> _centerBacks({Offset? fromSeat}) => [
    for (var k = 0; k < 2; k++)
      if (fromSeat != null)
        _Fly(
          from: fromSeat,
          to: _center + Offset(-62 + k * 124.0, 0),
          delay: _ms(300 + k * 200),
          duration: _ms(500),
          child: const LiarsPokerCardView(
            face: LiarsCardFace.back,
            width: 104,
            rounded: true,
          ),
        )
      else
        Positioned(
          left: _center.dx - 62 + k * 124 - 52,
          top: _center.dy - 76,
          child: const LiarsPokerCardView(
            face: LiarsCardFace.back,
            width: 104,
            rounded: true,
          ),
        ),
  ];

  /// 가운데 두 장을 [at]에 한 장씩 뒤집습니다.
  List<Widget> _flipPair(String faces, Duration at) => [
    for (var k = 0; k < 2; k++)
      Positioned(
        left: _center.dx - 62 + k * 124 - 52,
        top: _center.dy - 76,
        child: _Flip(
          delay: at + _ms(k * 250),
          face: _face(faces[k]),
          width: 104,
        ),
      ),
  ];

  Widget _bubbleChild(
    Offset at,
    String text, {
    bool dim = false,
    Color color = _ink,
  }) => Positioned(
    left: at.dx - 120,
    top: at.dy - 30,
    width: 240,
    child: Center(
      child: Opacity(
        opacity: dim ? .75 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _ink, width: 3),
            boxShadow: const [BoxShadow(color: _ink, offset: Offset(0, 4))],
          ),
          child: Text(
            text,
            style: LiarsPokerFonts.text(
              size: 24,
              color: color,
              weight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _bubbleAt(
    Offset at,
    String text, {
    Duration from = Duration.zero,
    Duration? to,
    bool dim = false,
    Color color = _ink,
  }) => Positioned.fill(
    child: TutorialTimed(
      from: from,
      to: to,
      child: Stack(
        clipBehavior: Clip.none,
        children: [_bubbleChild(at, text, dim: dim, color: color)],
      ),
    ),
  );

  /// 다음 사람 옆에 뜨는 '믿고 내 카드 내기 / LIAR!' 선택지입니다.
  Widget _choiceAt(
    Offset seat, {
    required bool pickLiar,
    required Duration until,
  }) {
    final at = _toward(seat, .62);
    return Positioned(
      left: at.dx - 120,
      top: at.dy - 70,
      width: 240,
      child: TutorialTimed(
        from: _ms(600),
        to: until,
        child: TutorialAppear(
          delay: _ms(600),
          fromScale: .7,
          offset: Offset.zero,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _ink, width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ChoiceRow(
                  text: _t('믿고 내 카드 내기', 'Trust & play', '相信并出牌', '相信並出牌'),
                  background: _bone,
                  textColor: _ink,
                  picked: !pickLiar,
                  at: _ms(pickLiar ? 2200 : 1800),
                ),
                const SizedBox(height: 6),
                _ChoiceRow(
                  text: 'LIAR!',
                  background: _lie,
                  textColor: _bone,
                  picked: pickLiar,
                  at: _ms(pickLiar ? 2200 : 1800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 튜토리얼 좌석: 프로필, 강조 고리, 탈락 X, 왕관입니다.
class _QuickSeat extends StatefulWidget {
  const _QuickSeat({required this.player, this.outAt, this.crownAt, this.ring});

  final TutorialPlayer player;
  final Duration? outAt;
  final Duration? crownAt;
  final Color? ring;

  @override
  State<_QuickSeat> createState() => _QuickSeatState();
}

class _QuickSeatState extends State<_QuickSeat> {
  bool _out = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final outAt = widget.outAt;
    if (outAt != null) {
      _timer = Timer(outAt, () {
        if (mounted) setState(() => _out = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = widget.ring;
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: _ms(400),
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: ring ?? _ink, width: 5),
              boxShadow: [
                if (ring != null)
                  BoxShadow(
                    color: ring.withValues(alpha: .6),
                    blurRadius: 26,
                    spreadRadius: 6,
                  ),
              ],
            ),
            child: ClipOval(
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(
                  _out ? _grayMatrix : _identityMatrix,
                ),
                child: MosiFace(
                  characterId: widget.player.characterId,
                  size: 86,
                ),
              ),
            ),
          ),
          if (_out)
            const TutorialAppear(
              fromScale: .5,
              offset: Offset.zero,
              child: Icon(
                Icons.close_rounded,
                color: Color(0xFFE0465A),
                size: 110,
              ),
            ),
          if (widget.crownAt != null)
            Positioned(
              top: -52,
              child: TutorialAppear(
                delay: widget.crownAt!,
                offset: const Offset(0, -30),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: _sun,
                  size: 58,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _identityMatrix = <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];
const _grayMatrix = <double>[
  .13, .42, .05, 0, 0, //
  .13, .42, .05, 0, 0, //
  .13, .42, .05, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// 선택지 한 줄입니다. [at]에 골라진 쪽은 크게 튀고, 아닌 쪽은 흐려집니다.
class _ChoiceRow extends StatefulWidget {
  const _ChoiceRow({
    required this.text,
    required this.background,
    required this.textColor,
    required this.picked,
    required this.at,
  });

  final String text;
  final Color background;
  final Color textColor;
  final bool picked;
  final Duration at;

  @override
  State<_ChoiceRow> createState() => _ChoiceRowState();
}

class _ChoiceRowState extends State<_ChoiceRow> {
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.at, () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: _ms(300),
    opacity: _done && !widget.picked ? .3 : 1,
    child: AnimatedScale(
      duration: _ms(300),
      curve: Curves.easeOutBack,
      scale: _done && widget.picked ? 1.08 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: widget.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _ink, width: 2),
          boxShadow: [
            if (_done && widget.picked)
              const BoxShadow(color: _sun, spreadRadius: 4),
          ],
        ),
        child: Text(
          widget.text,
          textAlign: TextAlign.center,
          style: LiarsPokerFonts.text(
            size: 22,
            color: widget.textColor,
            weight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

/// '뒤집어 보면?' 한 경우: 뒷면 카드가 한 장씩 뒤집히고 진실/거짓 도장이 찍힙니다.
class _CaseColumn extends StatelessWidget {
  const _CaseColumn({required this.faces, required this.start});

  final String faces;
  final Duration start;

  bool get _isTruth => !faces.contains('l');

  @override
  Widget build(BuildContext context) {
    final stampAt = start + _ms(faces.length * 180 + 500);
    return SizedBox(
      width: 210,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var k = 0; k < faces.length; k++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _Flip(
                    delay: start + _ms(k * 180),
                    face: _face(faces[k]),
                    width: 64,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          TutorialAppear(
            delay: stampAt,
            fromScale: 1.6,
            offset: Offset.zero,
            duration: _ms(380),
            curve: Curves.easeOutCubic,
            child: Transform.rotate(
              angle: -.1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _isTruth ? _truth : _lie,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isTruth
                      ? _t('진실', 'Truth', '真话', '真話')
                      : _t('거짓', 'Lie', '谎话', '謊話'),
                  style: LiarsPokerFonts.headline(size: 34, color: _bone),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 화면을 어둡게 덮고 벌칙 룰렛을 크게 돌린 뒤 생존/탈락 도장을 찍습니다.
class _PenaltyOverlay extends StatelessWidget {
  const _PenaltyOverlay({
    required this.player,
    required this.at,
    required this.survive,
  });

  final TutorialPlayer player;
  final Duration at;
  final bool survive;

  @override
  Widget build(BuildContext context) {
    final resultAt = _ms(2900);
    return Positioned.fill(
      child: TutorialLater(
        at: at,
        child: TutorialAppear(
          duration: _ms(350),
          offset: Offset.zero,
          curve: Curves.easeOut,
          child: ColoredBox(
            color: const Color(0x9E0A0604),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _QuickSeat(
                        player: player,
                        outAt: survive ? null : resultAt,
                        ring: survive ? _sun : null,
                      ),
                      const SizedBox(height: 14),
                      _QuickPill(
                        text: _t(
                          '${player.nickname} 벌칙',
                          '${player.nickname}’s penalty',
                          '${player.nickname} 惩罚',
                          '${player.nickname} 懲罰',
                        ),
                        color: _lie,
                        textColor: _bone,
                      ),
                    ],
                  ),
                  const SizedBox(width: 48),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const _Roulette(size: 320),
                      TutorialAppear(
                        delay: resultAt,
                        fromScale: 1.7,
                        offset: Offset.zero,
                        duration: _ms(380),
                        curve: Curves.easeOutCubic,
                        child: Transform.rotate(
                          angle: -.1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: survive ? _truth : _lie,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _bone, width: 5),
                              boxShadow: const [
                                BoxShadow(color: _ink, offset: Offset(0, 6)),
                              ],
                            ),
                            child: Text(
                              survive
                                  ? _t('생존!', 'Safe!', '存活！', '存活！')
                                  : _t('탈락!', 'Out!', '淘汰！', '淘汰！'),
                              style: LiarsPokerFonts.headline(
                                size: 48,
                                color: _bone,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _QuickPill extends StatelessWidget {
  const _QuickPill({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: _ink, width: 3),
    ),
    child: Text(
      text,
      style: LiarsPokerFonts.text(
        size: 20,
        color: textColor,
        weight: FontWeight.w800,
      ),
    ),
  );
}

//======================================================================
// 휴대폰
//======================================================================
class _QuickPhone extends StatelessWidget {
  const _QuickPhone({required this.view});

  final TutorialPhoneView view;

  static TextStyle get _capStyle => LiarsPokerFonts.text(
    size: 27,
    color: _bone,
    weight: FontWeight.w800,
  ).copyWith(height: 1.35);

  /// 단계별 (문구, 시각) 목록과 첫 문구 아래 작은 글입니다.
  (List<(String, Duration)>, String?) _caption(int step) => switch (step) {
    0 => (
      [
        (
          _t('라이어스 1분 요약', 'Liars in 1 minute', '1分钟看懂说谎者', '1分鐘看懂說謊者'),
          Duration.zero,
        ),
      ],
      _t('태블릿과 함께 봐요', 'Watch with the tablet', '和平板一起看', '和平板一起看'),
    ),
    1 => (
      [
        (
          _t(
            '끝까지 살아남는 1명이 이겨요',
            'The last one standing wins',
            '坚持到最后的1人获胜',
            '堅持到最後的1人獲勝',
          ),
          Duration.zero,
        ),
      ],
      null,
    ),
    2 => (
      [
        (
          _t(
            '카드를 내면 상대는 뒷면만 볼 수 있어요',
            'Others only see the backs of your cards',
            '你出的牌别人只能看到背面',
            '你出的牌別人只能看到背面',
          ),
          Duration.zero,
        ),
        (
          _t(
            '그래서 거짓 카드를 섞어 내도 아무도 몰라요!',
            'So no one knows if you slip in a lie!',
            '所以混进谎话牌也没人知道！',
            '所以混進謊話牌也沒人知道！',
          ),
          _ms(3000),
        ),
      ],
      null,
    ),
    3 => (
      [
        (
          _t(
            '뒷면 카드, 뒤집어 보면?',
            'Flip the face-down cards?',
            '把背面的牌翻过来？',
            '把背面的牌翻過來？',
          ),
          Duration.zero,
        ),
        (
          _t(
            '1장이라도 거짓이 섞이면 → 거짓!',
            'Even one lie → it’s a lie!',
            '只要混了一张谎话 → 就是谎话！',
            '只要混了一張謊話 → 就是謊話！',
          ),
          _ms(6500),
        ),
      ],
      null,
    ),
    4 => (
      [
        (
          _t('앞사람 말을 믿으면?', 'Trust the previous player?', '相信上一个人？', '相信上一個人？'),
          Duration.zero,
        ),
        (
          _t(
            'LIAR를 안 외치면 할 일은 하나, 내 카드 내기!',
            'No LIAR? Then just play your cards!',
            '不喊 LIAR 就只做一件事：出牌！',
            '不喊 LIAR 就只做一件事：出牌！',
          ),
          _ms(2700),
        ),
      ],
      null,
    ),
    5 => (
      [
        (
          _t(
            '앞사람이 거짓을 낸 것 같으면 LIAR!',
            'Think they lied? Call LIAR!',
            '觉得上一个人说谎就喊 LIAR！',
            '覺得上一個人說謊就喊 LIAR！',
          ),
          Duration.zero,
        ),
        (
          _t(
            '맞히면 → 카드를 낸 사람이 벌칙!',
            'Right → the player who played gets the penalty!',
            '猜对 → 出牌的人受罚！',
            '猜對 → 出牌的人受罰！',
          ),
          _ms(4300),
        ),
      ],
      null,
    ),
    _ => (
      [
        (
          _t(
            '그런데 뒤집었더니 전부 진실이면?',
            'But what if they’re all truths?',
            '可是翻开全是真话呢？',
            '可是翻開全是真話呢？',
          ),
          Duration.zero,
        ),
        (
          _t(
            '틀렸으니 → LIAR를 외친 내가 벌칙!',
            'Wrong → the LIAR caller gets the penalty!',
            '猜错 → 喊 LIAR 的我受罚！',
            '猜錯 → 喊 LIAR 的我受罰！',
          ),
          _ms(3300),
        ),
      ],
      null,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (phases, sub) = _caption(view.step);
    return Stack(
      children: [
        Positioned(
          left: 24,
          right: 24,
          top: 70,
          bottom: 150,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _mini(),
              const SizedBox(height: 26),
              TutorialPhaseCaption(
                phases: phases,
                sub: sub,
                style: _capStyle,
                subStyle: LiarsPokerFonts.text(
                  size: 18,
                  color: _gold,
                  weight: FontWeight.w700,
                ),
              ),
            ],
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
              color: _bone,
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatar(TutorialPlayer player, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: _ink, width: 3),
    ),
    child: ClipOval(
      child: MosiFace(characterId: player.characterId, size: size - 6),
    ),
  );

  Widget _panel(List<Widget> children) => TutorialAppear(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x9917110F),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );

  Widget _card(String c, {double width = 46}) => LiarsPokerCardView(
    face: c == 'b' ? LiarsCardFace.back : _face(c),
    width: width,
    rounded: true,
  );

  Widget _arrow() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 6),
    child: Icon(Icons.arrow_forward_rounded, color: _bone, size: 20),
  );

  Widget _stamp(bool truth) => Transform.rotate(
    angle: -.08,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      decoration: BoxDecoration(
        color: truth ? _truth : _lie,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        truth ? _t('진실', 'Truth', '真话', '真話') : _t('거짓', 'Lie', '谎话', '謊話'),
        style: LiarsPokerFonts.headline(size: 18, color: _bone),
      ),
    ),
  );

  Widget _penaltyRow(String faces, TutorialPlayer who) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _card(faces[0], width: 40),
      const SizedBox(width: 6),
      _card(faces[1], width: 40),
      _arrow(),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _avatar(who, 46),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _lie,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _ink, width: 2),
            ),
            child: Text(
              _t('벌칙', 'Penalty', '惩罚', '懲罰'),
              style: LiarsPokerFonts.text(
                size: 14,
                color: _bone,
                weight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _mini() {
    final players = view.players;
    final me = view.me;
    final owner = players.isEmpty ? me : players[0];
    final next = players.length < 2 ? owner : players[1];
    switch (view.step) {
      case 0:
        return _avatar(me, 76);
      case 1:
        return _panel([
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Wrap(
              spacing: 10,
              children: [
                for (var i = 0; i < players.length; i++)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: _QuickSeatMini(
                      player: players[i],
                      outAt: i == 0 ? null : _ms(1000 + 500 * (i - 1)),
                      crown: i == 0,
                    ),
                  ),
              ],
            ),
          ),
        ]);
      case 2:
        return _panel([
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _card('b', width: 54),
              const SizedBox(width: 8),
              _card('b', width: 54),
            ],
          ),
        ]);
      case 3:
        return _panel([
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _card('t', width: 40),
              const SizedBox(width: 6),
              _card('l', width: 40),
              _arrow(),
              _stamp(false),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _card('t', width: 40),
              const SizedBox(width: 6),
              _card('t', width: 40),
              _arrow(),
              _stamp(true),
            ],
          ),
        ]);
      case 4:
        return _panel([
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _bone,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _ink, width: 2),
            ),
            child: Text(
              _t('믿고 내 카드 내기', 'Trust & play', '相信并出牌', '相信並出牌'),
              style: LiarsPokerFonts.text(
                size: 16,
                color: _ink,
                weight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _arrow(),
              _card('b', width: 48),
              const SizedBox(width: 8),
              Text(
                _t('다음 사람', 'Next player', '下一个人', '下一個人'),
                style: LiarsPokerFonts.text(
                  size: 15,
                  color: _bone,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ]);
      case 5:
        return _panel([_penaltyRow('tl', owner)]);
      default:
        return _panel([_penaltyRow('tt', next)]);
    }
  }
}

/// 휴대폰 목표 장면의 작은 프로필: 한 명씩 X와 함께 어두워지고, 남은 1명에 왕관이 내려옵니다.
class _QuickSeatMini extends StatefulWidget {
  const _QuickSeatMini({required this.player, this.outAt, this.crown = false});

  final TutorialPlayer player;
  final Duration? outAt;
  final bool crown;

  @override
  State<_QuickSeatMini> createState() => _QuickSeatMiniState();
}

class _QuickSeatMiniState extends State<_QuickSeatMini> {
  bool _out = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final outAt = widget.outAt;
    if (outAt != null) {
      _timer = Timer(outAt, () {
        if (mounted) setState(() => _out = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _ink, width: 3),
        ),
        child: ClipOval(
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(
              _out ? _grayMatrix : _identityMatrix,
            ),
            child: MosiFace(characterId: widget.player.characterId, size: 38),
          ),
        ),
      ),
      if (_out)
        const TutorialAppear(
          fromScale: .5,
          offset: Offset.zero,
          child: Icon(Icons.close_rounded, color: Color(0xFFE0465A), size: 48),
        ),
      if (widget.crown)
        Positioned(
          top: -22,
          child: TutorialAppear(
            delay: _ms(2600),
            offset: const Offset(0, -14),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: _sun,
              size: 26,
            ),
          ),
        ),
    ],
  );
}
