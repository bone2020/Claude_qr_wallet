import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../providers/language_provider.dart';

/// First-launch language picker.
///
/// Shown when [hasPickedLanguageProvider] is false. The user picks one
/// of the supported [AppLanguage] values; we persist via
/// [LanguageNotifier.setLanguage] (which writes to SharedPreferences),
/// then navigate to splash so the normal app routing logic takes over.
///
/// Header strings are NOT localized — they appear in all three supported
/// languages stacked, because the picker must be readable to anyone
/// regardless of the current MaterialApp.locale (which defaults to
/// English until a pick happens).
///
/// Button labels use each [AppLanguage]'s nativeName so a user who can't
/// read the current locale still recognizes their language.
class FirstLaunchLanguageScreen extends ConsumerWidget {
  const FirstLaunchLanguageScreen({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref, AppLanguage lang) async {
    await ref.read(languageNotifierProvider.notifier).setLanguage(lang);
    if (!context.mounted) return;
    context.go(AppRoutes.splash);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Choose your language',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Choisissez votre langue',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'اختر لغتك',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 48),
              for (final lang in AppLanguage.values) ...[
                _LanguageButton(
                  language: lang,
                  onTap: () => _pick(context, ref, lang),
                ),
                const SizedBox(height: 16),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({required this.language, required this.onTap});

  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Directionality(
          textDirection:
              language == AppLanguage.arabic ? TextDirection.rtl : TextDirection.ltr,
          child: Text(
            language.nativeName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
    );
  }
}
