import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBDEGDLAy5RIUhKu2VsltyYuRypGq2WrUU',
    appId: '1:464929383103:web:af422fc8699766ebdd5c0a',
    messagingSenderId: '464929383103',
    projectId: 'smart-aquaponics-addad',
    authDomain: 'smart-aquaponics-addad.firebaseapp.com',
    storageBucket: 'smart-aquaponics-addad.firebasestorage.app',
    measurementId: 'G-HBWCRMHDRQ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDXDIC6xuYHryY9byf07-1HsWFr7Bg3Z3I',
    appId: '1:464929383103:android:12f98921086f327add5c0a',
    messagingSenderId: '464929383103',
    projectId: 'smart-aquaponics-addad',
    storageBucket: 'smart-aquaponics-addad.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBKiVVQcekHnfXRodGqlV3xn38R7ntUWtY',
    appId: '1:464929383103:ios:aa07f1118cab9cd5dd5c0a',
    messagingSenderId: '464929383103',
    projectId: 'smart-aquaponics-addad',
    storageBucket: 'smart-aquaponics-addad.firebasestorage.app',
    iosBundleId: 'com.example.projekakuaponik',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBKiVVQcekHnfXRodGqlV3xn38R7ntUWtY',
    appId: '1:464929383103:ios:aa07f1118cab9cd5dd5c0a',
    messagingSenderId: '464929383103',
    projectId: 'smart-aquaponics-addad',
    storageBucket: 'smart-aquaponics-addad.firebasestorage.app',
    iosBundleId: 'com.example.projekakuaponik',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBDEGDLAy5RIUhKu2VsltyYuRypGq2WrUU',
    appId: '1:464929383103:web:d540b2d8b4d80eeadd5c0a',
    messagingSenderId: '464929383103',
    projectId: 'smart-aquaponics-addad',
    authDomain: 'smart-aquaponics-addad.firebaseapp.com',
    storageBucket: 'smart-aquaponics-addad.firebasestorage.app',
    measurementId: 'G-VBS3P9E2TM',
  );
}
