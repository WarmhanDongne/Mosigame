// [timeout_notice.dart] 는 내 차례 시간이 다 됐을 때 타이머 자리에
// "시간 초과"와 자동으로 처리된 일을 보여 주는 파일이다.
//
// 디자인: Claude Design '시간 초과 턴 넘김 안내' 라이어스 '라' 안.
// - 상자 없이 빨간 "시간 초과" 글자와 그 아래 한 줄(예: LIAR 자동 선언)
// - 나타나는 순간 화면 가장자리가 붉게 한 번 번쩍입니다.
// 화면을 가리지 않고 눌림도 막지 않도록 전체를 IgnorePointer로 감쌉니다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';

// ============================================================

/// 시간 초과로 대신 처리된 일입니다. 서버 `lastTimeout.kind` 값과 같습니다.
enum LiarsPokerTimeoutKind {
  submit,
  liar,
  fold;

  static LiarsPokerTimeoutKind? fromWire(String? value) => switch (value) {
    'submit' => LiarsPokerTimeoutKind.submit,
    'liar' => LiarsPokerTimeoutKind.liar,
    'fold' => LiarsPokerTimeoutKind.fold,
    _ => null,
  };

  String get label => switch (this) {
    LiarsPokerTimeoutKind.submit => GameLocale.select(
      ko: '카드 1장 자동 제출',
      en: '1 card auto-submitted',
      zhHans: '已自动出 1 张牌',
      zhHant: '已自動出 1 張牌',
    ),
    LiarsPokerTimeoutKind.liar => GameLocale.select(
      ko: 'LIAR 자동 선언',
      en: 'LIAR called automatically',
      zhHans: '已自动喊 LIAR',
      zhHant: '已自動喊 LIAR',
    ),
    LiarsPokerTimeoutKind.fold => GameLocale.select(
      ko: 'FOLD 자동 선택',
      en: 'FOLD chosen automatically',
      zhHans: '已自动选择 FOLD',
      zhHant: '已自動選擇 FOLD',
    ),
  };
}

class LiarsPokerTimeoutNotice extends StatefulWidget {
  const LiarsPokerTimeoutNotice({
    super.key,
    required this.kind,
    required this.textTop,
  });

  final LiarsPokerTimeoutKind kind;

  /// "시간 초과" 글자의 위쪽 위치입니다. 세로 화면은 타이머 자리와 같습니다.
  final double textTop;

  /// 안내가 머무는 전체 시간입니다. 상위 화면이 이 시간 뒤에 지웁니다.
  static const visibleFor = Duration(milliseconds: 2600);

  @override
  State<LiarsPokerTimeoutNotice> createState() =>
      _LiarsPokerTimeoutNoticeState();
}

class _LiarsPokerTimeoutNoticeState extends State<LiarsPokerTimeoutNotice>
    with SingleTickerProviderStateMixin {
  static const _red = Color(0xFFFF4B4B);
  static const _bone = Color(0xFFF2EADB);
  static const _glow = Color(0xBFB8262B);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final title = GameLocale.select(
      ko: '시간 초과',
      en: 'Time out',
      zhHans: '超时',
      zhHant: '逾時',
    );
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        label: '$title. ${widget.kind.label}',
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = reduceMotion ? 1.0 : _controller.value;
              // 글자: 1.5배에서 살짝 작게 튕겼다가 제자리(약 0.33초).
              final pop = Curves.easeOutBack.transform((t / .36).clamp(0.0, 1.0));
              final scale = 1.5 - .5 * pop;
              final textOpacity = (t / .2).clamp(0.0, 1.0);
              // 아랫줄: 글자가 자리 잡은 뒤 위에서 살짝 내려옵니다.
              final sub = Curves.easeOut.transform(
                ((t - .3) / .35).clamp(0.0, 1.0),
              );
              // 가장자리 번쩍임: 빠르게 켜졌다가 천천히 꺼집니다.
              final glow = reduceMotion
                  ? 0.0
                  : t < .2
                  ? t / .2
                  : (1 - (t - .2) / .8).clamp(0.0, 1.0);
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (glow > 0)
                    Opacity(
                      opacity: glow,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            radius: 1.05,
                            colors: [Color(0x00B8262B), _glow],
                            stops: [.62, 1],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: widget.textTop,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: textOpacity,
                          child: Transform.scale(
                            scale: scale,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _red,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                letterSpacing: 1,
                                shadows: [
                                  Shadow(color: Color(0xE6000000), blurRadius: 10),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: sub,
                          child: Transform.translate(
                            offset: Offset(0, -6 * (1 - sub)),
                            child: Text(
                              widget.kind.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _bone,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 6),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
