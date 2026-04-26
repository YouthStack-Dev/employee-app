import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        return ios;
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBklDHnFfOLFrPG85YIgNWGQ-9hz6yzQyg',
    appId: '1:570547490090:ios:09bea603027a0909246253',
    messagingSenderId: '570547490090',
    projectId: 'ets-1-ccb71',
    storageBucket: 'ets-1-ccb71.firebasestorage.app',
    databaseURL: 'https://ets-1-ccb71-default-rtdb.firebaseio.com',
    iosBundleId: 'com.example.employeeFlutter',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBklDHnFfOLFrPG85YIgNWGQ-9hz6yzQyg',
    appId: '1:570547490090:android:09bea603027a0909246253',
    messagingSenderId: '570547490090',
    projectId: 'ets-1-ccb71',
    storageBucket: 'ets-1-ccb71.firebasestorage.app',
    databaseURL: 'https://ets-1-ccb71-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBklDHnFfOLFrPG85YIgNWGQ-9hz6yzQyg',
    appId: '1:570547490090:web:09bea603027a0909246253',
    messagingSenderId: '570547490090',
    projectId: 'ets-1-ccb71',
    storageBucket: 'ets-1-ccb71.firebasestorage.app',
    databaseURL: 'https://ets-1-ccb71-default-rtdb.firebaseio.com',
  );
}
