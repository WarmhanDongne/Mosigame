import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:project00/platform/home/phone/models/room_join_feedback.dart';
import 'package:project00/platform/home/phone/screens/phone_room_nickname.dart';
import 'package:project00/platform/home/phone/widgets/phone_flow_transition.dart';
import 'package:project00/platform/home/phone/widgets/room_code_entry.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:game_kit/template_game.dart';

//=======================그룹 참여 코드 화면==============================
class PhoneRoomJoin extends StatefulWidget {
  const PhoneRoomJoin({
    super.key,
    required this.gameCatalog,
    this.startWithCode = false,
  });

  final GameCatalog gameCatalog;

  /// true면 카메라 대신 방 코드 입력 칸을 먼저 엽니다(로비의 도움 카드).
  final bool startWithCode;

  @override
  State<PhoneRoomJoin> createState() => _PhoneRoomJoinState();
}

class _PhoneRoomJoinState extends State<PhoneRoomJoin>
    with WidgetsBindingObserver {
  final TextEditingController _roomCodeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  late final RoomProvider _roomProvider = RoomProvider(
    gameCatalog: widget.gameCatalog,
  );
  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isOpeningNameInput = false;
  bool _codeMode = false;
  bool _submittedFromCodeMode = false;
  RoomJoinFeedback? _feedback;

  /// 입장 확인이 끝나 체크를 보여 주는 중인지입니다(로비 연출 3번).
  bool _joinSucceeded = false;

  /// 코드가 틀릴 때마다 바뀌어 코드 칸만 흔듭니다.
  int _codeShake = 0;

  @override
  void initState() {
    super.initState();
    _roomCodeController.addListener(_refreshCode);
    _codeFocusNode.addListener(_onCodeFocus);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.startWithCode) {
        // 포커스를 주면 기존 코드 모드 전환(_onCodeFocus)이 그대로 동작합니다.
        if (mounted) _codeFocusNode.requestFocus();
        return;
      }
      _startScannerIfVisible();
    });
  }

  Future<void> _startScannerIfVisible() async {
    if (!mounted || _codeMode || _isOpeningNameInput) return;
    try {
      await _scannerController.start();
    } on MobileScannerException {
      // 카메라를 시작하지 못해도 같은 화면의 수동 코드 입력은 유지합니다.
    }
  }

  void _onCodeFocus() async {
    if (!_codeFocusNode.hasFocus || _codeMode) return;
    setState(() => _codeMode = true);
    try {
      await _scannerController.stop();
    } on MobileScannerException {
      // 카메라가 준비되지 않았어도 코드 입력을 열 수 있습니다.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    try {
      if (state == AppLifecycleState.resumed &&
          !_codeMode &&
          !_isOpeningNameInput) {
        await _startScannerIfVisible();
      } else if (state != AppLifecycleState.resumed) {
        await _scannerController.stop();
      }
    } on MobileScannerException {
      // 수동 코드 입력은 카메라 권한/연결 상태와 무관하게 유지합니다.
    }
  }

  void _showScanner() {
    _codeFocusNode.unfocus();
    setState(() {
      _codeMode = false;
      _submittedFromCodeMode = false;
      _feedback = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScannerIfVisible();
    });
  }

  void _refreshCode() {
    _feedback = null;
    _roomProvider.errorMessage = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeFocusNode.removeListener(_onCodeFocus);
    _roomCodeController.removeListener(_refreshCode);
    _scannerController.dispose();
    _roomCodeController.dispose();
    _codeFocusNode.dispose();
    _roomProvider.dispose();
    super.dispose();
  }

  Future<void> _openNameInput() async {
    final roomCode = _roomCodeController.text.trim().toUpperCase();
    if (roomCode.length != 5) return;
    if (_isOpeningNameInput) return;
    final submittedFromCodeMode = _codeMode;
    if (submittedFromCodeMode) _codeFocusNode.unfocus();
    setState(() {
      _isOpeningNameInput = true;
      _feedback = null;
      if (submittedFromCodeMode) {
        _submittedFromCodeMode = true;
        _codeMode = false;
      }
    });
    // 전용 자판이 화면 아래로 완전히 빠진 다음 검증·다음 route를 시작합니다.
    // 두 동작을 겹치면 다음 화면이 자판 높이만큼 밀렸다가 돌아오는 것처럼 보입니다.
    if (submittedFromCodeMode) {
      final keyboardExit = MosiMotion.of(context, MosiMotion.exit);
      if (keyboardExit > Duration.zero) {
        await Future<void>.delayed(keyboardExit);
      }
      if (!mounted) return;
    }
    final validated = await _roomProvider.validateRoomJoin(roomCode);
    if (!mounted) return;
    if (!validated) {
      setState(() {
        _isOpeningNameInput = false;
        _submittedFromCodeMode = false;
        _codeMode = submittedFromCodeMode;
        _feedback = roomJoinFeedbackFor(_roomProvider.errorMessage);
        _codeShake++;
      });
      if (submittedFromCodeMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _codeFocusNode.requestFocus();
        });
      }
      return;
    }

    // 확인되면 버튼 안에 체크를 그리고 잠깐 보여 준 뒤 다음 화면으로 넘깁니다.
    setState(() => _joinSucceeded = true);
    await Future<void>.delayed(MosiMotion.of(context, MosiMotion.check));
    if (!mounted) return;

    try {
      await _scannerController.stop();
    } on MobileScannerException {
      // 카메라가 없어도 참여 코드를 직접 입력할 수 있습니다.
    }
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
      _isOpeningNameInput = false;
      _joinSucceeded = false;
      _submittedFromCodeMode = false;
      _codeMode = submittedFromCodeMode;
    });
    if (submittedFromCodeMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _codeFocusNode.requestFocus();
      });
    }
    await _startScannerIfVisible();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _roomCodeController.text.length == 5;
    // 완료를 누른 뒤에도 코드 화면 자체는 유지하고 자판만 먼저 내립니다.
    final showCodeEntry = _codeMode || _submittedFromCodeMode;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: !_isOpeningNameInput && !_codeMode,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_isOpeningNameInput && _codeMode) _showScanner();
        },
        child: Scaffold(
          backgroundColor: MosiColors.violet,
          body: SafeArea(
            bottom: !showCodeEntry,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '뒤로'.localized,
                        onPressed: _isOpeningNameInput
                            ? null
                            : () {
                                if (_codeMode) {
                                  _showScanner();
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: MosiColors.white,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.chevron_left,
                            size: 22,
                            color: MosiColors.white,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '그룹 참여하기'.localized,
                          textAlign: TextAlign.center,
                          style: MosiFonts.sans(
                            size: 17,
                            weight: FontWeight.w700,
                            color: MosiColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          children: [
                            PhoneFlowContentSwap(
                              stateKey: showCodeEntry
                                  ? 'code-title'
                                  : 'scanner-title',
                              child: MosiBalancedText(
                                showCodeEntry
                                    ? '방 코드 입력'.localized
                                    : '어느 방에 들어갈까요?'.localized,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: MosiFonts.sans(
                                  size: 23,
                                  weight: FontWeight.w700,
                                  color: MosiColors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            PhoneFlowContentSwap(
                              stateKey: showCodeEntry
                                  ? 'code-subtitle'
                                  : 'scanner-subtitle',
                              child: Text(
                                showCodeEntry
                                    ? ''
                                    : '태블릿에 뜬 QR을 네모 안에 비춰 주세요'.localized,
                                textAlign: TextAlign.center,
                                style: MosiFonts.sans(
                                  size: 12,
                                  color: const Color(0xBBFFFFFF),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            PhoneFlowContentSwap(
                              stateKey: showCodeEntry
                                  ? 'code-entry-step'
                                  : 'scanner-entry-step',
                              child: showCodeEntry
                                  ? _buildCodeLead()
                                  : _buildScannerLead(),
                            ),
                            // 확인하는 동안에도 코드 칸은 그대로 두고, 틀리면 칸만
                            // 흔듭니다(로비 연출 3번).
                            MosiShake(
                              trigger: _codeShake == 0 ? null : _codeShake,
                              child: RoomCodeBoxes(
                                key: const ValueKey('room-code-boxes'),
                                controller: _roomCodeController,
                                focusNode: _codeFocusNode,
                                onSubmitted: _openNameInput,
                                feedback: _feedback,
                                enabled: !_isOpeningNameInput,
                              ),
                            ),
                            MosiReveal(
                              visible: _feedback != null,
                              child: _feedback == null
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: InlineJoinFeedback(
                                        feedback: _feedback!,
                                      ),
                                    ),
                            ),
                            PhoneFlowContentSwap(
                              stateKey: showCodeEntry
                                  ? 'scan-again'
                                  : 'keyboard-hint',
                              child: showCodeEntry
                                  ? TextButton.icon(
                                      onPressed: _isOpeningNameInput
                                          ? null
                                          : _showScanner,
                                      icon: const Icon(
                                        Icons.qr_code_scanner,
                                        size: 16,
                                      ),
                                      label: Text(
                                        'QR로 찍기'.localized,
                                        style: MosiFonts.sans(
                                          size: 12,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: MosiColors.white,
                                      ),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Text(
                                        '칸을 누르면 키보드가 올라와요'.localized,
                                        style: MosiFonts.sans(
                                          size: 11,
                                          color: const Color(0xBBFFFFFF),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                PhoneFlowContentSwap(
                  stateKey: showCodeEntry || canSubmit || _isOpeningNameInput,
                  alignment: Alignment.bottomCenter,
                  child: showCodeEntry || canSubmit || _isOpeningNameInput
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: !canSubmit && !_isOpeningNameInput
                              ? Semantics(
                                  button: true,
                                  enabled: false,
                                  child: Container(
                                    height: 52,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0x22FFFFFF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0x77FFFFFF),
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      GameLocale.select(
                                        ko: '${5 - _roomCodeController.text.length}글자 더 입력해 주세요',
                                        en: 'Enter ${5 - _roomCodeController.text.length} more characters',
                                        zhHans:
                                            '还需输入 ${5 - _roomCodeController.text.length} 个字符',
                                        zhHant:
                                            '還需輸入 ${5 - _roomCodeController.text.length} 個字元',
                                      ),
                                      style: MosiFonts.sans(
                                        size: 15,
                                        weight: FontWeight.w700,
                                        color: const Color(0xCCFFFFFF),
                                      ),
                                    ),
                                  ),
                                )
                              : MosiButton(
                                  label: canSubmit
                                      ? '입력 완료'.localized
                                      : GameLocale.select(
                                          ko: '${5 - _roomCodeController.text.length}글자 더 입력해 주세요',
                                          en: 'Enter ${5 - _roomCodeController.text.length} more characters',
                                          zhHans:
                                              '还需输入 ${5 - _roomCodeController.text.length} 个字符',
                                          zhHant:
                                              '還需輸入 ${5 - _roomCodeController.text.length} 個字元',
                                        ),
                                  height: 52,
                                  expand: true,
                                  fontSize: 16,
                                  background: canSubmit
                                      ? MosiColors.lime
                                      : const Color(0x33FFFFFF),
                                  foreground: canSubmit
                                      ? MosiColors.navy
                                      : MosiColors.white,
                                  loading:
                                      _isOpeningNameInput && !_joinSucceeded,
                                  loadingDots: true,
                                  success: _joinSucceeded,
                                  onPressed: canSubmit && !_isOpeningNameInput
                                      ? _openNameInput
                                      : null,
                                ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                // 방 코드는 영문 대문자·숫자뿐이라 기기 키보드 대신 전용 자판을
                // 띄웁니다. 숨은 입력칸은 실제 키보드·화면 읽기용으로만 남습니다.
                RoomCodeKeypadTransition(
                  visible: _codeMode,
                  child: RoomCodeKeypad(
                    length: _roomCodeController.text.length,
                    enabled: !_isOpeningNameInput,
                    onKey: _typeCode,
                    onBackspace: _eraseCode,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _typeCode(String character) {
    final code = _roomCodeController.text;
    if (code.length >= 5) return;
    HapticFeedback.selectionClick();
    final next = code + character;
    _roomCodeController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void _eraseCode() {
    final code = _roomCodeController.text;
    if (code.isEmpty) return;
    HapticFeedback.selectionClick();
    final next = code.substring(0, code.length - 1);
    _roomCodeController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Widget _buildScannerLead() => Column(
    children: [
      _buildScanner(),
      const SizedBox(height: 26),
      Row(
        children: [
          const Expanded(child: Divider(color: Color(0x66FFFFFF))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '또는 방 코드 입력'.localized,
              style: MosiFonts.sans(size: 12, color: MosiColors.white),
            ),
          ),
          const Expanded(child: Divider(color: Color(0x66FFFFFF))),
        ],
      ),
      const SizedBox(height: 14),
    ],
  );

  Widget _buildCodeLead() => Column(
    children: [
      const SizedBox(height: 4),
    ],
  );

  Widget _buildScanner() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 22),
    child: AspectRatio(
      aspectRatio: 1,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: MosiColors.navy,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MosiColors.ink, width: 3),
          boxShadow: const [
            BoxShadow(color: MosiColors.ink, offset: Offset(6, 6)),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _scannerController,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Text(
                    GameLocale.select(
                      ko: '카메라를 사용할 수 없어요.\n아래에 방 코드를 입력해 주세요.',
                      en: 'Camera unavailable.\nEnter the room code below.',
                      zhHans: '无法使用相机。\n请在下方输入房间码。',
                      zhHant: '無法使用相機。\n請在下方輸入房間碼。',
                    ),
                    textAlign: TextAlign.center,
                    style: MosiFonts.sans(size: 13, color: MosiColors.white),
                  ),
                ),
              ),
              onDetect: (capture) {
                if (_isOpeningNameInput || _codeMode) return;
                for (final barcode in capture.barcodes) {
                  final value = barcode.rawValue?.trim().toUpperCase();
                  if (value != null &&
                      RegExp(r'^[A-Z0-9]{5}$').hasMatch(value)) {
                    _roomCodeController.text = value;
                    _openNameInput();
                    break;
                  }
                }
              },
            ),
            const IgnorePointer(child: ScannerFrame()),
          ],
        ),
      ),
    ),
  );
}
