import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:project00/platform/announcements/models/platform_announcement.dart';

class PlatformAnnouncementService {
  PlatformAnnouncementService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseBackend.firestore;

  final FirebaseFirestore _firestore;

  Stream<List<PlatformAnnouncement>> watchActive() {
    return _firestore.collection('platformAnnouncements').snapshots().map((
      snapshots,
    ) {
      final values = snapshots.docs
          .map(PlatformAnnouncement.fromSnapshot)
          .where((announcement) => announcement.active)
          .toList();
      values.sort((left, right) => left.kind.index.compareTo(right.kind.index));
      return values;
    });
  }
}
