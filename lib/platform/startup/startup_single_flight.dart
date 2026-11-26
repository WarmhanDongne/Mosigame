// [startup_single_flight.dart] 는 앱 시작 재시도가 동시에 실행되지 않게 합니다.

import 'dart:async';

/// 같은 시작 작업을 여러 번 요청해도 진행 중인 실행 하나만 공유합니다.
///
/// 실패 화면의 재시도 버튼을 연속으로 눌러 Firebase 초기화가 겹치는 일을
/// 막습니다. 실행이 끝난 뒤에는 다음 재시도를 새로 시작할 수 있습니다.
class StartupSingleFlight {
  Future<void>? _running;

  bool get isRunning => _running != null;

  Future<void> run(Future<void> Function() action) {
    final running = _running;
    if (running != null) return running;

    final completer = Completer<void>();
    _running = completer.future;
    unawaited(() async {
      try {
        await action();
        completer.complete();
      } catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        _running = null;
      }
    }());
    return completer.future;
  }
}
