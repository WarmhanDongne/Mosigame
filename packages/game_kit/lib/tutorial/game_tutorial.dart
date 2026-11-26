// [game_tutorial.dart] 는 자리 배치가 끝난 뒤 태블릿과 휴대폰이 함께 보는
// 첫 플레이 튜토리얼의 공통 틀을 정의하는 파일이다.
//
// - [GameTutorial] : 게임마다 구현하는 튜토리얼 내용(단계 수·화면)
// - [GameTutorialTabletHost] : 태블릿 진행자. 모두 확인하면 다음 단계로 넘기고,
//   모두 건너뛰면 끝 화면, 모두 고르면 게임 시작/다시 보기를 정합니다.
// - [GameTutorialPhoneGate] : 휴대폰. 튜토리얼이 열리면 자리 배치 대기 화면 대신
//   튜토리얼을 보여 주고, 확인·연습·건너뛰기·선택을 자기 칸에 씁니다.
//
// 진행 규칙(시안과 같음)
// - 안내 단계: 모두 '이해했어요'를 눌러야 다음 단계
// - 연습 단계: 모두 해 봐야 다음 단계
// - 건너뛰기: 모두 눌러야 끝 화면으로
// - 끝 화면: 모두 고르면 진행. 한 명이라도 '다시 보기'면 처음부터 다시
//
// 자동 진행([GameTutorial.autoPlay], 1분 요약)
// - 단계마다 정해진 시간([GameTutorial.autoDuration])이 지나면 저절로 넘어감
// - 건너뛰기: 모두 누르면 바로 게임 시작
// - 끝 화면: 5초 카운트 뒤 '게임 시작!'과 함께 바로 게임. 태블릿의 '다시 보기'를
//   누르면 처음부터 다시

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/tutorial/tutorial_session.dart';

export 'package:game_kit/tutorial/tutorial_session.dart';

// ============================================================

String _t(String ko, String en, String zhHans, String zhHant) =>
    GameLocale.select(ko: ko, en: en, zhHans: zhHans, zhHant: zhHant);

const _ink = Color(0xFF111111);
const _navy = Color(0xFF0E0A3D);
const _lime = Color(0xFFA4D65E);
const _sun = Color(0xFFF2E14C);
const _violet = Color(0xFF5A3FF0);
const _violetDeep = Color(0xFF3A22C8);
const _muted = Color(0xFF55527A);
const _cream = Color(0xFFF7F4EC);

/// 자동 진행 끝 화면에서 게임으로 들어가기 전 세는 시간입니다.
const _autoEndCountdown = Duration(seconds: 5);

//==========[ 튜토리얼에 나오는 플레이어 ]==========
class TutorialPlayer {
  const TutorialPlayer({
    required this.uid,
    required this.nickname,
    required this.characterId,
    this.seatIndex = 0,
  });

  final String uid;
  final String nickname;
  final String characterId;

  /// 태블릿 자리 번호입니다(자리 배치 결과).
  final int seatIndex;
}

//==========[ 태블릿이 그릴 때 받는 값 ]==========
class TutorialTabletView {
  const TutorialTabletView({
    required this.size,
    required this.players,
    required this.step,
    required this.phase,
    required this.round,
    required this.entries,
    required this.ended,
  });

  /// 그림 영역 크기입니다. 화면 비율에 맞춰 늘어나므로 고정값 대신 이 값을 씁니다.
  final Size size;

  /// 자리 배치 순서의 플레이어입니다.
  final List<TutorialPlayer> players;
  final int step;
  final int phase;
  final int round;

  /// 지금 회차에 플레이어가 쓴 응답입니다.
  final Map<String, TutorialEntry> entries;
  final bool ended;

  int get playerCount => players.length;

  bool isDone(String uid) {
    final entry = entries[uid];
    return entry != null &&
        entry.step == step &&
        entry.phase == phase &&
        entry.done;
  }

  int get doneCount => players.where((p) => isDone(p.uid)).length;

  /// 그 플레이어가 이번 회차에 남겨 둔 값입니다(예: 낸 카드).
  String memoOf(String uid) => entries[uid]?.memo ?? '';

  /// [stepOf] 단계에서 그 플레이어가 마친 연습 값입니다. 다른 단계면 빈 문자열입니다.
  String valueAt(String uid, int stepOf) {
    final entry = entries[uid];
    if (entry == null || entry.step != stepOf || !entry.done) return '';
    return entry.value;
  }
}

//==========[ 휴대폰이 그릴 때 받는 값 ]==========
class TutorialPhoneView {
  const TutorialPhoneView({
    required this.me,
    required this.players,
    required this.step,
    required this.phase,
    required this.round,
    required this.done,
    required this.value,
    required this.memo,
    required this.doneCount,
    required this.ended,
    required this.complete,
    this.skipOn = false,
    this.toggleSkip,
  });

  final TutorialPlayer me;
  final List<TutorialPlayer> players;
  final int step;
  final int phase;
  final int round;

  /// 이번 단계·장면을 마쳤는지입니다.
  final bool done;

  /// 이번 단계에서 마친 연습 값입니다.
  final String value;

  /// 이번 회차에 남겨 둔 값입니다(예: 앞 단계에서 낸 카드).
  final String memo;

  /// 이번 단계를 마친 사람 수입니다(익명).
  final int doneCount;
  final bool ended;

  /// 연습을 마치고 결과 값을 보냅니다. [memo]를 주면 다음 단계에도 남겨 둡니다.
  final void Function(String value, {String? memo}) complete;

  /// 내가 건너뛰기를 눌렀는지입니다. [GameTutorial.autoPlay]에서 튜토리얼이
  /// 건너뛰기 버튼을 직접 그릴 때 씁니다.
  final bool skipOn;

  /// 건너뛰기를 켜고 끕니다.
  final VoidCallback? toggleSkip;

  int get playerCount => players.length;

  int get myIndex {
    final index = players.indexWhere((p) => p.uid == me.uid);
    return index < 0 ? 0 : index;
  }
}

//==========[ 게임마다 구현하는 튜토리얼 ]==========
abstract class GameTutorial {
  const GameTutorial();

  /// 게임 id(서버·카탈로그와 같음)입니다.
  String get gameId;

  /// 끝 화면(게임 시작/다시 보기)까지 포함한 단계 수입니다.
  int get stepCount;

  /// 마지막 단계는 끝 화면입니다.
  int get endStep => stepCount - 1;

  /// 한 단계 안의 장면 수입니다. 기본은 1입니다.
  int phaseCount(int step) => 1;

  /// '이해했어요'로 넘기는 안내 장면인지입니다. 아니면 연습 장면입니다.
  bool isInfo(int step, int phase);

  /// 첫 단계의 확인 버튼 문구입니다.
  String get startLabel => _t('튜토리얼 시작!', 'Start tutorial!', '开始教程！', '開始教學！');

  /// 끝난 뒤 'GAME START' 아래에 보일 게임 이름입니다.
  String get title;

  /// 태블릿 배경(디자인 영역 바깥까지 채움)입니다.
  Widget buildTabletBackground(BuildContext context) =>
      const ColoredBox(color: _navy);

