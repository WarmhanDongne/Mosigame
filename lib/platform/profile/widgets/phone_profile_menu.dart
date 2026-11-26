// [phone_profile_menu.dart] 는 휴대폰 로비 오른쪽 위 프로필을 누르면 그 자리에서
// 펼쳐지는 말풍선 메뉴다.
//
// 메뉴 · 닉네임 바꾸기 · 계정 연결(Google/Apple/이메일) · 연결 완료 · 로그아웃 ·
// 회원탈퇴 · 탈퇴 완료를 한 말풍선 안에서 전환합니다. 화면이 바뀔 때 말풍선
// 높이가 부드럽게 늘었다 줄고, 내용은 옆으로 미끄러져 들어옵니다. 내용은 말풍선
// 밖으로 나가지 않게 잘라 냅니다.
// 디자인: Claude Design '프로필 메뉴 · 흐름 애니메이션' (로그아웃 경고 1안).
//
// 저장·연결·로그아웃·탈퇴의 실제 동작은 기존 태블릿 프로필 모달과 같은
// 서비스(FirebaseAuthService, ProfileUpdateController)를 그대로 씁니다.

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project00/platform/auth/models/nickname_policy.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/widgets/auth_design.dart';
import 'package:project00/platform/home/room/services/player_room_session_store.dart';
import 'package:project00/platform/localization/platform_localizations.dart';
import 'package:project00/platform/notifications/push_notification_host.dart';
import 'package:project00/platform/profile/providers/profile_update_controller.dart';
import 'package:project00/platform/profile/widgets/tablet_profile.dart';

// ============================================================

const _ink = MosiColors.ink;
const _navy = MosiColors.navy;
const _violet = MosiColors.violet;
const _sun = MosiColors.sun;
const _cream = MosiColors.cream;
const _muted = Color(0xFF8C8AA8);
const _danger = Color(0xFFC2283C);
const _softYellow = Color(0xFFFFF8C7);
const _dashLine = Color(0xFFE4E1EE);

/// 휴대폰 프로필 말풍선을 엽니다. 누른 프로필(오른쪽 위)에서 펼쳐집니다.
Future<void> showPhoneProfileMenu(
  BuildContext context, {
  FirebaseAuthService? authService,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.close,
    barrierColor: const Color(0x8C08061A),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => PhoneProfileMenu(authService: authService),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .6, end: 1).animate(curved),
          alignment: Alignment.topRight,
          child: child,
        ),
      );
    },
  );
}

enum _Panel { menu, nickname, link, email, linked, logout, delete, bye }

enum _LinkMethod { google, apple, email }

class PhoneProfileMenu extends StatefulWidget {
  const PhoneProfileMenu({super.key, this.authService});

  /// 테스트에서 계정 서비스를 바꿔 끼울 때 씁니다.
  final FirebaseAuthService? authService;

  @override
  State<PhoneProfileMenu> createState() => _PhoneProfileMenuState();
}

