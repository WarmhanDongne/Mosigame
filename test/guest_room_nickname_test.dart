import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/constants/room_character.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:project00/platform/home/phone/models/guest_room_nickname.dart';

void main() {
  final originalLocale = GameLocale.current;
  tearDown(() => GameLocale.current = originalLocale);

  for (final locale in const [
    Locale('ko'),
    Locale('en'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    test('방 캐릭터별 게스트 별명은 $locale에서 한 개씩 고유하다', () {
      GameLocale.current = locale;
      final nicknames = [
        for (final character in roomCharacters)
          guestRoomNicknameForCharacter(character.id),
      ];

      expect(nicknames, hasLength(roomCharacters.length));
      expect(nicknames.toSet(), hasLength(roomCharacters.length));
      expect(nicknames.every((nickname) => nickname.runes.length <= 8), isTrue);
      expect(nicknames.every((nickname) => !nickname.contains(' ')), isTrue);
    });
  }

  test('예전 캐릭터 아트 ID도 같은 프로필 별명을 사용한다', () {
    GameLocale.current = const Locale('ko');

    expect(guestRoomNicknameForCharacter('burger'), '버거');
    expect(guestRoomNicknameForCharacter('popcorn'), '팝콘');
    expect(guestRoomNicknameForCharacter('unknown'), '버거');
  });

  test('자동 게스트는 캐릭터나 별명이 겹치는 선택지를 건너뛴다', () {
    GameLocale.current = const Locale('ko');

    final available = availableGuestRoomCharacters(
      occupiedCharacterIds: {'cat'},
      occupiedNicknames: {'버거', '우유'},
    );
    final ids = available.map((character) => character.id).toSet();
    final nicknames = available
        .map((character) => guestRoomNicknameForCharacter(character.id))
        .toSet();

    expect(ids, isNot(contains('cat')));
    expect(ids, isNot(contains('frog')));
    expect(ids, isNot(contains('penguin')));
    expect(nicknames, isNot(contains('팝콘')));
    expect(nicknames, isNot(contains('버거')));
    expect(nicknames, isNot(contains('우유')));
  });

  test('자동 이름의 게스트는 선택한 프로필 별명을 따른다', () {
    GameLocale.current = const Locale('ko');

    for (final automaticName in [null, '', '사용자', '게스트a1b2c3']) {
      final seed = roomNicknameSeed(
        isAnonymous: true,
        characterId: 'penguin',
        pendingNickname: null,
        displayName: automaticName,
        email: null,
        maxLength: 8,
      );

      expect(seed.nickname, '우유');
      expect(seed.followsCharacter, isTrue);
    }
  });

  test('게스트가 직접 변경한 프로필 이름은 방 기본값으로 유지한다', () {
    final saved = roomNicknameSeed(
      isAnonymous: true,
      characterId: 'penguin',
      pendingNickname: null,
      displayName: '나만의별명',
      email: null,
      maxLength: 8,
    );
    final pending = roomNicknameSeed(
      isAnonymous: true,
      characterId: 'penguin',
      pendingNickname: '방금수정',
      displayName: '게스트a1b2c3',
      email: null,
      maxLength: 8,
    );

    expect(saved.nickname, '나만의별명');
    expect(saved.followsCharacter, isFalse);
    expect(pending.nickname, '방금수정');
    expect(pending.followsCharacter, isFalse);
  });

  test('회원은 기존 계정 닉네임 우선순위를 유지한다', () {
    final pending = roomNicknameSeed(
      isAnonymous: false,
      characterId: 'frog',
      pendingNickname: '수정중',
      displayName: '프로필',
      email: 'member@example.com',
      maxLength: 8,
    );
    final email = roomNicknameSeed(
      isAnonymous: false,
      characterId: 'frog',
      pendingNickname: null,
      displayName: null,
      email: 'very-long-member@example.com',
      maxLength: 8,
    );

    expect(pending.nickname, '수정중');
    expect(pending.followsCharacter, isFalse);
    expect(email.nickname, 'very-lon');
    expect(email.followsCharacter, isFalse);
  });
}
