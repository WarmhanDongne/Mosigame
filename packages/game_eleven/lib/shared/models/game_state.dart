// [game_state.dart] 는 ELEVEN 서버 상태를 한 번에 발행하는 불변 상태 파일이다.
//
// - [Package] : ELEVEN
// - [State] : 공개·본인 개인(휴대폰)·controller 기록(태블릿)을 묶은 화면 상태
//
// 즉, 화면이 서버 상태 세 경로를 같은 시점의 값으로 읽게 하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/models/game_session_state.dart';
import 'package:game_eleven/shared/services/history_mapper.dart';
import 'package:game_eleven/shared/services/private_state_mapper.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';

// ============================================================

const Object _notProvided = Object();

@immutable
class ElevenGameState implements GameSessionState<ElevenGameState> {
  const ElevenGameState({
    required this.loading,
    required this.public,
    required this.private,
    required this.history,
    required this.commandInFlight,
    this.errorMessage,
  });

  factory ElevenGameState.initial() => const ElevenGameState(
    loading: true,
    public: ElevenPublicSnapshot.initial,
    private: ElevenPrivateSnapshot.empty,
    history: [],
    commandInFlight: false,
  );

  /// 첫 공개 상태(`game/public`)를 아직 받지 못했는지입니다.
  final bool loading;
  final ElevenPublicSnapshot public;

  /// 휴대폰 본인 상태입니다. 태블릿에서는 항상 비어 있습니다.
  final ElevenPrivateSnapshot private;

  /// 태블릿 전용 지난 라운드 기록입니다. 휴대폰에서는 항상 비어 있습니다.
  final List<ElevenHistoryEntry> history;

  @override
  final bool commandInFlight;

  @override
  final String? errorMessage;

  GameInterruption? get interruption => public.interruption;
  bool get isFinished => public.isFinished;
  ElevenHistoryEntry? get lastHistory => history.isEmpty ? null : history.last;

  /// 휴대폰 P08 판정 표시용 이번 라운드 결과입니다. `public.lastRoundResult`가
  /// 현재 라운드의 것일 때만 돌려줍니다(지난 라운드 값을 새 라운드에 쓰지 않음).
  /// 승자 또는 동점만 있고 숫자·합·판정 유형은 없습니다.
  ElevenRoundResult? get currentRoundResult {
    final result = public.lastRoundResult;
    return result != null && result.round == public.round ? result : null;
  }

  /// [uid] 기준 이번 라운드 승·패·동점입니다. 결과가 아직 없으면 null입니다.
  ElevenRoundOutcome? roundOutcomeFor(String uid) =>
      currentRoundResult?.outcomeFor(uid);

  ElevenGameState copyWith({
    bool? loading,
    ElevenPublicSnapshot? public,
    ElevenPrivateSnapshot? private,
    List<ElevenHistoryEntry>? history,
    bool? commandInFlight,
    Object? errorMessage = _notProvided,
  }) {
    return ElevenGameState(
      loading: loading ?? this.loading,
      public: public ?? this.public,
      private: private ?? this.private,
      history: history ?? this.history,
      commandInFlight: commandInFlight ?? this.commandInFlight,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  // ---------------------------------------------------------------------------
  // 공용 뼈대가 쓰는 계약
  // ---------------------------------------------------------------------------
  @override
  ElevenGameState markCommandStarted() =>
      copyWith(commandInFlight: true, errorMessage: null);

  @override
  ElevenGameState markCommandFinished() => copyWith(commandInFlight: false);

  @override
  ElevenGameState withError(String? message) => copyWith(errorMessage: message);

  @override
  ElevenGameState asRemovedGame() => ElevenGameState(
    loading: false,
    public: ElevenPublicSnapshot(
      status: 'finished',
      phase: 'finished',
      round: public.round,
      revision: public.revision,
      players: public.players,
      scores: public.scores,
    ),
    private: private,
    history: history,
    commandInFlight: commandInFlight,
    errorMessage: errorMessage,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElevenGameState &&
          loading == other.loading &&
          public == other.public &&
          private == other.private &&
          listEquals(history, other.history) &&
          commandInFlight == other.commandInFlight &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
    loading,
    public,
    private,
    Object.hashAll(history),
    commandInFlight,
    errorMessage,
  );
}
