// [phone_join_scanner.dart] 는 휴대폰 로비 가운데의 "스캐너 미리보기" 영역이다.
//
// 휴대폰은 방에 참여하는 기기라, 태블릿처럼 보유 게임 책장을 두지 않고 화면
// 자체를 QR 스캐너처럼 보여 줍니다. 움직이는 스캔선이 "태블릿 QR을 비추면
// 된다"는 걸 글 없이 알려 주고, 아래 그룹 참여 버튼으로 실제 스캐너를 엽니다.
// QR이 안 찍힐 때를 위해 작은 도움 카드로 방 코드 입력을 엽니다.
// 디자인: Claude Design '휴대폰 로비 · 최종안' (4-2 바이올렛 + 3번 도움 카드).

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/localization/platform_localizations.dart';

// ============================================================

/// 스캐너 로비의 바탕색입니다. 머리 띠와 같은 보라를 씁니다.
const phoneScannerLobbyBackground = MosiColors.violet;

/// 스캐너 모서리·스캔선·버튼에 쓰는 강조색입니다.
const _accent = MosiColors.sun;

/// 스캐너 틀 안쪽의 한 단계 진한 보라입니다.
const _finderFill = Color(0xFF4730D0);

class PhoneJoinScanner extends StatelessWidget {
  const PhoneJoinScanner({
    super.key,
    required this.busy,
    required this.onJoin,
    required this.onEnterCode,
  });

  /// 이전 방 복구·대기실 진입 중이면 버튼을 잠급니다.
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onEnterCode;

  @override
  Widget build(BuildContext context) {
    final title = GameLocale.select(
      ko: '태블릿의 |QR|을\n비추면 바로 입장',
      en: "Point at the tablet's |QR|\nto join right away",
      zhHans: '对准平板的|二维码|\n即可直接加入',
      zhHant: '對準平板的|QR碼|\n即可直接加入',
    ).split('|');
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 제목·버튼·도움 카드 자리를 빼고 남는 높이에 맞춰 스캐너 틀 크기를 정합니다.
          final finder = math
              .min(constraints.maxWidth * .62, constraints.maxHeight - 290)
              .clamp(120.0, 240.0);
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          for (var i = 0; i < title.length; i++)
                            TextSpan(
                              text: title[i],
                              style: TextStyle(
                                color: i == 1 ? _accent : MosiColors.white,
                              ),
                            ),
                        ],
                      ),
                      style: const TextStyle(
                        fontFamily:
                            'packages/${MosiFonts.package}/${MosiFonts.logo}',
                        fontSize: 28,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(child: _ScannerFinder(size: finder)),
                    const SizedBox(height: 28),
                    SafeArea(
                      top: false,
                      minimum: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MosiButton(
                            label: busy
                                ? context.l10n.reconnecting
                                : context.l10n.joinGroup,
                            height: 58,
                            fontSize: 18,
                            radius: 16,
                            shadowOffset: 6,
                            background: _accent,
                            foreground: MosiColors.ink,
                            shadowColor: MosiColors.ink,
                            expand: true,
                            leading: const Icon(Icons.qr_code_scanner_rounded),
                            onPressed: busy ? null : onJoin,
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: _CodeHelpCard(
                              onTap: busy ? null : onEnterCode,
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
        },
      ),
    );
  }
}

