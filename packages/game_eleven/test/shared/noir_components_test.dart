// 시안 A 공통 부품(토큰·타일·토스트·모션 상수) 위젯 테스트와 골든(S5-0b 3).
//
// 골든은 macOS에서 만든 PNG라 다른 OS의 글자·안티에일리어싱 차이로 픽셀이 달라질 수
// 있어 macOS에서만 비교한다. 숫자 글꼴은 루트 assets/fonts/StardosStencil-Bold.ttf를
// 불러 실제 글꼴로 그린다(한글은 테스트 기본 글꼴 상자로 그려진다).
// 갱신: packages/game_eleven 에서 `flutter test --update-goldens test/shared/noir_components_test.dart`.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/game_copy.dart';
import 'package:game_eleven/shared/noir/noir_motion.dart';
import 'package:game_eleven/shared/noir/noir_toast_schedule.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';
import 'package:game_eleven/shared/models/timing.dart';
import 'package:game_eleven/shared/widgets/noir_tile.dart';
import 'package:game_eleven/shared/widgets/noir_toast.dart';

final _goldenSkip = Platform.isMacOS
    ? false
    : '골든 PNG는 macOS 기준이다(다른 OS는 글자 렌더링 차이)';

Future<void> _loadNumberFont() async {
  final bytes = File(
    '../../assets/fonts/StardosStencil-Bold.ttf',
  ).readAsBytesSync();
  final loader = FontLoader(ElevenNoirFonts.number)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Widget _stage(Widget child, {Size size = const Size(400, 200)}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    backgroundColor: ElevenNoirColors.table,
    body: Center(
      child: RepaintBoundary(
        key: const ValueKey('golden'),
        child: Container(
          width: size.width,
          height: size.height,
          color: ElevenNoirColors.table,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(_loadNumberFont);

  group('tokens', () {
    test('colors are the screens.md 1-1 values', () {
      expect(ElevenNoirColors.ink, const Color(0xFF141414));
      expect(ElevenNoirColors.cream, const Color(0xFFF7F0E4));
      expect(ElevenNoirColors.table, const Color(0xFF262524));
      expect(ElevenNoirColors.blackTile, const Color(0xFF1B1B1B));
      expect(ElevenNoirColors.red, const Color(0xFFC9242A));
      expect(ElevenNoirColors.accentRed, const Color(0xFFE23A3A));
      expect(ElevenNoirColors.warnRed, const Color(0xFFD42A2F));
      expect(ElevenNoirColors.deepRed, const Color(0xFF8E1A1F));
    });

    test('number font is StardosStencil 700 (decision 8)', () {
      expect(ElevenNoirFonts.number, 'StardosStencil');
      expect(ElevenNoirFonts.numberWeight, FontWeight.w700);
    });
  });

  group('motion constants', () {
    test('bounce curve and toast enter/exit follow MotionKit', () {
      expect(ElevenCurves.bounce, const Cubic(0.3, 1.3, 0.6, 1));
      expect(ElevenToastMotion.enter, const Duration(milliseconds: 200));
      expect(ElevenToastMotion.exit, const Duration(milliseconds: 200));
      expect(ElevenToastMotion.enterOffsetY, 8);
      expect(
        ElevenToastHold.roundResult.duration,
        const Duration(milliseconds: 900),
        reason: '타일 자동 제출 0.9초(결정 5)',
      );
    });

    test('toast schedules match the static tq* cycles in motion.md 2', () {
      List<ElevenToastHold> holds(List<ElevenToastStep> steps) => [
        for (final step in steps) step.hold,
      ];
      // 등장 시작 ~ 마지막 퇴장 끝(ms): T01 1100, T06 1300, T09 1400,
      // T10 3300, T11 3700.
      expect(
        ElevenToastMotion.sequence(holds(ElevenToastSchedule.pickTile())),
        const Duration(milliseconds: 1100),
      );
      expect(
        ElevenToastMotion.sequence(holds(ElevenToastSchedule.autoSubmitted())),
        const Duration(milliseconds: 1300),
      );
      expect(
        ElevenToastMotion.sequence(
          holds(ElevenToastSchedule.roundIntro(6, 'A')),
        ),
        const Duration(milliseconds: 1400),
      );
      expect(
        ElevenToastMotion.sequence(holds(ElevenToastSchedule.earlyEnd('A'))),
        const Duration(milliseconds: 3300),
      );
      expect(
        ElevenToastMotion.sequence(holds(ElevenToastSchedule.tieDrawStart())),
        const Duration(milliseconds: 3700),
      );
      expect(ElevenToastSchedule.earlyEnd('A').last.text, '승자\nA');
      expect(ElevenToastSchedule.earlyEnd('A').first.accent, isFalse);
    });

    test('time bar turns deep red from 10 seconds left (decision 3)', () {
      expect(
        ElevenTimeBarMotion.colorFor(const Duration(seconds: 11)),
        const Color(0xFFD42A2F),
      );
      expect(
        ElevenTimeBarMotion.colorFor(const Duration(seconds: 10)),
        const Color(0xFF8E1A1F),
      );
    });

    test('client timing follows the prototypes (changed in S5-0b)', () {
      expect(ElevenTiming.roundResult, const Duration(milliseconds: 3200));
      expect(ElevenTiming.drawReveal, const Duration(milliseconds: 4700));
      expect(ElevenTiming.roundIntro, const Duration(milliseconds: 1400));
      expect(ElevenTiming.submit, const Duration(milliseconds: 350));
      expect(ElevenTiming.finalWin, const Duration(milliseconds: 1500));
      expect(ElevenDrawMotion.dealAll, const Duration(milliseconds: 500));
    });
  });

  group('toast frames', () {
    final steps = ElevenToastSchedule.earlyEnd('A');

    test('rises 8px while fading in, holds, fades out, then gaps', () {
      final start = ElevenToastFrame.at(steps, Duration.zero);
      expect(start.stepIndex, 0);
      expect(start.opacity, 0);
      expect(start.offsetY, 8);
      final held = ElevenToastFrame.at(
        steps,
        const Duration(milliseconds: 500),
      );
      expect(held.opacity, 1);
      expect(held.offsetY, 0);
      final exiting = ElevenToastFrame.at(
        steps,
        const Duration(milliseconds: 1100),
      );
      expect(exiting.stepIndex, 0);
      expect(exiting.opacity, inExclusiveRange(0, 1));
      expect(exiting.offsetY, 0);
      expect(
        ElevenToastFrame.at(
          steps,
          const Duration(milliseconds: 1300),
        ).stepIndex,
        isNull,
        reason: '단계 사이 0.2초 공백',
      );
      final second = ElevenToastFrame.at(
        steps,
        const Duration(milliseconds: 2000),
      );
      expect(second.stepIndex, 1);
      expect(second.opacity, 1);
      expect(
        ElevenToastFrame.at(
          steps,
          const Duration(milliseconds: 3300),
        ).stepIndex,
        isNull,
      );
    });

    test('reduced motion keeps opacity but drops movement', () {
      final frame = ElevenToastFrame.at(
        steps,
        const Duration(milliseconds: 100),
        reduceMotion: true,
      );
      expect(frame.opacity, inExclusiveRange(0, 1));
      expect(frame.offsetY, 0);
    });
  });

  group('toast widget', () {
    testWidgets('plays once per playKey and ends hidden', (tester) async {
      var finished = 0;
      Widget build(Object key) => _stage(
        ElevenToastSequence(
          steps: ElevenToastSchedule.submitted(),
          playKey: key,
          onFinished: () => finished++,
        ),
        size: const Size(1040, 278),
      );
      await tester.pumpWidget(build('r1'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(ElevenScreenCopy.toastSubmitted), findsNWidgets(2));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(ElevenScreenCopy.toastSubmitted), findsNothing);
      expect(finished, 1);
      // 같은 키로 다시 그려도 재생하지 않는다.
      await tester.pumpWidget(build('r1'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(ElevenScreenCopy.toastSubmitted), findsNothing);
      // 키가 바뀌면 처음부터 재생한다.
      await tester.pumpWidget(build('r2'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(ElevenScreenCopy.toastSubmitted), findsNWidgets(2));
      await tester.pumpAndSettle();
    });

    testWidgets('animate false shows the final (hidden) state', (tester) async {
      await tester.pumpWidget(
        _stage(
          ElevenToastSequence(
            steps: ElevenToastSchedule.pickTile(),
            playKey: 1,
            animate: false,
          ),
        ),
      );
      expect(find.text(ElevenScreenCopy.toastPickTile), findsNothing);
    });
  });

  group('tile', () {
    testWidgets('faces: numbers only on revealed black/white', (tester) async {
      await tester.pumpWidget(
        _stage(
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevenNoirTile(
                face: ElevenTileFace.black,
                spec: ElevenTileSpec.phoneHand,
                value: 6,
              ),
              ElevenNoirTile(
                face: ElevenTileFace.back,
                spec: ElevenTileSpec.drawCard,
                value: 7,
              ),
              ElevenNoirTile(
                face: ElevenTileFace.black,
                spec: ElevenTileSpec.tabletSlot,
              ),
            ],
          ),
          size: const Size(400, 220),
        ),
      );
      // 손패는 가운데 숫자 + 모서리 숫자.
      expect(find.text('6'), findsNWidgets(2));
      // 뒷면은 값을 받아도 그리지 않는다.
      expect(find.text('7'), findsNothing);
      expect(
        tester.getSize(find.byType(ElevenNoirTile).first),
        ElevenTileSpec.phoneHand.size,
      );
    });

    testWidgets('states map to screens.md opacity', (tester) async {
      Future<double?> opacityOf(ElevenTileState state) async {
        await tester.pumpWidget(
          _stage(
            ElevenNoirTile(
              face: ElevenTileFace.white,
              spec: ElevenTileSpec.phoneHand,
              value: 3,
              state: state,
            ),
          ),
        );
        final opacity = find.descendant(
          of: find.byType(ElevenNoirTile),
          matching: find.byType(Opacity),
        );
        return opacity.evaluate().isEmpty
            ? null
            : tester.widget<Opacity>(opacity.first).opacity;
      }

      expect(await opacityOf(ElevenTileState.normal), isNull);
      expect(await opacityOf(ElevenTileState.used), 0.28);
      expect(await opacityOf(ElevenTileState.locked), 0.6);
      expect(await opacityOf(ElevenTileState.dim), 0.35);
      expect(await opacityOf(ElevenTileState.lose), 0.38);
    });

    testWidgets('selected tile shows the badge label', (tester) async {
      await tester.pumpWidget(
        _stage(
          ElevenNoirTile(
            face: ElevenTileFace.black,
            spec: ElevenTileSpec.phoneHand,
            value: 6,
            state: ElevenTileState.selected,
            badgeLabel: ElevenScreenCopy.selectedBadge,
          ),
        ),
      );
      expect(find.text(ElevenScreenCopy.selectedBadge), findsOneWidget);
    });

    testWidgets('empty slot shows a question mark', (tester) async {
      await tester.pumpWidget(
        _stage(
          const ElevenNoirTile(
            face: ElevenTileFace.empty,
            spec: ElevenTileSpec.tabletSlot,
          ),
        ),
      );
      expect(find.text('?'), findsOneWidget);
    });
  });

  group('goldens', () {
    testWidgets('phone hand row: normal, selected, used, locked', (
      tester,
    ) async {
      await tester.pumpWidget(
        _stage(
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: ElevenNoirSpacing.handTileGap,
            children: [
              const ElevenNoirTile(
                face: ElevenTileFace.black,
                spec: ElevenTileSpec.phoneHand,
                value: 0,
              ),
              ElevenNoirTile(
                face: ElevenTileFace.black,
                spec: ElevenTileSpec.phoneHand,
                value: 6,
                state: ElevenTileState.selected,
                badgeLabel: ElevenScreenCopy.selectedBadge,
              ),
              const ElevenNoirTile(
                face: ElevenTileFace.black,
                spec: ElevenTileSpec.phoneHand,
                value: 8,
                state: ElevenTileState.used,
              ),
              const ElevenNoirTile(
                face: ElevenTileFace.white,
                spec: ElevenTileSpec.phoneHand,
                value: 7,
              ),
              const ElevenNoirTile(
                face: ElevenTileFace.white,
                spec: ElevenTileSpec.phoneHand,
                value: 9,
                state: ElevenTileState.locked,
              ),
              const ElevenNoirTile(
                face: ElevenTileFace.black,
                spec: ElevenTileSpec.phonePanel,
                value: 11,
              ),
            ],
          ),
          size: const Size(520, 180),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile('goldens/phone_hand.png'),
      );
    });

    testWidgets('tablet slots and draw cards', (tester) async {
      await tester.pumpWidget(
        _stage(
          const Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 28,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 24,
                children: [
                  ElevenNoirTile(
                    face: ElevenTileFace.black,
                    spec: ElevenTileSpec.tabletSlot,
                  ),
                  ElevenNoirTile(
                    face: ElevenTileFace.white,
                    spec: ElevenTileSpec.tabletSlot,
                    state: ElevenTileState.win,
                  ),
                  ElevenNoirTile(
                    face: ElevenTileFace.back,
                    spec: ElevenTileSpec.tabletDrawSlot,
                  ),
                  ElevenNoirTile(
                    face: ElevenTileFace.empty,
                    spec: ElevenTileSpec.tabletSlot,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 24,
                children: [
                  ElevenNoirTile(
                    face: ElevenTileFace.back,
                    spec: ElevenTileSpec.drawCard,
                  ),
                  ElevenNoirTile(
                    face: ElevenTileFace.back,
                    spec: ElevenTileSpec.drawCard,
                    state: ElevenTileState.picked,
                  ),
                  ElevenNoirTile(
                    face: ElevenTileFace.white,
                    spec: ElevenTileSpec.drawCard,
                    value: 7,
                    numberQuarterTurns: 1,
                  ),
                  ElevenNoirTile(
                    face: ElevenTileFace.black,
                    spec: ElevenTileSpec.drawCard,
                    value: 4,
                    numberQuarterTurns: 3,
                  ),
                  ElevenNoirTile(
                    face: ElevenTileFace.back,
                    spec: ElevenTileSpec.drawCard,
                    state: ElevenTileState.dim,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 24,
                children: [
                  ElevenNoirTile(
                    face: ElevenTileFace.black,
                    spec: ElevenTileSpec.historyCell,
                    state: ElevenTileState.win,
                  ),
                  ElevenNoirTile(
                    face: ElevenTileFace.white,
                    spec: ElevenTileSpec.historyCell,
                    state: ElevenTileState.lose,
                  ),
                  ElevenNoirTile(
                    face: ElevenTileFace.empty,
                    spec: ElevenTileSpec.historyCell,
                  ),
                ],
              ),
            ],
          ),
          size: const Size(720, 440),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile('goldens/tablet_tiles.png'),
      );
    });

    testWidgets('tablet toast text, cream and accent', (tester) async {
      await tester.pumpWidget(
        _stage(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevenToastText(text: '7 : 3'),
              ElevenToastText(text: '11', accent: true),
            ],
          ),
          size: const Size(520, 320),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile('goldens/tablet_toast.png'),
      );
    });
  }, skip: _goldenSkip);
}
