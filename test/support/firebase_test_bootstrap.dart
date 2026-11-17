import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:project00/firebase_bootstrap.dart';

/// Initializes the default Firebase app and the isolated test backend app.
///
/// Widget tests that exercise game UI can reach [FirebaseBackend] indirectly.
/// In the default test backend mode that means the named `mosigame-test` app,
/// not the default Firebase app.
Future<void> initializeFirebaseAppsForTest() async {
  await Firebase.initializeApp();
  if (FirebaseBackend.isTest) {
    await initializeFirebaseBackend();
  }
}

/// Core host fake which preserves the requested options for named test apps.
///
/// The package-provided [MockFirebaseApp] intentionally returns skeletal
/// options. App UI also constructs Storage services, which require the real
/// test app's `storageBucket` option.
class FirebaseTestCore extends MockFirebaseApp {
  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async => CoreInitializeResponse(
    name: appName,
    options: initializeAppRequest,
    pluginConstants: {},
  );
}