/// "QR이 안 찍히나요?" 작은 도움 카드입니다. 누르면 방 코드 입력을 엽니다.
class _CodeHelpCard extends StatelessWidget {
  const _CodeHelpCard({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = GameLocale.select(
      ko: 'QR이 안 찍히나요?',
      en: "QR not scanning?",
      zhHans: '扫不了二维码？',
      zhHant: '掃不了QR碼？',
    );
    final body = GameLocale.select(
      ko: '방 코드 5자리로 입장해요',
      en: 'Join with the 5-character room code',
      zhHans: '用5位房间码加入',
      zhHant: '用5位房間碼加入',
    );
    return Semantics(
      button: true,
      label: '$title $body',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .5 : 1,
          child: Container(
            padding: const EdgeInsets.fromLTRB(7, 6, 10, 6),
            decoration: BoxDecoration(
              color: const Color(0x590E0A3D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MosiColors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ABC',
                    style: MosiFonts.grotesk(size: 9, color: MosiColors.violet),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MosiFonts.sans(
                          size: 12,
                          weight: FontWeight.w700,
                          color: MosiColors.white,
                        ),
                      ),
                      Text(
                        body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MosiFonts.sans(
                          size: 11,
                          color: MosiColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _accent,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 네 모서리 괄호와 위아래로 오가는 스캔선이 있는 스캐너 틀입니다.
class _ScannerFinder extends StatefulWidget {
  const _ScannerFinder({required this.size});

  final double size;

  @override
  State<_ScannerFinder> createState() => _ScannerFinderState();
}

class _ScannerFinderState extends State<_ScannerFinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final corner = size * .2;
    final inset = size * .045;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _finderFill,
          borderRadius: BorderRadius.circular(size * .1),
          border: Border.all(color: MosiColors.ink, width: 3),
          boxShadow: const [
            BoxShadow(color: MosiColors.ink, offset: Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * .1 - 3),
          child: Stack(
            children: [
              // 태블릿 화면과 그 위의 QR을 흐린 실루엣으로 둡니다.
              Center(
                child: Container(
                  width: size * .55,
                  height: size * .38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0x73FFFFFF),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: CustomPaint(
                    size: Size.square(size * .18),
                    painter: const _QrSilhouettePainter(),
                  ),
                ),
              ),
              for (final align in const [
                Alignment.topLeft,
                Alignment.topRight,
                Alignment.bottomLeft,
                Alignment.bottomRight,
              ])
                Positioned(
                  left: align.x < 0 ? inset : null,
                  right: align.x > 0 ? inset : null,
                  top: align.y < 0 ? inset : null,
                  bottom: align.y > 0 ? inset : null,
                  child: CustomPaint(
                    size: Size.square(corner),
                    painter: _CornerPainter(align),
                  ),
                ),
              AnimatedBuilder(
                animation: _scan,
                builder: (context, _) {
                  final t = reduceMotion
                      ? .5
                      : Curves.easeInOut.transform(_scan.value);
                  final top = size * .1 + (size * .78) * t;
                  return Positioned(
                    left: size * .11,
                    right: size * .11,
                    top: top,
                    child: Container(
                      height: 3,
                      decoration: const BoxDecoration(
                        color: _accent,
                        boxShadow: [BoxShadow(color: _accent, blurRadius: 14)],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.align);

  final Alignment align;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .11;
    final paint = Paint()
      ..color = _accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final half = stroke / 2;
    final x0 = align.x < 0 ? half : size.width - half;
    final y0 = align.y < 0 ? half : size.height - half;
    final x1 = align.x < 0 ? size.width : 0.0;
    final y1 = align.y < 0 ? size.height : 0.0;
    final r = size.width * .3;
    final path = Path()
      ..moveTo(x1, y0)
      ..lineTo(x0 + (align.x < 0 ? r : -r), y0)
      ..quadraticBezierTo(x0, y0, x0, y0 + (align.y < 0 ? r : -r))
      ..lineTo(x0, y1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) => oldDelegate.align != align;
}

class _QrSilhouettePainter extends CustomPainter {
  const _QrSilhouettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cells = 7;
    final cell = size.width / cells;
    final paint = Paint()..color = const Color(0x8CFFFFFF);
    for (var y = 0; y < cells; y++) {
      for (var x = 0; x < cells; x++) {
        if ((x * 3 + y * 5 + x * y) % 3 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell * .9, cell * .9),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrSilhouettePainter oldDelegate) => false;
}