class _PhoneProfileMenuState extends State<PhoneProfileMenu>
    with SingleTickerProviderStateMixin {
  late final FirebaseAuthService _auth =
      widget.authService ?? FirebaseAuthService();
  final ProfileUpdateController _updates = ProfileUpdateController.instance;
  final ImagePicker _picker = ImagePicker();
  final _nickname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nicknameFocus = FocusNode();

  /// 회원탈퇴 버튼을 꾹 누르는 동안 차오르는 진행도입니다(1.5초).
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..addStatusListener(_onHoldStatus);

  _Panel _panel = _Panel.menu;
  bool _forward = true;
  _LinkMethod? _linking;
  String? _linkedLabel;
  String? _error;
  bool _busy = false;
  bool _doorShut = false;

  /// 이름이 바뀔 때마다 늘려 이름을 한 번 톡 튀게 합니다.
  int _nameBump = 0;

  static final _order = _Panel.values;

  User? get _user => FirebaseBackend.auth.currentUser;
  bool get _isGuest => _user?.isAnonymous == true;

  bool get _appleAvailable =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  String get _displayName {
    final pending = _updates.pendingFor(_user?.uid);
    return pending?.nickname ?? profileDisplayName(_user);
  }

  @override
  void initState() {
    super.initState();
    _updates.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _updates.removeListener(_refresh);
    _hold.dispose();
    _nickname.dispose();
    _email.dispose();
    _password.dispose();
    _nicknameFocus.dispose();
    super.dispose();
  }

  void _go(_Panel next) {
    if (_busy || next == _panel) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = _order.indexOf(next) >= _order.indexOf(_panel);
      _panel = next;
      _error = null;
      _doorShut = false;
    });
    if (next == _Panel.nickname) {
      final name = _displayName;
      _nickname
        ..text = name.characters.length <= nicknameMaxLength
            ? name
            : name.characters.take(nicknameMaxLength).toString()
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: _nickname.text.length,
        );
      // 말풍선이 커진 뒤 입력 칸에 포커스를 줍니다.
      Future<void>.delayed(const Duration(milliseconds: 360), () {
        if (mounted && _panel == _Panel.nickname) _nicknameFocus.requestFocus();
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // 사진 · 닉네임
  // ---------------------------------------------------------------------------

  /// 사진을 누르면 앨범을 열고, 고른 사진을 바로 저장합니다.
  Future<void> _pickImage() async {
    if (_busy || _updates.isSaving) return;
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      unawaited(
        _saveProfile(
          nickname: _displayName,
          nicknameChanged: false,
          imageBytes: bytes,
          imageName: image.name,
          imageType: image.mimeType,
        ),
      );
    } catch (_) {
      _showMessage(
        GameLocale.select(
          ko: '앨범을 열지 못했습니다. 잠시 후 다시 시도해주세요.',
          en: 'Could not open the photo library. Try again shortly.',
          zhHans: '无法打开相册。请稍后重试。',
          zhHant: '無法開啟相簿。請稍後重試。',
        ),
      );
    }
  }

  void _saveNickname() {
    final nickname = _nickname.text.trim();
    if (nickname == _displayName) {
      _go(_Panel.menu);
      return;
    }
    if (nickname.runes.length < nicknameMinLength) {
      setState(
        () => _error = GameLocale.select(
          ko: '닉네임을 $nicknameMinLength자 이상 입력해주세요.',
          en: 'Enter at least $nicknameMinLength characters.',
          zhHans: '昵称至少需要 $nicknameMinLength 个字符。',
          zhHant: '暱稱至少需要 $nicknameMinLength 個字元。',
        ),
      );
      return;
    }
    unawaited(_saveProfile(nickname: nickname, nicknameChanged: true));
    _go(_Panel.menu);
    setState(() => _nameBump += 1);
  }

  Future<void> _saveProfile({
    required String nickname,
    required bool nicknameChanged,
    Uint8List? imageBytes,
    String? imageName,
    String? imageType,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await _updates.save(
        PendingProfileUpdate(
          ownerUid: _user?.uid,
          nickname: nickname,
          nicknameChanged: nicknameChanged,
          imageBytes: imageBytes,
          imageName: imageName,
          imageType: imageType,
        ),
        service: _auth,
      );
    } on Object catch (error) {
      final message = error is AuthServiceException
          ? error.message
          : _updates.errorMessage ??
                GameLocale.select(
                  ko: '프로필을 저장하지 못했습니다.',
                  en: 'Could not save your profile.',
                  zhHans: '无法保存个人资料。',
                  zhHant: '無法儲存個人資料。',
                );
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // ---------------------------------------------------------------------------
  // 계정 연결
  // ---------------------------------------------------------------------------

  Future<void> _link(
    _LinkMethod method,
    String label,
    Future<void> Function() operation,
  ) async {
    if (_linking != null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _linking = method;
      _error = null;
    });
    try {
      await operation();
      if (!mounted) return;
      setState(() {
        _linking = null;
        _linkedLabel = label;
      });
      _go(_Panel.linked);
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _linking = null;
        _error = error.code == 'canceled' ? null : error.message;
      });
    }
  }

  void _linkEmail() {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = '이메일 주소를 확인해주세요.'.localized);
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = '비밀번호를 8자 이상 입력해주세요.'.localized);
      return;
    }
    unawaited(
      _link(
        _LinkMethod.email,
        GameLocale.select(ko: '이메일', en: 'email', zhHans: '邮箱', zhHant: '電子郵件'),
        () => _auth.linkGuestWithEmail(email: email, password: _password.text),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 로그아웃 · 회원탈퇴
  // ---------------------------------------------------------------------------

  Future<void> _logout() async {
    if (_busy) return;
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _doorShut = true;
    });
    // 문이 닫히는 모습을 보여 준 뒤 실제로 로그아웃합니다.
    await Future<void>.delayed(const Duration(milliseconds: 650));
    try {
      await PushDeviceRegistration.unregisterBeforeSignOut();
      await FirebaseBackend.auth.signOut();
      _updates.clear();
      if (navigator.mounted) navigator.popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _doorShut = false;
      });
      _showMessage(
        GameLocale.select(
          ko: '로그아웃하지 못했습니다. 잠시 후 다시 시도해주세요.',
          en: 'Could not log out. Try again shortly.',
          zhHans: '无法退出登录。请稍后重试。',
          zhHant: '無法登出。請稍後重試。',
        ),
      );
    }
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) unawaited(_deleteAccount());
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await _auth.deleteAccount();
      await PlayerRoomSessionStore.instance.clear();
      _updates.clear();
      if (!mounted) return;
      setState(() => _busy = false);
      _go(_Panel.bye);
      await Future<void>.delayed(const Duration(milliseconds: 2300));
      if (navigator.mounted) navigator.popUntil((route) => route.isFirst);
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      _hold.value = 0;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // 화면
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isTablet = media.size.shortestSide >= 600;
    // 휴대폰은 기존 말풍선 폭을 유지하고, 태블릿은 헤더의 여유 폭을
    // 사용해 내용이 눌리지 않도록 키웁니다.
    final width = isTablet
        ? math.min(media.size.width - 64, 440.0)
        : math.min(media.size.width - 20, 300.0);
    // 태블릿 헤더는 로비 바깥 여백 안에 있으므로 말풍선 꼬리를
    // 프로필 버튼의 오른쪽 아래에 맞춥니다.
    final right = isTablet ? 32.0 : 10.0;
    final top = media.padding.top + (isTablet ? 86.0 : 66.0);
    return Stack(
      children: [
        Positioned(
          top: top,
          right: right,
          width: width,
          child: Material(
            type: MaterialType.transparency,
            child: _Bubble(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // 나가는 화면은 높이 계산에서 빼 말풍선이 새 화면 높이로 맞춰집니다.
                      for (final child in previous)
                        Positioned(left: 0, right: 0, top: 0, child: child),
                      ?current,
                    ],
                  ),
                  transitionBuilder: (child, animation) {
                    final entering = child.key == ValueKey(_panel);
                    final dx = (_forward == entering) ? .12 : -.12;
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(dx, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_panel),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: _buildPanel(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel() => switch (_panel) {
    _Panel.menu => _menuPanel(),
    _Panel.nickname => _nicknamePanel(),
    _Panel.link => _linkPanel(),
    _Panel.email => _emailPanel(),
    _Panel.linked => _linkedPanel(),
    _Panel.logout => _logoutPanel(),
    _Panel.delete => _deletePanel(),
    _Panel.bye => _byePanel(),
  };

  Widget _avatar(double size, {bool editable = false}) {
    final pending = _updates.pendingFor(_user?.uid);
    final avatar = ProfileAvatar(
      user: _user,
      size: size,
      name: pending?.nickname,
      image: pending?.imageBytes == null
          ? null
          : MemoryImage(pending!.imageBytes!),
      syncing: pending != null && _updates.isSaving,
      syncFailed: pending != null && _updates.hasFailed,
    );
    if (!editable) return avatar;
    return Semantics(
      button: true,
      label: context.l10n.changePhoto,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            Positioned(
              right: -4,
              bottom: -3,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _sun,
                  shape: BoxShape.circle,
                  border: Border.all(color: _ink, width: 2.5),
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 13,
                  color: _ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountBadge() {
    final providers =
        _user?.providerData.map((info) => info.providerId).toSet() ?? {};
    final String label;
    Widget? leading;
    if (_isGuest) {
      label = GameLocale.select(
        ko: '게스트',
        en: 'Guest',
        zhHans: '访客',
        zhHant: '訪客',
      );
    } else if (providers.contains('google.com')) {
      label = 'Google';
      leading = const _GoogleDot(size: 10);
    } else if (providers.contains('apple.com')) {
      label = 'Apple';
    } else {
      label = GameLocale.select(
        ko: '이메일',
        en: 'Email',
        zhHans: '邮箱',
        zhHant: '電子郵件',
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: MosiColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 4)],
          Text(
            label,
            style: MosiFonts.sans(
              size: 10.5,
              weight: FontWeight.w900,
              color: _navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _avatar(58, editable: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(_nameBump),
                          tween: Tween<double>(
                            begin: _nameBump == 0 ? 1.0 : 1.3,
                            end: 1.0,
                          ),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) => Transform.scale(
                            scale: scale,
                            alignment: Alignment.centerLeft,
                            child: child,
                          ),
                          child: Text(
                            _displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MosiFonts.sans(
                              size: 21,
                              weight: FontWeight.w900,
                              color: _navy,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      _PencilButton(
                        label: context.l10n.nickname,
                        onTap: () => _go(_Panel.nickname),
                      ),
                    ],
                  ),
                  _accountBadge(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isGuest)
          _MenuRow(
            key: const Key('guest-account-link-row'),
            icon: const _LinkIcon(),
            label: GameLocale.select(
              ko: '계정 연결하기',
              en: 'Link an account',
              zhHans: '关联账号',
              zhHant: '連結帳號',
            ),
            highlight: true,
            onTap: () => _go(_Panel.link),
          ),
        _MenuRow(
          icon: const _DoorIcon(),
          label: context.l10n.logout,
          onTap: () => _go(_Panel.logout),
        ),
        _MenuRow(
          icon: const _TrashIcon(),
          label: context.l10n.deleteAccount,
          danger: true,
          last: true,
          showChevron: false,
          onTap: () => _go(_Panel.delete),
        ),
      ],
    );
  }

  Widget _nicknamePanel() {
    final count = _nickname.text.characters.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _avatar(40),
            const SizedBox(width: 12),
            Text(
              GameLocale.select(
                ko: '닉네임 바꾸기',
                en: 'Change nickname',
                zhHans: '修改昵称',
                zhHant: '修改暱稱',
              ),
              style: _titleStyle,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                GameLocale.select(
                  ko: '새 닉네임',
                  en: 'New nickname',
                  zhHans: '新昵称',
                  zhHant: '新暱稱',
                ),
                style: MosiFonts.sans(
                  size: 12,
                  weight: FontWeight.w900,
                  color: _violet,
                ),
              ),
            ),
            Text(
              '$count / $nicknameMaxLength',
              style: MosiFonts.grotesk(size: 12, color: _muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 입력 칸이 작게 시작해 통통 튀며 커집니다.
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: .55, end: 1.0),
          duration: const Duration(milliseconds: 520),
          curve: Curves.elasticOut,
          builder: (context, scale, child) => Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: child,
          ),
          child: _ShadowBox(
            radius: 16,
            child: TextField(
              controller: _nickname,
              focusNode: _nicknameFocus,
              maxLength: nicknameMaxLength,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _saveNickname(),
              style: MosiFonts.sans(
                size: 28,
                weight: FontWeight.w900,
                color: _navy,
              ),
              decoration: const InputDecoration(
                counterText: '',
                filled: true,
                fillColor: _softYellow,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.nicknameHint,
          style: MosiFonts.sans(size: 11, color: _muted, height: 1.45),
        ),
        _errorText(),
        const SizedBox(height: 12),
        _TwoButtons(
          leftLabel: context.l10n.cancel,
          onLeft: () => _go(_Panel.menu),
          rightLabel: context.l10n.save,
          rightColor: _sun,
          rightText: _ink,
          onRight: _saveNickname,
        ),
      ],
    );
  }

  Widget _panelHeader(String title, _Panel back) => Row(
    children: [
      Semantics(
        button: true,
        label: context.l10n.close,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: _linking == null ? () => _go(back) : null,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: MosiColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _ink, width: 2),
            ),
            child: const Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: _ink,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: _titleStyle)),
    ],
  );

  Widget _linkPanel() {
    final blocked = _linking != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panelHeader(
          GameLocale.select(
            ko: '계정 연결하기',
            en: 'Link an account',
            zhHans: '关联账号',
            zhHant: '連結帳號',
          ),
          _Panel.menu,
        ),
        const SizedBox(height: 10),
        Text(
          GameLocale.select(
            ko: '지금 닉네임·구매 내역 등 내 정보를 그대로 옮겨요. 다른 기기에서도 이 계정으로 이어서 할 수 있어요.',
            en: 'Your nickname, purchases, and other info move over as they are. Continue on any device with this account.',
            zhHans: '昵称、购买记录等信息会原样保留。可在其他设备上用此账号继续。',
            zhHant: '暱稱、購買記錄等資訊會原樣保留。可在其他裝置上用此帳號繼續。',
          ),
          style: MosiFonts.sans(
            size: 12.5,
            color: MosiColors.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        _BigButton(
          key: const Key('guest-link-google'),
          label: 'Google로 연결'.localized,
          leading: const _GoogleDot(size: 16),
          background: MosiColors.white,
          foreground: _ink,
          loading: _linking == _LinkMethod.google,
          onTap: blocked
              ? null
              : () => _link(
                  _LinkMethod.google,
                  'Google',
                  _auth.linkGuestWithGoogle,
                ),
        ),
        if (_appleAvailable)
          _BigButton(
            key: const Key('guest-link-apple'),
            label: 'Apple로 연결'.localized,
            leading: const Icon(Icons.apple, size: 18, color: MosiColors.white),
            background: _ink,
            foreground: MosiColors.white,
            loading: _linking == _LinkMethod.apple,
            onTap: blocked
                ? null
                : () => _link(
                    _LinkMethod.apple,
                    'Apple',
                    _auth.linkGuestWithApple,
                  ),
          ),
        _BigButton(
          key: const Key('guest-link-email-toggle'),
          label: '이메일로 연결'.localized,
          leading: const Icon(
            Icons.mail_outline_rounded,
            size: 18,
            color: MosiColors.white,
          ),
          background: _violet,
          foreground: MosiColors.white,
          onTap: blocked ? null : () => _go(_Panel.email),
        ),
        const SizedBox(height: 10),
        Text(
          GameLocale.select(
            ko: '이미 다른 모시겜 계정에 쓰는 로그인 정보는 연결할 수 없어요.',
            en: 'A sign-in already used by another MosiGame account cannot be linked.',
            zhHans: '已用于其他摩西游戏账号的登录信息无法关联。',
            zhHant: '已用於其他摩西遊戲帳號的登入資訊無法連結。',
          ),
          style: MosiFonts.sans(size: 11, color: _muted, height: 1.5),
        ),
        _errorText(),
      ],
    );
  }

  Widget _emailPanel() {
    final blocked = _linking != null;
    InputDecoration deco(String hint) =>
        mosiInputDecoration().copyWith(hintText: hint);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panelHeader('이메일로 연결'.localized, _Panel.link),
        const SizedBox(height: 12),
        TextField(
          key: const Key('guest-link-email'),
          controller: _email,
          enabled: !blocked,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: deco('이메일'.localized),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('guest-link-password'),
          controller: _password,
          enabled: !blocked,
          obscureText: true,
          autocorrect: false,
          decoration: deco('비밀번호 · 8자 이상'.localized),
          onSubmitted: (_) => _linkEmail(),
        ),
        _errorText(),
        const SizedBox(height: 6),
        _BigButton(
          key: const Key('guest-link-email-submit'),
          label: GameLocale.select(
            ko: '연결하기',
            en: 'Link',
            zhHans: '关联',
            zhHant: '連結',
          ),
          background: _sun,
          foreground: _ink,
          loading: _linking == _LinkMethod.email,
          onTap: blocked ? null : _linkEmail,
        ),
      ],
    );
  }

  Widget _linkedPanel() {
    final via = _linkedLabel ?? 'Google';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        const _SuccessBadge(),
        const SizedBox(height: 14),
        Text(
          GameLocale.select(
            ko: '계정이 연결됐어요!',
            en: 'Account linked!',
            zhHans: '账号已关联！',
            zhHant: '帳號已連結！',
          ),
          style: _titleStyle.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          GameLocale.select(
            ko: '게스트 정보가 $via 계정에 안전하게 저장됐어요',
            en: 'Your guest info is now saved to your $via account',
            zhHans: '访客信息已安全保存到 $via 账号',
            zhHant: '訪客資訊已安全儲存到 $via 帳號',
          ),
          textAlign: TextAlign.center,
          style: MosiFonts.sans(
            size: 12.5,
            color: MosiColors.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        _BigButton(
          label: GameLocale.select(
            ko: '확인',
            en: 'OK',
            zhHans: '确定',
            zhHant: '確定',
          ),
          background: _sun,
          foreground: _ink,
          onTap: () {
            _go(_Panel.menu);
            setState(() => _nameBump += 1);
          },
        ),
      ],
    );
  }

  Widget _logoutPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _DoorArt(shut: _doorShut)),
        const SizedBox(height: 6),
        Text(
          GameLocale.select(
            ko: '로그아웃할까요?',
            en: 'Log out?',
            zhHans: '要退出登录吗？',
            zhHant: '要登出嗎？',
          ),
          textAlign: TextAlign.center,
          style: _titleStyle.copyWith(fontSize: 23),
        ),
        if (_isGuest)
          _GuestWarning(onLink: () => _go(_Panel.link))
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              GameLocale.select(
                ko: '다음에 다시 로그인하면 그대로 이어져요.',
                en: 'Sign in again later to pick up where you left off.',
                zhHans: '下次重新登录即可继续。',
                zhHant: '下次重新登入即可繼續。',
              ),
              textAlign: TextAlign.center,
              style: MosiFonts.sans(size: 12.5, color: MosiColors.muted),
            ),
          ),
        const SizedBox(height: 14),
        _TwoButtons(
          leftLabel: context.l10n.cancel,
          onLeft: _busy ? null : () => _go(_Panel.menu),
          rightLabel: context.l10n.logout,
          rightColor: _navy,
          rightText: MosiColors.white,
          onRight: _busy ? null : _logout,
        ),
      ],
    );
  }

  Widget _deletePanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: _WobbleTrash()),
        const SizedBox(height: 6),
        Text(
          GameLocale.select(
            ko: '정말 탈퇴할까요?',
            en: 'Delete your account?',
            zhHans: '确定要注销吗？',
            zhHant: '確定要註銷嗎？',
          ),
          textAlign: TextAlign.center,
          style: _titleStyle.copyWith(fontSize: 23),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _ink, width: 2),
          ),
          child: Row(
            children: [
              const Icon(Icons.close_rounded, size: 16, color: _danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  GameLocale.select(
                    ko: '구매한 게임도 함께 지워져요',
                    en: 'Purchased games are deleted too',
                    zhHans: '已购买的游戏也会一并删除',
                    zhHant: '已購買的遊戲也會一併刪除',
                  ),
                  style: MosiFonts.sans(
                    size: 13,
                    weight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          GameLocale.select(
            ko: '모두 지워지고 되돌릴 수 없어요',
            en: 'This cannot be undone',
            zhHans: '删除后无法恢复',
            zhHant: '刪除後無法復原',
          ),
          textAlign: TextAlign.center,
          style: MosiFonts.sans(
            size: 11.5,
            weight: FontWeight.w700,
            color: _danger,
          ),
        ),
        _errorText(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BigButton(
                label: context.l10n.cancel,
                background: MosiColors.white,
                foreground: _navy,
                onTap: _busy ? null : () => _go(_Panel.menu),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _holdButton()),
          ],
        ),
      ],
    );
  }

  /// 1.5초 동안 꾹 눌러야 탈퇴가 진행됩니다. 손을 떼면 되돌아갑니다.
  Widget _holdButton() {
    void release() {
      if (_hold.status != AnimationStatus.completed && !_busy) _hold.reverse();
    }

    return Semantics(
      button: true,
      label: context.l10n.deleteAccount,
      child: GestureDetector(
        onTapDown: (_) {
          if (!_busy) _hold.forward();
        },
        onTapUp: (_) => release(),
        onTapCancel: release,
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) {
            final label = _busy
                ? context.l10n.checkingDeletion
                : _hold.value == 0
                ? GameLocale.select(
                    ko: '꾹 눌러 탈퇴',
                    en: 'Hold to delete',
                    zhHans: '长按注销',
                    zhHant: '長按註銷',
                  )
                : GameLocale.select(
                    ko: '계속 누르고 있어요…',
                    en: 'Keep holding…',
                    zhHans: '继续按住…',
                    zhHant: '繼續按住…',
                  );
            return Container(
              height: 48,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: _danger,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _ink, width: 2.5),
                boxShadow: const [BoxShadow(color: _ink, offset: Offset(0, 4))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: _hold.value,
                    heightFactor: 1,
                    child: const ColoredBox(color: Color(0xFF7E1020)),
                  ),
                  Center(
                    child: Text(
                      label,
                      maxLines: 1,
                      style: MosiFonts.sans(
                        size: 14,
                        weight: FontWeight.w900,
                        color: MosiColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _byePanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        _Waving(child: _avatar(76)),
        const SizedBox(height: 12),
        Text(
          GameLocale.select(
            ko: '탈퇴했어요',
            en: 'Account deleted',
            zhHans: '已注销',
            zhHant: '已註銷',
          ),
          style: _titleStyle.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          GameLocale.select(
            ko: '그동안 함께해 줘서 고마워요.\n언제든 다시 놀러 오세요!',
            en: 'Thanks for playing with us.\nCome back anytime!',
            zhHans: '感谢一路相伴。\n欢迎随时回来！',
            zhHant: '感謝一路相伴。\n歡迎隨時回來！',
          ),
          textAlign: TextAlign.center,
          style: MosiFonts.sans(
            size: 12.5,
            color: MosiColors.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _errorText() {
    final error = _error;
    if (error == null || error.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: MosiNotice(message: error),
    );
  }

  TextStyle get _titleStyle => const TextStyle(
    fontFamily: 'packages/${MosiFonts.package}/${MosiFonts.logo}',
    fontSize: 22,
    color: _navy,
    height: 1.2,
  );
}

// =============================================================================
// 작은 부품들
// =============================================================================

/// 흰 말풍선: 검은 테두리와 아래 그림자, 오른쪽 위 꼬리. 내용은 밖으로 나가지 않게 자릅니다.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: MosiColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _ink, width: 3),
            boxShadow: const [BoxShadow(color: _ink, offset: Offset(0, 7))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: child,
          ),
        ),
        Positioned(
          top: -9,
          right: 18,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: MosiColors.white,
                border: Border(
                  left: BorderSide(color: _ink, width: 3),
                  top: BorderSide(color: _ink, width: 3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShadowBox extends StatelessWidget {
  const _ShadowBox({required this.child, this.radius = 14});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _ink, width: 3),
      boxShadow: const [BoxShadow(color: _ink, offset: Offset(0, 5))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius - 3),
      child: child,
    ),
  );
}

class _PencilButton extends StatelessWidget {
  const _PencilButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: _sun,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _ink, width: 2),
        ),
        child: const Icon(Icons.edit_rounded, size: 14, color: _ink),
      ),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
    this.danger = false,
    this.last = false,
    this.showChevron = true,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  final bool danger;
  final bool last;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: MosiFonts.sans(
        size: 13.5,
        weight: highlight ? FontWeight.w900 : FontWeight.w700,
        color: danger ? _danger : _navy,
      ),
    );
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: danger ? 42 : 46),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: _dashLine, width: 2)),
        ),
        child: Row(
          children: [
            SizedBox(width: 30, height: 30, child: icon),
            const SizedBox(width: 10),
            // 계정 연결하기는 형광펜처럼 노란 밑줄로 강조합니다.
            if (highlight)
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      _sun,
                      _sun,
                    ],
                    stops: [0, .55, .55, 1],
                  ),
                ),
                child: text,
              )
            else
              text,
            const Spacer(),
            if (showChevron)
              const Icon(Icons.chevron_right_rounded, size: 20, color: _muted),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.leading,
    this.loading = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Opacity(
        opacity: onTap == null && !loading ? .55 : 1,
        child: MosiButton(
          label: label,
          expand: true,
          height: 48,
          radius: 14,
          fontSize: 14.5,
          shadowOffset: 4,
          background: background,
          foreground: foreground,
          shadowColor: _ink,
          leading: leading,
          loading: loading,
          onPressed: onTap,
        ),
      ),
    );
  }
}

