import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/services.dart';
import '../models/user_model.dart';

// ============================================================
// SERVICE PROVIDERS
// ============================================================

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Local storage service provider
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

/// Biometric service provider
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

// ============================================================
// AUTH STATE
// ============================================================

/// Current Firebase auth user stream
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Auth state enum
enum AuthState {
  initial,
  unauthenticated,
  authenticated,
  loading,
}

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthStateData> {
  final AuthService _authService;
  final LocalStorageService _localStorage;

  AuthNotifier(this._authService, this._localStorage)
      : super(AuthStateData.initial()) {
    _init();
  }

  Future<void> _init() async {
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        // User is signed in, fetch their data
        await _loadUserData();
      } else {
        // User is signed out
        state = AuthStateData.unauthenticated();
        await _localStorage.clearAll();
      }
    });
  }

  Future<void> _loadUserData() async {
    state = state.copyWith(authState: AuthState.loading);
    
    try {
      // Try to get cached user first
      final cachedUser = await _localStorage.getUser();
      if (cachedUser != null) {
        state = AuthStateData.authenticated(cachedUser);
      }

      // Then fetch fresh data from server
      final userService = UserService();
      final user = await userService.getCurrentUser();
      
      if (user != null) {
        await _localStorage.saveUser(user);
        state = AuthStateData.authenticated(user);
      } else {
        state = AuthStateData.unauthenticated();
      }
    } catch (e) {
      // If fetch fails, use cached data
      final cachedUser = await _localStorage.getUser();
      if (cachedUser != null) {
        state = AuthStateData.authenticated(cachedUser);
      } else {
        state = AuthStateData.unauthenticated();
      }
    }
  }

  /// Sign up with email
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    state = state.copyWith(authState: AuthState.loading);
    
    final result = await _authService.signUpWithEmail(
      email: email,
      password: password,
      fullName: fullName,
      phoneNumber: phoneNumber,
    );

    if (result.success && result.user != null) {
      await _localStorage.saveUser(result.user!);
      state = AuthStateData.authenticated(result.user!);
    } else {
      state = state.copyWith(authState: AuthState.unauthenticated);
    }

    return result;
  }

  /// Sign in with email
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(authState: AuthState.loading);
    
    final result = await _authService.signInWithEmail(
      email: email,
      password: password,
    );

    if (result.success && result.user != null) {
      await _localStorage.saveUser(result.user!);
      state = AuthStateData.authenticated(result.user!);
    } else {
      state = state.copyWith(authState: AuthState.unauthenticated);
    }

    return result;
  }

  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    state = state.copyWith(authState: AuthState.loading);
    
    final result = await _authService.signInWithGoogle();

    if (result.success && result.user != null) {
      await _localStorage.saveUser(result.user!);
      state = AuthStateData.authenticated(result.user!);
    } else {
      state = state.copyWith(authState: AuthState.unauthenticated);
    }

    return result;
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(authState: AuthState.loading);
    await _authService.signOut();
    await _localStorage.clearAll();
    state = AuthStateData.unauthenticated();
  }

  /// Update user data
  void updateUser(UserModel user) {
    state = AuthStateData.authenticated(user);
    _localStorage.saveUser(user);
  }
}

/// Auth state data
class AuthStateData {
  final AuthState authState;
  final UserModel? user;
  final String? error;

  AuthStateData({
    required this.authState,
    this.user,
    this.error,
  });

  factory AuthStateData.initial() {
    return AuthStateData(authState: AuthState.initial);
  }

  factory AuthStateData.unauthenticated() {
    return AuthStateData(authState: AuthState.unauthenticated);
  }

  factory AuthStateData.authenticated(UserModel user) {
    return AuthStateData(authState: AuthState.authenticated, user: user);
  }

  AuthStateData copyWith({
    AuthState? authState,
    UserModel? user,
    String? error,
  }) {
    return AuthStateData(
      authState: authState ?? this.authState,
      user: user ?? this.user,
      error: error ?? this.error,
    );
  }

  bool get isAuthenticated => authState == AuthState.authenticated;
  bool get isLoading => authState == AuthState.loading;
}

/// Auth state provider
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthStateData>((ref) {
  final authService = ref.watch(authServiceProvider);
  final localStorage = ref.watch(localStorageServiceProvider);
  return AuthNotifier(authService, localStorage);
});

/// Current user provider
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authNotifierProvider).user;
});

/// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).isAuthenticated;
});
