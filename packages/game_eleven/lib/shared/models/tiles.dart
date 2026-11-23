// [tiles.dart] 는 ELEVEN 타일 집합과 표시용 색을 정의하는 파일이다.
//
// - [Package] : ELEVEN
// - [Model] : 타일 값·색 (화면 표시 전용)
//
// 판정·점수·승패는 서버(functions/src/eleven/rules.ts)가 결정한다. 이 파일은 본인 손패와
// 이미 공개된 색을 그리기 위한 값만 갖고, 판정 로직을 두지 않는다.

/// 개인 손패 전체: 0–9, 11. 10은 없다.
const List<int> elevenTiles = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11];

/// 공용 뽑기 묶음의 칸 수입니다.
const int elevenDrawSlotCount = 11;

/// 최대 라운드 수입니다.
const int elevenMaxRounds = 11;

enum ElevenTileColor {
  black,
  white;

  /// 서버 공개 값(`"black"`/`"white"`)을 읽습니다. 모르는 값은 null입니다.
  static ElevenTileColor? tryParse(Object? raw) => switch (raw) {
    'black' => ElevenTileColor.black,
    'white' => ElevenTileColor.white,
    _ => null,
  };

  /// 본인 손패의 색입니다. 흑 = 0, 2, 4, 6, 8, 11 / 백 = 1, 3, 5, 7, 9.
  static ElevenTileColor of(int value) => value == 11 || value.isEven
      ? ElevenTileColor.black
      : ElevenTileColor.white;
}
