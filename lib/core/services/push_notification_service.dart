import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';

/// Top-level background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
}

/// Push notification service using Firebase Cloud Messaging
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the push notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Notification permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push notifications permission denied');
      return;
    }

    // Initialize local notifications for foreground display
    await _initializeLocalNotifications();

    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle notification tap when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check for initial message (app opened from terminated state via notification)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _initialized = true;
    debugPrint('Push notification service initialized');
  }

  /// Initialize local notifications plugin for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Local notification tapped: ${details.payload}');
      },
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'qr_wallet_transactions',
        'Transaction Notifications',
        description: 'Notifications for wallet transactions and account alerts',
        importance: Importance.high,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Handle foreground messages — show as local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          'qr_wallet_transactions',
          'Transaction Notifications',
          channelDescription: 'Notifications for wallet transactions and account alerts',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: json.encode(message.data),
    );
  }

  /// Handle notification tap — navigate to relevant screen
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');

    final action = message.data['action'] as String?;
    if (action == null) return;

    // Delay to ensure app is fully rendered after cold start
    Future.delayed(const Duration(milliseconds: 500), () {
      final context = rootNavigatorKey.currentContext;
      if (context == null) {
        debugPrint('Navigator context not available for notification tap');
        return;
      }

      switch (action) {
        // Transaction notifications → go to notifications screen
        case 'deposit':
        case 'money_sent':
        case 'money_received':
        case 'withdrawal_completed':
        case 'withdrawal_initiated':
        case 'withdrawal_failed':
        case 'momo_timeout':
          GoRouter.of(context).push(AppRoutes.notifications);
          break;

        // Security notifications → go to profile
        case 'pin_changed':
        case 'account_blocked':
        case 'account_blocked_by_admin':
        case 'account_unblocked':
        case 'suspicious_activity':
          GoRouter.of(context).push(AppRoutes.profile);
          break;

        // Default → notifications screen
        default:
          GoRouter.of(context).push(AppRoutes.notifications);
          break;
      }
    });
  }

  /// Save FCM token to Firestore subcollection (supports multiple devices)
  Future<void> saveTokenToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      debugPrint('FCM Token: $token');

      // Store token in subcollection — each device gets its own document
      // Use token hash as doc ID to avoid duplicates from same device
      final tokenDocId = token.hashCode.toRadixString(16);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fcm_tokens')
          .doc(tokenDocId)
          .set({
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also keep the legacy fcmToken field for backward compatibility
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          // Remove old token doc, add new one
          final oldDocId = token.hashCode.toRadixString(16);
          final newDocId = newToken.hashCode.toRadixString(16);

          final batch = FirebaseFirestore.instance.batch();
          batch.delete(FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('fcm_tokens')
              .doc(oldDocId));
          batch.set(
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .collection('fcm_tokens')
                  .doc(newDocId),
              {
                'token': newToken,
                'platform': Platform.isIOS ? 'ios' : 'android',
                'updatedAt': FieldValue.serverTimestamp(),
              });
          // Update legacy field too
          batch.update(
              FirebaseFirestore.instance.collection('users').doc(currentUser.uid),
              {
                'fcmToken': newToken,
                'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
              });
          await batch.commit();

          debugPrint('FCM Token refreshed and saved');
        }
      });
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  /// Remove THIS device's FCM token on logout (other devices keep theirs)
  Future<void> removeToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await _messaging.getToken();
        if (token != null) {
          final tokenDocId = token.hashCode.toRadixString(16);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('fcm_tokens')
              .doc(tokenDocId)
              .delete();
        }
        // Update legacy field to another active token if any, or delete
        final remainingTokens = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('fcm_tokens')
            .limit(1)
            .get();
        if (remainingTokens.docs.isEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'fcmToken': FieldValue.delete(),
          });
        } else {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'fcmToken': remainingTokens.docs.first.data()['token'],
          });
        }
      }
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('Failed to remove FCM token: $e');
    }
  }
}
