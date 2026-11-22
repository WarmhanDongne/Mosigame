import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/sound/game_background_music.dart';
import 'package:game_kit/sound/providers/sound_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('게임 BGM은 백그라운드에서 멈추고 복귀하면 이어서 재생한다', (tester) async {
    final sound = _Sound();
    final music = GameBackgroundMusic();
    await tester.pumpWidget(
      ChangeNotifierProvider<SoundProvider>.value(
        value: sound,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              music.attach(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    music.start('game.m4a');
    await tester.pump();
    expect(sound.calls, ['play game.m4a']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(sound.calls.last, 'pause');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(sound.calls.last, 'resume');

    music.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Sound extends SoundProvider {
  _Sound() : super(preferences: _Preferences());

  final calls = <String>[];

  @override
  Future<void> playBgm(String assetPath) async => calls.add('play $assetPath');

  @override
  Future<void> pauseBgm() async => calls.add('pause');

  @override
  Future<void> resumeBgm() async => calls.add('resume');

  @override
  Future<void> stopBgm() async => calls.add('stop');
}

class _Preferences implements SharedPreferencesAsync {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
