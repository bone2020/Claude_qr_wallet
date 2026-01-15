import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../providers/theme_provider.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeNotifierProvider.notifier).appThemeMode;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textPrimaryDark),
          onPressed: () => context.pop(),
        ),
        title: Text('Appearance', style: AppTextStyles.headlineMedium()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme', style: AppTextStyles.headlineSmall()),
            const SizedBox(height: 16),

            _buildThemeOption(
              context: context,
              ref: ref,
              icon: Iconsax.sun_1,
              title: 'Light',
              subtitle: 'Light background with dark text',
              mode: AppThemeMode.light,
              currentMode: currentTheme,
            ),
            _buildThemeOption(
              context: context,
              ref: ref,
              icon: Iconsax.moon,
              title: 'Dark',
              subtitle: 'Dark background with light text',
              mode: AppThemeMode.dark,
              currentMode: currentTheme,
            ),
            _buildThemeOption(
              context: context,
              ref: ref,
              icon: Iconsax.mobile,
              title: 'System',
              subtitle: 'Follow system settings',
              mode: AppThemeMode.system,
              currentMode: currentTheme,
            ),

            const SizedBox(height: 32),

            // Preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preview', style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildPreviewCard(
                        isLight: false,
                        isSelected: currentTheme == AppThemeMode.dark,
                      ),
                      const SizedBox(width: 16),
                      _buildPreviewCard(
                        isLight: true,
                        isSelected: currentTheme == AppThemeMode.light,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String title,
    required String subtitle,
    required AppThemeMode mode,
    required AppThemeMode currentMode,
  }) {
    final isSelected = mode == currentMode;

    return GestureDetector(
      onTap: () => ref.read(themeNotifierProvider.notifier).setTheme(mode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondaryDark,
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
            if (isSelected)
              const Icon(Iconsax.tick_circle, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard({required bool isLight, required bool isSelected}) {
    return Expanded(
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 8,
              decoration: BoxDecoration(
                color: isLight ? Colors.grey[300] : Colors.grey[700],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 60,
              height: 6,
              decoration: BoxDecoration(
                color: isLight ? Colors.grey[200] : Colors.grey[800],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
