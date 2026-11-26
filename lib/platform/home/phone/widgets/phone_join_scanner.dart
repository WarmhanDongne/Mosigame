// [phone_join_scanner.dart] 는 휴대폰 로비 가운데에서 바로 QR을 찍고, 버튼 위
// 코드 칸으로 방에 들어가는 참여 영역이다.
//
// 휴대폰은 방에 참여하는 기기라 태블릿처럼 보유 게임 책장을 두지 않습니다.
// 로비에 들어오면 스캐너 틀에서 카메라가 바로 켜지고, QR이 찍히면 버튼을 누르지
// 않아도 입장합니다. QR이 안 될 때는 바로 아래 다섯 칸에 방 코드를 넣습니다.
// 따로 열리던 스캔·코드 화면은 더 이상 거치지 않습니다.
// 디자인: Claude Design '휴대폰 로비 · 바로 참여 흐름'.

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/template_game.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:project00/platform/home/phone/models/room_join_feedback.dart';
import 'package:project00/platform/home/phone/screens/phone_room_nickname.dart';
import 'package:project00/platform/home/phone/widgets/phone_flow_transition.dart';
import 'package:project00/platform/home/phone/widgets/room_code_entry.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/localization/platform_localizations.dart';

// ============================================================

/// 스캐너 로비의 바탕색입니다. 머리 띠와 같은 보라를 씁니다.
const phoneScannerLobbyBackground = MosiColors.violet;

/// 스캐너 모서리·스캔선·참여 버튼에 쓰는 강조색입니다.
const _accent = MosiColors.lime;
const _finderBackground = Color(0xFF0E0A3D);

class PhoneJoinScanner extends StatefulWidget {
  const PhoneJoinScanner({
    super.key,
    required this.gameCatalog,
    required this.busy,
    required this.onJoinFinished,
  });

  final GameCatalog gameCatalog;

  /// 이전 방 복구·대기실 진입 중이면 참여를 막습니다.
  final bool busy;

  /// 닉네임 화면에서 돌아왔을 때 로비가 방 상태를 다시 확인하도록 알립니다.
  final VoidCallback onJoinFinished;

  @override
  State<PhoneJoinScanner> createState() => _PhoneJoinScannerState();
}

