import 'package:game_kit/core/constants/room_character.dart';
import 'package:game_kit/localization/game_locale.dart';

class RoomNicknameSeed {
  const RoomNicknameSeed({
    required this.nickname,
    required this.followsCharacter,
  });

  final String nickname;

  /// `true`인 동안은 게스트가 캐릭터를 바꾸면 기본 별명도 같이 바꿉니다.
  /// 사용자가 닉네임을 한 번이라도 편집하면 `false`로 전환해 입력을 보존합니다.
  final bool followsCharacter;
}

/// 방 캐릭터 프로필에 대응하는 한 단어 게스트 별명입니다.
///
/// 같은 방에서 캐릭터는 중복 선택할 수 없으므로, 기본 별명도 자연스럽게
/// 서로 다른 값을 사용합니다. 예전 ID와 아트 ID는 [roomCharacterById]로 먼저
/// 정규화합니다.
String guestRoomNicknameForCharacter(String? characterId) {
  final normalizedId = roomCharacterById(characterId).id;
  final names =
      _guestRoomNicknames[normalizedId] ??
      _guestRoomNicknames[defaultRoomCharacterId]!;
  return GameLocale.select(
    ko: names.$1,
    en: names.$2,
    zhHans: names.$3,
    zhHant: names.$4,
  );
}

/// 현재 방에서 캐릭터와 자동 게스트 별명이 모두 빈 선택지입니다.
List<RoomCharacter> availableGuestRoomCharacters({
  required Set<String> occupiedCharacterIds,
  required Set<String> occupiedNicknames,
}) => roomCharacters
    .where(
      (character) =>
          !occupiedCharacterIds.contains(character.id) &&
          !occupiedNicknames.contains(
            guestRoomNicknameForCharacter(character.id),
          ),
    )
    .toList(growable: false);

/// 계정 정보와 선택된 방 캐릭터로 입장 화면의 초기 닉네임을 결정합니다.
RoomNicknameSeed roomNicknameSeed({
  required bool isAnonymous,
  required String? characterId,
  required String? pendingNickname,
  required String? displayName,
  required String? email,
  required int maxLength,
}) {
  final pending = _trimmedOrNull(pendingNickname);
  final displayed = _trimmedOrNull(displayName);

  if (isAnonymous) {
    // 지금 프로필 저장 중인 이름은 사용자가 직접 고른 값이므로 우선합니다.
    if (pending != null) {
      return RoomNicknameSeed(
        nickname: _truncate(pending, maxLength),
        followsCharacter: false,
      );
    }
    // 서버가 자동 생성한 게스트 이름과 기존 fallback은 방 캐릭터 별명으로
    // 바꾸되, 게스트가 프로필에서 직접 변경한 이름은 그대로 유지합니다.
    if (displayed != null && !_isAutomaticGuestName(displayed)) {
      return RoomNicknameSeed(
        nickname: _truncate(displayed, maxLength),
        followsCharacter: false,
      );
    }
    return RoomNicknameSeed(
      nickname: guestRoomNicknameForCharacter(characterId),
      followsCharacter: true,
    );
  }

  final accountNickname =
      pending ??
      displayed ??
      _trimmedOrNull(email)?.split('@').first ??
      GameLocale.select(ko: '사용자', en: 'Player', zhHans: '玩家', zhHant: '玩家');
  return RoomNicknameSeed(
    nickname: _truncate(accountNickname, maxLength),
    followsCharacter: false,
  );
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _isAutomaticGuestName(String value) {
  if (value == '사용자' ||
      value == 'Player' ||
      value == '玩家' ||
      value.toLowerCase() == 'guest') {
    return true;
  }
  return RegExp(
    r'^(게스트|guest)[0-9a-f]{6}$',
    caseSensitive: false,
  ).hasMatch(value);
}

String _truncate(String value, int maxLength) {
  final runes = value.runes;
  if (runes.length <= maxLength) return value;
  return String.fromCharCodes(runes.take(maxLength));
}

const _guestRoomNicknames = <String, (String, String, String, String)>{
  'frog': ('버거', 'Burger', '汉堡', '漢堡'),
  'cat': ('팝콘', 'Popcorn', '爆米花', '爆米花'),
  'bear': ('양동이', 'Bucket', '水桶', '水桶'),
  'bee': ('냄비', 'Pot', '锅子', '鍋子'),
  'kindbear': ('택배', 'Parcel', '包裹', '包裹'),
  'whale': ('수박', 'Melon', '西瓜', '西瓜'),
  'crab': ('마스크', 'Mask', '口罩', '口罩'),
  'hedgehog': ('후드', 'Hoodie', '兜帽', '連帽'),
  'deer': ('목도리', 'Scarf', '围巾', '圍巾'),
  'elephant': ('우주인', 'Astro', '宇航员', '宇航員'),
  'shark': ('용접공', 'Welder', '焊工', '焊工'),
  'owl': ('물안경', 'Goggles', '护目镜', '護目鏡'),
  'snake': ('변장', 'Disguise', '伪装', '偽裝'),
  'penguin': ('우유', 'Milk', '牛奶', '牛奶'),
  'octopus': ('라면', 'Noodles', '杯面', '杯麵'),
  'giraffe': ('전등', 'Lamp', '灯罩', '燈罩'),
};
