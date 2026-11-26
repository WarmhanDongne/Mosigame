// [liars_quick_tutorial.dart] 라이어스 '1분 요약' 튜토리얼(태블릿 + 휴대폰)이다.
//
// 캔버스 시안(LiarsQuick.dc.html)의 좌표·크기·색·시각을 그대로 옮긴 화면입니다.
// 태블릿은 시안 기기 안쪽 796×536, 휴대폰은 264×568을 설계 크기로 씁니다.
// 등장인물은 시안과 같은 4명(택배·냄비·후드·수박)으로 고정합니다.
//
// 단계와 길이(시안 DUR)
//  0 시작 2.5초 · 1 목표 4.2초 · 2 카드 내기 6.5초 · 3 뒤집어 보면 9.5초
//  4 믿으면 6.0초 · 5 LIAR·거짓 9.8초 · 6 LIAR·진실 8.2초 · 7 끝

part of 'liars_tutorial.dart';

/// 시안과 같은 등장인물입니다(이름, 캐릭터 아이디).
const _qCast = [
  ('택배', 'kindbear'),
  ('냄비', 'bee'),
  ('후드', 'hedgehog'),
  ('수박', 'whale'),
];

/// 시안 좌석입니다(796×536 기준 중심 좌표와 회전 각도).
const _qSeats = [
  (Offset(398, 471.68), 0.0),
  (Offset(55.72, 268), 90.0),
  (Offset(398, 64.32), 180.0),
  (Offset(740.28, 268), -90.0),
];

/// 가운데 카드 두 장의 왼쪽 위 좌표와 크기입니다.
const _qCardsAt = Offset(286, 200);
const _qCardW = 104.0;
const _qCardGap = 16.0;

const _qWhite = Color(0xFFFFFFFF);
const _qBlack = Color(0xFF111111);
const _qRed = Color(0xFFE0465A);
const _qNavy = Color(0xFF0E0A3D);

double _qRad(double deg) => deg * math.pi / 180;

Duration _qms(num ms) => Duration(milliseconds: ms.round());

Duration _qs(num seconds) => _qms(seconds * 1000);

class LiarsPokerQuickTutorial extends GameTutorial {
  const LiarsPokerQuickTutorial();

  /// 시안 DUR입니다(밀리초).
  static const _durations = [2500, 4200, 6500, 9500, 6000, 9800, 8200];

  @override
  String get gameId => 'liars_poker';

  @override
  String get title => _t('라이어스', 'Liars', '说谎者', '說謊者');

  @override
  int get stepCount => _durations.length + 1;

  @override
  bool isInfo(int step, int phase) => true;

  @override
  bool get autoPlay => true;

  @override
  Duration autoDuration(int step) =>
      _qms(_durations[step.clamp(0, _durations.length - 1)]);

  @override
  Size get tabletDesignSize => const Size(796, 536);

  @override
  Size get phoneDesignSize => const Size(264, 568);

  @override
  Widget buildTabletBackground(BuildContext context) =>
      const LiarsPokerWoodTableBackground();

  @override
  Widget buildPhoneBackground(BuildContext context) =>
      const LiarsPokerWoodTableBackground();

  @override
  Widget buildTablet(BuildContext context, TutorialTabletView view) =>
      _QTablet(step: view.step);

  @override
  Widget buildPhone(BuildContext context, TutorialPhoneView view) =>
      _QPhone(view: view);

  @override
  TutorialEndStyle get autoEndStyle => TutorialEndStyle(
    ink: _ink,
    cream: _bone,
    accent: _sun,
    goBg: _lime,
    shade: const Color(0xCC080418),
    numStyle: LiarsPokerFonts.headline(size: 26, color: _ink),
    labelStyle: LiarsPokerFonts.text(
      size: 20,
      weight: FontWeight.w700,
      color: _ink,
    ),
    goStyle: LiarsPokerFonts.headline(size: 38, color: _ink, height: 1.2),
  );

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
    style: LiarsPokerFonts.headline(size: 52, color: _bone, height: 1.25)
        .copyWith(
          shadows: const [Shadow(color: _ink, offset: Offset(0, 4))],
        ),
  );

  @override
  Widget buildPhoneEnd(BuildContext context, TutorialPhoneView view) =>
      TutorialLookAtTablet(
        titleStyle:
            LiarsPokerFonts.headline(
              size: 30,
              color: _bone,
              height: 1.2,
            ).copyWith(
              shadows: const [Shadow(color: _ink, offset: Offset(0, 3))],
            ),
        body: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: _t(
                  '카드를 나눠 주기 전에\n이번 판 ',
                  'Before the cards are dealt,\ncheck how many ',
                  '发牌之前\n这一局有几张',
                  '發牌之前\n這一局有幾張',
                ),
              ),
              TextSpan(
                text: _t('진실 카드', 'truth cards', '真话牌', '真話牌'),
                style: const TextStyle(color: Color(0xFF7FE0A8)),
              ),
              TextSpan(text: _t('가 몇 장인지\n', ' there are\n', '\n', '\n')),
              TextSpan(
                text: _t('꼭 확인하세요', 'this round', '一定要确认', '一定要確認'),
                style: const TextStyle(color: Color(0xFFFFD98A)),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: LiarsPokerFonts.text(
            size: 16,
            weight: FontWeight.w700,
            color: _bone.withValues(alpha: .82),
            height: 1.55,
          ),
        ),
      );
}

