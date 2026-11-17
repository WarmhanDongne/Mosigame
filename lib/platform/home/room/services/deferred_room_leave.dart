// [deferred_room_leave.dart] 는 오프라인에서 나간 방의 서버 퇴장을 연결 뒤에 마무리하는 파일이다.
//
// - [Platform] : 로비(휴대폰 대기실)
// - [Service] : 저장된 퇴장 의도를 연결이 돌아오면 서버에 보내고 결과를 확정함
//
// 즉, 인터넷이 끊긴 동안에도 사용자가 방에서 바로 나갈 수 있게 하기 위해 필요한 파일이다.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:project00/platform/home/room/services/player_room_session_store.dart';
import 'package:project00/platform/home/room/services/room_leave_intent.dart';
import 'package:project00/platform/home/room/services/room_service.dart';

/// 화면과 [RoomProvider]가 사라진 뒤에도 미확정 퇴장을 이어서 보냅니다.
///
/// 휴대폰의 입장용 provider는 홈으로 돌아가면 폐기됩니다. 퇴장 요청의 소유를
/// 화면에 두면 연결이 돌아왔을 때 보낼 주체가 없으므로 프로세스 단위로 둡니다.
///
/// 첫 시도는 즉시 실행합니다. 오프라인이라 실패해도 퇴장 작업이 기기에 먼저
/// 저장되므로, 이번 실행에서 연결이 끝내 돌아오지 않으면 다음 앱 실행의 이전
/// 세션 확인이 같은 퇴장을 마무리합니다. 그동안 방 세션 저장값은 지우지 않습니다.
abstract final class DeferredRoomLeave {
  static final Map<String, _PendingLeave> _pending = {};

  /// 한 방에 대해 연결될 때마다 다시 시도하는 최대 횟수입니다.
  static const int maxAttempts = 6;

  static bool isPending(String roomCode) =>
      _pending.containsKey(roomCode.trim().toUpperCase());

  static void start(RoomService service, String roomCode) {
    final code = roomCode.trim().toUpperCase();
    if (_pending.containsKey(code)) return;
    final pending = _PendingLeave(service, code);
    _pending[code] = pending;
    pending.begin();
  }

  @visibleForTesting
  static void resetForTesting() {
    for (final pending in _pending.values.toList()) {
      pending.cancel();
    }
    _pending.clear();
  }
}

class _PendingLeave {
  _PendingLeave(this.service, this.code);

  final RoomService service;
  final String code;
  StreamSubscription<bool>? _connection;
  bool _inFlight = false;
  bool _finished = false;
  int _attempts = 0;

  void begin() {
    unawaited(_attempt());
    _connection = service.watchServerConnection().listen((connected) {
      if (connected) unawaited(_attempt());
    }, onError: (Object _) {});
  }

  Future<void> _attempt() async {
    if (_inFlight || _finished) return;
    _inFlight = true;
    _attempts += 1;
    try {
      await service.leaveRoom(code);
      if (_finished) return;
      RoomLeaveIntent.complete(code);
      await PlayerRoomSessionStore.instance.clear(onlyRoomCode: code);
      _finish();
    } catch (_) {
      // 결과 미확정입니다. 퇴장 의도를 보존하고 다음 연결에서 다시 확인합니다.
      RoomLeaveIntent.fail(code);
      if (_attempts >= DeferredRoomLeave.maxAttempts) _finish();
    } finally {
      _inFlight = false;
    }
  }

  void _finish() {
    cancel();
    DeferredRoomLeave._pending.remove(code);
  }

  void cancel() {
    _finished = true;
    unawaited(_connection?.cancel());
    _connection = null;
  }
}
