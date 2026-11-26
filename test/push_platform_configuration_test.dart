import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('jinsung 기본 backend는 Dart·Android·iOS 모두 TEST를 사용한다', () {
    final backend = File(
      'packages/game_kit/lib/firebase/firebase_backend.dart',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final iosSelector = File(
      'tool/select_ios_firebase_config.sh',
    ).readAsStringSync();

    expect(backend, contains("defaultValue: 'test'"));
    expect(gradle, contains('?: "test"'));
    expect(iosSelector, contains('backend="test"'));
  });

  test('iOS 푸시는 APNs entitlement와 background modes를 함께 유지한다', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final xcodeProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    final backgroundModes = _plistArray(infoPlist, 'UIBackgroundModes');
    expect(backgroundModes, contains('<string>fetch</string>'));
    expect(backgroundModes, contains('<string>remote-notification</string>'));
    expect(entitlements, contains('<key>aps-environment</key>'));
    expect(entitlements, contains('<string>\$(PUSH_APS_ENVIRONMENT)</string>'));
    expect(xcodeProject, contains('PUSH_APS_ENVIRONMENT = development;'));
    expect(xcodeProject, contains('PUSH_APS_ENVIRONMENT = production;'));
    expect(
      appDelegate,
      contains(
        'FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()',
      ),
    );
  });

  test('iOS 산출물은 Dart backend와 같은 Firebase plist를 선택한다', () {
    final selector = File(
      'tool/select_ios_firebase_config.sh',
    ).readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final testPlist = File(
      'ios/Firebase/GoogleService-Info-test.plist',
    ).readAsStringSync();
    final serverPlist = File(
      'ios/Firebase/GoogleService-Info-server.plist',
    ).readAsStringSync();

    expect(selector, contains('MOSIGAME_BACKEND='));
    expect(selector, contains(r'GoogleService-Info-${config_name}.plist'));
    expect(project, contains('Select Firebase Configuration'));
    expect(project, contains('select_ios_firebase_config.sh'));
    expect(testPlist, contains('<string>ban-pick-simulator</string>'));
    expect(serverPlist, contains('<string>project0000-ec01e</string>'));
    expect(testPlist, contains('1:127477049099:ios:'));
    expect(serverPlist, contains('1:93097008048:ios:'));
  });

  test('Android background FCM resources follow the Dart backend', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final testConfig =
        jsonDecode(
              File(
                'android/app/firebase/test/google-services.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final serverConfig =
        jsonDecode(
              File(
                'android/app/firebase/server/google-services.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final testProject = testConfig['project_info'] as Map<String, dynamic>;
    final serverProject = serverConfig['project_info'] as Map<String, dynamic>;

    expect(gradle, contains('project.findProperty("dart-defines")'));
    expect(gradle, contains('MOSIGAME_BACKEND='));
    expect(gradle, contains('firebase/test/google-services.json'));
    expect(gradle, contains('firebase/server/google-services.json'));
    expect(gradle, contains('GoogleServicesTask'));
    expect(gradle, contains('googleServicesJsonFiles.set'));
    expect(gradle, contains('id("com.google.gms.google-services")'));
    expect(testProject['project_id'], 'ban-pick-simulator');
    expect(serverProject['project_id'], 'project0000-ec01e');
  });

  test('푸시 클라이언트는 선택된 Firebase와 기본 Messaging 앱 일치를 확인한다', () {
    final host = File(
      'lib/platform/notifications/push_notification_host.dart',
    ).readAsStringSync();
    final backend = File(
      'packages/game_kit/lib/firebase/firebase_backend.dart',
    ).readAsStringSync();

    expect(host, contains('FirebaseBackend.defaultAppMatchesSelectedBackend'));
    expect(backend, contains('defaultAppMatchesSelectedBackend'));
    expect(
      backend,
      contains("Firebase.app().options.projectId == app.options.projectId"),
    );
  });

  test('iOS 푸시는 앱이 열린 중에도 배너와 소리를 표시한다', () {
    final host = File(
      'lib/platform/notifications/push_notification_host.dart',
    ).readAsStringSync();

    expect(host, contains('setForegroundNotificationPresentationOptions('));
    expect(host, contains('alert: true'));
    expect(host, contains('sound: true'));
    expect(host, contains('badge: false'));
  });
}

String _plistArray(String plist, String key) {
  final keyIndex = plist.indexOf('<key>$key</key>');
  expect(keyIndex, greaterThanOrEqualTo(0), reason: '$key 키가 없습니다.');
  final arrayStart = plist.indexOf('<array>', keyIndex);
  final arrayEnd = plist.indexOf('</array>', arrayStart);
  expect(arrayStart, greaterThan(keyIndex), reason: '$key 배열 시작이 없습니다.');
  expect(arrayEnd, greaterThan(arrayStart), reason: '$key 배열 끝이 없습니다.');
  return plist.substring(arrayStart, arrayEnd);
}
