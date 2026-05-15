import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/language_provider.dart';

/// Language settings screen — Phase 6 Step 12.
///
/// Lets a signed-in user choose between English, French, and Arabic.
/// Tapping a language:
///   1. Persists the choice locally and updates Riverpod state
///      (which causes MaterialApp to rebuild in the new locale).
///   2. If the user is signed in, syncs the choice to Firestore
///      (`users/{uid}.preferredLanguage`) so it persists across devices.
///   3. Refreshes the local UserModel cache via [AuthNotifier.updateUser].
///
/// Mirrors the structure of [ThemeSettingsScreen] for consistency.
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textPrimaryDark),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppLocalizations.of(context).selectLanguage,
          style: AppTextStyles.headlineMedium(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).languageDescription,
              style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 24),
            for (final lang in AppLanguage.values)
              _buildLanguageOption(
                context: context,
                ref: ref,
                lang: lang,
                isSelected: lang == currentLanguage,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required WidgetRef ref,
    required AppLanguage lang,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _onLanguageSelected(ref, lang),
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
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Iconsax.global,
                color: isSelected ? AppColors.primary : AppColors.textSecondaryDark,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(lang.nativeName, style: AppTextStyles.bodyLarge()),
            ),
            if (isSelected)
              const Icon(Iconsax.tick_circle, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _onLanguageSelected(WidgetRef ref, AppLanguage lang) async {
    // 1. Persist locally + update Riverpod state.
    //    MaterialApp rebuilds in the new locale immediately.
    await ref.read(languageNotifierProvider.notifier).setLanguage(lang);

    // 2. If signed in, sync to Firestore for cross-device persistence.
    final currentUser = ref.read(authNotifierProvider).user;
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .update({'preferredLanguage': lang.code});

        // 3. Refresh local cache + state with the new value.
        final updatedUser =
            currentUser.copyWith(preferredLanguage: lang.code);
        ref.read(authNotifierProvider.notifier).updateUser(updatedUser);
      } catch (e) {
        // Local change is already in effect; cross-device sync deferred
        // until the next opportunity. Log technical detail for engineers.
        debugPrint('Failed to sync preferredLanguage to Firestore: $e');
      }
    }
  }
}
