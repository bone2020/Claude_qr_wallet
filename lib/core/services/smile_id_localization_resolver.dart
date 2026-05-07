import '../../generated/l10n/app_localizations.dart';

/// Identifies the kind of validation failure produced by
/// [SmileIDService.validateIdNumber].
///
/// The service returns one of these values; the UI layer (which has a
/// [BuildContext]) calls [resolveIdValidationErrorMessage] to convert it
/// into a user-visible, translated message.
enum IdValidationErrorKey {
  idNumberRequired,
  ninLength,
  bvnLength,
  ssnitFormat,
  southAfricanIdLength,
  ugandaNinFormat,
  tpinLength,
}

/// Identifies the kind of in-service Smile ID failure carried by
/// [SmileIDResult.errorKey] when the service itself produced the error.
///
/// External errors (network, server, third-party SDK) still come through
/// [SmileIDResult.error] as free-form text — they do not get an [errorKey].
enum SmileIDErrorKey {
  parseResultFailed,
}

/// Resolves an [IdValidationErrorKey] into a translated, user-visible message.
///
/// Exhaustiveness is enforced by the switch expression — adding a new enum
/// value without a matching case here is a compile error.
String resolveIdValidationErrorMessage(
  AppLocalizations loc,
  IdValidationErrorKey key,
) {
  return switch (key) {
    IdValidationErrorKey.idNumberRequired => loc.idNumberRequired,
    IdValidationErrorKey.ninLength => loc.ninLengthError,
    IdValidationErrorKey.bvnLength => loc.bvnLengthError,
    IdValidationErrorKey.ssnitFormat => loc.ssnitFormatError,
    IdValidationErrorKey.southAfricanIdLength => loc.southAfricanIdLengthError,
    IdValidationErrorKey.ugandaNinFormat => loc.ugandaNinFormatError,
    IdValidationErrorKey.tpinLength => loc.tpinLengthError,
  };
}

/// Resolves a [SmileIDErrorKey] into a translated, user-visible message.
String resolveSmileIdErrorMessage(
  AppLocalizations loc,
  SmileIDErrorKey key,
) {
  return switch (key) {
    SmileIDErrorKey.parseResultFailed => loc.smileIdParseError,
  };
}

/// Resolves an ID type's `value` string (e.g. `'NATIONAL_ID'`, `'VOTERS_ID'`)
/// into the translated dropdown label that the user sees in the KYC ID-type
/// picker.
///
/// Falls back to the raw value if the type is unknown — a defensive escape
/// hatch that keeps the picker usable if a new ID type is added to
/// `countryIdTypes` without a matching label entry here.
String resolveIdTypeLabel(AppLocalizations loc, String idTypeValue) {
  switch (idTypeValue) {
    case 'NATIONAL_ID':
      return loc.nationalId;
    case 'VOTERS_ID':
      return loc.votersIdLabel;
    case 'DRIVERS_LICENSE':
      return loc.driversLicense;
    case 'PASSPORT':
      return loc.internationalPassportLabel;
    case 'ALIEN_ID':
      return loc.alienIdLabel;
    case 'NIN':
      return loc.ninFullLabel;
    case 'BVN':
      return loc.bvnFullLabel;
    case 'SSNIT':
      return loc.ssnitLabel;
    case 'UGANDA_NIN':
      return loc.ugandaNationalIdLabel;
    case 'TPIN':
      return loc.tpinFullLabel;
    default:
      return idTypeValue;
  }
}