class _PhoneJoinScannerState extends State<PhoneJoinScanner>
    with WidgetsBindingObserver {
  late final RoomProvider _roomProvider = RoomProvider(
    gameCatalog: widget.gameCatalog,
  );
  final MobileScannerController _scanner = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _code = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  /// 전용 자판이 올라와 있는 동안입니다. 그동안 카메라는 멈춥니다.
  bool _keypadOpen = false;
  bool _joining = false;

  /// 방을 찾아 체크를 보여 주는 중입니다.
  bool _found = false;

  /// 카메라를 열지 못했습니다(권한 거절·기기 미지원).
  bool _cameraFailed = false;
  RoomJoinFeedback? _feedback;

  /// 코드가 모자라거나 틀릴 때마다 바뀌어 코드 칸만 흔듭니다.
  int _shake = 0;

  bool get _blocked => widget.busy || _joining;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _codeFocus.addListener(_handleCodeFocus);
    _code.addListener(_handleCodeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeFocus.removeListener(_handleCodeFocus);
    _code.removeListener(_handleCodeChanged);
    unawaited(_scanner.dispose());
    _code.dispose();
    _codeFocus.dispose();
    _roomProvider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_keypadOpen && !_joining) unawaited(_startCamera());
    } else {
      unawaited(_stopCamera());
    }
  }

  Future<void> _startCamera({bool userInitiated = false}) async {
    if (!mounted || _keypadOpen || _joining || _scanner.value.isStarting) {
      return;
    }
    try {
      await _scanner.start();
      // mobile_scanner는 시작 실패를 throw하지 않고 controller 상태에 저장합니다.
      final error = _scanner.value.error;
      if (error != null) throw error;
      if (mounted && _cameraFailed) setState(() => _cameraFailed = false);
    } on MobileScannerException catch (error) {
      // 카메라가 없어도 아래 코드 칸으로 들어갈 수 있습니다.
      if (mounted) setState(() => _cameraFailed = true);
      if (mounted &&
          userInitiated &&
          error.errorCode == MobileScannerErrorCode.permissionDenied) {
        final open = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('카메라 권한이 필요해요'.localized),
            content: Text('설정에서 카메라 접근을 허용하면 QR로 입장할 수 있어요.'.localized),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('취소'.localized),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('설정 열기'.localized),
              ),
            ],
          ),
        );
        if (open == true && mounted) {
          try {
            await const MethodChannel(
              'mosigame/camera_settings',
            ).invokeMethod<void>('open');
          } on PlatformException {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('기기 설정에서 카메라 권한을 켜 주세요.'.localized)),
              );
            }
          } on MissingPluginException {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('기기 설정에서 카메라 권한을 켜 주세요.'.localized)),
              );
            }
          }
        }
      }
    }
  }

  Future<void> _stopCamera() async {
    try {
      await _scanner.stop();
    } on MobileScannerException {
      // 아직 켜지지 않았으면 멈출 것도 없습니다.
    }
  }

  void _handleCodeFocus() {
    final open = _codeFocus.hasFocus;
    if (open == _keypadOpen) return;
    setState(() => _keypadOpen = open);
    if (open) {
      unawaited(_stopCamera());
    } else {
      unawaited(_startCamera());
    }
  }

  void _handleCodeChanged() {
    if (!mounted) return;
    setState(() {
      _feedback = null;
      _roomProvider.errorMessage = null;
    });
  }

  void _openKeypad() {
    if (_blocked) return;
    setState(() => _feedback = null);
    _codeFocus.requestFocus();
  }

  void _closeKeypad() => _codeFocus.unfocus();

  void _switchToQr() {
    if (_blocked) return;
    setState(() => _feedback = null);
    _closeKeypad();
    unawaited(_startCamera());
  }

  void _typeCode(String character) {
    if (_code.text.length >= 5) return;
    HapticFeedback.selectionClick();
    _setCode(_code.text + character);
  }

  void _eraseCode() {
    if (_code.text.isEmpty) {
      // 지울 글자가 없으면 삭제 키를 키보드 내리기 버튼처럼 씁니다.
      _closeKeypad();
      return;
    }
    HapticFeedback.selectionClick();
    _setCode(_code.text.substring(0, _code.text.length - 1));
  }

  void _setCode(String value) {
    _code.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_blocked || _keypadOpen || _found) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim().toUpperCase();
      if (value != null && RegExp(r'^[A-Z0-9]{5}$').hasMatch(value)) {
        _setCode(value);
        unawaited(_join(fromScan: true));
        break;
      }
    }
  }

  /// 코드 다섯 자리를 확인하고 닉네임 화면으로 넘어갑니다.
  ///
  /// 다섯 자리가 안 되면 칸을 흔들고 자판을 열어 바로 이어 쓰게 합니다.
  Future<void> _join({bool fromScan = false}) async {
    if (_blocked) return;
    final roomCode = _code.text.trim().toUpperCase();
    if (roomCode.length != 5) {
      setState(() => _shake++);
      _openKeypad();
      return;
    }
    _closeKeypad();
    setState(() {
      _joining = true;
      _feedback = null;
    });
    await _stopCamera();
    final validated = await _roomProvider.validateRoomJoin(roomCode);
    if (!mounted) return;
    if (!validated) {
      setState(() {
        _joining = false;
        _feedback = roomJoinFeedbackFor(_roomProvider.errorMessage);
        _shake++;
      });
      unawaited(_startCamera());
      if (!fromScan) _openKeypad();
      return;
    }

    // 확인되면 잠깐 체크를 보여 준 뒤 닉네임 화면으로 넘어갑니다.
    setState(() => _found = true);
    await Future<void>.delayed(MosiMotion.of(context, MosiMotion.check));
    if (!mounted) return;

    await Navigator.push(
      context,
      PhoneFlowRoute<void>(
        builder: (_) =>
            PhoneRoomNickname(roomCode: roomCode, provider: _roomProvider),
      ),
    );
    if (!mounted) return;
    setState(() {
      _joining = false;
      _found = false;
    });
    _setCode('');
    widget.onJoinFinished();
    unawaited(_startCamera());
  }

  @override
  Widget build(BuildContext context) {
    final title = GameLocale.select(
      ko: '태블릿의 |QR|을\n비추면 바로 입장',
      en: "Point at the tablet's |QR|\nto join right away",
      zhHans: '对准平板的|二维码|\n即可直接加入',
      zhHant: '對準平板的|QR碼|\n即可直接加入',
    ).split('|');
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      children: [
        Expanded(child: _buildScannerContent(title, bottomInset)),
        _buildJoinFooter(bottomInset),
        RoomCodeKeypadTransition(
          visible: _keypadOpen,
          child: RoomCodeKeypad(
            length: _code.text.length,
            enabled: !_blocked,
            onKey: _typeCode,
            onBackspace: _eraseCode,
          ),
        ),
      ],
    );
  }

  Widget _buildScannerContent(List<String> title, double bottomInset) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final finder = math.min(constraints.maxWidth * .86, 310.0);
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: _keypadOpen ? 1.0 : 0.0),
                  duration: MosiMotion.of(context, MosiMotion.settle),
                  curve: Curves.easeInOutCubic,
                  builder: (context, progress, child) => Column(
                    children: [
                      SizedBox(
                        height: 90 - 35 * progress,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Opacity(
                              opacity: 1 - progress,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    for (var i = 0; i < title.length; i++)
                                      TextSpan(
                                        text: title[i],
                                        style: TextStyle(
                                          color: i == 1
                                              ? _accent
                                              : MosiColors.white,
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
                            ),
                            Opacity(
                              opacity: progress,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Text(
                                  GameLocale.select(
                                    ko: '방 코드 입력',
                                    en: 'Enter room code',
                                    zhHans: '输入房间码',
                                    zhHant: '輸入房間碼',
                                  ),
                                  key: const ValueKey('room-code-heading'),
                                  style: const TextStyle(
                                    fontFamily:
                                        'packages/${MosiFonts.package}/${MosiFonts.logo}',
                                    fontSize: 28,
                                    height: 1.25,
                                    color: MosiColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ClipRect(
                        child: Align(
                          heightFactor: 1 - progress,
                          alignment: Alignment.topCenter,
                          child: IgnorePointer(
                            ignoring: _keypadOpen,
                            child: Opacity(opacity: 1 - progress, child: child),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 스캐너와 입력칸의 트리를 유지하고 공간만 접어 입력칸을 이동시킵니다.
                  child: Center(child: _buildFinder(finder)),
                ),
                const SizedBox(height: 24),
                _buildCodeEntry(bottomInset),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinder(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _finderBackground,
          borderRadius: BorderRadius.circular(size * .1),
          border: Border.all(color: MosiColors.ink, width: 3),
          boxShadow: const [
            BoxShadow(color: MosiColors.ink, offset: Offset(0, 6)),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _scanner,
              // 카메라를 못 쓰는 사정은 틀 전체를 덮는 안내로 보여 줍니다.
              errorBuilder: (context, error) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_cameraFailed) {
                    setState(() => _cameraFailed = true);
                  }
                });
                return const SizedBox.shrink();
              },
              onDetect: _handleDetect,
            ),
            IgnorePointer(
              child: _ScannerOverlay(
                size: size,
                scanning: !_keypadOpen && !_found && !_cameraFailed,
                cameraFailed: _cameraFailed && !_keypadOpen,
                found: _found,
              ),
            ),
            if (_cameraFailed && !_keypadOpen) _buildCameraDenied(),
            if (_keypadOpen)
              ColoredBox(
                color: const Color(0x8C0E0A3D),
                child: Center(
                  child: Text(
                    GameLocale.select(
                      ko: '코드 입력 중',
                      en: 'Entering code',
                      zhHans: '正在输入房间码',
                      zhHant: '正在輸入房間碼',
                    ),
                    style: MosiFonts.sans(
                      size: 11,
                      weight: FontWeight.w700,
                      color: MosiColors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 카메라를 못 쓸 때 틀 안에 띄우는 안내입니다. 코드 칸으로 들어가면 됩니다.
  Widget _buildCameraDenied() {
    return ColoredBox(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              GameLocale.select(
                ko: '카메라를 사용할 수 없어요.',
                en: 'Camera unavailable',
                zhHans: '无法使用相机',
                zhHant: '無法使用相機',
              ),
              textAlign: TextAlign.center,
              style: MosiFonts.sans(
                size: 13.5,
                weight: FontWeight.w700,
                color: MosiColors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              GameLocale.select(
                ko: '아래에 방 코드를 입력해 주세요.',
                en: 'Enter the room code below.',
                zhHans: '请在下方输入房间码。',
                zhHant: '請在下方輸入房間碼。',
              ),
              textAlign: TextAlign.center,
              style: MosiFonts.sans(size: 11.5, color: const Color(0xD9FFFFFF)),
            ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: () => unawaited(_startCamera(userInitiated: true)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: MosiColors.ink, width: 2.5),
                    boxShadow: const [
                      BoxShadow(color: MosiColors.ink, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Text(
                    GameLocale.select(
                      ko: '카메라 허용',
                      en: 'Allow camera',
                      zhHans: '允许相机',
                      zhHant: '允許相機',
                    ),
                    style: MosiFonts.sans(
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: MosiColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeEntry(double bottomInset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MosiReveal(
          visible: !_keypadOpen,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Expanded(child: Divider(color: Color(0x59FFFFFF))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    GameLocale.select(
                      ko: '또는 방 코드 입력',
                      en: 'Or enter room code',
                      zhHans: '或输入房间码',
                      zhHant: '或輸入房間碼',
                    ),
                    style: MosiFonts.sans(
                      size: 11.5,
                      weight: FontWeight.w700,
                      color: const Color(0xD9FFFFFF),
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0x59FFFFFF))),
              ],
            ),
          ),
        ),
        MosiShake(
          trigger: _shake == 0 ? null : _shake,
          child: RoomCodeBoxes(
            key: const ValueKey('lobby-room-code-boxes'),
            controller: _code,
            focusNode: _codeFocus,
            onSubmitted: _join,
            feedback: _feedback,
            enabled: !_blocked,
          ),
        ),
        MosiReveal(
          visible: _feedback != null,
          child: _feedback == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: InlineJoinFeedback(feedback: _feedback!),
                  ),
                ),
        ),
        const SizedBox(height: 14),
        MosiReveal(
          visible: _keypadOpen,
          child: Semantics(
            button: true,
            enabled: !_blocked,
            label: 'QR로 찍기'.localized,
            excludeSemantics: true,
            child: GestureDetector(
              key: const Key('lobby-qr-scan-button'),
              onTap: _blocked ? null : _switchToQr,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 20,
                      color: MosiColors.white,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'QR로 찍기'.localized,
                      style: MosiFonts.sans(
                        size: 16,
                        weight: FontWeight.w700,
                        color: MosiColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinFooter(double bottomInset) {
    final ready = _code.text.length == 5 || _joining || _found;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: ready
          ? DecoratedBox(
              key: const ValueKey('lobby-join-footer'),
              decoration: const BoxDecoration(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  16 + (_keypadOpen ? 0 : bottomInset),
                ),
                child: MosiButton(
                  label: widget.busy
                      ? context.l10n.reconnecting
                      : context.l10n.joinGroup,
                  height: 56,
                  fontSize: 18,
                  radius: 16,
                  shadowOffset: 5,
                  background: _accent,
                  foreground: MosiColors.ink,
                  shadowColor: MosiColors.ink,
                  expand: true,
                  leading: const Icon(Icons.qr_code_scanner_rounded),
                  loading: _joining && !_found,
                  loadingDots: true,
                  success: _found,
                  onPressed: widget.busy ? null : () => unawaited(_join()),
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('lobby-join-footer-hidden')),
    );
  }
}

/// 스캐너 틀 위에 그리는 네 모서리와 오가는 스캔선입니다.
class _ScannerOverlay extends StatefulWidget {
  const _ScannerOverlay({
    required this.size,
    required this.scanning,
    required this.cameraFailed,
    required this.found,
  });

  final double size;
  final bool scanning;
  final bool cameraFailed;
  final bool found;

  @override
  State<_ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<_ScannerOverlay>
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final corner = size * .18;
    final inset = size * .1;
    // 방을 찾으면 모서리가 연두로 바뀌며 가운데로 조여듭니다.
    final pull = widget.found ? corner * .34 : 0.0;
    return Stack(
      children: [
        for (final align in const [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ])
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            left: align.x < 0 ? inset + pull : null,
            right: align.x > 0 ? inset + pull : null,
            top: align.y < 0 ? inset + pull : null,
            bottom: align.y > 0 ? inset + pull : null,
            child: CustomPaint(
              size: Size.square(corner),
              painter: _CornerPainter(
                align,
                widget.found ? const Color(0xFFD8F5B0) : _accent,
              ),
            ),
          ),
        if (widget.found)
          Center(
            child: Container(
              width: size * .34,
              height: size * .34,
              decoration: BoxDecoration(
                color: _accent,
                shape: BoxShape.circle,
                border: Border.all(color: MosiColors.ink, width: 3),
              ),
              child: Icon(
                Icons.check_rounded,
                size: size * .2,
                color: MosiColors.ink,
              ),
            ),
          ),
        if (widget.scanning || widget.cameraFailed)
          AnimatedBuilder(
            animation: _scan,
            builder: (context, _) {
              final t = widget.cameraFailed
                  ? .5
                  : reduceMotion
                  ? .5
                  : Curves.easeInOut.transform(_scan.value);
              return Positioned(
                left: size * .15,
                right: size * .15,
                top: size * .1 + (size * .78) * t,
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
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.align, this.color);

  final Alignment align;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .11;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
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
  bool shouldRepaint(_CornerPainter oldDelegate) =>
      oldDelegate.align != align || oldDelegate.color != color;
}
