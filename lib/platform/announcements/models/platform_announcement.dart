import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

enum PlatformAnnouncementKind { notice, maintenance }

class PlatformAnnouncementCopy {
  const PlatformAnnouncementCopy({required this.title, required this.body});

  final String title;
  final String body;

  factory PlatformAnnouncementCopy.fromMap(Map<String, dynamic>? data) {
    return PlatformAnnouncementCopy(
      title: data?['title'] is String ? data!['title'] as String : '',
      body: data?['body'] is String ? data!['body'] as String : '',
    );
  }
}

/// A public, server-authored lobby message. It contains no private user data.
class PlatformAnnouncement {
  const PlatformAnnouncement({
    required this.kind,
    required this.active,
    required this.localized,
    this.maintenancePeriod,
  });

  final PlatformAnnouncementKind kind;
  final bool active;
  final Map<String, PlatformAnnouncementCopy> localized;
  final String? maintenancePeriod;

  PlatformAnnouncementCopy copyFor(Locale locale) {
    final localeKey = switch ((locale.languageCode, locale.scriptCode)) {
      ('ko', _) => 'ko',
      ('zh', 'Hant') => 'zh-Hant',
      ('zh', _) when const {'TW', 'HK', 'MO'}.contains(locale.countryCode) =>
        'zh-Hant',
      ('zh', _) => 'zh-Hans',
      _ => 'en',
    };
    return localized[localeKey] ??
        localized['en'] ??
        localized['ko'] ??
        const PlatformAnnouncementCopy(title: '', body: '');
  }

  factory PlatformAnnouncement.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data();
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Announcement data is missing.');
    }
    return PlatformAnnouncement.fromData(data);
  }

  factory PlatformAnnouncement.fromData(Map<String, dynamic> data) {
    final kind = data['kind'] == 'maintenance'
        ? PlatformAnnouncementKind.maintenance
        : PlatformAnnouncementKind.notice;
    final rawLocalized = data['localized'];
    final localized = <String, PlatformAnnouncementCopy>{};
    if (rawLocalized is Map) {
      for (final entry in rawLocalized.entries) {
        if (entry.key is String && entry.value is Map) {
          localized[entry.key as String] = PlatformAnnouncementCopy.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    return PlatformAnnouncement(
      kind: kind,
      active: data['active'] == true,
      localized: localized,
      maintenancePeriod: data['maintenancePeriod'] is String
          ? data['maintenancePeriod'] as String
          : null,
    );
  }
}
