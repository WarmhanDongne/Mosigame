// [tiles.dart] 는 ELEVEN 타일 집합과 표시용 색을 정의하는 파일이다.
//
// - [Package] : ELEVEN
// - [Model] : 타일 값·색 (화면 표시 전용)
//
// 판정·점수·승패는 서버(functions/src/eleven/rules.ts)가 결정한다. 이 파일은 본인 손패와
// 이미 공개된 색을 그리기 위한 값만 갖고, 판정 로직을 두지 않는다.

/// 개인 손패 전체: 0–9, 11. 10은 없다.
const List<int> elevenTiles = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11];

/// 공용 뽑기 묶음: 1–9 9장. 개인 손패와 별개다(계약 2절, 2026-11-25 승인).
/// 첫 선공 뽑기와 최종 동점 뽑기가 같은 묶음을 쓴다. 공개 전 배치는 서버에만 있다.
const List<int> elevenDrawTiles = [1, 2, 3, 4, 5, 6, 7, 8, 9];

/// 공용 뽑기 묶음의 칸 수입니다. 고를 수 있는 위치는 slotIndex 0–8입니다.
const int elevenDrawSlotCount = 9;

/// 서버가 받는 뽑기 위치 범위(0–8) 안인지입니다.
bool elevenIsDrawSlot(int slotIndex) =>
    slotIndex >= 0 && slotIndex < elevenDrawSlotCount;

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

  /// 타일 값의 색입니다. 흑 = 0, 2, 4, 6, 8, 11 / 백 = 1, 3, 5, 7, 9.
  /// 공개된 공용 뽑기 카드(1–9)도 같은 규칙(짝수 흑, 홀수 백)을 쓴다
  /// (S5-0b 결정 4, 하준 2026-11-25).
  static ElevenTileColor of(int value) => value == 11 || value.isEven
      ? ElevenTileColor.black
      : ElevenTileColor.white;
}
