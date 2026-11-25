// [game_sounds.dart] 는 ELEVEN에서 쓰는 배경음악과 효과음 경로를 모아 두는 파일이다.
//
// - [Package] : ELEVEN
// - [Sound] : 게임 진행 단계에 맞는 음악과 효과음을 관리함
//
// 소리는 방 가운데 태블릿에서만 낸다. 휴대폰까지 함께 울리면 같은 소리가 겹쳐 들린다.
// 새 음원은 앱 번들에 포함되어야 하므로 코드 패치(Shorebird)만으로는 전달되지 않는다.

/// ELEVEN 전용 소리 경로입니다.
///
/// 원본(이슈 #221): BGM musinova "minimal underscore piano pulse loop edit",
/// 인트로 Mixkit "cinematic glass hit suspense", 카드 Kenney Casino Audio(CC0).
/// iOS가 ogg를 재생하지 못하므로 모두 m4a(AAC)로 변환해 넣었습니다.
abstract final class ElevenSounds {
  static const _root = 'packages/game_eleven/assets/games/eleven/sounds';

  /// 새 판이 시작될 때(첫 선공 뽑기 화면) 한 번 울리는 인트로입니다(4.7초).
  static const intro = '$_root/intro.m4a';

  /// 타일이 놓일 때(뽑기에서 한 장을 고름, 선공·후공 제출) 냅니다.
  static const cardPlace = '$_root/card_place.m4a';

  /// 타일이 뒤집혀 공개될 때(뽑기 공개, 라운드 결과 강조) 냅니다.
  static const cardFlip = '$_root/card_flip.m4a';

  /// 판 내내 반복되는 배경음악입니다(89초 루프). BGM 채널로 재생합니다.
  ///
  /// 반복 재생이라 화면을 떠날 때 반드시 멈춰야 하므로 [preloadTargets]에
  /// 넣지 않습니다.
  static const background = '$_root/background.m4a';

  /// 인트로가 울린 뒤 배경음악을 깔기까지 기다리는 시간입니다.
  ///
  /// 인트로의 타격음이 지나고 잔향이 줄어드는 지점입니다. 귀로 들어 보고
  /// 조정할 값입니다.
  static const backgroundAfterIntro = Duration(milliseconds: 2500);

  /// 첫 재생이 화면보다 늦지 않도록 게임 진입 때 미리 준비하는 효과음입니다.
  static const preloadTargets = [intro, cardPlace, cardFlip];

  /// 다른 게임에 들어갈 때 이 소리들을 놓아 주기 위한 preload 범위입니다.
  static const preloadScope = 'eleven';
}
