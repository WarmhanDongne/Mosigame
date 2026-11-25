// S7(나) 번역 검사: ELEVEN 문구가 en·zh-Hans·zh-Hant에서 한국어 없이 나오는지 확인한다.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/game_copy.dart';
import 'package:game_kit/localization/game_locale.dart';

final _hangul = RegExp(r'[가-힣ㄱ-ㆎ]');

void main() {
  tearDown(() => GameLocale.current = const Locale('ko'));

  test('every GameLocale.select in game_copy.dart has Hangul-free en/zh', () {
    final source = File('lib/game_copy.dart').readAsStringSync();
    expect(source.contains('_ko('), isFalse, reason: '번역 전 임시 표시가 남아 있다');
    final selects = 'GameLocale.select('.allMatches(source).length;
    expect(selects, greaterThan(150));
    for (final key in ['en', 'zhHans', 'zhHant']) {
      final values = RegExp(
        "$key: (?:'''(.*?)'''|'((?:[^'\\\\]|\\\\.)*)')",
        dotAll: true,
      ).allMatches(source).map((m) => m.group(1) ?? m.group(2)!).toList();
      expect(values.length, selects, reason: '$key 값 수');
      for (final value in values) {
        expect(_hangul.hasMatch(value), isFalse, reason: '$key: $value');
      }
    }
  });

  test('locale switch changes visible copy', () {
    String sample() => [
      ElevenCopy.title,
      ElevenScreenCopy.pillMyTurn,
      ElevenScreenCopy.toastRoundIntro(6, 'Ann'),
      ElevenScreenCopy.drawOtherWon(3, 7, 'Ann'),
      ElevenScreenCopy.finalNote(6, 2),
      ElevenScreenCopy.rulebookMarkdown,
    ].join('|');

    final ko = sample();
    expect(ko, contains('내 차례'));

    GameLocale.current = const Locale('en');
    final en = sample();
    expect(en, contains('My turn'));
    expect(en, contains('Round 6\nAnn first'));
    expect(_hangul.hasMatch(en), isFalse);

    GameLocale.current = const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    );
    final hans = sample();
    expect(hans, contains('我的回合'));
    expect(hans, contains('ELEVEN'));
    expect(_hangul.hasMatch(hans), isFalse);

    GameLocale.current = const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
    );
    final hant = sample();
    expect(hant, contains('遊戲'));
    expect(hant, isNot(hans));
    expect(_hangul.hasMatch(hant), isFalse);
  });

  test('rulebook keeps the same five sections in every language', () {
    for (final locale in const [
      Locale('ko'),
      Locale('en'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ]) {
      GameLocale.current = locale;
      final titles = RegExp(
        r'^# ',
        multiLine: true,
      ).allMatches(ElevenScreenCopy.rulebookMarkdown).length;
      expect(titles, 5, reason: '$locale');
    }
  });
}
