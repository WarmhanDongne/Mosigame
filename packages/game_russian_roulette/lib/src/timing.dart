import 'package:game_russian_roulette/src/view.dart';

/// 러시안 룰렛 연출 타이밍입니다. 긴장감은 살리되 한 턴 구경 시간이 늘어지지
/// 않게 맞췄습니다(공개 0.8초 간격, 회전 0.9초 간격, 발포 전 1.4초).
///
/// 실기기 확정 전에는 이 파일의 값만 조정하면 휴대폰·태블릿
/// 표시와 서버 연출 단계 진행 시점을 같이 바꿀 수 있습니다.
abstract final class RussianRouletteTiming {
  /// 한 턴의 비공개 선택 시간입니다(서버 RUSSIAN_ROULETTE_TURN_MS와 같음).
  static const turn = Duration(seconds: 30);

  /// 선택이 잠긴 뒤 첫 행동을 공개하기 전 긴장 구간입니다.
  static const revealLead = Duration(milliseconds: 700);

  /// 행동 공개 카드 하나의 간격입니다.
  static const revealStep = Duration(milliseconds: 800);

  /// 마지막 행동 공개 후 회전으로 넘어가기 전 여운입니다.
  static const revealTail = Duration(milliseconds: 600);

  /// 회전 횟수를 집계한 뒤 첫 칸을 움직이기 전 준비 구간입니다.
  static const rotationLead = Duration(milliseconds: 500);

  /// 총이 한 사람씩 시계 방향으로 이동하는 간격입니다.
  static const rotationStep = Duration(milliseconds: 900);

  /// 마지막 회전 후 격발 표시로 넘어가기 전 여운입니다.
  static const rotationTail = Duration(milliseconds: 600);

  /// 총이 좌석 사이를 이동하는 실제 모션 길이입니다.
  static const gunTurn = Duration(milliseconds: 600);

  /// 격발 표시 후 피격 결과가 나오기 전 정지 시간입니다.
  static const firingHold = Duration(milliseconds: 1400);

  /// 방패 충돌·흔들림 모션의 길이입니다.
  static const shieldImpact = Duration(milliseconds: 650);

  /// 방패로 막은 결과를 보여 주는 시간입니다.
  static const blockedOutcome = Duration(milliseconds: 3200);

  /// 탈락, 생존 인원, 다음 타겟을 순서대로 보여 주는 시간입니다.
  static const eliminatedOutcome = Duration(milliseconds: 4200);

  /// 휴대폰·태블릿에서 단계(화면)가 바뀔 때 겹쳐 넘어가는 시간입니다.
  static const stageFade = Duration(milliseconds: 600);

  /// 휴대폰 머리줄은 고정하고 아래 본문만 겹쳐 바꿀 때의 시간입니다.
  static const bodyFade = Duration(milliseconds: 380);

  /// 태블릿이 연출이 끝나기 이만큼 전에 다음 단계를 미리 요청합니다.
  /// 서버 응답을 기다리는 동안 모든 화면이 멈춰 보이던 틈을 없앱니다.
  /// 각 단계의 여운(tail)보다 짧아야 연출이 잘리지 않습니다.
  static const phaseRequestLead = Duration(milliseconds: 300);

  /// 자리표 상태 칸이 바뀔 때의 전환 시간입니다.
  static const plateFade = Duration(milliseconds: 450);

  static Duration revealing(int aliveCount) =>
      revealLead + revealStep * aliveCount.clamp(0, 8) + revealTail;

  static Duration rotating(int spinCount) =>
      rotationLead + rotationStep * spinCount.clamp(0, 8) + rotationTail;

  static Duration outcome({required bool blocked}) =>
      blocked ? blockedOutcome : eliminatedOutcome;

  static int revealedCount(Duration elapsed, int total) {
    final afterLead = elapsed - revealLead;
    if (afterLead.isNegative) return 0;
    return ((afterLead.inMilliseconds ~/ revealStep.inMilliseconds) + 1).clamp(
      0,
      total,
    );
  }

