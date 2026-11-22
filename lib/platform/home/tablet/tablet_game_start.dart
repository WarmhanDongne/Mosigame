import 'dart:convert';

import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';

// Local identity only: never issues a DB/callable request to enable prefetch.
String? tabletStartIdentityKey(String roomCode) {
  final uid = FirebaseBackend.auth.currentUser?.uid;
  if (uid == null) return null;
  final identity = RoomSessionIdentityStore.instance.current(
    uid,
    'controller',
    roomCode,
  );
  return identity == null ? null : jsonEncode(identity.toJson());
}

/// An uncertain start must be reconciled before writing seats again.
Future<bool> hasPendingTabletGameStart(String roomCode) async {
  final uid = FirebaseBackend.auth.currentUser?.uid;
  if (uid == null) return false;
  final store = RoomSessionIdentityStore.instance;
  await store.load();
  if (FirebaseBackend.auth.currentUser?.uid != uid) return false;
  return store.pendingGameStart(uid, 'controller', roomCode) != null;
}

Future<bool> prepareTabletGameStart({
  required String roomCode,
  required Future<bool> Function() saveSeats,
  required Future<void> Function() startGame,
  required bool Function() isCurrent,
  Future<bool> Function()? beforeStart,
}) async {
  final pending = await hasPendingTabletGameStart(roomCode);
  if (!isCurrent()) return false;
  if (!pending && !await saveSeats()) return false;
  if (!isCurrent()) return false;
  // 좌석을 저장한 뒤, 시작 명령 전에 튜토리얼처럼 모두가 함께 볼 화면을 띄웁니다.
  // 이미 보낸 시작 명령을 확인하는 중(pending)이면 다시 띄우지 않습니다.
  if (!pending && beforeStart != null) {
    if (!await beforeStart()) return false;
    if (!isCurrent()) return false;
  }
  await startGame();
  return isCurrent();
}
