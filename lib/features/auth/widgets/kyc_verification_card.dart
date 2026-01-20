import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/constants.dart';

/// Shared verification card widget used across all KYC screens
class KycVerificationCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isVerified;
  final VoidCallback? onStartVerification;
  final bool isLoading;

  const KycVerificationCard({
    super.key,
    required this.title,
    required this.description,
    this.isVerified = false,
    this.onStartVerification,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        color: isVerified
            ? AppColors.success.withOpacity(0.1)
            : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(
          color: isVerified ? AppColors.success : AppColors.inputBorderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVerified ? Icons.verified_rounded : Icons.fingerprint_rounded,
                color: isVerified ? AppColors.success : AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: AppDimensions.spaceSM),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.headlineSmall(
                    color: isVerified ? AppColors.success : null,
                  ),
                ),
              ),
              if (isVerified)
                const Icon(Icons.check_circle, color: AppColors.success),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSM),
          Text(
            description,
            style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
          ),
          if (!isVerified) ...[
            const SizedBox(height: AppDimensions.spaceMD),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onStartVerification,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.backgroundDark,
                        ),
                      )
                    : const Icon(Icons.camera_alt_rounded),
                label: Text(isLoading ? 'Please wait...' : AppStrings.startVerification),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.backgroundDark,
                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceMD),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ID type selection card for the main KYC screen
class KycIdTypeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const KycIdTypeCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceLG),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(color: AppColors.inputBorderDark),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppDimensions.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelLarge(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryDark,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  }
}

/// Date of birth picker widget
class KycDateOfBirthPicker extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onTap;

  const KycDateOfBirthPicker({
    super.key,
    this.selectedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.dateOfBirth,
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: AppDimensions.inputHeightMD,
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMD),
            decoration: BoxDecoration(
              color: AppColors.inputBackgroundDark,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              border: Border.all(color: AppColors.inputBorderDark),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                        : AppStrings.selectDate,
                    style: selectedDate != null
                        ? AppTextStyles.inputText()
                        : AppTextStyles.inputHint(),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.textSecondaryDark,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ID number input field widget
class KycIdNumberInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helperText;

  const KycIdNumberInput({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputBackgroundDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            border: Border.all(color: AppColors.inputBorderDark),
          ),
          child: TextField(
            controller: controller,
            style: AppTextStyles.inputText(),
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.inputHint(),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMD,
                vertical: AppDimensions.spaceMD,
              ),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: AppDimensions.spaceXS),
          Text(
            helperText!,
            style: AppTextStyles.bodySmall(color: AppColors.textTertiaryDark),
          ),
        ],
      ],
    );
  }
}
