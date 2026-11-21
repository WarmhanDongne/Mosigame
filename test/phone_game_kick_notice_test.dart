import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/phone/widgets/phone_game_kick_notice.dart';

void main() {
  testWidgets('강퇴 안내는 게임을 덮고 5초 뒤 로비 복귀를 요청한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var returns = 0;

    await tester.pumpWidget(
      MaterialApp(home: PhoneGameKickNotice(onReturnToLobby: () => returns++)),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('게임에서 나왔어요'), findsOneWidget);
    expect(find.text('방장이 이 게임에서 내보냈어요'), findsOneWidget);
    expect(find.text('로비로 가기'), findsOneWidget);
    expect(find.text('5초 뒤 자동으로 이동해요'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('1초 뒤 자동으로 이동해요'), findsOneWidget);
    expect(returns, 0);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(returns, 1);
  });

  testWidgets('로비 버튼은 카운트다운을 기다리지 않고 한 번만 복귀를 요청한다', (tester) async {
    var returns = 0;
    await tester.pumpWidget(
      MaterialApp(home: PhoneGameKickNotice(onReturnToLobby: () => returns++)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const Key('phone-game-kick-lobby-button')));
    await tester.pump();
    expect(returns, 1);

    await tester.pump(const Duration(seconds: 5));
    expect(returns, 1);
  });

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('세로·가로 휴대폰에서 강퇴 안내가 넘치지 않는다 ($size)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: PhoneGameKickNotice(onReturnToLobby: () {})),
      );
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.byKey(const Key('phone-game-kick-notice')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
