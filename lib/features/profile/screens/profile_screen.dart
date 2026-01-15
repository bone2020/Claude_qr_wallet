import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';

/// User profile screen
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _darkMode = true;
  bool _biometricEnabled = true;

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
    final userName = user?.fullName ?? 'User';
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
                  onTap: () {
                    // TODO: Navigate to linked accounts
                  },
                ),
              ],
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceLG),

            // Security Section
            _buildSection(
              title: AppStrings.security,
              children: [
                _buildSwitchItem(
                  icon: Iconsax.finger_scan,
                  title: AppStrings.biometricLogin,
                  value: _biometricEnabled,
                  onChanged: (value) {
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
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceLG),

            // Preferences Section
            _buildSection(
              title: 'Preferences',
              children: [
                _buildCurrencyMenuItem(ref),
                _buildSwitchItem(
                  icon: Iconsax.moon,
                  title: AppStrings.darkMode,
                  value: _darkMode,
                  onChanged: (value) {
                    setState(() => _darkMode = value);
                    // TODO: Implement theme switching
                  },
                ),
                _buildMenuItem(
                  icon: Iconsax.notification,
                  title: AppStrings.notifications,
                  onTap: () => context.push(AppRoutes.notificationSettings),
                ),
              ],
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

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
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceXXL),

            // Logout Button
            _buildLogoutButton()
                .animate()
                .fadeIn(delay: 500.ms, duration: 400.ms),

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