//======================================================================
// 시안 CSS 애니메이션 조각
//======================================================================
/// [delay] 뒤에 [duration] 동안 0 → 1로 흐르는 값을 건네줍니다.
class _QFx extends StatefulWidget {
  const _QFx({
    required this.duration,
    required this.builder,
    this.delay = Duration.zero,
    this.curve = Curves.linear,
    this.child,
  });

  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Widget? child;
  final Widget Function(double t, Widget? child) builder;

  @override
  State<_QFx> createState() => _QFxState();
}

class _QFxState extends State<_QFx> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
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
    child: widget.child,
    builder: (context, child) =>
        widget.builder(widget.curve.transform(_c.value), child),
  );
}

/// 시안 pop: 투명에서 보이고, 0.6배에서 살짝 넘치며 커집니다.
Widget _qPop(
  Widget child, {
  num delay = 0,
  num duration = .45,
  double from = .6,
  Curve curve = const Cubic(.3, 1.4, .5, 1),
}) => _QFx(
  delay: _qs(delay),
  duration: _qs(duration),
  curve: curve,
  child: child,
  builder: (t, c) => Opacity(
    opacity: t.clamp(0, 1),
    child: Transform.scale(scale: from + (1 - from) * t, child: c),
  ),
);

/// 시안 crown: 위에서 내려오며 기울기가 풀립니다.
Widget _qCrown(Widget child, {num delay = 0}) => _QFx(
  delay: _qs(delay),
  duration: _qs(.6),
  curve: Curves.easeOut,
  child: child,
  builder: (t, c) => Opacity(
    opacity: t.clamp(0, 1),
    child: Transform.translate(
      offset: Offset(0, -30 * (1 - t)),
      child: Transform.rotate(angle: _qRad(-12 * (1 - t)), child: c),
    ),
  ),
);

/// 시안 slideUp: 아래에서 200px 올라오며 8도 기울기가 풀립니다.
Widget _qSlideUp(Widget child, {num delay = 0}) => _QFx(
  delay: _qs(delay),
  duration: _qs(.5),
  curve: const Cubic(.2, .8, .3, 1),
  child: child,
  builder: (t, c) => Opacity(
    opacity: t.clamp(0, 1),
    child: Transform.translate(
      offset: Offset(0, 200 * (1 - t)),
      child: Transform.rotate(angle: _qRad(8 * (1 - t)), child: c),
    ),
  ),
);

/// 시안 slam: 크게 나타나 작아졌다 제자리에 찍힙니다(-6도 고정).
Widget _qSlam(Widget child, {num delay = 0}) => _QFx(
  delay: _qs(delay),
  duration: _qs(.4),
  curve: const Cubic(.2, .9, .3, 1),
  child: child,
  builder: (t, c) {
    final double opacity;
    final double scale;
    if (t < .6) {
      final k = t / .6;
      opacity = k;
      scale = 2.2 + (.92 - 2.2) * k;
    } else {
      opacity = 1;
      scale = .92 + .08 * ((t - .6) / .4);
    }
    return Opacity(
      opacity: opacity.clamp(0, 1),
      child: Transform.rotate(
        angle: _qRad(-6),
        child: Transform.scale(scale: scale, child: c),
      ),
    );
  },
);

/// 시안 flipOut: 뒷면이 0에서 90도로 돌아 사라집니다.
Widget _qFlipOut(Widget child, {num delay = 0}) => _QFx(
  delay: _qs(delay),
  duration: _qs(.2),
  curve: Curves.easeIn,
  child: child,
  builder: (t, c) => Opacity(
    opacity: t >= 1 ? 0 : 1,
    child: Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .0012)
        ..rotateY(_qRad(90 * t)),
      child: c,
    ),
  ),
);

/// 시안 flipIn: 앞면이 90에서 0도로 돌아 나타납니다.
Widget _qFlipIn(Widget child, {num delay = 0, num duration = .35}) => _QFx(
  delay: _qs(delay),
  duration: _qs(duration),
  curve: Curves.easeOut,
  child: child,
  builder: (t, c) => Opacity(
    opacity: t <= 0 ? 0 : 1,
    child: Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .0012)
        ..rotateY(_qRad(90 * (1 - t))),
      child: c,
    ),
  ),
);

/// 시안 fromPot: 왼쪽 자리에서 가운데로 밀려 들어옵니다(90도로 누운 카드).
Widget _qFromPot(Widget child, {num delay = 0}) => _QFx(
  delay: _qs(delay),
  duration: _qs(.6),
  curve: const Cubic(.2, .8, .3, 1),
  child: child,
  builder: (t, c) => Opacity(
    opacity: (t / .2).clamp(0, 1),
    child: Transform.translate(
      offset: Offset(-340 * (1 - t), 14 * t),
      child: Transform.rotate(
        angle: _qRad(90),
        child: Transform.scale(scale: .8 + .2 * t, child: c),
      ),
    ),
  ),
);

