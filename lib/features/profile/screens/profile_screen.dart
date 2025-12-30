import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';

/// User profile screen
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _darkMode = true;
  bool _biometricEnabled = true;

  // Mock user data - replace with actual data
  final String _userName = 'John Doe';
  final String _email = 'john.doe@email.com';
  final String _phone = '+234 803 123 4567';
  final String? _profilePhoto = null;

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppStrings.cancel,
              style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement logout
              context.go(AppRoutes.welcome);
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
            _buildProfileHeader()
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
                  onTap: () {
                    // TODO: Navigate to change password
                  },
                ),
                _buildMenuItem(
                  icon: Iconsax.key,
                  title: AppStrings.changePin,
                  onTap: () {
                    // TODO: Navigate to change PIN
                  },
                ),
              ],
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: AppDimensions.spaceLG),

            // Preferences Section
            _buildSection(
              title: 'Preferences',
              children: [
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
                  onTap: () {
                    // TODO: Navigate to notifications settings
                  },
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
                  onTap: () {
                    // TODO: Navigate to help & support
                  },
                ),
                _buildMenuItem(
                  icon: Iconsax.info_circle,
                  title: AppStrings.about,
                  onTap: () {
                    // TODO: Navigate to about
                  },
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

  Widget _buildProfileHeader() {
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
          child: _profilePhoto != null
              ? ClipOval(
                  child: Image.network(
                    _profilePhoto!,
                    fit: BoxFit.cover,
                  ),
                )
              : Center(
                  child: Text(
                    _userName.split(' ').map((e) => e[0]).take(2).join().toUpperCase(),
                    style: AppTextStyles.displaySmall(color: AppColors.primary),
                  ),
                ),
        ),

        const SizedBox(height: AppDimensions.spaceMD),

        // Name
        Text(
          _userName,
          style: AppTextStyles.headlineMedium(),
        ),

        const SizedBox(height: AppDimensions.spaceXXS),

        // Email
        Text(
          _email,
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),

        const SizedBox(height: AppDimensions.spaceXXS),

        // Phone
        Text(
          _phone,
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
