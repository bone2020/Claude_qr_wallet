import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for sensitive data
/// Uses encrypted storage (Keychain on iOS, EncryptedSharedPreferences on Android)
class SecureStorageService {
  static SecureStorageService? _instance;
  late final FlutterSecureStorage _storage;

  // Storage keys
  static const String _authTokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _pinHashKey = 'pin_hash';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _sessionKeyKey = 'session_key';

  SecureStorageService._() {
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        sharedPreferencesName: 'qr_wallet_secure_prefs',
        preferencesKeyPrefix: 'qrw_',
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        accountName: 'QRWalletAccount',
      ),
    );
  }

  /// Get singleton instance
  static SecureStorageService get instance {
    _instance ??= SecureStorageService._();
    return _instance!;
  }

  // ============================================================
  // AUTH TOKEN MANAGEMENT
  // ============================================================

  /// Store auth token securely
  Future<void> setAuthToken(String token) async {
    await _storage.write(key: _authTokenKey, value: token);
  }

  /// Get stored auth token
  Future<String?> getAuthToken() async {
    return await _storage.read(key: _authTokenKey);
  }

  /// Store refresh token securely
  Future<void> setRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  /// Get stored refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// Clear all auth tokens (on logout)
  Future<void> clearAuthTokens() async {
    await Future.wait([
      _storage.delete(key: _authTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _sessionKeyKey),
    ]);
  }

  // ============================================================
  // PIN MANAGEMENT
  // ============================================================

  /// Store PIN hash (never store plain PIN)
  Future<void> setPinHash(String pinHash) async {
    await _storage.write(key: _pinHashKey, value: pinHash);
  }

  /// Get stored PIN hash
  Future<String?> getPinHash() async {
    return await _storage.read(key: _pinHashKey);
  }

  /// Check if PIN is set
  Future<bool> hasPinSet() async {
    final pinHash = await getPinHash();
    return pinHash != null && pinHash.isNotEmpty;
  }

  /// Clear PIN hash
  Future<void> clearPinHash() async {
    await _storage.delete(key: _pinHashKey);
  }

  // ============================================================
  // BIOMETRIC SETTINGS
  // ============================================================

  /// Set biometric authentication enabled/disabled
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricEnabledKey,
      value: enabled.toString(),
    );
  }

  /// Check if biometric is enabled
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  // ============================================================
  // SESSION MANAGEMENT
  // ============================================================

  /// Store session key for secure operations
  Future<void> setSessionKey(String key) async {
    await _storage.write(key: _sessionKeyKey, value: key);
  }

  /// Get session key
  Future<String?> getSessionKey() async {
    return await _storage.read(key: _sessionKeyKey);
  }

  // ============================================================
  // GENERIC SECURE STORAGE
  // ============================================================

  /// Store any secure value
  Future<void> setSecureValue(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Get any secure value
  Future<String?> getSecureValue(String key) async {
    return await _storage.read(key: key);
  }

  /// Delete a secure value
  Future<void> deleteSecureValue(String key) async {
    await _storage.delete(key: key);
  }

  /// Check if a key exists
  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }

  /// Clear all secure storage (complete wipe)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
