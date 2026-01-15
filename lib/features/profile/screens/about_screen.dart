import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
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
        title: Text('About', style: AppTextStyles.headlineMedium()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // App Logo
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.wallet_3,
                color: AppColors.primary,
                size: 64,
              ),
            ),

            const SizedBox(height: 24),

            // App Name
            Text('QR Wallet', style: AppTextStyles.headlineLarge()),
            const SizedBox(height: 8),
            Text(
              'Version $_version (Build $_buildNumber)',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
            ),

            const SizedBox(height: 32),

            // Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'QR Wallet is a secure and easy-to-use digital wallet that allows you to send, receive, and manage money with just a scan. Experience the future of payments today.',
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 32),

            // Links
            _buildLinkItem(
              icon: Iconsax.document,
              title: 'Terms of Service',
              onTap: () => _launchUrl('https://qrwallet.com/terms'),
            ),
            _buildLinkItem(
              icon: Iconsax.shield_tick,
              title: 'Privacy Policy',
              onTap: () => _launchUrl('https://qrwallet.com/privacy'),
            ),
            _buildLinkItem(
              icon: Iconsax.star,
              title: 'Rate Us',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rate us on the App Store!')),
                );
              },
            ),
            _buildLinkItem(
              icon: Iconsax.share,
              title: 'Share App',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share feature coming soon!')),
                );
              },
            ),

            const SizedBox(height: 32),

            // Copyright
            Text(
              '© 2024 QR Wallet. All rights reserved.',
              style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 8),
            Text(
              'Made with ❤️ in Ghana',
              style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        tileColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: AppColors.primary, size: 24),
        title: Text(title, style: AppTextStyles.bodyLarge()),
        trailing: const Icon(Iconsax.arrow_right_3, color: AppColors.textSecondaryDark, size: 20),
      ),
    );
  }
}
