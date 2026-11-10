// Test-project Firebase options generated from Firebase app registrations.
// API keys identify Firebase apps; they are not service-account credentials.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

abstract final class TestFirebaseOptions {
  static const projectId = 'ban-pick-simulator';
  static const googleWebClientId =
      '127477049099-39oe6etakf0dhs1ugb0j98i3hn7c4org.apps.googleusercontent.com';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
        'Test Firebase options support Android, iOS and web only.',
      ),
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDDw0DN-3Hv5rpSccdjeygfh0XYLVD1txo',
    appId: '1:127477049099:web:c11a93f52655e4a0dd640e',
    messagingSenderId: '127477049099',
    projectId: projectId,
    authDomain: 'ban-pick-simulator.firebaseapp.com',
    databaseURL:
        'https://ban-pick-simulator-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'ban-pick-simulator.firebasestorage.app',
    measurementId: 'G-6B5LV4JJ5T',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCFl3zfVKhRmrBYeOLYHZ4zQM_11bUmf2o',
    appId: '1:127477049099:android:6f08ec7b66fc88f1dd640e',
    messagingSenderId: '127477049099',
    projectId: projectId,
    databaseURL:
        'https://ban-pick-simulator-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'ban-pick-simulator.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDTgUYuAvW017Ufb4WHKkDvFfNuwjkfQh8',
    appId: '1:127477049099:ios:7325f1c2b41106d7dd640e',
    messagingSenderId: '127477049099',
    projectId: projectId,
    databaseURL:
        'https://ban-pick-simulator-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'ban-pick-simulator.firebasestorage.app',
    iosClientId:
        '127477049099-mgdb3u9psnah10llpmd574cm7hdoodlk.apps.googleusercontent.com',
    iosBundleId: 'com.warmhandongne.msg',
  );
}
