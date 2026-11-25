import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/ui.dart' as eleven;
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:game_kit/mosi_ui/mosi_game_modal.dart';
import 'package:project00/games/game_registry.dart';
import 'package:project00/platform/home/tablet/widgets/detail/game_detail_previews.dart';

void main() {
  // 구성품 판은 정해진 칸에 글자를 맞추므로 테스트 기본 글꼴(Ahem) 대신 앱 글꼴로
  // 넘침을 확인합니다(game_preview_localization_test와 같은 방식).
  setUpAll(() async {
    for (final (family, files) in const [
      (
        'packages/game_kit/IBMPlexSansKR',
        [
          'packages/game_kit/assets/fonts/IBMPlexSansKR-Regular.ttf',
          'packages/game_kit/assets/fonts/IBMPlexSansKR-Bold.ttf',
        ],
      ),
      (
        'packages/game_kit/SpaceGrotesk',
        ['packages/game_kit/assets/fonts/SpaceGrotesk-Bold.ttf'],
      ),
      ('StardosStencil', ['assets/fonts/StardosStencil-Bold.ttf']),
    ]) {
      final loader = FontLoader(family);
      for (final file in files) {
        loader.addFont(rootBundle.load(file));
      }
      await loader.load();
    }
  });

  test('registry exposes ELEVEN as a fixed 2-player game', () {
    final game = const GameRegistry().find('eleven');
    expect(game, isNotNull);
    expect(game!.supportedPlayerCounts, [2]);
    expect(game.leaveFunctionName, 'game_eleven_leave_game');
    expect(game.requiredAssetVersion, 0);
  });

  test('ELEVEN has its own lobby art, detail theme and seat theme', () {
    expect(MosiGameArt.isKnown('eleven'), isTrue);
    final art = MosiGameArt.of('eleven');
    expect(art, same(MosiGameArt.eleven));
    expect(art.detailTheme.ground, eleven.ElevenNoirColors.table);
    expect(art.accent, isNot(art.detailTheme.ground));
    expect(MosiSeatTheme.of('eleven'), same(MosiSeatTheme.eleven));
    expect(gamePartsBackground('eleven'), eleven.ElevenNoirColors.table);
  });

  test('settings and rulebook dialogs pick the ELEVEN noir theme', () {
    for (final name in ['일레븐', 'ELEVEN']) {
      expect(
        MosiGameModalTheme.fromName(name),
        same(MosiGameModalTheme.eleven),
      );
    }
    expect(
      MosiGameModalTheme.fromName('라이어스 포커'),
      same(MosiGameModalTheme.liarsPoker),
    );
  });

  testWidgets('ELEVEN seat layout table and seats render', (tester) async {
    final game = const GameRegistry().find('eleven')!;
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final table = game.buildLayoutTable(captured);
    final seats = [
      for (final seat in [0, 1]) game.buildLayoutChair(captured, seat),
    ];
    expect(table, isNotNull);
    expect(seats, everyElement(isNotNull));
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            SizedBox.square(dimension: 90, child: seats[0]),
            SizedBox.square(dimension: 300, child: table),
            SizedBox.square(dimension: 90, child: seats[1]),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ELEVEN shelf cover and spine render at shelf sizes', (
    tester,
  ) async {
    for (final (width, height) in const [(46.0, 288.0), (55.0, 282.0)]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: MosiGameSpine(
              gameId: 'eleven',
              onTap: () {},
              width: width,
              height: height,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'spine ${width}x$height');
    }
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: MosiGameCover(gameId: 'eleven', width: 240)),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(694, 560), Size(980, 520), Size(560, 640)]) {
    testWidgets('lobby preview and components render at $size', (tester) async {
      final preview = buildGamePlayPreview('eleven');
      final parts = buildGameParts('eleven', playerCount: 2);
      expect(preview, isNotNull);
      expect(parts, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.fromSize(size: size, child: preview),
        ),
      );
      // 세 라운드(13.5초)를 지나며 장면마다 넘침 없이 그려지는지 봅니다.
      for (var i = 0; i < 28; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull, reason: 'frame $i');
      }

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.fromSize(
            size: size,
            child: GameDetailStage(child: parts!),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('eleven-judge-strip')), findsOneWidget);
    });
  }

  testWidgets('preview shows the judged sum and score after reveal', (
    tester,
  ) async {
    final previous = GameLocale.current;
    GameLocale.current = const Locale('ko');
    addTearDown(() => GameLocale.current = previous);

    Future<void> frame(int ms) => tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.fromSize(
            size: eleven.elevenPreviewSize,
            child: eleven.ElevenPreviewFrame(ms: ms),
          ),
        ),
      ),
    );

    // 1R 결과: 8 + 3 = 11 → 10 이상이므로 작은 수(B) 승.
    await frame(3000);
    expect(find.text('3 + 8 = 11'), findsOneWidget);
    expect(find.text('합이 10 이상이면 작은 수 승'), findsOneWidget);

    // 2R 결과: 1 + 6 = 7 → 10 미만이므로 큰 수(A) 승.
    await frame(4500 + 3000);
    expect(find.text('1 + 6 = 7'), findsOneWidget);
    expect(find.text('합이 10 미만이면 큰 수 승'), findsOneWidget);

    // 3R 결과: 9 + 11 = 20 → 11 승.
    await frame(9000 + 3000);
    expect(find.text('9 + 11 = 20'), findsOneWidget);
    expect(find.text('9와 11이면 11이 이겨요'), findsOneWidget);
  });
}
