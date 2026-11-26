import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/announcements/models/platform_announcement.dart';
import 'package:project00/platform/announcements/widgets/platform_announcement_dialog.dart';

void main() {
  const notice = PlatformAnnouncement(
    kind: PlatformAnnouncementKind.notice,
    active: true,
    localized: {
      'ko': PlatformAnnouncementCopy(title: '새 소식', body: '상점에서 확인하세요.'),
    },
  );
  const maintenance = PlatformAnnouncement(
    kind: PlatformAnnouncementKind.maintenance,
    active: true,
    localized: {
      'ko': PlatformAnnouncementCopy(title: '점검 안내', body: '잠시 뒤 만나요.'),
    },
    maintenancePeriod: '15:00 - 16:00',
  );

  Future<void> openDialog(
    WidgetTester tester, {
    required Size size,
    required PlatformAnnouncement announcement,
    VoidCallback? onOpenStore,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    unawaited(
      showPlatformAnnouncementDialog(
        context: hostContext,
        announcement: announcement,
        onOpenStore: onOpenStore,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('태블릿 공지는 닫기와 상점으로 버튼 폭이 같다', (tester) async {
    var storeOpened = false;
    await openDialog(
      tester,
      size: const Size(1024, 768),
      announcement: notice,
      onOpenStore: () => storeOpened = true,
    );

    final close = find.widgetWithText(MosiButton, '닫기');
    final store = find.widgetWithText(MosiButton, '상점으로');
    expect(close, findsOneWidget);
    expect(store, findsOneWidget);
    expect(tester.getSize(close).width, tester.getSize(store).width);

    await tester.tap(store);
    await tester.pumpAndSettle();
    expect(storeOpened, isTrue);
    expect(find.text('새 소식'), findsNothing);
  });

  testWidgets('휴대폰 공지는 긴 닫기 버튼 하나만 표시한다', (tester) async {
    await openDialog(
      tester,
      size: const Size(390, 844),
      announcement: notice,
      onOpenStore: () {},
    );

    final close = find.widgetWithText(MosiButton, '닫기');
    expect(close, findsOneWidget);
    expect(find.text('상점으로'), findsNothing);
    expect(tester.getSize(close).width, greaterThan(270));
  });

  testWidgets('점검 모달은 버튼이 없고 바깥 터치와 뒤로가기로 닫히지 않는다', (tester) async {
    await openDialog(
      tester,
      size: const Size(390, 844),
      announcement: maintenance,
    );

    expect(find.byType(MosiButton), findsNothing);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('점검 안내'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('점검 안내'), findsOneWidget);
  });

  testWidgets('공지와 점검 모달의 상단 가로선을 카드 폭만큼 가린다', (tester) async {
    for (final announcement in [notice, maintenance]) {
      await openDialog(
        tester,
        size: const Size(390, 844),
        announcement: announcement,
      );

      final mask = find.byKey(const Key('platform-announcement-top-rule-mask'));
      expect(mask, findsOneWidget);
      expect(tester.getSize(mask).width, greaterThan(280));

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
    }
  });
}
