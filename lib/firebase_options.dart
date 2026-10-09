// Firebase project settings for each platform; FlutterFire generated this file.
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
/// Returns the Firebase settings for the platform running RangerNet.
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
    apiKey: 'AIzaSyAUZ-x80KwQUTZsSKGJmoCqCMSKfgV72hA',
    appId: '1:991758102233:web:b8598330553076173258c8',
    messagingSenderId: '991758102233',
    projectId: 'rangernet',
    authDomain: 'rangernet.firebaseapp.com',
    storageBucket: 'rangernet.firebasestorage.app',
    measurementId: 'G-F80C907V95',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCl_ezvsuZxhDZVc5xGDgx5Vr4glC0l-1o',
    appId: '1:991758102233:android:ee56d551a6ed620a3258c8',
    messagingSenderId: '991758102233',
    projectId: 'rangernet',
    storageBucket: 'rangernet.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDjTy-JGvxOY4_JfPB-jgrhsJGo8SVvwbM',
    appId: '1:229269952910:ios:b8a896c1462f911c0cecdf',
    messagingSenderId: '229269952910',
    projectId: 'rangernet-wildlife-2',
    storageBucket: 'rangernet-wildlife-2.firebasestorage.app',
    iosBundleId: 'lk.rangernet.rangernet',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDjTy-JGvxOY4_JfPB-jgrhsJGo8SVvwbM',
    appId: '1:229269952910:ios:b8a896c1462f911c0cecdf',
    messagingSenderId: '229269952910',
    projectId: 'rangernet-wildlife-2',
    storageBucket: 'rangernet-wildlife-2.firebasestorage.app',
    iosBundleId: 'lk.rangernet.rangernet',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAnc0ZJlWIRXvaYMDrkIbW0TkXYkjy3s6Y',
    appId: '1:229269952910:web:076ce8e3e91b23bd0cecdf',
    messagingSenderId: '229269952910',
    projectId: 'rangernet-wildlife-2',
    authDomain: 'rangernet-wildlife-2.firebaseapp.com',
    storageBucket: 'rangernet-wildlife-2.firebasestorage.app',
  );
}
