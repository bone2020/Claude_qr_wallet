import '../../generated/l10n/app_localizations.dart';
import '../utils/error_handler_localization_resolver.dart';
import 'user_service.dart';

/// Identifies the kind of user-result error carried by [UserResult.errorKey].
///
/// Mirrors the C.2 pattern (AuthErrorKey): a single enum captures every
/// error path, with a single resolver function and a single field on the
/// result class.
enum UserErrorKey {
  userNotAuthenticated,
  noUpdatesProvided,
  idFrontImageRequired,
  fallback,
}

/// Resolves a [UserErrorKey] into a translated, user-visible message.
String resolveUserErrorMessage(AppLocalizations loc, UserErrorKey key) {
  return switch (key) {
    UserErrorKey.userNotAuthenticated => loc.userErrorUserNotAuthenticated,
    UserErrorKey.noUpdatesProvided => loc.userErrorNoUpdatesProvided,
    UserErrorKey.idFrontImageRequired => loc.userErrorIdFrontImageRequired,
    UserErrorKey.fallback => loc.userErrorFallback,
  };
}

/// One-line resolver for UI consumers.
String resolveUserResultError(AppLocalizations loc, UserResult result) {
  if (result.errorKey != null) {
    return resolveUserErrorMessage(loc, result.errorKey!);
  }
  if (result.genericErrorKey != null) {
    return resolveGenericErrorMessage(loc, result.genericErrorKey!);
  }
  return loc.userErrorFallback;
}
