import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:project00/platform/localization/locale_settings.dart';

/// Registers only a signed-in, fully onboarded phone for game event pushes.
class PushNotificationHost extends StatefulWidget {
  const PushNotificationHost({
    super.key,
    required this.uid,
    required this.child,
  });

  final String uid;
  final Widget child;

  @override
  State<PushNotificationHost> createState() => _PushNotificationHostState();
}

class _PushNotificationHostState extends State<PushNotificationHost> {
  StreamSubscription<String>? _tokenSubscription;
  String _locale = 'korean';
  String? _token;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextLocale =
        LocaleSettingsScope.maybeOf(context)?.language.name ?? 'korean';
    if (_locale == nextLocale) return;
    _locale = nextLocale;
    final token = _token;
    if (token != null) unawaited(_register(token));
  }

  @override
  void didUpdateWidget(covariant PushNotificationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final token = _token;
    if (oldWidget.uid != widget.uid && token != null) {
      unawaited(_register(token));
    }
  }

  Future<void> _start() async {
    if (kIsWeb ||
        FirebaseBackend.isLocal ||
        Firebase.apps.isEmpty ||
        Firebase.app().options.projectId !=
            FirebaseBackend.app.options.projectId ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      _tokenSubscription = messaging.onTokenRefresh.listen((token) {
        unawaited(_register(token));
      });
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        var apnsToken = await messaging.getAPNSToken();
        for (
          var attempt = 0;
          attempt < 5 && apnsToken == null && mounted;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(seconds: 2));
          apnsToken = await messaging.getAPNSToken();
        }
        if (apnsToken == null) return;
      }
      final token = await messaging.getToken();
      if (token != null) await _register(token);
    } catch (error) {
      debugPrint('게임 알림 등록 실패: ${error.runtimeType}');
    }
  }

  Future<void> _register(String token) async {
    if (!mounted || FirebaseBackend.auth.currentUser?.uid != widget.uid) return;
    try {
      await FirebaseBackend.functions.httpsCallable('registerPushDevice').call({
        'token': token,
        'locale': _locale,
      });
      final previousToken = _token;
      _token = token;
      PushDeviceRegistration.registeredToken = token;
      PushDeviceRegistration.signedOutTokenCleared = false;
      if (previousToken != null && previousToken != token) {
        try {
          await FirebaseBackend.functions
              .httpsCallable('unregisterPushDevice')
              .call({'token': previousToken});
        } catch (error) {
          debugPrint('이전 게임 알림 토큰 해제 실패: ${error.runtimeType}');
        }
      }
    } catch (error) {
      debugPrint('게임 알림 등록 실패: ${error.runtimeType}');
    }
  }

  @override
  void dispose() {
    unawaited(_tokenSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

abstract final class PushDeviceRegistration {
  static String? registeredToken;
  static bool signedOutTokenCleared = false;

  static Future<void> clearSignedOutToken() async {
    if (signedOutTokenCleared ||
        kIsWeb ||
        FirebaseBackend.isLocal ||
        Firebase.apps.isEmpty ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS) ||
        FirebaseBackend.auth.currentUser != null ||
        Firebase.app().options.projectId !=
            FirebaseBackend.app.options.projectId) {
      return;
    }
    signedOutTokenCleared = true;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('로그아웃 기기 알림 정리 실패: ${error.runtimeType}');
    }
  }

  /// Best effort: a failed push cleanup must never prevent account sign-out.
  static Future<void> unregisterBeforeSignOut() async {
    final token = registeredToken;
    registeredToken = null;
    if (token == null) return;
    try {
      await FirebaseBackend.functions
          .httpsCallable('unregisterPushDevice')
          .call({'token': token});
    } catch (error) {
      debugPrint('게임 알림 해제 실패: ${error.runtimeType}');
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('게임 알림 토큰 삭제 실패: ${error.runtimeType}');
    }
  }
}
