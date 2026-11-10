import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// One Firebase app for platform and game code. Local credentials/caches live in
/// a named demo app; server mode retains the existing default app.
abstract final class FirebaseBackend {
  static const mode = String.fromEnvironment(
    'MOSIGAME_BACKEND',
    // This branch is dedicated to device testing against ban-pick-simulator.
    // Production builds must come from develop, whose default remains server.
    defaultValue: 'test',
  );
  static const isLocal = mode == 'local';
  static const isTest = mode == 'test';
  static const projectId = 'demo-mosigame-e13';
  static const appName = 'mosigame-local';
  static const _testAppName = 'mosigame-test';
  static const functionsRegion = 'asia-northeast3';
  static const configuredHost = String.fromEnvironment(
    'MOSIGAME_EMULATOR_HOST',
  );

  static String get host => configuredHost.isNotEmpty
      ? configuredHost
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : '127.0.0.1';

  /// Reject a typo or a local release/profile build before initializing any SDK.
  static void validate({
    String backend = mode,
    bool debug = kDebugMode,
    String emulatorHost = configuredHost,
  }) {
    if (backend != 'server' && backend != 'test' && backend != 'local') {
      throw ArgumentError('MOSIGAME_BACKEND must be server, test or local.');
    }
    if (backend == 'local' && !debug) {
      throw StateError('The local Firebase backend requires a debug build.');
    }
    if (emulatorHost.isNotEmpty &&
        !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9.\-]*$').hasMatch(emulatorHost)) {
      throw ArgumentError(
        'MOSIGAME_EMULATOR_HOST must be a host, without a port or scheme.',
      );
    }
  }

  static FirebaseApp get app => isLocal
      ? Firebase.app(appName)
      : isTest
      ? Firebase.app(_testAppName)
      : Firebase.app();
  static FirebaseAuth get auth => isLocal || isTest
      ? FirebaseAuth.instanceFor(app: app)
      : FirebaseAuth.instance;
  static FirebaseFirestore get firestore => isLocal || isTest
      ? FirebaseFirestore.instanceFor(app: app)
      : FirebaseFirestore.instance;
  static FirebaseDatabase get database => FirebaseDatabase.instanceFor(
    app: app,
    databaseURL: app.options.databaseURL,
  );
  static FirebaseFunctions get functions =>
      FirebaseFunctions.instanceFor(app: app, region: functionsRegion);
}