  static bool showsSpinSummary(Duration elapsed, int total) =>
      elapsed >= revealLead + revealStep * total.clamp(0, 8);

  static int completedRotationSteps(Duration elapsed, int total) {
    final afterLead = elapsed - rotationLead;
    if (afterLead.isNegative || total <= 0) return 0;
    return ((afterLead.inMilliseconds ~/ rotationStep.inMilliseconds) + 1)
        .clamp(0, total);
  }
}

/// 이 기기 시계로 본 지금 단계의 시작 시각을 돌려줍니다.
///
/// 서버가 단계 시작 시각([RussianRouletteView.phaseStartedAt])을 보내고 서버
/// 시각 보정([serverNow])이 있으면, 늦게 받은 기기도 같은 시점부터 연출을 셉니다.
/// 값이 없거나 보정 전이거나 믿기 어려운 차이(음수·1분 초과)면 받은 순간부터 셉니다.
int rouletteLocalPhaseStart({
  required int localNow,
  required int? serverNow,
  required int phaseStartedAt,
}) {
  if (serverNow == null || phaseStartedAt <= 0) return localNow;
  final elapsed = serverNow - phaseStartedAt;
  if (elapsed < 0) return localNow;
  if (elapsed > 60000) return localNow;
  return localNow - elapsed;
}

/// 태블릿이 잡아 두는 연출 단계 예약의 식별자입니다.
///
/// 중단 여부를 포함합니다. 중단 중에는 예약을 버리므로, 재개가 같은 단계라도
/// 새 예약으로 보여야 다시 걸립니다. 빼면 재개 시점의 식별자가 중단 직전과
/// 같아져 예약이 다시 걸리지 않고 단계가 영원히 넘어가지 않습니다.
String roulettePhaseKey(RussianRouletteView game) =>
    '${game.round}:${game.phase}:${game.targetUid}:${game.spinCount}:'
    '${game.paused}';

/// 이 단계를 얼마나 보여 준 뒤 진행 명령을 보낼지입니다.
///
/// `null`은 태블릿이 진행 명령을 보내지 않는 상태입니다. 중단과 종료, 그리고
/// 서버가 직접 시간을 재는 선택 단계가 여기에 해당합니다.
Duration? roulettePhaseDelay(RussianRouletteView game) {
  if (game.paused || game.finished) return null;
  return switch (game.phase) {
    'revealing' => RussianRouletteTiming.revealing(game.aliveCount),
    'rotating' => RussianRouletteTiming.rotating(game.spinCount),
    'firing' => RussianRouletteTiming.firingHold,
    'outcome' => RussianRouletteTiming.outcome(
      blocked: game.shotBlocked == true,
    ),
    _ => null,
  };
}

/// 첫 게임 시작 준비가 끝나기 전에는 일반 선택 화면을 먼저 노출하지 않습니다.
///
/// 준비 중 공개 상태를 그대로 그리면 프로필과 총구가 잠깐 보인 뒤, 준비가
/// 끝나 시작 연출이 0초부터 재생되면서 다시 어두워지는 깜빡임이 생깁니다.
/// 이 게임([RussianRouletteView.startedAt])의 시작 연출을 이미 보여 줬다면
/// 첫 턴 중간에 멈춘 것이므로 기존 화면을 유지합니다. 멈춘 동안은 마감 시각이
/// 비어 있어(0) 마감 시각으로는 구분할 수 없습니다.
bool rouletteShouldHoldIntroFrame(
  RussianRouletteView game, {
  required int presentedStartedAt,
}) {
  if (game.finished ||
      game.round != 1 ||
      game.phase != 'selecting' ||
      !game.paused) {
    return false;
  }
  return presentedStartedAt == 0 || game.startedAt != presentedStartedAt;
}
