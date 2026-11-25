// [game_controller.dart] 는 ELEVEN 서버 상태 구독과 게임 명령을 조율하는 파일이다.
//
// - [Package] : ELEVEN
// - [Controller] : 공용 뼈대(GameSessionController)를 상속한 세션 컨트롤러
//
// 휴대폰은 공개 + 본인 개인 상태, 태블릿은 공개 + controller 기록을 구독한다.
// 승패·점수·다음 단계는 서버가 정하고 이 파일은 읽은 값을 그대로 옮긴다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/providers/game_session_controller.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';
import 'package:game_kit/services/game_query_service.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/services/game_service.dart';
import 'package:game_eleven/shared/services/history_mapper.dart';
import 'package:game_eleven/shared/services/private_state_mapper.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';

// ============================================================

class ElevenController extends GameSessionController<ElevenGameState> {
  ElevenController({
    required this.roomCode,
    required this.uid,
    required this.service,
    required this.isController,
  });

  @override
  final String roomCode;
  @override
  final String uid;
  final ElevenService service;

  /// 태블릿(진행 기기)이면 true입니다. 개인 상태 대신 controller 기록을 구독합니다.
  final bool isController;

  StreamSubscription<DatabaseEvent>? _historySubscription;

  @override
  GameQueryService get query => service.query;

  @override
  GameInterruptionCommandService get interruptionCommands =>
      service.interruption;

  @override
  String get commandCrashReason => '일레븐 서버 명령';

  @override
  GameInterruption? get interruption => state.interruption;

  @override
  ElevenGameState build() {
    Timer.run(() {
      if (ref.mounted) unawaited(_warmUp());
    });
    startSession(watchPrivate: !isController);
    if (isController) {
      _historySubscription = service.query
          .watchControllerHistory(roomCode)
          .listen(_handleHistory, onError: handleSubscriptionError);
      ref.onDispose(() => unawaited(_historySubscription?.cancel()));
    }
    return ElevenGameState.initial();
  }

  Future<void> _warmUp() async {
    try {
      await (isController
          ? service.command.warmUpControllerCommands()
          : service.command.warmUpPlayerCommands());
    } catch (_) {
      // 예열 실패는 실제 명령이 다시 호출하므로 화면에 알리지 않습니다.
    }
  }

  // ---------------------------------------------------------------------------
  // 서버 스냅샷 해석
  // ---------------------------------------------------------------------------
  @override
  void applyPublicValue(Object? value) {
    if (value is! Map) return;
    state = state.copyWith(
      loading: false,
      public: ElevenPublicSnapshot.fromValue(value),
    );
  }

  @override
  void handlePrivateEvent(DatabaseEvent event) {
    if (isController) return;
    state = state.copyWith(
      private: ElevenPrivateSnapshot.fromValue(event.snapshot.value),
    );
  }

  void _handleHistory(DatabaseEvent event) {
    if (!ref.mounted) return;
    state = state.copyWith(history: parseElevenHistory(event.snapshot.value));
  }

  // ---------------------------------------------------------------------------
  // 게임 명령
  // ---------------------------------------------------------------------------
  /// 휴대폰 본인 제출입니다. 서버가 거절하면 false를 돌려주고 완료 표시를 하지 않습니다.
  ///
  /// 노션 결정(계약 9절): 요청 중·실패 UI를 두지 않는다. 그래서 [run]의 오류
  /// 문구 경로를 쓰지 않고, 중복 탭은 화면의 제출 중 플래그가 막습니다.
  Future<bool> submitTile({required int round, required int value}) =>
      _progress(
        () => service.command.submitTile(
          roomCode: roomCode,
          round: round,
          value: value,
        ),
      );

  /// 태블릿 공용 뽑기입니다. 차례는 서버의 `nextPickerUid`를 그대로 보냅니다.
  Future<bool> pickDrawTile(int slotIndex) {
    final picker = state.public.draw?.nextPickerUid;
    if (picker == null) return Future.value(false);
    return run(
      () => service.command.pickDrawTile(
        roomCode: roomCode,
        pickerUid: picker,
        slotIndex: slotIndex,
      ),
    );
  }

  /// 마감이 지난 뒤 호출합니다. 이미 바뀐 차례는 서버가 `ignored`로 무시합니다.
  ///
  /// 사용자 행동이 아닌 진행 알림이라 [run]의 오류 표시를 쓰지 않습니다.
  /// 서버가 마감 전이라고 답하면(`success:false`) false를 돌려 재시도하게 합니다.
  Future<bool> sendTimeout({required int round, required String phase}) =>
      _progress(
        () => service.command.timeoutTurn(
          roomCode: roomCode,
          round: round,
          phase: phase,
        ),
      );

  /// 연출이 끝난 단계를 서버에 알립니다. revision이 다르면 서버가 무시합니다.
  Future<bool> sendCompletePhase(int revision) => _progress(
    () => service.command.completePhase(roomCode: roomCode, revision: revision),
  );

  Future<bool> _progress(Future<Map<String, dynamic>> Function() send) async {
    try {
      final result = await send();
      return result['success'] != false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> endGame() =>
      run(() => service.command.endGame(roomCode: roomCode));

  Future<bool> restartGame() =>
      run(() => service.command.startGame(roomCode: roomCode, restart: true));
}
