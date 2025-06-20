// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
    apiKey: 'AIzaSyB-LBr4r4t5Cc6hQm3CQOYkb9leq0qwDYk',
    appId: '1:249664250866:web:f545b2d1003668bb14016b',
    messagingSenderId: '249664250866',
    projectId: 'authapp2025',
    authDomain: 'authapp2025.firebaseapp.com',
    storageBucket: 'authapp2025.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCI9MlpZhhQv-5jUt3oS1mJ0Oyb89Cu2IY',
    appId: '1:249664250866:android:593f746c6857978414016b',
    messagingSenderId: '249664250866',
    projectId: 'authapp2025',
    storageBucket: 'authapp2025.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDuULMSHjuEEJ-nCppgUIYsnvvT2713rJI',
    appId: '1:249664250866:ios:fd82094caa64e1a614016b',
    messagingSenderId: '249664250866',
    projectId: 'authapp2025',
    storageBucket: 'authapp2025.firebasestorage.app',
    iosBundleId: 'com.example.authApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDuULMSHjuEEJ-nCppgUIYsnvvT2713rJI',
    appId: '1:249664250866:ios:fd82094caa64e1a614016b',
    messagingSenderId: '249664250866',
    projectId: 'authapp2025',
    storageBucket: 'authapp2025.firebasestorage.app',
    iosBundleId: 'com.example.authApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyB-LBr4r4t5Cc6hQm3CQOYkb9leq0qwDYk',
    appId: '1:249664250866:web:0c3bb02aa8d7082614016b',
    messagingSenderId: '249664250866',
    projectId: 'authapp2025',
    authDomain: 'authapp2025.firebaseapp.com',
    storageBucket: 'authapp2025.firebasestorage.app',
  );
}
