/// 러시안 룰렛 전용 사운드 경로입니다.
///
/// 한 방의 여러 기기에서 겹쳐 울리지 않도록 BGM과 공개 연출 효과음은
/// 진행용 태블릿에서만 재생합니다.
abstract final class RussianRouletteSounds {
  static const _root =
      'packages/game_russian_roulette/assets/games/russian_roulette/sounds';

  /// 게임 진행 동안 반복 재생하는 긴장감 있는 배경음입니다.
  static const background = '$_root/background.mp3';

  /// 총이 생존자 사이를 이동하는 회전 단계에서 재생합니다.
  static const revolverSpin = '$_root/revolver_spin.mp3';

  /// 격발 결과가 표시되는 순간 한 번 재생합니다.
  static const gunshot = '$_root/gunshot.mp3';

  /// 격발 대상이 방패로 막은 경우 총성과 함께 재생합니다.
  static const shieldImpact = '$_root/shield_impact.mp3';

  /// 마지막 생존자 결과 표시에서 재생합니다.
  static const victory = '$_root/victory.mp3';

  /// 첫 연출이 화면보다 늦게 들리지 않도록 진입 시 미리 준비합니다.
  static const preloadTargets = [revolverSpin, gunshot, shieldImpact, victory];
}
