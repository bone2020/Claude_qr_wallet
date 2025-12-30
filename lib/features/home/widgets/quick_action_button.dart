import 'package:flutter/material.dart';

import '../../../core/constants/constants.dart';

/// Quick action button for home screen
class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              border: Border.all(color: AppColors.inputBorderDark),
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          Text(
            label,
            style: AppTextStyles.labelSmall(color: AppColors.textSecondaryDark),
          ),
        ],
      ),
    );
  }
}

/// Quick action button with primary styling
class PrimaryQuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const PrimaryQuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AppColors.backgroundDark,
              size: 24,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          Text(
            label,
            style: AppTextStyles.labelSmall(color: AppColors.textPrimaryDark),
          ),
        ],
      ),
    );
  }
}
