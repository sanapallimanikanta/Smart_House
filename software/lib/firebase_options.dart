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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyACPSQOol--JuzH_PFcTXOQo3Xs13GCeCU',
    appId: '1:1046980457520:web:19658e65f86446b3ef69f5',
    messagingSenderId: '1046980457520',
    projectId: 'led-on-off-8ef7b',
    authDomain: 'led-on-off-8ef7b.firebaseapp.com',
    databaseURL: 'https://led-on-off-8ef7b-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'led-on-off-8ef7b.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyACPSQOol--JuzH_PFcTXOQo3Xs13GCeCU',
    appId: '1:1046980457520:web:19658e65f86446b3ef69f5', // Using web appId as fallback, might not work for Auth but fine for RTDB usually if public rules or using REST styles, but best effort.
    messagingSenderId: '1046980457520',
    projectId: 'led-on-off-8ef7b',
    databaseURL: 'https://led-on-off-8ef7b-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'led-on-off-8ef7b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyACPSQOol--JuzH_PFcTXOQo3Xs13GCeCU',
    appId: '1:1046980457520:web:19658e65f86446b3ef69f5', // Fallback
    messagingSenderId: '1046980457520',
    projectId: 'led-on-off-8ef7b',
    databaseURL: 'https://led-on-off-8ef7b-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'led-on-off-8ef7b.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyACPSQOol--JuzH_PFcTXOQo3Xs13GCeCU',
    appId: '1:1046980457520:web:19658e65f86446b3ef69f5', // Fallback
    messagingSenderId: '1046980457520',
    projectId: 'led-on-off-8ef7b',
    databaseURL: 'https://led-on-off-8ef7b-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'led-on-off-8ef7b.firebasestorage.app',
  );
}
