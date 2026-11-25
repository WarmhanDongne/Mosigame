import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/phone/providers/game_stage.dart';
import 'package:game_eleven/shared/models/game_state.dart';
import 'package:game_eleven/shared/services/private_state_mapper.dart';
import 'package:game_eleven/shared/services/public_state_mapper.dart';

ElevenGameState _game(
  Map<String, Object?> public, {
  Map<String, Object?>? private,
  bool loading = false,
}) => ElevenGameState.initial().copyWith(
  loading: loading,
  public: ElevenPublicSnapshot.fromValue({
    'status': 'playing',
    'round': 3,
    'firstUid': 'a',
    'secondUid': 'b',
    ...public,
  }),
  private: ElevenPrivateSnapshot.fromValue(private),
);

ElevenPhoneStage _stage(
  Map<String, Object?> public, {
  String uid = 'a',
  Map<String, Object?>? private,
  int? local,
}) => resolveElevenPhoneStage(
  _game(public, private: private),
  uid: uid,
  locallySubmittedRound: local,
);

void main() {
  test('loading is connecting', () {
    expect(
      resolveElevenPhoneStage(ElevenGameState.initial(), uid: 'a'),
      ElevenPhoneStage.connecting,
    );
  });

  test('P01 draw phases wait on the phone', () {
    expect(_stage({'phase': 'drawPick'}), ElevenPhoneStage.drawWaiting);
    expect(_stage({'phase': 'drawReveal'}), ElevenPhoneStage.drawWaiting);
  });

  test('P02/P03 firstSubmit splits by role', () {
    expect(_stage({'phase': 'firstSubmit'}), ElevenPhoneStage.firstChoosing);
    expect(
      _stage({'phase': 'firstSubmit'}, uid: 'b'),
      ElevenPhoneStage.secondPreselect,
    );
    expect(ElevenPhoneStage.secondPreselect.canSelect, isTrue);
    expect(ElevenPhoneStage.secondPreselect.canSubmit, isFalse);
  });

  test('P04/P05/P07 secondSubmit splits by role and submission', () {
    expect(_stage({'phase': 'secondSubmit'}), ElevenPhoneStage.firstSubmitted);
    expect(
      _stage({'phase': 'secondSubmit'}, uid: 'b'),
      ElevenPhoneStage.secondChoosing,
    );
    expect(
      _stage({'phase': 'secondSubmit'}, uid: 'b', local: 3),
      ElevenPhoneStage.secondSubmitted,
    );
    // 지난 라운드의 로컬 제출 기록은 이번 라운드 완료로 보지 않습니다.
    expect(
      _stage({'phase': 'secondSubmit'}, uid: 'b', local: 2),
      ElevenPhoneStage.secondChoosing,
    );
    expect(
      _stage(
        {'phase': 'secondSubmit'},
        uid: 'b',
        private: {
          'tiles': [1],
          'submission': {'round': 3, 'value': 4, 'auto': true},
        },
      ),
      ElevenPhoneStage.secondSubmitted,
    );
  });

  test('P08 round result', () {
    expect(_stage({'phase': 'roundResult'}), ElevenPhoneStage.roundResult);
  });

  test('P10/P11 natural finish shows result; others close', () {
    expect(
      _stage({
        'status': 'finished',
        'phase': 'finished',
        'winnerUid': 'b',
        'finishReason': 'winner',
        'finishDetail': 'tieDraw',
      }),
      ElevenPhoneStage.finished,
    );
    // 한 명 퇴장 시 승자 없이 종료(D13).
    expect(
      _stage({
        'status': 'finished',
        'phase': 'finished',
        'winnerUid': null,
        'finishReason': 'insufficientPlayers',
      }),
      ElevenPhoneStage.closing,
    );
    expect(
      _stage({
        'status': 'finished',
        'phase': 'finished',
        'finishReason': 'manual',
      }),
      ElevenPhoneStage.closing,
    );
  });

  test('a non-participant never gets a submit stage', () {
    expect(
      _stage({'phase': 'firstSubmit'}, uid: 'z'),
      ElevenPhoneStage.connecting,
    );
  });
}
