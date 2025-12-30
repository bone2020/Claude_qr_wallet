import 'package:hive_flutter/hive_flutter.dart';

import '../../models/models.dart';

/// Local storage service using Hive for offline support
class LocalStorageService {
  static const String _userBoxName = 'user_box';
  static const String _walletBoxName = 'wallet_box';
  static const String _transactionsBoxName = 'transactions_box';
  static const String _settingsBoxName = 'settings_box';
  static const String _pendingTransactionsBoxName = 'pending_transactions_box';

  /// Initialize Hive and register adapters
  static Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(UserModelAdapter());
    Hive.registerAdapter(WalletModelAdapter());
    Hive.registerAdapter(TransactionModelAdapter());
    Hive.registerAdapter(TransactionTypeAdapter());
    Hive.registerAdapter(TransactionStatusAdapter());
  }

  // ============================================================
  // USER DATA
  // ============================================================

  /// Save user data locally
  Future<void> saveUser(UserModel user) async {
    final box = await Hive.openBox<Map>(_userBoxName);
    await box.put('current_user', user.toJson());
  }

  /// Get cached user data
  Future<UserModel?> getUser() async {
    final box = await Hive.openBox<Map>(_userBoxName);
    final data = box.get('current_user');
    if (data == null) return null;
    return UserModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// Clear user data
  Future<void> clearUser() async {
    final box = await Hive.openBox<Map>(_userBoxName);
    await box.delete('current_user');
  }

  // ============================================================
  // WALLET DATA
  // ============================================================

  /// Save wallet data locally
  Future<void> saveWallet(WalletModel wallet) async {
    final box = await Hive.openBox<Map>(_walletBoxName);
    await box.put('current_wallet', wallet.toJson());
  }

  /// Get cached wallet data
  Future<WalletModel?> getWallet() async {
    final box = await Hive.openBox<Map>(_walletBoxName);
    final data = box.get('current_wallet');
    if (data == null) return null;
    return WalletModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// Clear wallet data
  Future<void> clearWallet() async {
    final box = await Hive.openBox<Map>(_walletBoxName);
    await box.delete('current_wallet');
  }

  // ============================================================
  // TRANSACTIONS
  // ============================================================

  /// Save transactions locally (for offline viewing)
  Future<void> saveTransactions(List<TransactionModel> transactions) async {
    final box = await Hive.openBox<List>(_transactionsBoxName);
    final jsonList = transactions.map((t) => t.toJson()).toList();
    await box.put('transactions', jsonList);
  }

  /// Get cached transactions
  Future<List<TransactionModel>> getTransactions() async {
    final box = await Hive.openBox<List>(_transactionsBoxName);
    final data = box.get('transactions');
    if (data == null) return [];
    
    return data
        .map((item) => TransactionModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Add single transaction to cache
  Future<void> addTransaction(TransactionModel transaction) async {
    final transactions = await getTransactions();
    transactions.insert(0, transaction);
    
    // Keep only last 100 transactions
    if (transactions.length > 100) {
      transactions.removeRange(100, transactions.length);
    }
    
    await saveTransactions(transactions);
  }

  /// Clear transactions cache
  Future<void> clearTransactions() async {
    final box = await Hive.openBox<List>(_transactionsBoxName);
    await box.delete('transactions');
  }

  // ============================================================
  // PENDING TRANSACTIONS (Offline Queue)
  // ============================================================

  /// Save pending transaction for later sync
  Future<void> savePendingTransaction(Map<String, dynamic> transaction) async {
    final box = await Hive.openBox<List>(_pendingTransactionsBoxName);
    final pending = box.get('pending', defaultValue: [])!;
    pending.add({
      ...transaction,
      'queuedAt': DateTime.now().toIso8601String(),
    });
    await box.put('pending', pending);
  }

  /// Get all pending transactions
  Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    final box = await Hive.openBox<List>(_pendingTransactionsBoxName);
    final pending = box.get('pending', defaultValue: [])!;
    return pending.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  /// Remove pending transaction after sync
  Future<void> removePendingTransaction(String id) async {
    final box = await Hive.openBox<List>(_pendingTransactionsBoxName);
    final pending = box.get('pending', defaultValue: [])!;
    pending.removeWhere((item) => item['id'] == id);
    await box.put('pending', pending);
  }

  /// Clear all pending transactions
  Future<void> clearPendingTransactions() async {
    final box = await Hive.openBox<List>(_pendingTransactionsBoxName);
    await box.put('pending', []);
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  /// Save setting
  Future<void> saveSetting(String key, dynamic value) async {
    final box = await Hive.openBox(_settingsBoxName);
    await box.put(key, value);
  }

  /// Get setting
  Future<T?> getSetting<T>(String key, {T? defaultValue}) async {
    final box = await Hive.openBox(_settingsBoxName);
    return box.get(key, defaultValue: defaultValue) as T?;
  }

  /// Get all settings
  Future<Map<String, dynamic>> getAllSettings() async {
    final box = await Hive.openBox(_settingsBoxName);
    return Map<String, dynamic>.from(box.toMap());
  }

  /// Common settings keys
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyDarkMode = 'dark_mode';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyLastSyncTime = 'last_sync_time';
  static const String keyBalanceHidden = 'balance_hidden';
  static const String keyCurrency = 'currency';

  // ============================================================
  // AUTHENTICATION TOKENS
  // ============================================================

  /// Save auth token (for biometric re-auth)
  Future<void> saveAuthToken(String token) async {
    final box = await Hive.openBox(_settingsBoxName);
    await box.put('auth_token', token);
  }

  /// Get auth token
  Future<String?> getAuthToken() async {
    final box = await Hive.openBox(_settingsBoxName);
    return box.get('auth_token') as String?;
  }

  /// Clear auth token
  Future<void> clearAuthToken() async {
    final box = await Hive.openBox(_settingsBoxName);
    await box.delete('auth_token');
  }

  // ============================================================
  // CLEAR ALL DATA
  // ============================================================

  /// Clear all local data (on logout)
  Future<void> clearAll() async {
    await clearUser();
    await clearWallet();
    await clearTransactions();
    await clearPendingTransactions();
    await clearAuthToken();
    
    // Keep settings like dark mode preference
    final box = await Hive.openBox(_settingsBoxName);
    final darkMode = box.get(keyDarkMode);
    await box.clear();
    if (darkMode != null) {
      await box.put(keyDarkMode, darkMode);
    }
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    final timestamp = await getSetting<String>(keyLastSyncTime);
    if (timestamp == null) return null;
    return DateTime.parse(timestamp);
  }

  /// Update last sync timestamp
  Future<void> updateLastSyncTime() async {
    await saveSetting(keyLastSyncTime, DateTime.now().toIso8601String());
  }
}
