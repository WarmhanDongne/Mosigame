// [eleven_test_support.dart] 는 ELEVEN 위젯 테스트·골든·검수 스크린샷이 함께 쓰는 도우미다.
//
// - 글꼴: 숫자 StardosStencil(루트 assets)과 본문 대체 글꼴을 실제로 불러 한글이 상자로
//   그려지지 않게 한다. 본문 “Noto Sans KR”은 앱에 번들되어 있지 않으므로, 테스트에서는
//   저장소에 있는 IBMPlexSansKR(game_kit, OFL)을 같은 이름으로 등록해 대신 그린다.
//   글자 모양은 시안과 다르니 검수는 위치·크기·색 기준이다.
// - 검수 스크린샷: `ELEVEN_REVIEW=1 flutter test --update-goldens <파일>`일 때만
//   `review_out/<레인>/<이름>.png`로 저장한다(git 제외). 평소 테스트에서는 건너뛴다.
//
// S5-0b 공유 파일이다. 레인은 수정하지 않고 필요하면 LOG에 요청한다.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';

/// 패키지 루트(packages/game_eleven)에서 본 저장소 루트입니다.
const _repoRoot = '../..';

/// 숫자·본문 글꼴을 테스트 엔진에 등록합니다. `setUpAll`에서 한 번 부릅니다.
Future<void> loadElevenTestFonts() async {
  Future<ByteData> read(String path) async =>
      ByteData.sublistView(File(path).readAsBytesSync());

  final number = FontLoader(ElevenNoirFonts.number)
    ..addFont(read('$_repoRoot/assets/fonts/StardosStencil-Bold.ttf'));
  final body = FontLoader(ElevenNoirFonts.body);
  for (final weight in ['Regular', 'SemiBold', 'Bold']) {
    body.addFont(
      read(
        '$_repoRoot/packages/game_kit/assets/fonts/IBMPlexSansKR-$weight.ttf',
      ),
    );
  }
  await Future.wait([number.load(), body.load()]);
}

/// 검수 스크린샷을 만들지 여부입니다(`ELEVEN_REVIEW=1`).
bool get elevenReviewEnabled => Platform.environment['ELEVEN_REVIEW'] == '1';

/// 검수 스크린샷을 만들지 않을 때 testWidgets/group의 `skip`에 넘길 값입니다.
Object? get elevenReviewSkip =>
    elevenReviewEnabled ? false : 'ELEVEN_REVIEW=1 일 때만 검수 스크린샷을 만든다';

/// 골든 PNG는 macOS 기준이다. 다른 OS에서는 group `skip`으로 건너뛴다.
Object? get elevenGoldenSkip =>
    Platform.isMacOS ? false : '골든 PNG는 macOS 기준이다(다른 OS는 글자 렌더링 차이)';

/// [finder] 영역을 `review_out/<lane>/<name>.png`로 저장합니다.
///
/// [name]은 화면 ID 또는 연출 ID와 시점입니다. 예: `P02`, `T07`, `02_round-02600`.
/// 테스트 파일이 `test/<폴더>/` 바로 아래에 있다고 가정합니다.
Future<void> captureElevenReview(
  WidgetTester tester,
  Finder finder, {
  required String lane,
  required String name,
}) async {
  await expectLater(
    finder,
    matchesGoldenFile('../../review_out/$lane/$name.png'),
  );
}
