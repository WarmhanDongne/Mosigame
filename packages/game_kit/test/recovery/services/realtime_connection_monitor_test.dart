import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/services/realtime_connection_monitor.dart';

void main() {
  test(
    'refresh reopens a connection source that ended in the background',
    () async {
      final monitor = RealtimeConnectionMonitor.forTesting();
      addTearDown(monitor.dispose);
      final identity = Object();
      final sources = <StreamController<bool>>[];
      addTearDown(() async {
        for (final source in sources) {
          if (!source.isClosed) await source.close();
        }
      });
      Stream<bool> createSource() {
        final source = StreamController<bool>();
        sources.add(source);
        return source.stream;
      }

      final values = <bool>[];
      final subscription = monitor
          .watchConnectionSource(identity, createSource)
          .listen(values.add);
      addTearDown(subscription.cancel);

      sources.single.add(true);
      await Future<void>.delayed(Duration.zero);
      await sources.single.close();
      await Future<void>.delayed(Duration.zero);
      expect(values, [true, false]);

      await monitor.refreshConnectionSource(identity);
      expect(sources, hasLength(2));
      sources.last.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(values, [true, false, true]);
    },
  );

  test('concurrent refresh requests reopen the source only once', () async {
    final monitor = RealtimeConnectionMonitor.forTesting();
    addTearDown(monitor.dispose);
    final identity = Object();
    final sources = <StreamController<bool>>[];
    addTearDown(() async {
      for (final source in sources) {
        if (!source.isClosed) await source.close();
      }
    });
    Stream<bool> createSource() {
      final source = StreamController<bool>();
      sources.add(source);
      return source.stream;
    }

    final subscription = monitor
        .watchConnectionSource(identity, createSource)
        .listen((_) {});
    addTearDown(subscription.cancel);

    await Future.wait([
      monitor.refreshConnectionSource(identity),
      monitor.refreshConnectionSource(identity),
    ]);

    expect(sources, hasLength(2));
  });
}