/// 시안 winGlow: 금빛 테두리가 번지며 자리를 잡습니다.
Widget _qWinGlow(Widget child, {num delay = 0, num duration = 1.2}) => _QFx(
  delay: _qs(delay),
  duration: _qs(duration),
  curve: Curves.easeOut,
  child: child,
  builder: (t, c) {
    final k = t < .4 ? t / .4 : (t - .4) / .6;
    final solid = t < .4 ? 6 * k : 6 - 1 * k;
    final blur = t < .4 ? 30 * k : 30 - 8 * k;
    final spread = t < .4 ? 10 * k : 10 - 4 * k;
    final alpha = t < .4 ? .7 * k : .7 - .2 * k;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: _sun, spreadRadius: solid),
          BoxShadow(
            color: _sun.withValues(alpha: alpha.clamp(0, 1)),
            blurRadius: blur,
            spreadRadius: spread,
          ),
        ],
      ),
      child: c,
    );
  },
);

/// 시안 pickPulse: 고른 칸이 커지며 금빛 테두리가 생깁니다.
Widget _qPickPulse(Widget child, {num delay = 0}) => _QFx(
  delay: _qs(delay),
  duration: _qs(.5),
  child: child,
  builder: (t, c) {
    final scale = t < .5 ? 1 + .18 * (t / .5) : 1.18 - .1 * ((t - .5) / .5);
    final ring = t < .5 ? 6 * (t / .5) : 6 - 2 * ((t - .5) / .5);
    return Transform.scale(
      scale: scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: _sun, spreadRadius: ring)],
        ),
        child: c,
      ),
    );
  },
);

/// [delay] 뒤에 흐려집니다(시안 capOut·dimOut).
class _QFade extends StatefulWidget {
  const _QFade({
    required this.child,
    required this.delay,
    this.to = 0,
    this.from = 1,
  });

  final Widget child;
  final Duration delay;
  final double to;
  final double from;

  @override
  State<_QFade> createState() => _QFadeState();
}

class _QFadeState extends State<_QFade> {
  late double _opacity = widget.from;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _opacity = widget.to);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _opacity,
    duration: const Duration(milliseconds: 300),
    child: widget.child,
  );
}

/// 시안 grayOut: 회색이 되고 조금 어두워집니다.
class _QGray extends StatefulWidget {
  const _QGray({required this.child, this.delay});

  final Widget child;
  final Duration? delay;

  /// grayscale(1) 뒤 brightness(.6)입니다.
  static const matrix = <double>[
    .12756, .42912, .04332, 0, 0, //
    .12756, .42912, .04332, 0, 0, //
    .12756, .42912, .04332, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  State<_QGray> createState() => _QGrayState();
}

class _QGrayState extends State<_QGray> {
  bool _on = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final delay = widget.delay;
    if (delay != null) {
      _timer = Timer(delay, () {
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
  Widget build(BuildContext context) => widget.delay == null
      ? widget.child
      : Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _on ? 1 : 0,
                duration: _qms(400),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(_QGray.matrix),
                  child: widget.child,
                ),
              ),
            ),
          ],
        );
}

//======================================================================
// 시안 SVG 조각
//======================================================================
/// 탈락 X입니다(시안 24×24 뷰박스, 선 굵기 3.4).
class _QCross extends StatelessWidget {
  const _QCross({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _QCrossPainter());
}

class _QCrossPainter extends CustomPainter {
  const _QCrossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final paint = Paint()
      ..color = _qRed
      ..strokeWidth = 3.4 * k
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(5 * k, 5 * k), Offset(19 * k, 19 * k), paint);
    canvas.drawLine(Offset(19 * k, 5 * k), Offset(5 * k, 19 * k), paint);
  }

  @override
  bool shouldRepaint(covariant _QCrossPainter oldDelegate) => false;
}

/// 왕관입니다(시안 46×34 뷰박스).
class _QCrownArt extends StatelessWidget {
  const _QCrownArt({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, width * 34 / 46),
    painter: const _QCrownPainter(),
  );
}

class _QCrownPainter extends CustomPainter {
  const _QCrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 46;
    final path = Path()
      ..moveTo(3 * k, 30 * k)
      ..lineTo(6 * k, 8 * k)
      ..lineTo(16 * k, 18 * k)
      ..lineTo(23 * k, 3 * k)
      ..lineTo(30 * k, 18 * k)
      ..lineTo(40 * k, 8 * k)
      ..lineTo(43 * k, 30 * k)
      ..close();
    canvas.drawPath(path, Paint()..color = _sun);
    canvas.drawPath(
      path,
      Paint()
        ..color = _qBlack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * k
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _QCrownPainter oldDelegate) => false;
}

