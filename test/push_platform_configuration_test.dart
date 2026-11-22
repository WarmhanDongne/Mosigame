import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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
