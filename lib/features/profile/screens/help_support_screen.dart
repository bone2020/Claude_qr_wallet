import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // ============================================================
  // SUPPORT CONTACT CONFIG — change these in ONE place
  // ============================================================
  static const String _supportEmail = 'qrwallet.support@bongroups.co';

  // WhatsApp — full international format, digits only, NO leading + or spaces
  // TODO: Replace with actual support number once SIM is acquired and
  //       WhatsApp Business is configured (see Phase 4a §11.3 in spec).
  // For Dubai temporary: e.g. '971501234567'
  // For Ghana later:    e.g. '233241234567'
  static const String _whatsappNumber = '971000000000'; // <-- REPLACE BEFORE PRODUCTION

  static const String _whatsappPrefilledMessage =
      'Hi QR Wallet Support, I need help with...';

  // ============================================================
  // EMAIL HANDLER — opens mail app with subject + auto-filled device info
  // Auto-fills app version, device, user ID for faster triage.
  // ============================================================
  Future<void> _launchEmail(BuildContext context) async {
    String appVersion = 'unknown';
    String deviceInfo = 'unknown';
    String userId = 'not signed in';

    try {
      final pkg = await PackageInfo.fromPlatform();
      appVersion = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {}

    try {
      final dip = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await dip.androidInfo;
        deviceInfo = 'Android ${a.version.release} (${a.manufacturer} ${a.model})';
      } else if (Platform.isIOS) {
        final i = await dip.iosInfo;
        deviceInfo = 'iOS ${i.systemVersion} (${i.utsname.machine})';
      }
    } catch (_) {}

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) userId = user.uid;
    } catch (_) {}

    final body = '''
Hi QR Wallet Support,

I need help with: [describe your issue here]

---
Please do not delete the info below — it helps us help you faster.
App version: $appVersion
Device: $deviceInfo
User ID: $userId
''';

    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'QR Wallet Support Request',
        'body': body,
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not open email app. Please email us at qrwallet.support@bongroups.co'),
        ),
      );
    }
  }

  // ============================================================
  // WHATSAPP HANDLER — opens WhatsApp with pre-filled message
  // ============================================================
  Future<void> _launchWhatsApp(BuildContext context) async {
    final encodedMessage = Uri.encodeComponent(_whatsappPrefilledMessage);
    final uri = Uri.parse('https://wa.me/$_whatsappNumber?text=$encodedMessage');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not open WhatsApp. Please make sure WhatsApp is installed.'),
        ),
      );
    }
  }

  // ============================================================
  // WHATSAPP QR DIALOG — for users to scan with another phone
  // ============================================================
  void _showWhatsAppQrDialog(BuildContext context) {
    final encodedMessage = Uri.encodeComponent(_whatsappPrefilledMessage);
    final waUrl = 'https://wa.me/$_whatsappNumber?text=$encodedMessage';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chat on WhatsApp',
                style: AppTextStyles.headlineSmall(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Scan with another phone\nor tap "Open WhatsApp" below',
                style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: waUrl,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _launchWhatsApp(context);
                  },
                  icon: const Icon(Iconsax.message, size: 20),
                  label: const Text('Open WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Close',
                  style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
        title: Text('Help & Support', style: AppTextStyles.headlineMedium()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact Us', style: AppTextStyles.headlineSmall()),
            const SizedBox(height: 16),
            _buildContactItem(
              context: context,
              icon: Iconsax.sms,
              title: 'Email Support',
              subtitle: _supportEmail,
              onTap: () => _launchEmail(context),
            ),
            _buildContactItem(
              context: context,
              icon: Iconsax.message,
              title: 'WhatsApp Support',
              subtitle: 'Chat with us on WhatsApp',
              onTap: () => _showWhatsAppQrDialog(context),
              iconColor: const Color(0xFF25D366),
            ),
            const SizedBox(height: 32),
            Text('Frequently Asked Questions', style: AppTextStyles.headlineSmall()),
            const SizedBox(height: 16),
            _buildFaqItem(
              question: 'How do I add money to my wallet?',
              answer:
                  'You can add money via Card, Mobile Money, or Bank Transfer. Go to Home → Add Money and choose your preferred method.',
            ),
            _buildFaqItem(
              question: 'How do I send money to someone?',
              answer:
                  'Tap "Send" on the home screen, enter the recipient\'s wallet ID or scan their QR code, enter the amount, and confirm.',
            ),
            _buildFaqItem(
              question: 'How long do withdrawals take?',
              answer:
                  'Bank transfers typically take 1-3 business days. Mobile Money withdrawals are usually instant.',
            ),
            _buildFaqItem(
              question: 'Is my money safe?',
              answer:
                  'Yes! We use bank-level encryption and secure payment processors. Your funds are protected at all times.',
            ),
            _buildFaqItem(
              question: 'How do I change my PIN?',
              answer:
                  'Go to Profile → Change PIN. Enter your current PIN, then create and confirm your new PIN.',
            ),
            _buildFaqItem(
              question: 'What if I forget my password?',
              answer:
                  'On the login screen, tap "Forgot Password?" and enter your email. We\'ll send you a reset link.',
            ),
            const SizedBox(height: 32),
            Text('Follow Us', style: AppTextStyles.headlineSmall()),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildSocialButton(
                    Icons.facebook, () => _launchUrl('https://facebook.com/qrwallet')),
                const SizedBox(width: 16),
                _buildSocialButton(
                    Iconsax.camera, () => _launchUrl('https://instagram.com/qrwallet')),
                const SizedBox(width: 16),
                _buildSocialButton(
                    Iconsax.message, () => _launchUrl('https://x.com/qrwallet')),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final color = iconColor ?? AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        tileColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: AppTextStyles.bodyLarge()),
        subtitle: Text(subtitle,
            style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark)),
        trailing: const Icon(Iconsax.arrow_right_3,
            color: AppColors.textSecondaryDark, size: 20),
      ),
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textSecondaryDark,
        title: Text(question, style: AppTextStyles.bodyMedium()),
        children: [
          Text(
            answer,
            style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
    );
  }
}