  /// 휴대폰 배경입니다.
  Widget buildPhoneBackground(BuildContext context) =>
      const ColoredBox(color: _navy);

  /// 태블릿 그림 영역의 기준 크기입니다. 실제로는 화면 비율에 맞춰 한쪽을 늘려
  /// 화면 전체를 채웁니다([TutorialTabletView.size]).
  Size get tabletDesignSize => const Size(1180, 820);

  /// 휴대폰 그림 영역 크기입니다.
  Size get phoneDesignSize => const Size(390, 844);

  Widget buildTablet(BuildContext context, TutorialTabletView view);

  Widget buildPhone(BuildContext context, TutorialPhoneView view);

  //----------[ 자동 진행(1분 요약) ]----------
  /// 장면이 정해진 시간마다 저절로 넘어가는 방식인지입니다. true면 확인 버튼이
  /// 없고, 모두 건너뛰면 바로 게임을 시작하며, 끝 화면은 5초 카운트 뒤 게임으로
  /// 들어갑니다.
  bool get autoPlay => false;

  /// 튜토리얼이 열린 동안 휴대폰을 가로로 돌릴지입니다. 휴대폰 게임 화면이
  /// 가로인 게임(파이널콜)에서 씁니다. [phoneDesignSize]도 가로로 맞추세요.
  /// 튜토리얼이 끝나 게임이 시작되면 가로를 그대로 두고(게임이 이어받음),
  /// 그 밖의 이유로 닫히면 대기 화면의 세로로 되돌립니다.
  bool get phoneLandscape => false;

  /// 끝 화면(목표 문구·다시 보기·게임 시작!)의 색과 글꼴입니다.
  TutorialEndStyle get autoEndStyle => const TutorialEndStyle();

  /// [autoPlay]일 때 [step] 단계를 보여 주는 시간입니다.
  Duration autoDuration(int step) => const Duration(seconds: 5);

  /// [autoPlay] 끝 화면의 한 줄 목표 문구입니다(태블릿).
  Widget buildAutoEndSlogan(BuildContext context) => Text(
    title,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: _cream,
      fontWeight: FontWeight.w900,
      fontSize: 64,
      height: 1.25,
      shadows: [Shadow(color: _ink, offset: Offset(0, 5))],
    ),
  );

  /// [autoPlay] 끝 화면 동안 휴대폰에 보일 화면입니다.
  Widget buildPhoneEnd(BuildContext context, TutorialPhoneView view) =>
      const TutorialLookAtTablet();
}

//==========[ 공용 연출: 지연 등장 ]==========
/// [delay] 뒤에 살짝 떠오르며 나타납니다. 시안의 rise·pop·slideIn과 같습니다.
class TutorialAppear extends StatefulWidget {
  const TutorialAppear({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offset = const Offset(0, 18),
    this.fromScale = 1,
    this.curve = Curves.easeOutBack,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final double fromScale;
  final Curve curve;

  @override
  State<TutorialAppear> createState() => _TutorialAppearState();
}

class _TutorialAppearState extends State<TutorialAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final t = widget.curve.transform(_controller.value);
      final fade = Curves.easeOut.transform(_controller.value);
      return Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: widget.offset * (1 - t),
          child: Transform.scale(
            scale: widget.fromScale + (1 - widget.fromScale) * t,
            child: child,
          ),
        ),
      );
    },
  );
}

//==========[ 공용 연출: 반복 맥박 ]==========
/// 눌러야 할 버튼 둘레에 노란 고리가 퍼집니다.
class TutorialPulse extends StatefulWidget {
  const TutorialPulse({
    super.key,
    required this.child,
    this.enabled = true,
    this.radius = 18,
  });

  final Widget child;
  final bool enabled;
  final double radius;

  @override
  State<TutorialPulse> createState() => _TutorialPulseState();
}