class _TwoButtons extends StatelessWidget {
  const _TwoButtons({
    required this.leftLabel,
    required this.onLeft,
    required this.rightLabel,
    required this.rightColor,
    required this.rightText,
    required this.onRight,
  });

  final String leftLabel;
  final VoidCallback? onLeft;
  final String rightLabel;
  final Color rightColor;
  final Color rightText;
  final VoidCallback? onRight;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _BigButton(
          label: leftLabel,
          background: MosiColors.white,
          foreground: _navy,
          onTap: onLeft,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _BigButton(
          label: rightLabel,
          background: rightColor,
          foreground: rightText,
          onTap: onRight,
        ),
      ),
    ],
  );
}

/// 로그아웃 경고 1안: 점선 카드 + 노란 ! + 보라 "먼저 계정 연결하기".
class _GuestWarning extends StatelessWidget {
  const _GuestWarning({required this.onLink});

  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: MosiDashedBorder(
        color: _ink,
        radius: 14,
        strokeWidth: 2.5,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _sun,
                  shape: BoxShape.circle,
                  border: Border.all(color: _ink, width: 2.5),
                ),
                child: Text(
                  '!',
                  style: MosiFonts.grotesk(size: 15, color: _ink),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      GameLocale.select(
                        ko: '게스트 정보는 이 폰에만 있어요',
                        en: 'Guest info lives only on this phone',
                        zhHans: '访客信息只保存在这台手机上',
                        zhHant: '訪客資訊只保存在這支手機上',
                      ),
                      style: MosiFonts.sans(
                        size: 13,
                        weight: FontWeight.w900,
                        color: _navy,
                      ),
                    ),
                    Text(
                      GameLocale.select(
                        ko: '로그아웃하면 다시 찾을 수 없어요',
                        en: "You can't get it back after logging out",
                        zhHans: '退出登录后将无法找回',
                        zhHant: '登出後將無法找回',
                      ),
                      style: MosiFonts.sans(
                        size: 11.5,
                        color: MosiColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onLink,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _violet,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _ink, width: 2),
                        ),
                        child: Text(
                          GameLocale.select(
                            ko: '먼저 계정 연결하기',
                            en: 'Link an account first',
                            zhHans: '先关联账号',
                            zhHant: '先連結帳號',
                          ),
                          style: MosiFonts.sans(
                            size: 12,
                            weight: FontWeight.w900,
                            color: MosiColors.white,
                          ),
                        ),
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
}

