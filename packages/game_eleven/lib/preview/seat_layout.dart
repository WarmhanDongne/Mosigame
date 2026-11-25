// [seat_layout.dart] 는 태블릿 자리 배치 완료 연출의 ELEVEN 테이블과 자리 카드를 그리는 파일이다.
//
// - [Package] : ELEVEN
// - [Widget] : 흑·백 사선 원탁(가운데 빨간 물음표 카드), 흑·백 자리 카드
//
// 시안: 캔버스 '태블릿 자리 배치(의자) 화면'. 플랫폼 자리 배치 편집기가
// [TemplateGame.buildLayoutTable]·[TemplateGame.buildLayoutChair]로 받아 그린다.

// ========================[ import ]==========================
import 'package:flutter/widgets.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_eleven/shared/noir/noir_text.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';

// ============================================================

/// 126° 사선으로 위는 흑, 아래는 백, 사이에 빨간 선을 긋는 그라디언트입니다.
LinearGradient _split(double from, double to) => LinearGradient(
  begin: const Alignment(-0.809, -0.588),
  end: const Alignment(0.809, 0.588),
  colors: const [
    ElevenNoirColors.blackTile,
    ElevenNoirColors.blackTile,
    ElevenNoirColors.accentRed,
    ElevenNoirColors.accentRed,
    ElevenNoirColors.whiteTile,
    ElevenNoirColors.whiteTile,
  ],
  stops: [0, from, from, to, to, 1],
);

//=======================원탁==============================
/// 자리 배치 가운데 원탁: 흑·백 사선 원판 위에 물음표 카드가 숨 쉬듯 커졌다 작아집니다.
class ElevenLayoutTable extends StatefulWidget {
  const ElevenLayoutTable({super.key});

  @override
  State<ElevenLayoutTable> createState() => _ElevenLayoutTableState();
}

class _ElevenLayoutTableState extends State<ElevenLayoutTable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FittedBox(
    child: SizedBox.square(
      dimension: 360,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _split(0.49, 0.51),
          border: Border.all(color: ElevenNoirColors.ink, width: 6),
          boxShadow: const [
            BoxShadow(color: Color(0x0DF7F0E4), spreadRadius: 10),
            BoxShadow(color: Color(0xFF0B0B0B), offset: Offset(0, 12)),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x99B9AE9C)),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                // CSS `qPulse`: 0→50%에서 1.08배, 다시 1배.
                final t = _pulse.value;
                final scale = 1 + 0.08 * (t < 0.5 ? t * 2 : (1 - t) * 2);
                return Transform.scale(scale: scale, child: child);
              },
              child: const _QuestionCard(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard();

  @override
  Widget build(BuildContext context) => Container(
    width: 108,
    height: 146,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: _split(0.49, 0.52),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ElevenNoirColors.ink, width: 4),
      boxShadow: const [
        BoxShadow(color: Color(0xFF000000), offset: Offset(0, 7)),
      ],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Text(
          '?',
          style: ElevenNoirText.number(82, height: 1).copyWith(
            color: null,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = ElevenNoirColors.ink,
          ),
        ),
        Text(
          '?',
          style: ElevenNoirText.number(
            82,
            color: ElevenNoirColors.accentRed,
            height: 1,
          ),
        ),
      ],
    ),
  );
}

//=======================자리 카드==============================
/// 자리 카드: 첫 자리는 흑 카드, 둘째 자리는 백 카드에 사람 아이콘과 자리 이름.
class ElevenLayoutSeat extends StatelessWidget {
  const ElevenLayoutSeat({super.key, required this.seatIndex});

  final int seatIndex;

  @override
  Widget build(BuildContext context) {
    final dark = seatIndex.isEven;
    final fg = dark ? ElevenNoirColors.cream : ElevenNoirColors.ink;
    final label = dark
        ? GameLocale.select(
            ko: '흑 자리',
            en: 'Black seat',
            zhHans: '黑方座位',
            zhHant: '黑方座位',
          )
        : GameLocale.select(
            ko: '백 자리',
            en: 'White seat',
            zhHans: '白方座位',
            zhHant: '白方座位',
          );
    return Semantics(
      label: label,
      child: FittedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 136,
              height: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dark
                    ? ElevenNoirColors.blackTile
                    : ElevenNoirColors.whiteTile,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ElevenNoirColors.ink, width: 4),
                boxShadow: [
                  const BoxShadow(
                    color: Color(0xFF000000),
                    offset: Offset(0, 8),
                  ),
                  if (dark)
                    const BoxShadow(color: Color(0x80F7F0E4), spreadRadius: 3),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: dark
                                ? ElevenNoirColors.innerLineOnDark
                                : ElevenNoirColors.innerLineOnLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: CustomPaint(
                      size: const Size.square(64),
                      painter: _PersonPainter(color: fg),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dark ? ElevenNoirColors.ink : ElevenNoirColors.cream,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: dark ? ElevenNoirColors.cream : ElevenNoirColors.ink,
                  width: 2,
                ),
              ),
              child: Text(
                label,
                style: ElevenNoirText.body(
                  15,
                  weight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 사람 아이콘(머리 원 + 어깨 호), 64×64 시안 좌표.
class _PersonPainter extends CustomPainter {
  const _PersonPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(32, 22), 10, paint);
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(32, 55), width: 38, height: 34),
      3.14159,
      3.14159,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_PersonPainter oldDelegate) => oldDelegate.color != color;
}
