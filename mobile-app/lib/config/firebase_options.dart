import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase configuration for SafeTrack Mobile App.
///
/// Values are injected at build time via --dart-define flags.
/// Example:
///   flutter run \
///     --dart-define=FIREBASE_API_KEY=your-api-key \
///     --dart-define=FIREBASE_APP_ID=your-app-id \
///     --dart-define=FIREBASE_MESSAGING_SENDER_ID=your-sender-id \
///     --dart-define=FIREBASE_PROJECT_ID=your-project-id \
///     --dart-define=FIREBASE_STORAGE_BUCKET=your-bucket \
///     --dart-define=FIREBASE_IOS_BUNDLE_ID=com.safetrack.mobile
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.safetrack.mobile',
  );

  static final FirebaseOptions android = FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );

  static final FirebaseOptions ios = FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: _iosBundleId,
  );
}
