// [sound_cues.dart] 는 ELEVEN 태블릿이 서버 공개 상태 변화에서 낼 효과음을 고르는 파일이다.
//
// 재생 자체는 board_state가 맡고, 여기서는 "이전 → 다음 공개 상태"만 보고 어떤
// 소리를 낼지 결정한다. 재생 장치 없이 시험할 수 있도록 순수 함수로 둔다.

// ========================[ import ]==========================
import 'package:game_eleven/shared/services/public_state_mapper.dart';
import 'package:game_eleven/tablet/providers/game_stage.dart';

// ============================================================

/// 공개 상태 변화로 생기는 효과음 종류입니다.
///
/// 뒤집기(공개) 소리는 화면 연출 타이머에 맞춰 board_state가 직접 냅니다.
enum ElevenTabletSoundCue {
  /// 새 판 시작(첫 선공 뽑기, 아직 아무도 뽑지 않음).
  intro,

  /// 타일이 놓임(뽑기 선택, 선공·후공 제출).
  place,
}

/// [previous] → [next] 공개 상태 변화에서 낼 효과음을 돌려줍니다.
///
/// [previous]가 null이면 처음 받은 상태입니다. 처음 받은 상태는 보통 이미
/// 진행 중인 판(재접속 등)이라 소리를 내지 않고, 막 시작한 첫 뽑기만 인트로를 냅니다.
List<ElevenTabletSoundCue> resolveElevenTabletSoundCues({
  required ElevenPublicSnapshot? previous,
  required ElevenPublicSnapshot next,
  required ElevenTabletStage stage,
}) {
  final freshStart =
      stage == ElevenTabletStage.firstDrawPick &&
      (next.draw?.picks.isEmpty ?? true);
  if (previous == null || previous.startedAt != next.startedAt) {
    return [if (freshStart) ElevenTabletSoundCue.intro];
  }

  final placed = _drawPicked(previous, next) || _tileSubmitted(previous, next);
  return [if (placed) ElevenTabletSoundCue.place];
}

bool _drawPicked(ElevenPublicSnapshot previous, ElevenPublicSnapshot next) {
  final before = previous.draw;
  final after = next.draw;
  if (before == null || after == null) return false;
  if (before.purpose != after.purpose) return false;
  return after.picks.length > before.picks.length;
}

bool _tileSubmitted(ElevenPublicSnapshot previous, ElevenPublicSnapshot next) {
  final before = previous.currentRound;
  final after = next.currentRound;
  if (before.round != after.round) return false;
  return (before.firstColor == null && after.firstColor != null) ||
      (before.secondColor == null && after.secondColor != null);
}
