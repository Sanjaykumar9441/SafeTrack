import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase configuration for SafeTrack Mobile App.
/// Values taken from google-services.json for Android.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD-44kK4R6XNohpFOkyu5PWNxAdQ2gIms4',
    appId: '1:915377574101:android:df97647ec965b682cdd25c',
    messagingSenderId: '915377574101',
    projectId: 'safedrive-144',
    storageBucket: 'safedrive-144.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD-44kK4R6XNohpFOkyu5PWNxAdQ2gIms4',
    appId: '1:915377574101:android:df97647ec965b682cdd25c',
    messagingSenderId: '915377574101',
    projectId: 'safedrive-144',
    storageBucket: 'safedrive-144.firebasestorage.app',
    iosBundleId: 'com.safetrack.mobile',
  );
}
