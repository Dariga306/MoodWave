import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDoetN0rxAbriHE8B4N_W7Mra_caZE5iPY',
    authDomain: 'moodwave-a4adb-98e29.firebaseapp.com',
    projectId: 'moodwave-a4adb-98e29',
    storageBucket: 'moodwave-a4adb-98e29.firebasestorage.app',
    messagingSenderId: '13338581238',
    appId: '1:13338581238:web:6a0a4178e76cdceaf1f4d7',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDoetN0rxAbriHE8B4N_W7Mra_caZE5iPY',
    appId: '1:13338581238:web:6a0a4178e76cdceaf1f4d7',
    messagingSenderId: '13338581238',
    projectId: 'moodwave-a4adb-98e29',
    storageBucket: 'moodwave-a4adb-98e29.firebasestorage.app',
  );
}