/// 열린 문. [shut]이 true가 되면 통통 튀며 닫힙니다.
class _DoorArt extends StatelessWidget {
  const _DoorArt({required this.shut});

  final bool shut;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 76,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: _navy,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                  bottom: Radius.circular(2),
                ),
                border: Border.all(color: _ink, width: 3),
              ),
            ),
          ),
          Positioned.fill(
            left: 3,
            top: 3,
            right: 3,
            bottom: 3,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: shut ? 0.0 : -.95),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, angle, child) => Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .004)
                  ..rotateY(angle),
                child: child,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF7D66FF),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                    bottom: Radius.circular(1),
                  ),
                  border: Border.all(color: _ink, width: 2.5),
                ),
                alignment: const Alignment(.65, .08),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _sun,
                    shape: BoxShape.circle,
                    border: Border.all(color: _ink, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 화면에 들어올 때 한 번 흔들리는 휴지통 타일입니다.
class _WobbleTrash extends StatelessWidget {
  const _WobbleTrash();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      builder: (context, t, child) => Transform.rotate(
        angle: math.sin(t * math.pi * 4) * (1 - t) * .22,
        child: child,
      ),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: MosiColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _ink, width: 3),
          boxShadow: const [BoxShadow(color: _ink, offset: Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(14),
        child: const _TrashIcon(),
      ),
    );
  }
}

