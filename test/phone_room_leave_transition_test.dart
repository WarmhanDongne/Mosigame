import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/phone/widgets/phone_room_leave_transition.dart';

void main() {
  testWidgets('Scaffold 밖에서 덮여도 나가는 중 문구에 노란 경고 밑줄이 붙지 않는다', (tester) async {
    // 실제 화면처럼 Scaffold·Material 없이 앱 라우트 바로 위에 그립니다. 앱이
    // 최상단에 두는 경고 글자 스타일(노란 이중 밑줄)이 그대로 내려오는 위치입니다.
    await tester.pumpWidget(
      const MaterialApp(
        home: PhoneRoomLeaveTransition(
          stage: PhoneRoomLeaveStage.leaving,
          progress: AlwaysStoppedAnimation(1),
          gameId: null,
          onRetry: _noop,
          onReturn: _noop,
          child: SizedBox.expand(),
        ),
      ),
    );

    for (final text in ['그룹에서 나가는 중이에요', '잠시만 기다려 주세요']) {
      final style = DefaultTextStyle.of(tester.element(find.text(text))).style;
      expect(style.decoration, isNot(TextDecoration.underline), reason: text);
    }
  });
}

void _noop() {}