class _TutorialPulseState extends State<TutorialPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            BoxShadow(
              color: _sun.withValues(alpha: .85 * (1 - _controller.value)),
              spreadRadius: 22 * _controller.value,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

//==========[ 공용 코치마크: 안내 카드 ]==========
class TutorialCoachTip extends StatelessWidget {
  const TutorialCoachTip({
    super.key,
    required this.badge,
    required this.title,
    required this.body,
    this.action,
    this.width = 330,
    this.delay = Duration.zero,
    this.warning = false,
    this.scale = 1,
  });

  final String badge;
  final String title;
  final String body;
  final String? action;
  final double width;
  final Duration delay;

  /// 잘못 눌렀을 때 테두리를 빨갛게 합니다.
  final bool warning;

  /// 글자 크기 배율입니다(태블릿은 1.3 정도).
  final double scale;

  @override
  Widget build(BuildContext context) => TutorialAppear(
    // 단계·문구가 바뀌면 다시 떠오르게 합니다.
    key: ValueKey('$badge|$title|$body'),
    delay: delay,
    offset: const Offset(0, -20),
    fromScale: .92,
    child: Container(
      width: width,
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        13 * scale,
        16 * scale,
        14 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * scale),
        border: Border.all(
          color: warning ? const Color(0xFFE0465A) : _ink,
          width: 3,
        ),
        boxShadow: const [BoxShadow(color: _navy, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 9 * scale,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: _violet,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _ink, width: 2),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12 * scale,
                  ),
                ),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 16 * scale,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6 * scale),
          Text(
            body,
            style: TextStyle(
              color: _muted,
              fontSize: 13.5 * scale,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (action != null && action!.isNotEmpty) ...[
            SizedBox(height: 8 * scale),
            Row(
              children: [
                Icon(
                  Icons.arrow_forward_rounded,
                  color: _violetDeep,
                  size: 16 * scale,
                ),
                SizedBox(width: 6 * scale),
                Expanded(
                  child: Text(
                    action!,
                    style: TextStyle(
                      color: _violetDeep,
                      fontWeight: FontWeight.w800,
                      fontSize: 13 * scale,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

//==========[ 공용 코치마크: 강조 고리 ]==========
/// 강조할 영역만 밝게 남기고 나머지를 어둡게 덮습니다.
class TutorialSpot extends StatefulWidget {
  const TutorialSpot({
    super.key,
    required this.rect,
    this.radius = 22,
    this.dim = true,
  });

  final Rect rect;
  final double radius;
  final bool dim;

  @override
  State<TutorialSpot> createState() => _TutorialSpotState();
}

class _TutorialSpotState extends State<TutorialSpot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fromRect(
    rect: widget.rect,
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: _sun, width: 3),
            boxShadow: [
              if (widget.dim)
                const BoxShadow(color: Color(0x9E080418), spreadRadius: 2000),
              BoxShadow(
                color: _sun.withValues(alpha: .9 * (1 - _controller.value)),
                spreadRadius: 18 * _controller.value,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

//==========[ 공용 코치마크: 누르는 손 ]==========
class TutorialHand extends StatefulWidget {
  const TutorialHand({super.key, required this.at, this.size = 52});

  /// 손가락 끝이 놓일 위치입니다.
  final Offset at;
  final double size;

  @override
  State<TutorialHand> createState() => _TutorialHandState();
}

class _TutorialHandState extends State<TutorialHand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: widget.at.dx - widget.size * .3,
    top: widget.at.dy - widget.size * .1,
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final v = _controller.value;
          // 0.45에서 위로 들었다가 0.6에서 꾹 누릅니다.
          final lift = v < .45
              ? v / .45
              : v < .6
              ? 1.0
              : 1 - (v - .6) / .4;
          final press = v >= .45 && v < .6 ? .88 : 1.0;
          return Transform.translate(
            offset: Offset(-6 * lift, -10 * lift),
            child: Transform.scale(scale: press, child: child),
          );
        },
        child: Stack(
          children: [
            Icon(Icons.touch_app, size: widget.size + 4, color: _ink),
            Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.touch_app,
                size: widget.size,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

//==========[ 태블릿 진행자 ]==========
/// 자리 배치 위에 올라오는 태블릿 튜토리얼 화면입니다.
///
/// 결과가 `start`가 되면 [onFinished]에 true를 넘깁니다. 화면이 닫히면(참가자
/// 변경 등) 호출한 쪽이 false로 처리합니다.
class GameTutorialTabletHost extends StatefulWidget {
  const GameTutorialTabletHost({
    super.key,
    required this.tutorial,
    required this.service,
    required this.players,
    required this.onFinished,
  });

  final GameTutorial tutorial;
  final GameTutorialService service;
  final List<TutorialPlayer> players;
  final ValueChanged<bool> onFinished;

  @override
  State<GameTutorialTabletHost> createState() => _GameTutorialTabletHostState();
}

class _GameTutorialTabletHostState extends State<GameTutorialTabletHost> {
  StreamSubscription<TutorialSnapshot>? _subscription;
  TutorialSnapshot _snapshot = const TutorialSnapshot();
  Timer? _advance;
  String? _scheduledFor;
  bool _starting = false;

  GameTutorial get _tutorial => widget.tutorial;

  @override
  void initState() {
    super.initState();
    _subscription = widget.service.watch().listen(_onSnapshot);
  }

  @override
  void dispose() {
    _advance?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  Map<String, TutorialEntry> _entriesOf(TutorialSession session) => {
    for (final player in widget.players)
      if (_snapshot.entries[player.uid]?.belongsTo(session) ?? false)
        player.uid: _snapshot.entries[player.uid]!,
  };

  void _onSnapshot(TutorialSnapshot snapshot) {
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
    final session = snapshot.session;
    if (session == null || !session.running || _starting) return;
    final entries = _entriesOf(session);
    final uids = widget.players.map((p) => p.uid).toList();
    bool all(bool Function(TutorialEntry) test) =>
        uids.isNotEmpty &&
        uids.every((uid) => entries[uid] != null && test(entries[uid]!));

    if (_tutorial.autoPlay) {
      _onAutoSnapshot(session, all);
      return;
    }
    final endMode = session.ended || session.step >= _tutorial.endStep;
    // 끝 화면: 모두 고르면 진행합니다.
    if (endMode) {
      if (all((e) => e.choice == 'start' || e.choice == 'replay')) {
        final replay = entries.values.any((e) => e.choice == 'replay');
        _schedule(
          'choose-${session.round}',
          const Duration(milliseconds: 700),
          () {
            if (replay) {
              unawaited(
                widget.service.update({
                  'round': session.round + 1,
                  'step': 0,
                  'phase': 0,
                  'ended': false,
                }),
              );
            } else {
              _finish();
            }
          },
        );
      }
      return;
    }
    // 건너뛰기: 모두 눌러야 끝 화면으로 갑니다.
    if (all((e) => e.skip)) {
      _schedule('skip-${session.round}', const Duration(milliseconds: 300), () {
        unawaited(widget.service.update({'ended': true}));
      });
      return;
    }
    // 단계: 모두 마치면 다음 장면·단계로 넘깁니다.
    if (all((e) => e.doneAt(session))) {
      final info = _tutorial.isInfo(session.step, session.phase);
      final key = 'advance-${session.round}-${session.step}-${session.phase}';
      _schedule(
        key,
        info
            ? const Duration(milliseconds: 450)
            : const Duration(milliseconds: 1400),
        () {
          final nextPhase = session.phase + 1;
          if (nextPhase < _tutorial.phaseCount(session.step)) {
            unawaited(widget.service.update({'phase': nextPhase}));
          } else {
            unawaited(
              widget.service.update({'step': session.step + 1, 'phase': 0}),
            );
          }
        },
      );
    }
  }

  /// 자동 진행: 단계 시간이 지나면 넘기고, 끝 화면은 카운트 뒤 시작합니다.
  void _onAutoSnapshot(
    TutorialSession session,
    bool Function(bool Function(TutorialEntry)) all,
  ) {
    if (all((e) => e.skip)) {
      _schedule(
        'auto-skip-${session.round}',
        const Duration(milliseconds: 300),
        _finish,
      );
      return;
    }
    if (session.ended || session.step >= _tutorial.endStep) {
      _schedule(
        'auto-end-${session.round}',
        _autoEndCountdown + const Duration(milliseconds: 900),
        _finish,
      );
      return;
    }
    _schedule(
      'auto-${session.round}-${session.step}',
      _tutorial.autoDuration(session.step),
      () => unawaited(
        widget.service.update({'step': session.step + 1, 'phase': 0}),
      ),
    );
  }

  /// 끝 화면의 '다시 보기': 처음부터 다시 봅니다.
  void _replay() {
    final session = _snapshot.session;
    if (session == null || _starting) return;
    _advance?.cancel();
    _scheduledFor = null;
    unawaited(
      widget.service.update({
        'round': session.round + 1,
        'step': 0,
        'phase': 0,
        'ended': false,
      }),
    );
  }

  void _schedule(String key, Duration delay, VoidCallback run) {
    if (_scheduledFor == key) return;
    _advance?.cancel();
    _scheduledFor = key;
    _advance = Timer(delay, () {
      if (mounted) run();
    });
  }

  Future<void> _finish() async {
    if (_starting) return;
    setState(() => _starting = true);
    await widget.service.update({'result': 'start'});
    await Future<void>.delayed(
      _tutorial.autoPlay
          ? const Duration(milliseconds: 500)
          : const Duration(milliseconds: 1400),
    );
    if (mounted) widget.onFinished(true);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildStage(context, _fullScreenSize(constraints.biggest)),
    );
  }

  /// 기준 크기의 짧은 쪽은 그대로 두고, 화면 비율에 맞춰 다른 쪽을 늘립니다.
  /// 그러면 글자·카드 크기는 유지하면서 화면 전체를 빈틈없이 채웁니다.
  Size _fullScreenSize(Size screen) {
    final base = _tutorial.tabletDesignSize;
    if (!screen.width.isFinite ||
        !screen.height.isFinite ||
        screen.width <= 0 ||
        screen.height <= 0) {
      return base;
    }
    final aspect = screen.width / screen.height;
    return aspect >= base.aspectRatio
        ? Size(base.height * aspect, base.height)
        : Size(base.width, base.width / aspect);
  }

  Widget _buildStage(BuildContext context, Size size) {
    final session = _snapshot.session;
    final entries = session == null
        ? const <String, TutorialEntry>{}
        : _entriesOf(session);
    final step = session?.step ?? 0;
    final phase = session?.phase ?? 0;
    final ended = session?.ended ?? false;
    final endMode = ended || step >= _tutorial.endStep;
    final view = TutorialTabletView(
      size: size,
      players: widget.players,
      step: step,
      phase: phase,
      round: session?.round ?? 0,
      entries: entries,
      ended: ended,
    );
    final auto = _tutorial.autoPlay;
    final info = !auto && !endMode && _tutorial.isInfo(step, phase);
    final skips = widget.players
        .where((p) => entries[p.uid]?.skip ?? false)
        .length;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _tutorial.buildTabletBackground(context),
          // 그림 영역이 화면 비율과 같아서 여백 없이 화면 전체를 채웁니다.
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox.fromSize(
                size: size,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (session != null)
                      Positioned.fill(
                        child: KeyedSubtree(
                          key: ValueKey(
                            'tablet-${session.round}-${ended ? 'end' : step}',
                          ),
                          child: _tutorial.buildTablet(context, view),
                        ),
                      ),
                    if (info && session != null)
                      Positioned(
                        left: 24,
                        top: 22,
                        child: _AckPill(
                          players: widget.players,
                          done: {
                            for (final p in widget.players)
                              if (view.isDone(p.uid)) p.uid,
                          },
                          label: step == 0
                              ? _t('준비', 'Ready', '准备', '準備')
                              : _t('이해했어요', 'Got it', '明白了', '明白了'),
                        ),
                      ),
                    if (skips > 0 && !endMode)
                      Positioned(
                        right: 24,
                        top: 22,
                        child: TutorialAppear(
                          child: _Pill(
                            dark: true,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.fast_forward_rounded,
                                  color: _sun,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _t(
                                    '건너뛰기 $skips/${widget.players.length} · 모두 누르면 건너뛰어요',
                                    'Skip $skips/${widget.players.length} · skips when everyone taps',
                                    '跳过 $skips/${widget.players.length} · 全员按下即跳过',
                                    '跳過 $skips/${widget.players.length} · 全員按下即跳過',
                                  ),
                                  style: const TextStyle(
                                    color: _cream,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (auto && endMode && session != null)
                      Positioned.fill(
                        child: TutorialAutoEnd(
                          key: ValueKey('auto-end-${session.round}'),
                          slogan: _tutorial.buildAutoEndSlogan(context),
                        style: _tutorial.autoEndStyle,
                          countdown: _autoEndCountdown,
                          onReplay: _starting ? null : _replay,
                        ),
                      ),
                    if (!auto && endMode && session != null && !_starting)
                      Positioned.fill(
                        child: _EndDialog(
                          players: widget.players,
                          entries: entries,
                          skipped: ended,
                          delay: ended
                              ? Duration.zero
                              : const Duration(milliseconds: 1400),
                        ),
                      ),
                    if (_starting && !auto)
                      Positioned.fill(
                        child: _GameStartShade(title: _tutorial.title),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//==========[ 휴대폰 ]==========
/// 자리 배치 대기 화면을 감싸, 튜토리얼이 열리면 튜토리얼로 바꿉니다.
///
/// 튜토리얼이 열리기 전에도 '이 게임 튜토리얼을 봤는지'를 자기 칸에 미리 적어
/// 태블릿이 보여 줄지 정할 수 있게 합니다.
class GameTutorialPhoneGate extends StatefulWidget {
  const GameTutorialPhoneGate({
    super.key,
    required this.roomCode,
    required this.uid,
    required this.tutorial,
    required this.players,
    required this.child,
    this.header,
  });

  final String roomCode;
  final String uid;
  final GameTutorial tutorial;

  /// 방의 플레이어(닉네임·캐릭터)입니다. 튜토리얼 순서는 태블릿이 정합니다.
  final List<TutorialPlayer> players;
  final Widget child;

  /// 튜토리얼 위에 그대로 둘 머리줄(방 나가기 등)입니다.
  final Widget? header;

  @override
  State<GameTutorialPhoneGate> createState() => _GameTutorialPhoneGateState();
}

class _GameTutorialPhoneGateState extends State<GameTutorialPhoneGate> {
  late GameTutorialService _service = GameTutorialService(widget.roomCode);
  StreamSubscription<TutorialSnapshot>? _subscription;
  TutorialSnapshot _snapshot = const TutorialSnapshot();
  TutorialEntry? _mine;
  bool _seen = false;
  String? _markedSeenFor;

  /// 이 화면이 휴대폰을 가로로 돌려 둔 상태인지입니다.
  bool _landscape = false;
  String? _lastResult;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void didUpdateWidget(GameTutorialPhoneGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomCode != widget.roomCode ||
        oldWidget.uid != widget.uid ||
        oldWidget.tutorial.gameId != widget.tutorial.gameId) {
      _subscription?.cancel();
      _service = GameTutorialService(widget.roomCode);
      _mine = null;
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    _seen = await TutorialSeenStore.isSeen(widget.uid, widget.tutorial.gameId);
    if (!mounted) return;
    _subscription = _service.watch().listen(_onSnapshot);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (_landscape && _lastResult != 'start') {
      unawaited(AppOrientation.lockPlatformPortrait());
    }
    super.dispose();
  }

  /// 튜토리얼이 열리고 닫힐 때 휴대폰 방향을 맞춥니다.
  void _syncOrientation() {
    if (!widget.tutorial.phoneLandscape) return;
    final active = _activeSession != null;
    if (active && !_landscape) {
      _landscape = true;
      unawaited(
        AppOrientation.applyPhoneGame(PhoneGameOrientation.landscapeOnly),
      );
    } else if (!active && _landscape) {
      _landscape = false;
      // 게임 시작이면 게임 화면이 같은 가로를 이어받습니다.
      if (_lastResult != 'start') {
        unawaited(AppOrientation.lockPlatformPortrait());
      }
    }
  }

  void _onSnapshot(TutorialSnapshot snapshot) {
    if (!mounted) return;
    final current = snapshot.entries[widget.uid];
    _mine ??= current ?? TutorialEntry(uid: widget.uid);
    // 아직 열리지 않았거나 다른 게임 기록이면 '봤는지'를 먼저 알립니다.
    if (current == null ||
        current.gameId != widget.tutorial.gameId ||
        current.seen != _seen) {
      final next = (_mine ?? TutorialEntry(uid: widget.uid)).copyWith(
        gameId: widget.tutorial.gameId,
        seen: _seen,
      );
      _mine = next;
      unawaited(_service.writeEntry(next));
    }
    final session = snapshot.session;
    if (session != null &&
        session.gameId == widget.tutorial.gameId &&
        session.result == 'start' &&
        _markedSeenFor != session.id) {
      _markedSeenFor = session.id;
      _seen = true;
      unawaited(TutorialSeenStore.markSeen(widget.uid, widget.tutorial.gameId));
    }
    final mineSession = snapshot.session;
    if (mineSession != null && mineSession.gameId == widget.tutorial.gameId) {
      _lastResult = mineSession.result;
    }
    setState(() => _snapshot = snapshot);
    _syncOrientation();
  }

  TutorialSession? get _activeSession {
    final session = _snapshot.session;
    if (session == null ||
        session.gameId != widget.tutorial.gameId ||
        !session.running ||
        !session.players.contains(widget.uid)) {
      return null;
    }
    return session;
  }

  TutorialEntry _entryFor(TutorialSession session) {
    final mine = _mine ?? TutorialEntry(uid: widget.uid);
    if (mine.sid == session.id && mine.round == session.round) return mine;
    // 새 튜토리얼·새 회차면 응답을 비웁니다.
    return TutorialEntry(
      uid: widget.uid,
      gameId: widget.tutorial.gameId,
      seen: _seen,
      sid: session.id,
      round: session.round,
    );
  }

  void _write(TutorialEntry entry) {
    setState(() => _mine = entry);
    unawaited(_service.writeEntry(entry));
  }

  void _complete(TutorialSession session, String value, {String? memo}) {
    final entry = _entryFor(session);
    if (entry.step == session.step &&
        entry.phase == session.phase &&
        entry.done) {
      return;
    }
    _write(
      entry.copyWith(
        step: session.step,
        phase: session.phase,
        done: true,
        value: value,
        memo: memo,
      ),
    );
  }

  void _toggleSkip(TutorialSession session) {
    final entry = _entryFor(session);
    _write(entry.copyWith(skip: !entry.skip));
  }

  void _choose(TutorialSession session, String choice) {
    final entry = _entryFor(session);
    if (entry.choice != null) return;
    _write(entry.copyWith(choice: choice));
  }

  List<TutorialPlayer> _playersOf(TutorialSession session) {
    final byUid = {for (final p in widget.players) p.uid: p};
    return [
      for (var i = 0; i < session.players.length; i++)
        byUid[session.players[i]] ??
            TutorialPlayer(
              uid: session.players[i],
              nickname: '',
              characterId: '',
              seatIndex: i,
            ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final session = _activeSession;
    if (session == null) {
      return widget.child;
    }
    final tutorial = widget.tutorial;
    final entry = _entryFor(session);
    final players = _playersOf(session);
    final me = players.firstWhere(
      (p) => p.uid == widget.uid,
      orElse: () =>
          TutorialPlayer(uid: widget.uid, nickname: '', characterId: ''),
    );
    final endMode = session.ended || session.step >= tutorial.endStep;
    final done =
        entry.step == session.step &&
        entry.phase == session.phase &&
        entry.done;
    final doneCount = session.players.where((uid) {
      final other = uid == widget.uid ? entry : _snapshot.entries[uid];
      return other != null && other.doneAt(session);
    }).length;
    final view = TutorialPhoneView(
      me: me,
      players: players,
      step: session.step,
      phase: session.phase,
      round: session.round,
      done: done,
      value: done ? entry.value : '',
      memo: entry.memo,
      doneCount: doneCount,
      ended: session.ended,
      complete: (value, {memo}) => _complete(session, value, memo: memo),
      skipOn: entry.skip,
      toggleSkip: () => _toggleSkip(session),
    );
    final auto = tutorial.autoPlay;
    final info =
        !auto && !endMode && tutorial.isInfo(session.step, session.phase);
    final size = tutorial.phoneDesignSize;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          tutorial.buildPhoneBackground(context),
          Column(
            children: [
              ?widget.header,
              Expanded(
                child: SafeArea(
                  top: widget.header == null,
                  child: Center(
                    child: FittedBox(
                      child: SizedBox.fromSize(
                        size: size,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: KeyedSubtree(
                                key: ValueKey(
                                  'phone-${session.round}-${endMode ? 'end' : session.step}',
                                ),
                                child: auto && endMode
                                    ? tutorial.buildPhoneEnd(context, view)
                                    : tutorial.buildPhone(context, view),
                              ),
                            ),
                            if (!endMode && !auto)
                              Positioned(
                                right: 14,
                                top: 10,
                                child: _SkipButton(
                                  on: entry.skip,
                                  onPressed: () => _toggleSkip(session),
                                ),
                              ),
                            if (!auto)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 18,
                                child: Center(
                                  child: endMode
                                      ? _EndButtons(
                                          choice: entry.choice,
                                          skipped: session.ended,
                                          onStart: () =>
                                              _choose(session, 'start'),
                                          onReplay: () =>
                                              _choose(session, 'replay'),
                                        )
                                      : info && !done
                                      ? TutorialPulse(
                                          child: _BigButton(
                                            label: session.step == 0
                                                ? tutorial.startLabel
                                                : _t(
                                                    '이해했어요',
                                                    'Got it',
                                                    '明白了',
                                                    '明白了',
                                                  ),
                                            onPressed: () =>
                                                _complete(session, 'ok'),
                                          ),
                                        )
                                      : info && done
                                      ? _WaitingChip(
                                          text: session.step == 0
                                              ? _t(
                                                  '준비 완료! 다른 사람을 기다려요',
                                                  'Ready! Waiting for others',
                                                  '准备好了！等待其他人',
                                                  '準備好了！等待其他人',
                                                )
                                              : _t(
                                                  '다른 사람을 기다려요',
                                                  'Waiting for others',
                                                  '等待其他人',
                                                  '等待其他人',
                                                ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

//==========[ 작은 조각들 ]==========
class _Pill extends StatelessWidget {
  const _Pill({required this.child, this.dark = false});
  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF17110F) : _cream,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: dark ? _sun : _ink, width: 3),
      boxShadow: const [BoxShadow(color: _ink, offset: Offset(0, 4))],
    ),
    child: child,
  );
}

class _AckPill extends StatelessWidget {
  const _AckPill({
    required this.players,
    required this.done,
    required this.label,
  });

  final List<TutorialPlayer> players;
  final Set<String> done;
  final String label;

  @override
  Widget build(BuildContext context) => _Pill(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < players.length; i++)
          Transform.translate(
            offset: Offset(-8.0 * i, 0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: done.contains(players[i].uid) ? 1 : .45,
                  child: _Face(characterId: players[i].characterId, size: 40),
                ),
                if (done.contains(players[i].uid))
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: TutorialAppear(
                      fromScale: .4,
                      offset: Offset.zero,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _lime,
                          shape: BoxShape.circle,
                          border: Border.all(color: _ink, width: 2),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: _ink,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        SizedBox(width: math.max(0.0, 14 - 8.0 * (players.length - 1)) + 6),
        Text(
          '$label ${done.length}/${players.length}',
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
      ],
    ),
  );
}

class _Face extends StatelessWidget {
  const _Face({required this.characterId, required this.size});
  final String characterId;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: _ink, width: 2.5),
    ),
    child: ClipOval(
      child: MosiFace(characterId: characterId, size: size - 5),
    ),
  );
}

class _EndDialog extends StatelessWidget {
  const _EndDialog({
    required this.players,
    required this.entries,
    required this.skipped,
    required this.delay,
  });

  final List<TutorialPlayer> players;
  final Map<String, TutorialEntry> entries;
  final bool skipped;
  final Duration delay;

  @override
  Widget build(BuildContext context) => TutorialAppear(
    delay: delay,
    offset: Offset.zero,
    fromScale: 1,
    child: ColoredBox(
      color: const Color(0xA8080418),
      child: Center(
        child: TutorialAppear(
          delay: delay,
          fromScale: .7,
          offset: Offset.zero,
          child: Container(
            width: 640,
            padding: const EdgeInsets.fromLTRB(36, 30, 36, 28),
            decoration: BoxDecoration(
              color: _cream,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _ink, width: 4),
              boxShadow: const [BoxShadow(color: _ink, offset: Offset(0, 9))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  skipped
                      ? _t('튜토리얼 건너뛰기', 'Tutorial skipped', '已跳过教程', '已跳過教學')
                      : _t('튜토리얼 완료!', 'Tutorial complete!', '教程完成！', '教學完成！'),
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('게임을 시작할까요?', 'Ready to play?', '开始游戏吗？', '開始遊戲嗎？'),
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 18,
                  runSpacing: 12,
                  children: [
                    for (final player in players)
                      _ChoiceFace(
                        player: player,
                        choice: entries[player.uid]?.choice,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  _t(
                    '모두 고르면 바로 진행해요.\n한 명이라도 “다시 보기”를 고르면 튜토리얼을 처음부터 다시 봐요.',
                    'Continues once everyone picks.\nIf anyone picks “Replay”, the tutorial starts over.',
                    '全员选择后立即进行。\n只要有人选择“再看一遍”，教程就从头开始。',
                    '全員選擇後立即進行。\n只要有人選擇「再看一次」，教學就從頭開始。',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 17,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ChoiceFace extends StatelessWidget {
  const _ChoiceFace({required this.player, required this.choice});
  final TutorialPlayer player;
  final String? choice;

  @override
  Widget build(BuildContext context) {
    final label = switch (choice) {
      'start' => _t('게임 시작', 'Start', '开始游戏', '開始遊戲'),
      'replay' => _t('다시 보기', 'Replay', '再看一遍', '再看一次'),
      _ => _t('고르는 중…', 'Choosing…', '选择中…', '選擇中…'),
    };
    return SizedBox(
      width: 108,
      child: Column(
        children: [
          Opacity(
            opacity: choice == null ? .5 : 1,
            child: _Face(characterId: player.characterId, size: 72),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: switch (choice) {
                'start' => _lime,
                'replay' => _sun,
                _ => Colors.transparent,
              },
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: choice == null ? const Color(0xFFC9C2E8) : _ink,
                width: 2,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: choice == null ? _muted : _ink,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameStartShade extends StatelessWidget {
  const _GameStartShade({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xCC080418),
    child: Center(
      child: TutorialAppear(
        fromScale: .6,
        offset: Offset.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GAME START',
              style: TextStyle(
                color: _sun,
                fontWeight: FontWeight.w900,
                fontSize: 84,
                letterSpacing: 4,
                shadows: [Shadow(color: _ink, offset: Offset(0, 6))],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                '튜토리얼 끝! 진짜 $title을(를) 시작해요',
                'Tutorial done! Let’s play $title',
                '教程结束！开始正式的$title',
                '教學結束！開始正式的$title',
              ),
              style: const TextStyle(
                color: _cream,
                fontWeight: FontWeight.w800,
                fontSize: 26,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.on, required this.onPressed});
  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: on,
    child: GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? _sun : const Color(0x26FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: on ? _ink : const Color(0x99FFFFFF),
            width: 2,
          ),
        ),
        child: Text(
          on
              ? _t('건너뛰기 취소', 'Cancel skip', '取消跳过', '取消跳過')
              : _t('건너뛰기', 'Skip', '跳过', '跳過'),
          style: TextStyle(
            color: on ? _ink : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    ),
  );
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.onPressed,
    this.color = _lime,
    this.width = 260,
    this.height = 68,
    this.fontSize = 22,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;
  final double width;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _ink, width: 3),
          boxShadow: const [BoxShadow(color: _navy, offset: Offset(0, 5))],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
          ),
        ),
      ),
    ),
  );
}

class _WaitingChip extends StatelessWidget {
  const _WaitingChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => TutorialAppear(
    fromScale: .7,
    offset: Offset.zero,
    child: _Pill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _lime,
              shape: BoxShape.circle,
              border: Border.all(color: _ink, width: 2),
            ),
            child: const Icon(Icons.check_rounded, size: 16, color: _ink),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EndButtons extends StatelessWidget {
  const _EndButtons({
    required this.choice,
    required this.skipped,
    required this.onStart,
    required this.onReplay,
  });

  final String? choice;
  final bool skipped;
  final VoidCallback onStart;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) => TutorialAppear(
    delay: skipped ? Duration.zero : const Duration(milliseconds: 1200),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: choice != null && choice != 'start' ? .5 : 1,
          child: TutorialPulse(
            enabled: choice == null,
            child: _BigButton(
              label: _t('게임 시작하기', 'Start the game', '开始游戏', '開始遊戲'),
              onPressed: onStart,
              height: 60,
              width: 280,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Opacity(
          opacity: choice != null && choice != 'replay' ? .5 : 1,
          child: _BigButton(
            label: _t('튜토리얼 다시 보기', 'Replay tutorial', '再看一遍教程', '再看一次教學'),
            onPressed: onReplay,
            color: choice == 'replay' ? _sun : Colors.white,
            height: 52,
            width: 280,
            fontSize: 17,
          ),
        ),
        if (choice != null) ...[
          const SizedBox(height: 12),
          Text(
            _t(
              '다른 사람이 고를 때까지 기다려요',
              'Waiting for the others',
              '等待其他人选择',
              '等待其他人選擇',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ],
    ),
  );
}

//======================================================================
// 자동 진행(1분 요약) 공용 조각
//======================================================================

//==========[ 정해진 시간 동안만 보이기 ]==========
/// [from]에 나타나 [to]에 사라집니다. [to]가 없으면 계속 보입니다.
class TutorialTimed extends StatefulWidget {
  const TutorialTimed({
    super.key,
    required this.child,
    this.from = Duration.zero,
    this.to,
    this.fade = const Duration(milliseconds: 260),
  });

  final Widget child;
  final Duration from;
  final Duration? to;
  final Duration fade;

  @override
  State<TutorialTimed> createState() => _TutorialTimedState();
}

class _TutorialTimedState extends State<TutorialTimed> {
  bool _shown = false;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    if (widget.from == Duration.zero) {
      _shown = true;
    } else {
      _timers.add(Timer(widget.from, () => _set(true)));
    }
    final to = widget.to;
    if (to != null) _timers.add(Timer(to, () => _set(false)));
  }

  void _set(bool shown) {
    if (mounted) setState(() => _shown = shown);
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !_shown,
    child: AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: widget.fade,
      child: widget.child,
    ),
  );
}

//==========[ 시간에 따라 바뀌는 설명 문구 ]==========
/// 한 장면 안에서 정해진 시각마다 바뀌는 큰 설명 문구입니다.
///
/// 모든 문구를 같은 칸에 겹쳐 두어, 문구가 바뀌어도 아래 요소가 움직이지 않게
/// 가장 긴 문구의 높이를 차지합니다.
class TutorialPhaseCaption extends StatelessWidget {
  const TutorialPhaseCaption({
    super.key,
    required this.phases,
    required this.style,
    this.sub,
    this.subStyle,
    this.textAlign = TextAlign.center,
    this.riseOffset = 18,
  });

  /// (문구, 나타나는 시각)입니다. 첫 문구는 보통 0초입니다.
  final List<(String, Duration)> phases;
  final TextStyle style;

  /// 첫 문구 아래에 함께 보일 작은 문구입니다.
  final String? sub;
  final TextStyle? subStyle;
  final TextAlign textAlign;

  /// 다음 문구가 올라오는 거리입니다(시안 rise 18px · qRise 14px).
  final double riseOffset;

  @override
  Widget build(BuildContext context) {
    final cross = switch (textAlign) {
      TextAlign.left || TextAlign.start => CrossAxisAlignment.start,
      TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.center,
    };
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        for (var i = 0; i < phases.length; i++)
          TutorialTimed(
            from: phases[i].$2,
            to: i + 1 < phases.length
                ? phases[i + 1].$2 - const Duration(milliseconds: 200)
                : null,
            fade: const Duration(milliseconds: 300),
            child: TutorialAppear(
              delay: phases[i].$2,
              offset: i == 0 ? Offset.zero : Offset(0, riseOffset),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              child: Column(
                crossAxisAlignment: cross,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      phases[i].$1,
                      textAlign: textAlign,
                      style: style,
                    ),
                  ),
                  if (i == 0 && sub != null && sub!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(sub!, textAlign: textAlign, style: subStyle ?? style),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

//==========[ 자동 진행 건너뛰기 버튼 ]==========
/// 휴대폰 아래 같은 자리에 두는 건너뛰기 버튼입니다. 누르면 '건너뛰기 취소'가
/// 되고, 모두 누르면 바로 게임을 시작합니다.
class TutorialAutoSkipButton extends StatelessWidget {
  const TutorialAutoSkipButton({
    super.key,
    required this.on,
    required this.onPressed,
    this.color = _cream,
    this.onColor = _sun,
    this.textOnColor = _ink,
    this.radius = 14,
    this.width = 180,
    this.height = 50,
    this.fontSize = 18,
  });

  final bool on;
  final VoidCallback? onPressed;
  final Color color;
  final Color onColor;
  final Color textOnColor;
  final double radius;
  final double width;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: on,
    child: GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? onColor : color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: on ? _ink : color.withValues(alpha: .6),
            width: 3,
          ),
        ),
        child: Text(
          on
              ? _t('건너뛰기 취소', 'Cancel skip', '取消跳过', '取消跳過')
              : _t('건너뛰기', 'Skip', '跳过', '跳過'),
          style: TextStyle(
            color: on ? textOnColor : color,
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
          ),
        ),
      ),
    ),
  );
}

//==========[ 자동 진행 끝 화면(태블릿) ]==========
/// 끝 화면의 게임별 색과 글꼴입니다. 시안과 같은 값을 넣어 주세요.
class TutorialEndStyle {
  const TutorialEndStyle({
    this.ink = _ink,
    this.cream = _cream,
    this.accent = _sun,
    this.goBg = _lime,
    this.shade = const Color(0xCC080418),
    this.numStyle,
    this.labelStyle,
    this.goStyle,
  });

  /// 글자·테두리·그림자 색입니다.
  final Color ink;

  /// '다시 보기' 버튼 바탕색입니다.
  final Color cream;

  /// 숫자를 세는 동그라미 바탕색입니다.
  final Color accent;

  /// '게임 시작!' 바탕색입니다.
  final Color goBg;

  /// 화면을 덮는 색입니다.
  final Color shade;

  /// 동그라미 안 숫자(26px)입니다.
  final TextStyle? numStyle;

  /// '다시 보기'(20px)입니다.
  final TextStyle? labelStyle;

  /// '게임 시작!'(38px)입니다.
  final TextStyle? goStyle;
}

/// 목표 문구 아래 '다시 보기' 버튼 안에서 5→1을 세고, 다 세면 '게임 시작!'으로
/// 바뀝니다. 시안과 같은 시각(0.6초부터 1초마다 · 5.6초에 사라지고 5.7초에
/// 등장)으로 움직입니다. 실제 게임 시작은 진행자가 맡습니다.
class TutorialAutoEnd extends StatelessWidget {
  const TutorialAutoEnd({
    super.key,
    required this.slogan,
    required this.countdown,
    required this.onReplay,
    this.style = const TutorialEndStyle(),
  });

  final Widget slogan;
  final Duration countdown;
  final VoidCallback? onReplay;
  final TutorialEndStyle style;

  /// 첫 숫자가 보이는 시각입니다.
  static const _first = Duration(milliseconds: 600);

  @override
  Widget build(BuildContext context) {
    final seconds = math.max(1, countdown.inSeconds);
    final fadeAt = _first + Duration(seconds: seconds);
    final goAt = fadeAt + const Duration(milliseconds: 100);
    return ColoredBox(
      color: style.shade,
      child: Center(
        child: TutorialAppear(
          duration: const Duration(milliseconds: 500),
          fromScale: .6,
          offset: Offset.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              slogan,
              const SizedBox(height: 30),
              SizedBox(
                height: 64,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    TutorialTimed(
                      to: fadeAt,
                      fade: const Duration(milliseconds: 250),
                      child: _replay(seconds),
                    ),
                    TutorialLater(
                      at: goAt,
                      child: TutorialAppear(
                        fromScale: .6,
                        offset: Offset.zero,
                        child: _go(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _replay(int seconds) => Semantics(
    button: true,
    label: _t('튜토리얼 다시 보기', 'Watch again', '再看一遍', '再看一遍'),
    child: GestureDetector(
      onTap: onReplay,
      child: Container(
        height: 60,
        padding: const EdgeInsets.fromLTRB(8, 0, 24, 0),
        decoration: BoxDecoration(
          color: style.cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: style.ink, width: 3),
          boxShadow: [BoxShadow(color: style.ink, offset: const Offset(0, 5))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: ClipOval(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: style.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: style.ink, width: 3),
                  ),
                  child: Stack(
                    children: [
                      for (var k = 0; k < seconds; k++)
                        Positioned.fill(
                          child: _CountNumber(
                            text: '${seconds - k}',
                            delay: _first + Duration(seconds: k),
                            style:
                                style.numStyle ??
                                TextStyle(
                                  color: style.ink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 26,
                                  height: 1,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _t('다시 보기', 'Watch again', '再看一遍', '再看一遍'),
              style:
                  style.labelStyle ??
                  TextStyle(
                    color: style.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _go() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
    decoration: BoxDecoration(
      color: style.goBg,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: style.ink, width: 4),
      boxShadow: [BoxShadow(color: style.ink, offset: const Offset(0, 6))],
    ),
    child: Text(
      _t('게임 시작!', 'Game start!', '游戏开始！', '遊戲開始！'),
      style:
          style.goStyle ??
          TextStyle(
            color: style.ink,
            fontWeight: FontWeight.w900,
            fontSize: 38,
            height: 1.2,
          ),
    ),
  );
}

/// 1초 동안 커졌다 사라지는 숫자 하나입니다(시안 cdNum).
class _CountNumber extends StatefulWidget {
  const _CountNumber({
    required this.text,
    required this.delay,
    required this.style,
  });

  final String text;
  final Duration delay;
  final TextStyle style;

  @override
  State<_CountNumber> createState() => _CountNumberState();
}

class _CountNumberState extends State<_CountNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
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
      final t = _c.value;
      double opacity;
      double scale;
      if (t <= 0) {
        opacity = 0;
        scale = 1.6;
      } else if (t < .15) {
        final k = t / .15;
        opacity = k;
        scale = 1.6 - .6 * k;
      } else if (t < .85) {
        opacity = 1;
        scale = 1;
      } else {
        final k = (t - .85) / .15;
        opacity = 1 - k;
        scale = 1 - .3 * k;
      }
      return Opacity(
        opacity: opacity.clamp(0, 1),
        child: Transform.scale(
          scale: scale,
          child: Center(child: Text(widget.text, style: widget.style)),
        ),
      );
    },
  );
}

//==========[ 태블릿을 봐 주세요(휴대폰) ]==========
/// 실제 태블릿 그림이 둥실 떠오르며 금빛으로 반짝이고, 아래에 안내가 붙습니다.
/// 라이어스 게임 안의 '태블릿을 봐 주세요!'와 같은 구성입니다.
class TutorialLookAtTablet extends StatefulWidget {
  const TutorialLookAtTablet({
    super.key,
    this.title,
    this.body,
    this.titleStyle,
    this.tabletWidth = 200,
    this.glow = const Color(0xFFE2C27E),
    this.titleGap = 26,
    this.bodyGap = 16,
  });

  final String? title;

  /// 제목 아래 작은 안내입니다. 없으면 제목만 보입니다.
  final Widget? body;
  final TextStyle? titleStyle;
  final double tabletWidth;
  final Color glow;

  /// 태블릿 그림과 제목, 제목과 안내 사이 간격입니다.
  final double titleGap;
  final double bodyGap;

  @override
  State<TutorialLookAtTablet> createState() => _TutorialLookAtTabletState();
}

class _TutorialLookAtTabletState extends State<TutorialLookAtTablet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.tabletWidth;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final t = _c.value;
                final bob = -8 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));
                return Transform.translate(
                  offset: Offset(0, bob),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15 * w / 200),
                      boxShadow: [
                        BoxShadow(
                          color: widget.glow.withValues(alpha: .7 * (1 - t)),
                          spreadRadius: 22 * t,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                );
              },
              child: CustomPaint(
                size: Size(w, w * 142 / 200),
                painter: const TutorialTabletPainter(),
              ),
            ),
            SizedBox(height: widget.titleGap),
            Text(
              widget.title ??
                  _t('태블릿을 봐 주세요!', 'Look at the tablet!', '请看平板！', '請看平板！'),
              textAlign: TextAlign.center,
              style:
                  widget.titleStyle ??
                  const TextStyle(
                    color: _cream,
                    fontWeight: FontWeight.w900,
                    fontSize: 34,
                    height: 1.2,
                    shadows: [Shadow(color: _ink, offset: Offset(0, 3))],
                  ),
            ),
            if (widget.body != null) ...[
              SizedBox(height: widget.bodyGap),
              widget.body!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 실제 태블릿처럼 금속 몸체·얇은 베젤·카메라·유리 반사광을 그립니다(200×142 기준).
class TutorialTabletPainter extends CustomPainter {
  const TutorialTabletPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 142);
    final buttonPaint = Paint()..color = const Color(0xFF3A3D42);
    canvas.drawRRect(
      RRect.fromLTRBR(60, 0, 82, 3, const Radius.circular(1.5)),
      buttonPaint,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(88, 0, 110, 3, const Radius.circular(1.5)),
      buttonPaint,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(196, 20, 199, 38, const Radius.circular(1.5)),
      buttonPaint,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(1.5, 16.5, 198.5, 151.5, const Radius.circular(15)),
      Paint()
        ..color = const Color(0x8C000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    const bodyRect = Rect.fromLTRB(1.5, 2.5, 198.5, 139.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(15)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B5F66), Color(0xFF2C2F34), Color(0xFF16181B)],
          stops: [0, 0.45, 1],
        ).createShader(bodyRect),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(2.5, 3.5, 197.5, 138.5, const Radius.circular(14)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x8C8A8F97),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(5, 6, 195, 136, const Radius.circular(12)),
      Paint()..color = const Color(0xFF07080A),
    );
    const screenRect = Rect.fromLTRB(11, 11, 189, 131);
    final screen = RRect.fromRectAndRadius(
      screenRect,
      const Radius.circular(7),
    );
    canvas.drawRRect(
      screen,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1F26), Color(0xFF0B0C10), Color(0xFF050608)],
          stops: [0, 0.6, 1],
        ).createShader(screenRect),
    );
    canvas.save();
    canvas.clipRRect(screen);
    final glare = Path()
      ..moveTo(11, 11)
      ..lineTo(97, 11)
      ..lineTo(45, 131)
      ..lineTo(11, 131)
      ..close();
    canvas.drawPath(
      glare,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x29FFFFFF), Color(0x00FFFFFF)],
        ).createShader(const Rect.fromLTRB(11, 11, 97, 131)),
    );
    canvas.restore();
    canvas.drawCircle(
      const Offset(100, 8.4),
      1.7,
      Paint()..color = const Color(0xFF1E2A3A),
    );
    canvas.drawCircle(
      const Offset(100, 8.4),
      .7,
      Paint()..color = const Color(0xFF4A6A8A),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TutorialTabletPainter oldDelegate) => false;
}

//==========[ 정해진 시각에 처음 만들기 ]==========
/// [at]이 되기 전에는 아무것도 만들지 않습니다. 룰렛처럼 만들어지는 순간
/// 움직이기 시작하는 위젯을 장면 중간에 시작할 때 씁니다.
class TutorialLater extends StatefulWidget {
  const TutorialLater({super.key, required this.at, required this.child});

  final Duration at;
  final Widget child;

  @override
  State<TutorialLater> createState() => _TutorialLaterState();
}

class _TutorialLaterState extends State<TutorialLater> {
  bool _ready = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.at == Duration.zero) {
      _ready = true;
    } else {
      _timer = Timer(widget.at, () {
        if (mounted) setState(() => _ready = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.child : const SizedBox.shrink();
}