/// 말풍선 꼬리입니다(아래쪽 20×12 · 왼쪽 14×20).
class _QTail extends StatelessWidget {
  const _QTail({required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: left ? const Size(14, 20) : const Size(20, 12),
    painter: _QTailPainter(left: left),
  );
}

class _QTailPainter extends CustomPainter {
  const _QTailPainter({required this.left});

  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (left) {
      path
        ..moveTo(0, size.height / 2)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    }
    canvas.drawPath(path..close(), Paint()..color = _ink);
  }

  @override
  bool shouldRepaint(covariant _QTailPainter oldDelegate) => false;
}

/// 작은 오른쪽 화살표입니다(시안 24×24 뷰박스).
class _QArrow extends StatelessWidget {
  const _QArrow();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size.square(18), painter: _QArrowPainter());
}

class _QArrowPainter extends CustomPainter {
  const _QArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final paint = Paint()
      ..color = _bone
      ..strokeWidth = 3 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(5 * k, 12 * k), Offset(19 * k, 12 * k), paint);
    canvas.drawPath(
      Path()
        ..moveTo(13 * k, 6 * k)
        ..lineTo(19 * k, 12 * k)
        ..lineTo(13 * k, 18 * k),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _QArrowPainter oldDelegate) => false;
}

//======================================================================
// 공용 조각
//======================================================================
/// 시안 카드입니다('b'는 뒷면).
Widget _qCard(String face, double width) => LiarsPokerCardView(
  face: face == 'b' ? LiarsCardFace.back : _face(face),
  width: width,
  rounded: true,
);

/// 시안 좌석 프로필입니다(사진 76px + 테두리 4px).
class _QAvatar extends StatelessWidget {
  const _QAvatar({required this.characterId, this.size = 76, this.border = 4});

  final String characterId;
  final double size;
  final double border;

  @override
  Widget build(BuildContext context) => Container(
    width: size + border * 2,
    height: size + border * 2,
    decoration: BoxDecoration(
      color: _qWhite,
      shape: BoxShape.circle,
      border: Border.all(color: _ink, width: border),
    ),
    child: ClipOval(
      child: MosiFace(characterId: characterId, size: size),
    ),
  );
}

/// 흰 말풍선입니다.
class _QBubble extends StatelessWidget {
  const _QBubble({required this.child, this.tailLeft = false});

  final Widget child;
  final bool tailLeft;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: _qWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ink, width: 3),
      ),
      child: child,
    );
    return tailLeft
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [const _QTail(left: true), box],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [box, const _QTail(left: false)],
          );
  }
}

/// 시안 알약입니다.
class _QPill extends StatelessWidget {
  const _QPill({
    required this.text,
    required this.background,
    required this.textColor,
    this.fontSize = 22,
    this.border = 3,
    this.borderColor = _ink,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  });

  final String text;
  final Color background;
  final Color textColor;
  final double fontSize;
  final double border;
  final Color borderColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: borderColor, width: border),
    ),
    child: Text(
      text,
      style: LiarsPokerFonts.text(
        size: fontSize,
        weight: FontWeight.w700,
        color: textColor,
      ),
    ),
  );
}

/// 진실·거짓 도장입니다.
class _QStamp extends StatelessWidget {
  const _QStamp({
    required this.truth,
    this.fontSize = 30,
    this.border = 4,
    this.radius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
  });

  final bool truth;
  final double fontSize;
  final double border;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final color = truth ? _truth : _lie;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border > 0 ? Border.all(color: color, width: border) : null,
      ),
      child: Text(
        truth ? _t('진실', 'Truth', '真话', '真話') : _t('거짓', 'Lie', '谎话', '謊話'),
        style: LiarsPokerFonts.headline(
          size: fontSize,
          color: _bone,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

/// 시안 벌칙 룰렛입니다. 실제 게임의 살롱 전구 원판을 그대로 씁니다.
class _QWheel extends StatefulWidget {
  const _QWheel({
    required this.size,
    required this.delay,
    required this.survive,
  });

  final double size;
  final Duration delay;
  final bool survive;

  /// 실제 게임 1회차 칸 구성입니다(위쪽부터 시계 방향, true면 탈락 칸).
  static const sections = [
    true, false, false, false, //
    true, false, false, false, //
    true, false, false, false, //
    true, false, false, false, //
  ];

  @override
  State<_QWheel> createState() => _QWheelState();
}

class _QWheelState extends State<_QWheel> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _qms(2200),
  );
  late final Animation<double> _angle = _c.drive(
    Tween<double>(
      begin: 0,
      // 시안 멈춤 각도: 생존 1383.75도(안전 칸) · 탈락 1428.75도(탈락 칸)
      end: _qRad(widget.survive ? 1383.75 : 1428.75),
    ).chain(CurveTween(curve: const Cubic(.15, .7, .2, 1))),
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
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: RouletteWheel(angle: _angle, sections: _QWheel.sections),
  );
}

