import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/announcements/models/platform_announcement.dart';

void main() {
  final announcement = PlatformAnnouncement.fromData({
    'kind': 'notice',
    'active': true,
    'localized': {
      'ko': {'title': '새 게임', 'body': '상점에서 확인하세요.'},
      'en': {'title': 'New game', 'body': 'See it in the store.'},
      'zh-Hans': {'title': '新游戏', 'body': '请在商店查看。'},
      'zh-Hant': {'title': '新遊戲', 'body': '請在商店查看。'},
    },
  });

  test('announcement reads active localized notice copy', () {
    expect(announcement.kind, PlatformAnnouncementKind.notice);
    expect(announcement.active, isTrue);
    expect(announcement.copyFor(const Locale('ko')).title, '새 게임');
    expect(
      announcement.copyFor(const Locale('en')).body,
      'See it in the store.',
    );
  });

  test('announcement selects traditional Chinese for a traditional region', () {
    expect(
      announcement
          .copyFor(
            const Locale.fromSubtags(languageCode: 'zh', countryCode: 'TW'),
          )
          .title,
      '新遊戲',
    );
    expect(
      announcement
          .copyFor(
            const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
          )
          .title,
      '新游戏',
    );
  });
}
