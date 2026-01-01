import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration options for qr-wallet-1993
class FirebaseConfig {
  FirebaseConfig._();

  /// Initialize Firebase with platform-specific options
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: _currentPlatformOptions,
    );
  }

  /// Get platform-specific Firebase options
  static FirebaseOptions get _currentPlatformOptions {
    if (kIsWeb) {
      return _webOptions;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidOptions;
      case TargetPlatform.iOS:
        return _iosOptions;
      case TargetPlatform.macOS:
        return _macOSOptions;
      default:
        throw UnsupportedError(
          'FirebaseConfig is not configured for this platform.',
        );
    }
  }

  // ============================================================
  // FIREBASE CONFIGURATION - qr-wallet-1993
  // ============================================================

  /// Android Firebase options (from google-services.json)
  static const FirebaseOptions _androidOptions = FirebaseOptions(
    apiKey: 'AIzaSyB961nijBwZ0vrgULyERZUtDNI2-hhQRRY',
    appId: '1:123632722078:android:34d26d8cb7235f3a7a5b8f',
    messagingSenderId: '123632722078',
    projectId: 'qr-wallet-1993',
    storageBucket: 'qr-wallet-1993.firebasestorage.app',
  );

  /// iOS Firebase options
  /// TODO: Update with values from GoogleService-Info.plist when you add iOS
  static const FirebaseOptions _iosOptions = FirebaseOptions(
    apiKey: 'AIzaSyB961nijBwZ0vrgULyERZUtDNI2-hhQRRY',
    appId: '1:123632722078:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '123632722078',
    projectId: 'qr-wallet-1993',
    storageBucket: 'qr-wallet-1993.firebasestorage.app',
    iosBundleId: 'com.qrwallet1993',
  );

  /// Web Firebase options
  static const FirebaseOptions _webOptions = FirebaseOptions(
    apiKey: 'AIzaSyB961nijBwZ0vrgULyERZUtDNI2-hhQRRY',
    appId: '1:123632722078:web:YOUR_WEB_APP_ID',
    messagingSenderId: '123632722078',
    projectId: 'qr-wallet-1993',
    storageBucket: 'qr-wallet-1993.firebasestorage.app',
    authDomain: 'qr-wallet-1993.firebaseapp.com',
  );

  /// macOS Firebase options
  static const FirebaseOptions _macOSOptions = FirebaseOptions(
    apiKey: 'AIzaSyB961nijBwZ0vrgULyERZUtDNI2-hhQRRY',
    appId: '1:123632722078:ios:YOUR_MACOS_APP_ID',
    messagingSenderId: '123632722078',
    projectId: 'qr-wallet-1993',
    storageBucket: 'qr-wallet-1993.firebasestorage.app',
    iosBundleId: 'com.qrwallet1993',
  );
}