//======================================================================
// 태블릿
//======================================================================
class _QTablet extends StatelessWidget {
  const _QTablet({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [for (var i = 0; i < _qSeats.length; i++) _seat(i), ..._scene()],
  );

  /// 자리 하나입니다. 자리는 3단계에서만 사라집니다.
  Widget _seat(int i) {
    final (center, angle) = _qSeats[i];
    final out = step == 1 && i > 0;
    final at = step == 1 ? .6 + (i - 1) * .5 : 0;
    final win = step == 1 && i == 0;
    return Positioned(
      left: center.dx - 60,
      top: center.dy - 60,
      width: 120,
      height: 120,
      child: AnimatedOpacity(
        opacity: step == 3 ? 0 : 1,
        duration: _qms(400),
        child: Transform.rotate(
          angle: _qRad(angle),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _QGray(
                  delay: out ? _qs(at) : null,
                  child: win
                      ? _qWinGlow(
                          _QAvatar(characterId: _qCast[i].$2),
                          delay: 2.4,
                        )
                      : _QAvatar(characterId: _qCast[i].$2),
                ),
                if (out)
                  Positioned(
                    left: -10,
                    top: -10,
                    child: _qPop(
                      const _QCross(size: 96),
                      delay: at,
                      duration: .4,
                    ),
                  ),
                if (win)
                  Positioned(
                    left: 9,
                    top: -40,
                    child: _qCrown(const _QCrownArt(width: 58), delay: 2.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 자리 뒤에 두는 강조 고리입니다.
  Widget _ring(int seat, {Color color = _sun}) {
    final center = _qSeats[seat].$1;
    return Positioned(
      left: center.dx - 46,
      top: center.dy - 46,
      width: 92,
      height: 92,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, spreadRadius: 4),
            BoxShadow(
              color: color.withValues(alpha: .55),
              blurRadius: 24,
              spreadRadius: 8,
            ),
          ],
        ),
      ),
    );
  }

  /// 가운데 카드 자리입니다([k]는 0 또는 1).
  Widget _centerCard(int k, Widget child) => Positioned(
    left: _qCardsAt.dx + k * (_qCardW + _qCardGap),
    top: _qCardsAt.dy,
    child: child,
  );

  /// 시안 bubble(x, y)입니다. 꼬리가 아래면 x가 가운데, 왼쪽이면 x가 왼쪽 끝입니다.
  Widget _bubbleAt(double x, double y, Widget child, {bool tailLeft = false}) =>
      tailLeft
      ? Positioned(left: x, top: y, child: child)
      : Positioned(
          left: x - 160,
          top: y,
          width: 320,
          child: Align(alignment: Alignment.topCenter, child: child),
        );

  Widget _quote(String text, {Color color = _ink}) => Text(
    text,
    style: LiarsPokerFonts.text(
      size: 26,
      weight: FontWeight.w700,
      color: color,
    ),
  );

  /// 믿기·LIAR 선택 상자입니다. [liar]면 LIAR가 골라집니다.
  Widget _choiceBox({required bool liar, required num at}) => _QBubble(
    tailLeft: true,
    child: SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pick(
            picked: !liar,
            at: at,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _bone,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _ink, width: 2),
              ),
              child: Text(
                _t('믿고 내 카드 내기', 'Trust & play', '相信并出牌', '相信並出牌'),
                style: LiarsPokerFonts.text(
                  size: 20,
                  weight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _pick(
            picked: liar,
            at: at,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _lie,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _ink, width: 2),
              ),
              child: Text(
                'LIAR!',
                textAlign: TextAlign.center,
                style: LiarsPokerFonts.text(
                  size: 24,
                  weight: FontWeight.w700,
                  color: _bone,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _pick({
    required bool picked,
    required num at,
    required Widget child,
  }) => picked
      ? _qPickPulse(child, delay: at)
      : _QFade(delay: _qs(at), to: .3, child: child);

  /// 벌칙 화면입니다. 어둡게 덮고 자리 사진과 룰렛을 크게 보여 줍니다.
  Widget _penalty({required int seat, required num at, required bool survive}) {
    final result = at + 2.7;
    return Positioned.fill(
      child: TutorialLater(
        at: _qs(at),
        child: _qPop(
          ColoredBox(
            color: const Color(0x9E0A0604),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _QGray(
                            delay: survive ? null : _qs(result),
                            child: survive
                                ? _qWinGlow(
                                    _QAvatar(
                                      characterId: _qCast[seat].$2,
                                      size: 88,
                                      border: 5,
                                    ),
                                    delay: result,
                                    duration: 1,
                                  )
                                : _QAvatar(
                                    characterId: _qCast[seat].$2,
                                    size: 88,
                                    border: 5,
                                  ),
                          ),
                          if (!survive)
                            Positioned(
                              left: -4,
                              top: -4,
                              child: _qPop(
                                const _QCross(size: 96),
                                delay: result,
                                duration: .4,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _QPill(
                        text: _t(
                          '${_qCast[seat].$1} 벌칙',
                          '${_qCast[seat].$1} · penalty',
                          '${_qCast[seat].$1} 惩罚',
                          '${_qCast[seat].$1} 懲罰',
                        ),
                        background: _lie,
                        textColor: _bone,
                      ),
                    ],
                  ),
                  const SizedBox(width: 34),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      _QWheel(size: 304, delay: _qs(at + .4), survive: survive),
                      _qSlam(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: survive ? _truth : _lie,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _bone, width: 5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x800A0604),
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Text(
                            survive
                                ? _t('생존!', 'Safe!', '存活！', '存活！')
                                : _t('탈락!', 'Out!', '淘汰！', '淘汰！'),
                            style: LiarsPokerFonts.headline(
                              size: 44,
                              color: _bone,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        delay: result,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          duration: .35,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  /// 3단계 '뒤집어 보면?' 한 경우입니다.
  Widget _caseColumn(String faces, num start) {
    const w = 70.0;
    final truth = !faces.contains('l');
    final stampAt = start + faces.length * .18 + .4;
    return SizedBox(
      width: 176,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 103,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                SizedBox(
                  width: w + (faces.length - 1) * (w - 22),
                  height: 103,
                  child: Stack(
                    children: [
                      for (var k = 0; k < faces.length; k++)
                        Positioned(
                          left: k * (w - 22),
                          child: _qFlipOut(
                            _qCard('b', w),
                            delay: start + k * .18,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: w + (faces.length - 1) * (w - 22),
                  height: 103,
                  child: Stack(
                    children: [
                      for (var k = 0; k < faces.length; k++)
                        Positioned(
                          left: k * (w - 22),
                          child: _qFlipIn(
                            _qCard(faces[k], w),
                            delay: start + k * .18 + .2,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: Center(
              child: _qSlam(_QStamp(truth: truth), delay: stampAt),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _scene() {
    switch (step) {
      case 0:
        return [
          Positioned.fill(
            child: Center(
              child: _qPop(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LIARS',
                      style:
                          MosiFonts.grotesk(
                            size: 64,
                            weight: FontWeight.w700,
                            color: _bone,
                            letterSpacing: 6,
                            height: 1,
                          ).copyWith(
                            shadows: const [
                              Shadow(color: _ink, offset: Offset(0, 5)),
                            ],
                          ),
                    ),
                    const SizedBox(height: 6),
                    _QPill(
                      text: _t('규칙 1분 요약', '1-minute rules', '1分钟规则', '1分鐘規則'),
                      background: _sun,
                      textColor: _qBlack,
                      fontSize: 16,
                      borderColor: _qBlack,
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
          _ring(0),
          _centerCard(0, _qSlideUp(_qCard('b', _qCardW), delay: .3)),
          _centerCard(1, _qSlideUp(_qCard('b', _qCardW), delay: .5)),
          _bubbleAt(
            250,
            430,
            _qPop(
              _QBubble(
                child: _quote(
                  _t('“진실 2장!”', '“2 truths!”', '“两张真话！”', '「兩張真話！」'),
                ),
              ),
              delay: 1.2,
            ),
          ),
        ];
      case 3:
        return [
          Positioned(
            left: 0,
            right: 0,
            top: 176,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (ci, faces) in const [
                  (0, 't'),
                  (1, 'tl'),
                  (2, 'ttt'),
                  (3, 'ltl'),
                ])
                  Padding(
                    padding: EdgeInsets.only(left: ci == 0 ? 0 : 14),
                    child: _caseColumn(faces, .9 + ci * 1.3),
                  ),
              ],
            ),
          ),
        ];
      case 4:
        return [
          _ring(1),
          _centerCard(0, _qCard('b', _qCardW)),
          _centerCard(1, _qCard('b', _qCardW)),
          _bubbleAt(
            250,
            430,
            _QFade(
              delay: _qs(2.6),
              from: .75,
              child: _QBubble(
                child: _quote(
                  _t('“진실 2장!”', '“2 truths!”', '“两张真话！”', '「兩張真話！」'),
                ),
              ),
            ),
          ),
          Positioned(
            left: 112,
            top: 196,
            child: _QFade(
              delay: _qs(2.6),
              child: _qPop(_choiceBox(liar: false, at: 1.8), delay: .6),
            ),
          ),
          Positioned(
            left: 346,
            top: 192,
            child: _qFromPot(_qCard('b', _qCardW), delay: 2.6),
          ),
          _bubbleAt(
            214,
            372,
            _qPop(
              _QBubble(
                child: _quote(
                  _t('“진실 1장!”', '“1 truth!”', '“一张真话！”', '「一張真話！」'),
                ),
              ),
              delay: 3.3,
            ),
          ),
        ];
      case 5:
        return [
          _ring(1),
          _centerCard(0, _qFlipOut(_qCard('b', _qCardW), delay: 3.0)),
          _centerCard(1, _qFlipOut(_qCard('b', _qCardW), delay: 3.25)),
          _centerCard(
            0,
            _qFlipIn(_qCard('t', _qCardW), delay: 3.22, duration: .5),
          ),
          _centerCard(
            1,
            _qFlipIn(_qCard('l', _qCardW), delay: 3.47, duration: .5),
          ),
          _bubbleAt(
            250,
            430,
            Opacity(
              opacity: .75,
              child: _QBubble(
                child: _quote(
                  _t('“진실 2장!”', '“2 truths!”', '“两张真话！”', '「兩張真話！」'),
                ),
              ),
            ),
          ),
          Positioned(
            left: 112,
            top: 196,
            child: _qPop(_choiceBox(liar: true, at: 2.2), delay: .6),
          ),
          _penalty(seat: 0, at: 4.8, survive: true),
        ];
      default:
        return [
          _ring(1, color: _qRed),
          _bubbleAt(
            118,
            214,
            _QFade(
              delay: _qs(3.4),
              child: _QBubble(
                tailLeft: true,
                child: _quote('LIAR!', color: _lie),
              ),
            ),
            tailLeft: true,
          ),
          _centerCard(0, _qFlipOut(_qCard('b', _qCardW), delay: 1.2)),
          _centerCard(1, _qFlipOut(_qCard('b', _qCardW), delay: 1.45)),
          _centerCard(
            0,
            _qFlipIn(_qCard('t', _qCardW), delay: 1.42, duration: .5),
          ),
          _centerCard(
            1,
            _qFlipIn(_qCard('t', _qCardW), delay: 1.67, duration: .5),
          ),
          _penalty(seat: 1, at: 3.6, survive: false),
        ];
    }
  }
}

//======================================================================
// 휴대폰
//======================================================================
class _QPhone extends StatelessWidget {
  const _QPhone({required this.view});

  final TutorialPhoneView view;

  /// 시안 CAP입니다(문구, 바뀌는 초, 두 번째 문구).
  static (List<(String, Duration)>, String?) _caption(int step) {
    (String, Duration) p(
      String ko,
      String en,
      String zh,
      String zt, [
      num at = 0,
    ]) => (_t(ko, en, zh, zt), _qs(at));
    return switch (step) {
      0 => (
        [p('라이어스 1분 요약', 'Liars in 1 minute', '1分钟看懂说谎者', '1分鐘看懂說謊者')],
        _t('태블릿과 함께 봐요', 'Watch with the tablet', '和平板一起看', '和平板一起看'),
      ),
      1 => (
        [
          p(
            '끝까지 살아남는 1명이 이겨요',
            'The last one standing wins',
            '坚持到最后的1人获胜',
            '堅持到最後的1人獲勝',
          ),
        ],
        null,
      ),
      2 => (
        [
          p(
            '카드를 내면 상대는 뒷면만 볼 수 있어요',
            'Others only see the backs of your cards',
            '你出的牌别人只能看到背面',
            '你出的牌別人只能看到背面',
          ),
          p(
            '그래서 거짓 카드를 섞어 내도 아무도 몰라요!',
            'So no one knows if you slip in a lie!',
            '所以混进谎话牌也没人知道！',
            '所以混進謊話牌也沒人知道！',
            3.0,
          ),
        ],
        null,
      ),
      3 => (
        [
          p(
            '뒷면 카드, 뒤집어 보면?',
            'Flip the face-down cards?',
            '把背面的牌翻过来？',
            '把背面的牌翻過來？',
          ),
          p(
            '1장이라도 거짓이 섞이면 → 거짓!',
            'Even one lie → it’s a lie!',
            '只要混了一张谎话 → 就是谎话！',
            '只要混了一張謊話 → 就是謊話！',
            6.5,
          ),
        ],
        null,
      ),
      4 => (
        [
          p('앞사람 말을 믿으면?', 'Trust the previous player?', '相信上一个人？', '相信上一個人？'),
          p(
            'LIAR를 안 외치면 할 일은 하나, 내 카드 내기!',
            'No LIAR? Then just play your cards!',
            '不喊 LIAR 就只做一件事：出牌！',
            '不喊 LIAR 就只做一件事：出牌！',
            2.7,
          ),
        ],
        null,
      ),
      5 => (
        [
          p(
            '앞사람이 거짓을 낸 것 같으면 LIAR!',
            'Think they lied? Call LIAR!',
            '觉得上一个人说谎就喊 LIAR！',
            '覺得上一個人說謊就喊 LIAR！',
          ),
          p(
            '맞히면 → 카드를 낸 사람이 벌칙!',
            'Right → the one who played gets the penalty!',
            '猜对 → 出牌的人受罚！',
            '猜對 → 出牌的人受罰！',
            4.3,
          ),
        ],
        null,
      ),
      _ => (
        [
          p(
            '그런데 뒤집었더니 전부 진실이면?',
            'But what if they’re all truths?',
            '可是翻开全是真话呢？',
            '可是翻開全是真話呢？',
          ),
          p(
            '틀렸으니 → LIAR를 외친 내가 벌칙!',
            'Wrong → the LIAR caller gets the penalty!',
            '猜错 → 喊 LIAR 的我受罚！',
            '猜錯 → 喊 LIAR 的我受罰！',
            3.3,
          ),
        ],
        null,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (phases, sub) = _caption(view.step);
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 70,
          height: 330,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _mini(),
                const SizedBox(height: 14),
                TutorialPhaseCaption(
                  phases: phases,
                  sub: sub,
                  style: LiarsPokerFonts.text(
                    size: 23,
                    weight: FontWeight.w700,
                    color: _bone,
                    height: 1.35,
                  ),
                  subStyle: LiarsPokerFonts.text(
                    size: 15,
                    weight: FontWeight.w700,
                    color: _gold,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 150,
          child: Center(
            child: _QSkip(on: view.skipOn, onPressed: view.toggleSkip),
          ),
        ),
      ],
    );
  }

  /// 시안 휴대폰 안내판입니다.
  Widget _panel(List<Widget> children) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0x9917110F),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );

  Widget _avatar(int i, {double size = 40, double border = 3}) => Container(
    width: size + border * 2,
    height: size + border * 2,
    decoration: BoxDecoration(
      color: _qWhite,
      shape: BoxShape.circle,
      border: Border.all(color: _ink, width: border),
    ),
    child: ClipOval(
      child: MosiFace(characterId: _qCast[i].$2, size: size),
    ),
  );

  /// 벌칙을 받는 사람입니다.
  Widget _penaltyFace(int i) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _avatar(i, size: 46),
      const SizedBox(height: 4),
      _QPill(
        text: _t('벌칙', 'Penalty', '惩罚', '懲罰'),
        background: _lie,
        textColor: _bone,
        fontSize: 14,
        border: 2,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    ],
  );

  Widget _caseRow(String faces, bool truth) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _qCard(faces[0], 40),
      const SizedBox(width: 8),
      _qCard(faces[1], 40),
      const SizedBox(width: 8),
      const _QArrow(),
      const SizedBox(width: 8),
      Transform.rotate(
        angle: _qRad(-6),
        child: _QStamp(
          truth: truth,
          fontSize: 18,
          border: 0,
          radius: 8,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        ),
      ),
    ],
  );

  Widget _mini() {
    switch (view.step) {
      case 0:
        return Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: _qWhite,
            shape: BoxShape.circle,
            border: Border.all(color: _qBlack, width: 3),
          ),
          child: ClipOval(child: MosiFace(characterId: _qCast[0].$2, size: 76)),
        );
      case 1:
        return _panel([
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < _qCast.length; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _QGray(
                          delay: i == 0 ? null : _qs(.6 + (i - 1) * .5),
                          child: _avatar(i, size: 34),
                        ),
                        if (i == 0)
                          Positioned(
                            left: 5,
                            top: -20,
                            child: _qCrown(
                              const _QCrownArt(width: 30),
                              delay: 2.6,
                            ),
                          )
                        else
                          Positioned(
                            left: -2,
                            top: -2,
                            child: _qPop(
                              const _QCross(size: 44),
                              delay: .6 + (i - 1) * .5,
                              duration: .4,
                            ),
                          ),
                      ],
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
              _qCard('b', 54),
              const SizedBox(width: 8),
              _qCard('b', 54),
            ],
          ),
        ]);
      case 3:
        return _panel([
          _caseRow('tl', false),
          const SizedBox(height: 10),
          _caseRow('tt', true),
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
                weight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _QArrow(),
              const SizedBox(width: 8),
              _qCard('b', 48),
              const SizedBox(width: 8),
              Text(
                _t('다음 사람', 'Next player', '下一个人', '下一個人'),
                style: LiarsPokerFonts.text(
                  size: 15,
                  weight: FontWeight.w700,
                  color: _bone,
                ),
              ),
            ],
          ),
        ]);
      case 5:
        return _panel([
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _qCard('t', 40),
              const SizedBox(width: 10),
              _qCard('l', 40),
              const SizedBox(width: 10),
              const _QArrow(),
              const SizedBox(width: 10),
              _penaltyFace(0),
            ],
          ),
        ]);
      default:
        return _panel([
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _qCard('t', 40),
              const SizedBox(width: 10),
              _qCard('t', 40),
              const SizedBox(width: 10),
              const _QArrow(),
              const SizedBox(width: 10),
              _penaltyFace(1),
            ],
          ),
        ]);
    }
  }
}

/// 시안 건너뛰기 버튼입니다.
class _QSkip extends StatelessWidget {
  const _QSkip({required this.on, required this.onPressed});

  final bool on;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(minWidth: 150),
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: on ? _sun : _bone.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: on ? _qBlack : _bone.withValues(alpha: .55),
            width: 3,
          ),
          boxShadow: const [BoxShadow(color: _qNavy, offset: Offset(0, 4))],
        ),
        child: Text(
          on
              ? _t('건너뛰기 취소', 'Cancel skip', '取消跳过', '取消跳過')
              : _t('건너뛰기', 'Skip', '跳过', '跳過'),
          style: LiarsPokerFonts.text(
            size: 16,
            weight: FontWeight.w700,
            color: on ? _qBlack : _bone,
          ),
        ),
      ),
    ),
  );
}
