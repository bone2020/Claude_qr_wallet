import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds signup form data temporarily until KYC is completed
class PendingSignupData {
  final String email;
  final String password;
  final String fullName;
  final String phoneNumber;
  final String countryCode;
  final String currencyCode;

  PendingSignupData({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phoneNumber,
    required this.countryCode,
    required this.currencyCode,
  });
}

class PendingSignupNotifier extends StateNotifier<PendingSignupData?> {
  PendingSignupNotifier() : super(null);

  void setSignupData({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String countryCode,
    required String currencyCode,
  }) {
    state = PendingSignupData(
      email: email,
      password: password,
      fullName: fullName,
      phoneNumber: phoneNumber,
      countryCode: countryCode,
      currencyCode: currencyCode,
    );
  }

  void clear() {
    state = null;
  }

  bool get hasData => state != null;
}

final pendingSignupProvider =
    StateNotifierProvider<PendingSignupNotifier, PendingSignupData?>((ref) {
  return PendingSignupNotifier();
});
