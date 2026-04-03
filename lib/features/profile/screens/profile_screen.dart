import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../widgets/business_logo_section.dart';

/// User profile screen
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _biometricEnabled = false;
  bool _accountBlocked = false;
  String? _accountBlockedBy;

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _loadAccountBlockedState();
  }

  Future<void> _loadBiometricSetting() async {
    final enabled = await SecureStorageService.isBiometricEnabled();
    if (mounted) {
      setState(() => _biometricEnabled = enabled);
    }
  }

  Future<void> _loadAccountBlockedState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _accountBlocked = doc.data()?['accountBlocked'] as bool? ?? false;
        _accountBlockedBy = doc.data()?['accountBlockedBy'] as String?;
      });
    }
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String?> _requestPin(String title) async {
    String? resultHash;
    final pinController = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
              ),
              title: Text(title, style: AppTextStyles.headlineSmall()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    style: AppTextStyles.headlineMedium(),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '\u25CF  \u25CF  \u25CF  \u25CF  \u25CF  \u25CF',
                      hintStyle: AppTextStyles.headlineMedium(color: AppColors.textTertiaryDark),
                      filled: true,
                      fillColor: AppColors.inputBackgroundDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                        borderSide: BorderSide(color: error != null ? AppColors.error : AppColors.inputBorderDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                        borderSide: BorderSide(color: error != null ? AppColors.error : AppColors.inputBorderDark),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    autofocus: true,
                    onChanged: (value) {
                      if (value.length == 6) {
                        resultHash = _hashPin(value);
                        Navigator.of(dialogContext).pop();
                      } else if (error != null) {
                        setDialogState(() => error = null);
                      }
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: AppTextStyles.bodySmall(color: AppColors.error)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    resultHash = null;
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text('Cancel', style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark)),
                ),
              ],
            );
          },
        );
      },
    );
   return resultHash;
  }

  Future<void> _handleBlockAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        ),
        title: Row(
          children: [
            const Icon(Icons.block, color: AppColors.error, size: 24),
            const SizedBox(width: 12),
            Text('Block Account', style: AppTextStyles.headlineSmall()),
          ],
        ),
        content: Text(
          'Are you sure you want to block your account?\n\nThis will prevent all transactions including:\n\u2022 Sending money\n\u2022 Withdrawing funds\n\u2022 Adding money\n\nYou can unblock anytime with your PIN.',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Block Account', style: AppTextStyles.labelMedium(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final pinHash = await _requestPin('Enter PIN to block your account');
    if (pinHash == null) return;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('blockAccount');
      await callable.call({'pinHash': pinHash});

      if (mounted) {
        setState(() {
          _accountBlocked = true;
          _accountBlockedBy = 'user';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account blocked successfully. All transactions are disabled.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String message = 'Failed to block account';
        if (e.toString().contains('Incorrect PIN')) {
          message = 'Incorrect PIN. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleUnblockAccount() async {
    // Check if admin-blocked
    if (_accountBlockedBy == 'admin') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          ),
          title: Text('Account Blocked by Support', style: AppTextStyles.headlineSmall()),
          content: Text(
            'Your account was blocked by customer support for security reasons.\n\nPlease contact our support team to verify your identity and unblock your account.',
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: AppTextStyles.labelMedium(color: AppColors.primary)),
            ),
          ],
        ),
      );
      return;
    }

    final pinHash = await _requestPin('Enter PIN to unblock your account');
    if (pinHash == null) return;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('unblockAccount');
      await callable.call({'pinHash': pinHash});

      if (mounted) {
        setState(() {
          _accountBlocked = false;
          _accountBlockedBy = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account unblocked successfully. All transactions are now enabled.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String message = 'Failed to unblock account';
        if (e.toString().contains('Incorrect PIN')) {
          message = 'Incorrect PIN. Please try again.';
        } else if (e.toString().contains('blocked by support')) {
          message = 'Your account was blocked by support. Please contact customer support.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        ),
        title: Text(AppStrings.logOut, style: AppTextStyles.headlineSmall()),
        content: Text(
          'Are you sure you want to log out?',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              AppStrings.cancel,
              style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Sign out using the auth provider
              await ref.read(authNotifierProvider.notifier).signOut();
              if (mounted) {
                context.go(AppRoutes.welcome);
              }
            },
            child: Text(
              AppStrings.logOut,
              style: AppTextStyles.labelMedium(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get real user data from provider
    final user = ref.watch(currentUserProvider);
    final userName = user?.displayName ?? 'User';
    final email = user?.email ?? '';
    final phone = user?.phoneNumber ?? '';
    final profilePhoto = user?.profilePhotoUrl;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: Text(AppStrings.profile, style: AppTextStyles.headlineMedium()),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
        child: Column(
          children: [
            // Profile Header
            _buildProfileHeader(
              userName: userName,
              email: email,
              phone: phone,
              profilePhoto: profilePhoto,
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: -0.1, end: 0, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceXXL),

            // Account Section
            _buildSection(
              title: AppStrings.accountSettings,
              children: [
                _buildMenuItem(
                  icon: Iconsax.user_edit,
                  title: AppStrings.editProfile,
                  onTap: () => context.push(AppRoutes.editProfile),
                ),
                _buildMenuItem(
                  icon: Iconsax.bank,
                  title: AppStrings.linkedAccounts,
                  onTap: () => context.push(AppRoutes.linkedAccounts),
                ),
              ],
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceLG),

            // Business Logo Section
            Padding(
              padding: const EdgeInsets.only(
                left: AppDimensions.spaceXS,
                bottom: AppDimensions.spaceSM,
              ),
              child: Text(
                'Business',
                style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
              ),
            ),
            const BusinessLogoSection()
                .animate()
                .fadeIn(delay: 150.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceLG),

            // Security Section
            _buildSection(
              title: AppStrings.security,
              children: [
                _buildSwitchItem(
                  icon: Iconsax.finger_scan,
                  title: AppStrings.biometricLogin,
                  value: _biometricEnabled,
                  onChanged: (value) async {
                    if (value) {
                      // Verify biometric is available before enabling
                      final bioService = BiometricService();
                      final canCheck = await bioService.canCheckBiometrics();
                      if (!canCheck) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No biometrics enrolled on this device. Please set up fingerprint or Face ID in device settings.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                        return;
                      }
                    }
                    await SecureStorageService.setBiometricEnabled(value);
                    setState(() => _biometricEnabled = value);
                  },
                ),
                _buildMenuItem(
                  icon: Iconsax.lock,
                  title: AppStrings.changePassword,
                  onTap: () => context.push(AppRoutes.changePassword),
                ),
                _buildMenuItem(
                  icon: Iconsax.key,
                  title: AppStrings.changePin,
                  onTap: () => context.push(AppRoutes.changePin),
                ),
              ],
            ).animate().fadeIn(delay: 250.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceLG),

            // Preferences Section
            _buildSection(
              title: 'Preferences',
              children: [
                _buildCurrencyMenuItem(ref),
                _buildMenuItem(
                  icon: Iconsax.moon,
                  title: 'Appearance',
                  onTap: () => context.push(AppRoutes.themeSettings),
                ),
                _buildMenuItem(
                  icon: Iconsax.notification,
                  title: AppStrings.notifications,
                  onTap: () => context.push(AppRoutes.notificationSettings),
                ),
              ],
            ).animate().fadeIn(delay: 350.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceLG),

            // Account Safety Section
            _buildSection(
              title: 'Account Safety',
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _accountBlocked ? _handleUnblockAccount : _handleBlockAccount,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spaceMD),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _accountBlocked
                                  ? AppColors.error.withOpacity(0.1)
                                  : AppColors.inputBackgroundDark,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                            ),
                            child: Icon(
                              _accountBlocked ? Icons.lock_open : Icons.block,
                              color: _accountBlocked ? AppColors.error : AppColors.textSecondaryDark,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spaceMD),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _accountBlocked ? 'Unblock Account' : 'Block Account',
                                  style: AppTextStyles.bodyMedium(
                                    color: _accountBlocked ? AppColors.error : null,
                                  ),
                                ),
                                Text(
                                  _accountBlocked
                                      ? (_accountBlockedBy == 'admin'
                                          ? 'Blocked by support \u2014 contact us to unblock'
                                          : 'Your account is currently blocked')
                                      : 'Temporarily disable all transactions',
                                  style: AppTextStyles.caption(color: AppColors.textTertiaryDark),
                                ),
                              ],
                            ),
                          ),
                          if (_accountBlocked)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'BLOCKED',
                                style: AppTextStyles.caption(color: AppColors.error),
                              ),
                            )
                          else
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textTertiaryDark,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceLG),

            // Support Section
            _buildSection(
              title: 'Support',
              children: [
                _buildMenuItem(
                  icon: Iconsax.message_question,
                  title: AppStrings.helpSupport,
                  onTap: () => context.push(AppRoutes.helpSupport),
                ),
                _buildMenuItem(
                  icon: Iconsax.info_circle,
                  title: AppStrings.about,
                  onTap: () => context.push(AppRoutes.about),
                ),
              ],
            ).animate().fadeIn(delay: 450.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceXXL),

            // Logout Button
            _buildLogoutButton()
                .animate()
                .fadeIn(delay: 550.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceLG),

            // Version
            Text(
              'Version 1.0.0',
              style: AppTextStyles.caption(color: AppColors.textTertiaryDark),
            ),

            const SizedBox(height: AppDimensions.spaceLG),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required String userName,
    required String email,
    required String phone,
    String? profilePhoto,
  }) {
    // Generate initials from name safely
    String initials = 'U';
    if (userName.isNotEmpty) {
      final parts = userName.split(' ').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    }

    return Column(
      children: [
        // Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary,
              width: 2,
            ),
          ),
          child: profilePhoto != null
              ? ClipOval(
                  child: Image.network(
                    profilePhoto,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        initials,
                        style: AppTextStyles.displaySmall(color: AppColors.primary),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    initials,
                    style: AppTextStyles.displaySmall(color: AppColors.primary),
                  ),
                ),
        ),

        const SizedBox(height: AppDimensions.spaceMD),

        // Name
        Text(
          userName,
          style: AppTextStyles.headlineMedium(),
        ),

        const SizedBox(height: AppDimensions.spaceXXS),

        // Email
        Text(
          email,
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),

        const SizedBox(height: AppDimensions.spaceXXS),

        // Phone
        Text(
          phone,
          style: AppTextStyles.bodySmall(color: AppColors.textTertiaryDark),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimensions.spaceXS,
            bottom: AppDimensions.spaceSM,
          ),
          child: Text(
            title,
            style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMD),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.inputBackgroundDark,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                ),
                child: Icon(
                  icon,
                  color: AppColors.textSecondaryDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppDimensions.spaceMD),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyMedium(),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiaryDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.inputBackgroundDark,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            ),
            child: Icon(
              icon,
              color: AppColors.textSecondaryDark,
              size: 20,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodyMedium(),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.3),
            inactiveThumbColor: AppColors.textSecondaryDark,
            inactiveTrackColor: AppColors.inputBorderDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyMenuItem(WidgetRef ref) {
    final currencyState = ref.watch(currencyNotifierProvider);
    final currency = currencyState.currency;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(AppRoutes.currencySelector),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMD),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.inputBackgroundDark,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                ),
                child: Center(
                  child: Text(
                    currency.flag,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Currency',
                      style: AppTextStyles.bodyMedium(),
                    ),
                    Text(
                      '${currency.name} (${currency.symbol})',
                      style: AppTextStyles.caption(color: AppColors.textSecondaryDark),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiaryDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeightLG,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Iconsax.logout, color: AppColors.error),
        label: Text(
          AppStrings.logOut,
          style: AppTextStyles.labelLarge(color: AppColors.error),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
        ),
      ),
    );
  }
}