/// 연결 완료: 초록 체크가 튀어나오고 색종이가 퍼집니다.
class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  static const _colors = [
    _sun,
    MosiColors.lime,
    Color(0xFF7D66FF),
    MosiColors.coral,
    Color(0xFF7FD4FF),
    _sun,
    MosiColors.lime,
    MosiColors.coral,
  ];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1100),
      builder: (context, t, _) {
        final pop = Curves.elasticOut.transform((t / .5).clamp(0.0, 1.0));
        final burst = Curves.easeOutCubic.transform(
          ((t - .2) / .8).clamp(0.0, 1.0),
        );
        return SizedBox(
          width: 160,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < _colors.length; i++)
                Transform.translate(
                  offset: Offset(
                    math.cos(i / _colors.length * math.pi * 2) * 70 * burst,
                    math.sin(i / _colors.length * math.pi * 2) * 48 * burst,
                  ),
                  child: Transform.rotate(
                    angle: i * 1.4 * burst,
                    child: Opacity(
                      opacity: t < .2 ? 0 : 1 - burst,
                      child: Container(
                        width: 8,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _colors[i],
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: _ink, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.scale(
                scale: .2 + .8 * pop,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: MosiColors.lime,
                    shape: BoxShape.circle,
                    border: Border.all(color: _ink, width: 3),
                    boxShadow: const [
                      BoxShadow(color: _ink, offset: Offset(0, 5)),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded, size: 50, color: _ink),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 탈퇴 완료 화면의 손 흔드는 캐릭터입니다.
class _Waving extends StatelessWidget {
  const _Waving({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0.0, end: 1.0),
    duration: const Duration(milliseconds: 1800),
    builder: (context, t, child) =>
        Transform.rotate(angle: math.sin(t * math.pi * 4) * .2, child: child),
    child: child,
  );
}

class _GoogleDot extends StatelessWidget {
  const _GoogleDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: SweepGradient(
        colors: [
          Color(0xFFEA4335),
          Color(0xFFEA4335),
          Color(0xFFFBBC05),
          Color(0xFFFBBC05),
          Color(0xFF34A853),
          Color(0xFF34A853),
          Color(0xFF4285F4),
          Color(0xFF4285F4),
        ],
        stops: [0, .25, .25, .5, .5, .75, .75, 1],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// 스티커 듀오톤 아이콘(시안의 SVG를 그대로 옮김, 28×28 기준)
// ---------------------------------------------------------------------------

abstract class _StickerPainter extends CustomPainter {
  const _StickerPainter();

  Paint stroke([Color color = _ink]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint fill(Color color) => Paint()..color = color;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LinkIcon extends StatelessWidget {
  const _LinkIcon();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _LinkPainter(), size: Size.square(28));
}

class _LinkPainter extends _StickerPainter {
  const _LinkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 28);
    final left = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3, 10, 12, 8),
      const Radius.circular(4),
    );
    final right = RRect.fromRectAndRadius(
      const Rect.fromLTWH(13, 10, 12, 8),
      const Radius.circular(4),
    );
    canvas
      ..drawRRect(left, fill(_sun))
      ..drawRRect(left, stroke())
      ..drawRRect(right, fill(MosiColors.lime))
      ..drawRRect(right, stroke())
      ..drawLine(const Offset(11, 14), const Offset(17, 14), stroke());
  }
}

class _DoorIcon extends StatelessWidget {
  const _DoorIcon();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _DoorPainter(), size: Size.square(28));
}

class _DoorPainter extends _StickerPainter {
  const _DoorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 28);
    const door = Rect.fromLTWH(5, 4, 10, 20);
    canvas
      ..drawRect(door, fill(const Color(0xFF7D66FF)))
      ..drawRect(door, stroke())
      ..drawCircle(const Offset(12, 14), 1.2, fill(_ink));
    final arrow = Path()
      ..moveTo(19, 10)
      ..lineTo(23, 14)
      ..lineTo(19, 18)
      ..moveTo(23, 14)
      ..lineTo(15, 14);
    canvas.drawPath(arrow, stroke());
  }
}

class _TrashIcon extends StatelessWidget {
  const _TrashIcon();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _TrashPainter(), size: Size.square(28));
}

class _TrashPainter extends _StickerPainter {
  const _TrashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 28);
    final body = Path()
      ..moveTo(7, 9)
      ..lineTo(8.5, 24)
      ..lineTo(19.5, 24)
      ..lineTo(21, 9)
      ..close();
    final lid = Path()
      ..moveTo(5, 9)
      ..lineTo(23, 9)
      ..moveTo(11, 9)
      ..lineTo(11, 5)
      ..lineTo(17, 5)
      ..lineTo(17, 9);
    canvas
      ..drawPath(body, fill(MosiColors.white))
      ..drawPath(body, stroke(_danger))
      ..drawPath(lid, stroke(_danger));
  }
}
