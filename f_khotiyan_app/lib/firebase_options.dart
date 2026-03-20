// File generated from google-services.json — project: f-khotiyan
// DO NOT EDIT — regenerate via: flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web platform not configured.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS not configured — add GoogleService-Info.plist.');
      default:
        throw UnsupportedError('Platform not supported.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBo34Z01bvkiCRy3p_BFRNPQ3sJ1Dcu-UA',
    appId: '1:93374871738:android:22f3eae62934215c4a6a83',
    messagingSenderId: '93374871738',
    projectId: 'f-khotiyan',
    storageBucket: 'f-khotiyan.firebasestorage.app',
  );
}
