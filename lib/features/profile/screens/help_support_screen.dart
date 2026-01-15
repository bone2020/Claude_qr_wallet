import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'qrwallet.support@bongroups.co',
      query: 'subject=QR Wallet Support Request',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone() async {
    final uri = Uri(scheme: 'tel', path: '+233123456789');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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
            // Contact Section
            Text('Contact Us', style: AppTextStyles.headlineSmall()),
            const SizedBox(height: 16),

            _buildContactItem(
              context: context,
              icon: Iconsax.sms,
              title: 'Email Support',
              subtitle: 'qrwallet.support@bongroups.co',
              onTap: _launchEmail,
            ),
            _buildContactItem(
              context: context,
              icon: Iconsax.call,
              title: 'Phone Support',
              subtitle: '+233 12 345 6789',
              onTap: _launchPhone,
            ),
            _buildContactItem(
              context: context,
              icon: Iconsax.message,
              title: 'Live Chat',
              subtitle: 'Chat with our support team',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Live chat coming soon!')),
                );
              },
            ),

            const SizedBox(height: 32),

            // FAQ Section
            Text('Frequently Asked Questions', style: AppTextStyles.headlineSmall()),
            const SizedBox(height: 16),

            _buildFaqItem(
              question: 'How do I add money to my wallet?',
              answer: 'You can add money via Card, Mobile Money, or Bank Transfer. Go to Home → Add Money and choose your preferred method.',
            ),
            _buildFaqItem(
              question: 'How do I send money to someone?',
              answer: 'Tap "Send" on the home screen, enter the recipient\'s wallet ID or scan their QR code, enter the amount, and confirm.',
            ),
            _buildFaqItem(
              question: 'How long do withdrawals take?',
              answer: 'Bank transfers typically take 1-3 business days. Mobile Money withdrawals are usually instant.',
            ),
            _buildFaqItem(
              question: 'Is my money safe?',
              answer: 'Yes! We use bank-level encryption and secure payment processors. Your funds are protected at all times.',
            ),
            _buildFaqItem(
              question: 'How do I change my PIN?',
              answer: 'Go to Profile → Change PIN. Enter your current PIN, then create and confirm your new PIN.',
            ),
            _buildFaqItem(
              question: 'What if I forget my password?',
              answer: 'On the login screen, tap "Forgot Password?" and enter your email. We\'ll send you a reset link.',
            ),

            const SizedBox(height: 32),

            // Social Media
            Text('Follow Us', style: AppTextStyles.headlineSmall()),
            const SizedBox(height: 16),

            Row(
              children: [
                _buildSocialButton(Icons.facebook, () => _launchUrl('https://facebook.com/qrwallet')),
                const SizedBox(width: 16),
                _buildSocialButton(Iconsax.camera, () => _launchUrl('https://instagram.com/qrwallet')),
                const SizedBox(width: 16),
                _buildSocialButton(Iconsax.message, () => _launchUrl('https://x.com/qrwallet')),
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        tileColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        title: Text(title, style: AppTextStyles.bodyLarge()),
        subtitle: Text(subtitle, style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark)),
        trailing: const Icon(Iconsax.arrow_right_3, color: AppColors.textSecondaryDark, size: 20),
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
