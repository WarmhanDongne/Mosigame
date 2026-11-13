/// 스토어 업데이트 안내입니다. 서버에 적힌 최소 빌드 번호보다 낮은 앱은 시작할 때
/// 업데이트 화면을 보고 스토어로 이동합니다.
///
/// Cloud Functions가 구버전 앱과 호환되지 않게 바뀔 때, 깨진 화면 대신 업데이트를
/// 안내하기 위한 장치입니다. 값은 Firestore `appConfig/update` 문서에 둡니다.
///
/// ```text
/// appConfig/update
///   minBuild: { android: 8, ios: 8 }   // 이 번호보다 낮은 빌드는 업데이트 필요
/// ```
///
/// 규칙:
/// - **확인에 실패하면 그대로 통과합니다.** 문서가 없거나, 네트워크가 끊겼거나,
///   값이 잘못돼도 앱을 막지 않습니다. 업데이트 안내는 켜는 조건이 아닙니다.
/// - 켤 때 한 번, 그리고 **앱으로 돌아올 때마다** 다시 확인합니다.
/// - Android·iOS가 아니면 아무 일도 하지 않습니다.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/core/update/shorebird_patch_screen.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 스토어의 모시겜 페이지입니다.
const appUpdateAndroidStoreUrl =
    'https://play.google.com/store/apps/details?id=com.warmhandongne.msg';
const appUpdateIosStoreUrl = 'https://apps.apple.com/app/id6828464086';

/// `appConfig/update` 문서에서 [platform]의 최소 빌드 번호를 읽습니다.
///
/// 값이 없거나 숫자가 아니면 null입니다(업데이트를 요구하지 않음).
int? appUpdateMinimumBuild(Object? data, TargetPlatform platform) {
  final key = switch (platform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => null,
  };
  if (key == null || data is! Map) return null;
  final minimums = data['minBuild'];
  if (minimums is! Map) return null;
  final value = minimums[key];
  return value is int && value > 0 ? value : null;
}

/// 지금 빌드([currentBuild])가 [minimumBuild]보다 낮아 업데이트가 필요한지입니다.
bool isAppUpdateRequired({
  required int? currentBuild,
  required int? minimumBuild,
}) =>
    currentBuild != null && minimumBuild != null && currentBuild < minimumBuild;

Future<int?> _readMinimumBuild() async {
  final snapshot = await FirebaseBackend.firestore
      .collection('appConfig')
      .doc('update')
      .get();
  return appUpdateMinimumBuild(snapshot.data(), defaultTargetPlatform);
}

Future<int?> _readCurrentBuild() async =>
    int.tryParse((await PackageInfo.fromPlatform()).buildNumber);

Future<void> _openStore() async {
  final url = defaultTargetPlatform == TargetPlatform.iOS
      ? appUpdateIosStoreUrl
      : appUpdateAndroidStoreUrl;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({
    super.key,
    required this.child,
    this.readMinimumBuild,
    this.readCurrentBuild,
    this.openStore,
  });

  final Widget child;

  /// 시험에서 갈아 끼우는 값입니다. null이면 실제 서버·기기 값을 씁니다.
  final Future<int?> Function()? readMinimumBuild;
  final Future<int?> Function()? readCurrentBuild;
  final Future<void> Function()? openStore;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  bool _updateRequired = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    if (_busy) return;
    _busy = true;
    try {
      final currentBuild =
          await (widget.readCurrentBuild ?? _readCurrentBuild)();
      final minimumBuild =
          await (widget.readMinimumBuild ?? _readMinimumBuild)();
      final required = isAppUpdateRequired(
        currentBuild: currentBuild,
        minimumBuild: minimumBuild,
      );
      if (mounted && required != _updateRequired) {
        setState(() => _updateRequired = required);
      }
    } catch (error) {
      // 확인하지 못하면 막지 않습니다. 다음에 앱으로 돌아올 때 다시 봅니다.
      debugPrint('[AppUpdate] 최소 버전 확인 실패: $error');
    } finally {
      _busy = false;
    }
  }

  Future<void> _handleUpdate() async {
    try {
      await (widget.openStore ?? _openStore)();
    } catch (error) {
      debugPrint('[AppUpdate] 스토어 열기 실패: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_updateRequired) return widget.child;
    return ShorebirdPatchScreen(
      title: '업데이트가 필요해요',
      message: '최신 버전으로 업데이트한 뒤 이용해 주세요',
      buttonDelay: Duration.zero,
      buttonLabel: '업데이트하기',
      onSkip: () => unawaited(_handleUpdate()),
    );
  }
}
