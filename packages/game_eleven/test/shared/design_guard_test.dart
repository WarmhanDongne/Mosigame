// 디자인 가드: 화면(lib/phone, lib/tablet)은 색·글꼴·글자 스타일·연출 시간·곡선을 직접
// 만들지 않고 lib/shared/noir/ 토큰과 lib/shared/widgets/ 공통 부품을 쓴다(S5-0b).
//
// 지금 있는 위반은 S4 임시 골격 화면에 있고(이유: 시안 화면 구현이 레인 A·B 범위),
// 공통 부품으로 옮기지 않고 허용 목록(파일·규칙·줄 내용)에 둔다. 허용 목록은 레인 소유
// 폴더 test/phone/design_guard_allowlist.dart, test/tablet/design_guard_allowlist.dart에
// 있다. 레인이 화면을 교체해 위반이 사라지면 이 테스트가 “허용 목록에 남은 항목”으로
// 실패하므로 그 항목도 함께 지운다. 새 위반은 추가하지 말고 토큰·공통 부품을 쓴다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../phone/design_guard_allowlist.dart';
import '../tablet/design_guard_allowlist.dart';

/// 검사 규칙: 이름 → 정규식. 주석은 검사 전에 지운다.
final _rules = <String, RegExp>{
  'Color(0x': RegExp(r'(?<![A-Za-z0-9_])Color\s*\(\s*0x'),
  'Colors.': RegExp(r'(?<![A-Za-z0-9_])Colors\.'),
  'fontFamily:': RegExp(r'(?<![A-Za-z0-9_])fontFamily\s*:'),
  'TextStyle(': RegExp(r'(?<![A-Za-z0-9_.])TextStyle\s*\('),
  'Duration(<숫자>': RegExp(
    r'(?<![A-Za-z0-9_])Duration\s*\(\s*(?:[A-Za-z]+\s*:\s*)?\d',
  ),
  'Curves.': RegExp(r'(?<![A-Za-z0-9_])Curves\.'),
  'Cubic(': RegExp(r'(?<![A-Za-z0-9_])Cubic\s*\('),
};

/// (파일, 규칙) → 허용하는 줄 내용. 레인끼리 같은 파일을 고치지 않도록 허용 목록은
/// 레인 소유 폴더에 나눠 둔다: test/phone/(레인 A), test/tablet/(레인 B).
final _allowed = <(String, String), List<String>>{
  ...phoneDesignGuardAllowlist,
  ...tabletDesignGuardAllowlist,
};

/// `//` 주석을 지운다(문자열 안 `//`는 이 패키지 화면 코드에 없다).
String _stripComments(String line) {
  final index = line.indexOf('//');
  return index < 0 ? line : line.substring(0, index);
}

/// 소스 한 개의 위반 목록: (규칙, 줄 번호, 줄 내용).
List<(String, int, String)> findViolations(String source) {
  final lines = source.split('\n');
  final stripped = [for (final line in lines) _stripComments(line)];
  // 여러 줄에 걸친 `Duration(\n milliseconds: 200` 도 잡도록 이어 붙여 검사한다.
  final joined = stripped.join('\n');
  final found = <(String, int, String)>[];
  for (final MapEntry(key: rule, value: pattern) in _rules.entries) {
    for (final match in pattern.allMatches(joined)) {
      final lineIndex = '\n'
          .allMatches(joined.substring(0, match.start))
          .length;
      found.add((rule, lineIndex + 1, lines[lineIndex].trim()));
    }
  }
  return found;
}

List<File> _screenSources() => [
  for (final dir in ['lib/phone', 'lib/tablet'])
    ...Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart')),
]..sort((a, b) => a.path.compareTo(b.path));

void main() {
  test('rules catch each forbidden construct and ignore tokens', () {
    const bad = '''
final a = Color(0xFF000000);
final b = Colors.red;
final c = TextStyle(fontFamily: 'X');
final d = Duration(milliseconds: 300);
final e = Duration(
  seconds: 2);
final f = Curves.easeOut;
final g = Cubic(0.3, 1.3, 0.6, 1);
''';
    final rules = findViolations(bad).map((v) => v.$1).toSet();
    expect(rules, _rules.keys.toSet());

    const good = '''
// TextStyle( 와 Colors. 는 주석이면 괜찮다
final a = ElevenNoirColors.ink;
final b = ElevenNoirText.body(17);
final c = base.copyWith(color: ElevenNoirColors.red);
final d = ElevenTiming.roundResult;
final e = Duration.zero;
final f = ElevenCurves.bounce;
final g = ElevenColors.table;
''';
    expect(findViolations(good), isEmpty);
  });

  test('phone and tablet screens use shared design tokens only', () {
    final sources = _screenSources();
    expect(sources, isNotEmpty, reason: 'run from packages/game_eleven');
    final unexpected = <String>[];
    final remaining = {
      for (final entry in _allowed.entries) entry.key: [...entry.value],
    };
    for (final file in sources) {
      final path = file.path.replaceAll(r'\', '/');
      for (final (rule, line, text) in findViolations(
        file.readAsStringSync(),
      )) {
        final allowed = remaining[(path, rule)];
        if (allowed != null && allowed.remove(text)) continue;
        unexpected.add('$path:$line [$rule] $text');
      }
    }
    expect(
      unexpected,
      isEmpty,
      reason:
          '화면에서 색·글꼴·TextStyle·연출 시간·곡선을 직접 만들었다. '
          'lib/shared/noir/ 토큰이나 lib/shared/widgets/ 부품을 쓴다.',
    );
    final stale = [
      for (final MapEntry(:key, :value) in remaining.entries)
        for (final text in value) '${key.$1} [${key.$2}] $text',
    ];
    expect(stale, isEmpty, reason: '허용 목록에 있지만 더는 없는 위반이다. 허용 목록에서 지운다.');
  });

  test('allowlist entries name a known rule and their own lane folder', () {
    for (final key in phoneDesignGuardAllowlist.keys) {
      expect(key.$1, startsWith('lib/phone/'));
      expect(_rules.keys, contains(key.$2));
    }
    for (final key in tabletDesignGuardAllowlist.keys) {
      expect(key.$1, startsWith('lib/tablet/'));
      expect(_rules.keys, contains(key.$2));
    }
  });
}
