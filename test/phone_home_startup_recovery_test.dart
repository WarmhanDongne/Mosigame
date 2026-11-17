import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/template_game.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/phone/screens/phone_home.dart';
import 'package:project00/platform/home/phone/widgets/phone_header.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/widgets/app_startup_surface.dart';

void main() {
  testWidgets('휴대폰 시작은 진행 중 게임을 묻지 않고 자동 복원한다', (tester) async {
    final provider = _Provider();
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneHome(
          gameCatalog: const EmptyGameCatalog(),
          roomProvider: provider,
          games: Future.value(const <GameInfo>[]),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AppStartupSurface), findsOneWidget);
    expect(find.byType(PhoneHeader), findsNothing);

    provider.detection.complete(RestorableSession.activeGame);
    await tester.pump();
    await tester.pump();
    expect(provider.restoreCalls, 1);
    expect(find.text('진행 중인 게임이 있어요'), findsNothing);
    expect(find.text('게임 다시 참여'), findsNothing);
    expect(find.byType(PhoneHeader), findsNothing);
  });
}

class _Provider extends ChangeNotifier implements RoomProvider {
  final detection = Completer<RestorableSession>();
  int restoreCalls = 0;

  @override
  bool get isLeaving => false;
  @override
  bool get isInRoom => false;
  @override
  Stream<bool> watchServerConnection() => Stream.value(true);
  @override
  Future<RestorableSession> detectRestorableSession() => detection.future;
  @override
  Future<bool> restorePlayerRoom() async {
    restoreCalls++;
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
