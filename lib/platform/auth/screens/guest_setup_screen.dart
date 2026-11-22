import 'package:game_kit/firebase/firebase_backend.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:project00/platform/auth/legal/signup_terms.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/widgets/auth_design.dart';
import 'package:project00/platform/auth/widgets/signup_terms_view.dart';

/// Anonymous authentication alone does not grant room access. The server saves
/// consent and creates a guest profile before AuthGate opens the lobby.
class GuestSetupScreen extends StatefulWidget {
  const GuestSetupScreen({super.key, required this.service});

  final OnboardingService service;

  @override
  State<GuestSetupScreen> createState() => _GuestSetupScreenState();
}

class _GuestSetupScreenState extends State<GuestSetupScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _start(SignupConsents consents) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.completeGuest(consents);
      // AuthGate switches to Home after observing the server's complete state.
    } on AuthServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await FirebaseBackend.auth.signOut();
    } on FirebaseAuthException catch (_) {
      if (mounted) {
        setState(
          () => _error = GameLocale.select(
            ko: '로그아웃하지 못했습니다. 다시 시도해주세요.',
            en: 'Could not log out. Try again.',
            zhHans: '无法退出登录，请重试。',
            zhHant: '無法登出，請重試。',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_leave());
    },
    child: MosiAuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MosiAuthHeader(
            title: GameLocale.select(
              ko: '게스트로 시작하기',
              en: 'Continue as guest',
              zhHans: '以访客身份开始',
              zhHant: '以訪客身分開始',
            ),
            onBack: _busy ? null : () => unawaited(_leave()),
          ),
          const SizedBox(height: 16),
          MosiNotice(
            message: GameLocale.select(
              ko: '자동 닉네임으로 시작하고, 나중에 프로필에서 이메일·Google·Apple 계정을 연결할 수 있어요. 연결 전에는 로그아웃하거나 앱 데이터를 지우면 복구할 수 없어요.',
              en: 'Start with an automatic nickname, then link email, Google, or Apple from your profile. Before linking, the guest account cannot be recovered after logout or clearing app data.',
              zhHans:
                  '使用自动昵称开始，之后可在个人资料中关联邮箱、Google 或 Apple。关联前退出登录或清除数据将无法恢复。',
              zhHant:
                  '使用自動暱稱開始，之後可在個人資料中連結電子郵件、Google 或 Apple。連結前登出或清除資料將無法恢復。',
            ),
            tone: MosiNoticeTone.info,
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            MosiNotice(message: _error!),
            const SizedBox(height: 12),
          ],
          SignupTermsView(busy: _busy, onAgreed: _start),
        ],
      ),
    ),
  );
}
