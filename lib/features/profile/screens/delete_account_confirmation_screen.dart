import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/biometric_service.dart';
import '../../auth/widgets/custom_text_field.dart';

/// Step 3 of the delete-account flow.
///
/// The final friction gate: the user must type DELETE exactly and re-confirm
/// their identity (password re-auth for email/password accounts, or biometric).
/// On success it navigates to Processing via `go` so the back button cannot
/// return here mid-deletion.
class DeleteAccountConfirmationScreen extends ConsumerStatefulWidget {
  /// When true, the request to deleteUserData carries `confirmForfeit: true`
  /// to authorise the server-side sub-threshold balance sweep. Set by the
  /// forfeit-consent screen via route extra.
  final bool confirmForfeit;

  const DeleteAccountConfirmationScreen({
    super.key,
    this.confirmForfeit = false,
  });

  @override
  ConsumerState<DeleteAccountConfirmationScreen> createState() =>
      _DeleteAccountConfirmationScreenState();
}

class _DeleteAccountConfirmationScreenState
    extends ConsumerState<DeleteAccountConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isReauthenticating = false;
  String? _reauthError;
  bool _confirmMatches = false;
  bool _biometricVerified = false;
  bool _biometricAvailable = false;

  /// Primary sign-in method: 'password', 'phone', 'google.com', 'apple.com',
  /// or 'unknown'. Phase 1 only implements re-auth for 'password'.
  String _primaryProvider = 'unknown';

  @override
  void initState() {
    super.initState();
    _resolvePrimaryProvider();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _confirmController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _resolvePrimaryProvider() {
    final providers = FirebaseAuth.instance.currentUser?.providerData ?? [];
    if (providers.any((p) => p.providerId == 'password')) {
      _primaryProvider = 'password';
    } else if (providers.isNotEmpty) {
      _primaryProvider = providers.first.providerId;
    } else {
      _primaryProvider = 'unknown';
    }
  }

  Future<void> _checkBiometricAvailability() async {
    final service = BiometricService();
    final supported = await service.isDeviceSupported();
    final canCheck = await service.canCheckBiometrics();
    if (!mounted) return;
    setState(() => _biometricAvailable = supported && canCheck);
  }

  bool get _requiresPasswordReauth =>
      _primaryProvider == 'password' && !_biometricVerified;

  bool get _canDelete {
    if (_isReauthenticating) return false;
    if (!_confirmMatches) return false;
    if (_requiresPasswordReauth) {
      return _passwordController.text.isNotEmpty;
    }
    return true;
  }

  Future<void> _onBiometric() async {
    final result = await BiometricService()
        .authenticate(reason: 'Confirm account deletion');
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _biometricVerified = true;
        _reauthError = null;
      });
    } else {
      setState(() => _reauthError =
          'Biometric authentication failed. Enter your password instead.');
    }
  }

  Future<void> _onDelete() async {
    setState(() {
      _isReauthenticating = true;
      _reauthError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        context.go(AppRoutes.welcome);
        return;
      }

      if (_requiresPasswordReauth) {
        if (!(_formKey.currentState?.validate() ?? false)) {
          setState(() => _isReauthenticating = false);
          return;
        }
        final email = user.email;
        if (email == null) {
          setState(() {
            _reauthError = 'No email on file for re-authentication.';
            _isReauthenticating = false;
          });
          return;
        }
        final credential = EmailAuthProvider.credential(
          email: email,
          password: _passwordController.text,
        );
        await user.reauthenticateWithCredential(credential);

        // Force a fresh ID token so the next httpsCallable invocation
        // (deleteUserData, called from the processing screen) carries
        // the post-reauth token. Without this, cloud_functions may
        // attach a stale/cached pre-reauth token that the Functions
        // gateway rejects with `unauthenticated` — the function body
        // never executes and nothing is logged on the server.
        await user.getIdToken(true);
      }
      // TODO(Phase 2): implement proper re-authentication for 'phone',
      // 'google.com' and 'apple.com' providers. Phase 1 relies on the
      // typed-DELETE confirmation (plus biometric where available) for those.

      if (!mounted) return;
      // Use go (not push) so the back button can't return here mid-deletion.
      // Forward confirmForfeit so the processing screen can pass it to the
      // server when invoking deleteUserData.
      context.go(
        AppRoutes.deleteAccountProcessing,
        extra: <String, dynamic>{'confirmForfeit': widget.confirmForfeit},
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Re-authentication failed. Please try again.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Incorrect password. Please try again.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later.';
      }
      setState(() {
        _reauthError = message;
        _isReauthenticating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reauthError = 'Something went wrong. Please try again.';
        _isReauthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryDark),
          onPressed: () => context.pop(),
        ),
        title: Text('Confirm deletion', style: AppTextStyles.headlineMedium()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.spaceLG),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: AppDimensions.iconXL,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceLG),
                Text(
                  'This is your last chance',
                  style: AppTextStyles.headlineSmall(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spaceMD),
                Text(
                  'Type DELETE below to confirm. This cannot be undone.',
                  style: AppTextStyles.bodyMedium(color: AppColors.textPrimaryDark)
                      .copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spaceLG),

                CustomTextField(
                  controller: _confirmController,
                  label: 'Type DELETE',
                  hintText: 'DELETE',
                  onChanged: (value) =>
                      setState(() => _confirmMatches = value.trim() == 'DELETE'),
                ),

                if (_primaryProvider == 'password') ...[
                  const SizedBox(height: AppDimensions.spaceMD),
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hintText: 'Enter your password',
                    obscureText: true,
                    enabled: !_biometricVerified,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (_requiresPasswordReauth &&
                          (value == null || value.isEmpty)) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spaceXS),
                  Text(
                    'Re-enter your password to confirm this is you',
                    style:
                        AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                  ),
                ],

                if (_biometricAvailable) ...[
                  const SizedBox(height: AppDimensions.spaceMD),
                  OutlinedButton.icon(
                    onPressed: _isReauthenticating ? null : _onBiometric,
                    icon: const Icon(Icons.fingerprint, color: AppColors.primary),
                    label: Text(
                      _biometricVerified
                          ? 'Identity verified'
                          : 'Use fingerprint / Face ID instead',
                      style: AppTextStyles.labelLarge(color: AppColors.primary),
                    ),
                  ),
                ],

                if (_reauthError != null) ...[
                  const SizedBox(height: AppDimensions.spaceMD),
                  Text(
                    _reauthError!,
                    style: AppTextStyles.bodySmall(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: AppDimensions.spaceXL),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isReauthenticating ? null : () => context.pop(),
                        child: Text('Cancel', style: AppTextStyles.labelLarge()),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceMD),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                        onPressed: _canDelete ? _onDelete : null,
                        child: _isReauthenticating
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Delete my account permanently',
                                style: AppTextStyles.labelLarge(
                                    color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceMD),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
