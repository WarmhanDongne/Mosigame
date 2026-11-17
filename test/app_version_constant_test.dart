import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/constants/app_constants.dart';

void main() {
  test('AppConstants.appVersion은 pubspec.yaml의 버전 이름과 같다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9.]+)\+\d+\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml에 version: x.y.z+n 이 필요합니다.');
    expect(AppConstants.appVersion, match!.group(1));
  });
}
