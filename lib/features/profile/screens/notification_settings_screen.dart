import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

import '../../../generated/l10n/app_localizations.dart';
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _isLoading = true;

  // Notification preferences
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _transactionAlerts = true;
  bool _promotionalUpdates = false;
  bool _securityAlerts = true;
  bool _paymentReminders = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final settings = doc.data()?['notificationSettings'] as Map<String, dynamic>?;

      if (settings != null && mounted) {
        setState(() {
          _pushNotifications = settings['pushNotifications'] ?? true;
          _emailNotifications = settings['emailNotifications'] ?? true;
          _transactionAlerts = settings['transactionAlerts'] ?? true;
          _promotionalUpdates = settings['promotionalUpdates'] ?? false;
          _securityAlerts = settings['securityAlerts'] ?? true;
          _paymentReminders = settings['paymentReminders'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'notificationSettings': {
          'pushNotifications': _pushNotifications,
          'emailNotifications': _emailNotifications,
          'transactionAlerts': _transactionAlerts,
          'promotionalUpdates': _promotionalUpdates,
          'securityAlerts': _securityAlerts,
          'paymentReminders': _paymentReminders,
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).settingsSavedToast),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).failedToSaveError(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _updateSetting(String setting, bool value) {
    setState(() {
      switch (setting) {
        case 'push':
          _pushNotifications = value;
          break;
        case 'email':
          _emailNotifications = value;
          break;
        case 'transaction':
          _transactionAlerts = value;
          break;
        case 'promotional':
          _promotionalUpdates = value;
          break;
        case 'security':
          _securityAlerts = value;
          break;
        case 'reminders':
          _paymentReminders = value;
          break;
      }
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textPrimaryDark),
          onPressed: () => context.pop(),
        ),
        title: Text(AppLocalizations.of(context).notificationSettingsTitle, style: AppTextStyles.headlineMedium()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // General Section
                  Text(AppLocalizations.of(context).generalSection, style: AppTextStyles.headlineSmall()),
                  const SizedBox(height: 16),

                  _buildToggleItem(
                    icon: Iconsax.notification,
                    title: AppLocalizations.of(context).pushNotificationsLabel,
                    subtitle: AppLocalizations.of(context).pushNotificationsSubtitle,
                    value: _pushNotifications,
                    onChanged: (v) => _updateSetting('push', v),
                  ),
                  _buildToggleItem(
                    icon: Iconsax.sms,
                    title: AppLocalizations.of(context).emailNotificationsLabel,
                    subtitle: AppLocalizations.of(context).emailNotificationsSubtitle,
                    value: _emailNotifications,
                    onChanged: (v) => _updateSetting('email', v),
                  ),

                  const SizedBox(height: 32),

                  // Transactions Section
                  Text(AppLocalizations.of(context).transactionsSection, style: AppTextStyles.headlineSmall()),
                  const SizedBox(height: 16),

                  _buildToggleItem(
                    icon: Iconsax.wallet_2,
                    title: AppLocalizations.of(context).transactionAlertsLabel,
                    subtitle: AppLocalizations.of(context).transactionAlertsSubtitle,
                    value: _transactionAlerts,
                    onChanged: (v) => _updateSetting('transaction', v),
                  ),
                  _buildToggleItem(
                    icon: Iconsax.clock,
                    title: AppLocalizations.of(context).paymentRemindersLabel,
                    subtitle: AppLocalizations.of(context).paymentRemindersSubtitle,
                    value: _paymentReminders,
                    onChanged: (v) => _updateSetting('reminders', v),
                  ),

                  const SizedBox(height: 32),

                  // Security & Updates Section
                  Text(AppLocalizations.of(context).securityAndUpdatesSection, style: AppTextStyles.headlineSmall()),
                  const SizedBox(height: 16),

                  _buildToggleItem(
                    icon: Iconsax.shield_tick,
                    title: AppLocalizations.of(context).securityAlertsLabel,
                    subtitle: AppLocalizations.of(context).securityAlertsSubtitle,
                    value: _securityAlerts,
                    onChanged: (v) => _updateSetting('security', v),
                    isImportant: true,
                  ),
                  _buildToggleItem(
                    icon: Iconsax.gift,
                    title: AppLocalizations.of(context).promotionalUpdatesLabel,
                    subtitle: AppLocalizations.of(context).promotionalUpdatesSubtitle,
                    value: _promotionalUpdates,
                    onChanged: (v) => _updateSetting('promotional', v),
                  ),

                  const SizedBox(height: 32),

                  // Info note
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.info_circle, color: AppColors.info, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context).securityAlertsCannotBeDisabledNote,
                            style: AppTextStyles.bodySmall(color: AppColors.info),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isImportant = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isImportant ? AppColors.warning : AppColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isImportant ? AppColors.warning : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyLarge()),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                ),
              ],
            ),
          ),
          Switch(
            value: isImportant ? true : value,
            onChanged: isImportant ? null : onChanged,
            activeThumbColor: AppColors.primary,
            inactiveThumbColor: AppColors.textSecondaryDark,
            inactiveTrackColor: AppColors.surfaceElevatedDark,
          ),
        ],
      ),
    );
  }
}
