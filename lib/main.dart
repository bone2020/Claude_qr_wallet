import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:smile_id/smile_id.dart';
import 'firebase_options.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/services.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/widgets/responsive_wrapper.dart';
import 'providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase Crashlytics
  if (kDebugMode) {
    // Disable Crashlytics collection in debug mode
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
  } else {
    // Enable Crashlytics in release mode
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  }

  // Catch Flutter framework errors
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  // Catch async errors not caught by Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Initialize Firebase App Check
  if (kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  } else {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
  }

  // Initialize Push Notifications
  final pushService = PushNotificationService();
  await pushService.initialize();

  // Initialize Smile ID for KYC verification
  SmileID.initialize(useSandbox: kDebugMode, enableCrashReporting: !kDebugMode);
  SmileID.setCallbackUrl(
    callbackUrl: Uri.parse(
      'https://us-central1-qr-wallet-1993.cloudfunctions.net/smileIdWebhook',
    ),
  );

  // Initialize local storage (Hive)
  await LocalStorageService.initialize();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: QRWalletApp(),
    ),
  );
}

class QRWalletApp extends ConsumerWidget {
  const QRWalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeNotifierProvider);

    return MaterialApp.router(
      title: 'QR Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Cap text scale factor at 1.5x to prevent layout overflow at extreme sizes
        final mediaQuery = MediaQuery.of(context);
        final cappedTextScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.5,
        );

        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: cappedTextScaler),
          child: ResponsiveWrapper(
            child: DeepLinkWrapper(
              child: Column(
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final connectivity = ref.watch(connectivityProvider);
                      return connectivity.when(
                        data: (isOnline) => isOnline
                            ? const SizedBox.shrink()
                            : const _OfflineBanner(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  ),
                  Expanded(child: child ?? const SizedBox.shrink()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Banner shown when the device is offline
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          bottom: 8,
          left: 16,
          right: 16,
        ),
        color: const Color(0xFFFF9800),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              'You are offline',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper widget to initialize deep link handling
class DeepLinkWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const DeepLinkWrapper({super.key, required this.child});

  @override
  ConsumerState<DeepLinkWrapper> createState() => _DeepLinkWrapperState();
}

class _DeepLinkWrapperState extends ConsumerState<DeepLinkWrapper>
    with WidgetsBindingObserver {
  final _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('DeepLinkWrapper: Initializing deep link service');
      _deepLinkService.init(ref.read(routerProvider));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('App lifecycle state changed: $state');
    // Re-sync router when app resumes from background
    if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed - syncing router with deep link service');
      _deepLinkService.setRouter(ref.read(routerProvider));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update router reference when dependencies change
    _deepLinkService.setRouter(ref.read(routerProvider));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
