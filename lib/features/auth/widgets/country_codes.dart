/// African country codes for phone number input
class CountryCode {
  final String name;
  final String code;
  final String dialCode;
  final String flag;
  final int minLength; // Minimum phone digits (without country code)
  final int maxLength; // Maximum phone digits (without country code)

  const CountryCode({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
    required this.minLength,
    required this.maxLength,
  });

  @override
  String toString() => '$flag $dialCode';

  /// Validate phone number length for this country
  bool isValidLength(String phoneNumber) {
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length >= minLength && digitsOnly.length <= maxLength;
  }

  /// Get validation error message
  String? getValidationError(String phoneNumber) {
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return 'Phone number is required';
    }
    if (digitsOnly.length < minLength) {
      return 'Phone number must be at least $minLength digits';
    }
    if (digitsOnly.length > maxLength) {
      return 'Phone number must not exceed $maxLength digits';
    }
    return null;
  }
}

/// List of African countries with their dial codes and phone number lengths
class AfricanCountryCodes {
  static const List<CountryCode> countries = [
    // West Africa
    CountryCode(name: 'Nigeria', code: 'NG', dialCode: '+234', flag: '🇳🇬', minLength: 10, maxLength: 11),
    CountryCode(name: 'Ghana', code: 'GH', dialCode: '+233', flag: '🇬🇭', minLength: 9, maxLength: 10),
    CountryCode(name: 'Senegal', code: 'SN', dialCode: '+221', flag: '🇸🇳', minLength: 9, maxLength: 9),
    CountryCode(name: 'Ivory Coast', code: 'CI', dialCode: '+225', flag: '🇨🇮', minLength: 10, maxLength: 10),
    CountryCode(name: 'Cameroon', code: 'CM', dialCode: '+237', flag: '🇨🇲', minLength: 9, maxLength: 9),
    CountryCode(name: 'Mali', code: 'ML', dialCode: '+223', flag: '🇲🇱', minLength: 8, maxLength: 8),
    CountryCode(name: 'Burkina Faso', code: 'BF', dialCode: '+226', flag: '🇧🇫', minLength: 8, maxLength: 8),
    CountryCode(name: 'Niger', code: 'NE', dialCode: '+227', flag: '🇳🇪', minLength: 8, maxLength: 8),
    CountryCode(name: 'Benin', code: 'BJ', dialCode: '+229', flag: '🇧🇯', minLength: 8, maxLength: 8),
    CountryCode(name: 'Togo', code: 'TG', dialCode: '+228', flag: '🇹🇬', minLength: 8, maxLength: 8),
    CountryCode(name: 'Sierra Leone', code: 'SL', dialCode: '+232', flag: '🇸🇱', minLength: 8, maxLength: 8),
    CountryCode(name: 'Liberia', code: 'LR', dialCode: '+231', flag: '🇱🇷', minLength: 7, maxLength: 8),
    CountryCode(name: 'Guinea', code: 'GN', dialCode: '+224', flag: '🇬🇳', minLength: 9, maxLength: 9),
    CountryCode(name: 'Guinea-Bissau', code: 'GW', dialCode: '+245', flag: '🇬🇼', minLength: 7, maxLength: 7),
    CountryCode(name: 'Gambia', code: 'GM', dialCode: '+220', flag: '🇬🇲', minLength: 7, maxLength: 7),
    CountryCode(name: 'Cape Verde', code: 'CV', dialCode: '+238', flag: '🇨🇻', minLength: 7, maxLength: 7),
    CountryCode(name: 'Mauritania', code: 'MR', dialCode: '+222', flag: '🇲🇷', minLength: 8, maxLength: 8),

    // East Africa
    CountryCode(name: 'Kenya', code: 'KE', dialCode: '+254', flag: '🇰🇪', minLength: 9, maxLength: 10),
    CountryCode(name: 'Tanzania', code: 'TZ', dialCode: '+255', flag: '🇹🇿', minLength: 9, maxLength: 9),
    CountryCode(name: 'Uganda', code: 'UG', dialCode: '+256', flag: '🇺🇬', minLength: 9, maxLength: 9),
    CountryCode(name: 'Rwanda', code: 'RW', dialCode: '+250', flag: '🇷🇼', minLength: 9, maxLength: 9),
    CountryCode(name: 'Ethiopia', code: 'ET', dialCode: '+251', flag: '🇪🇹', minLength: 9, maxLength: 9),
    CountryCode(name: 'Somalia', code: 'SO', dialCode: '+252', flag: '🇸🇴', minLength: 7, maxLength: 8),
    CountryCode(name: 'Djibouti', code: 'DJ', dialCode: '+253', flag: '🇩🇯', minLength: 8, maxLength: 8),
    CountryCode(name: 'Eritrea', code: 'ER', dialCode: '+291', flag: '🇪🇷', minLength: 7, maxLength: 7),
    CountryCode(name: 'South Sudan', code: 'SS', dialCode: '+211', flag: '🇸🇸', minLength: 9, maxLength: 9),
    CountryCode(name: 'Sudan', code: 'SD', dialCode: '+249', flag: '🇸🇩', minLength: 9, maxLength: 9),

    // Southern Africa
    CountryCode(name: 'South Africa', code: 'ZA', dialCode: '+27', flag: '🇿🇦', minLength: 9, maxLength: 9),
    CountryCode(name: 'Zimbabwe', code: 'ZW', dialCode: '+263', flag: '🇿🇼', minLength: 9, maxLength: 9),
    CountryCode(name: 'Zambia', code: 'ZM', dialCode: '+260', flag: '🇿🇲', minLength: 9, maxLength: 9),
    CountryCode(name: 'Botswana', code: 'BW', dialCode: '+267', flag: '🇧🇼', minLength: 7, maxLength: 8),
    CountryCode(name: 'Namibia', code: 'NA', dialCode: '+264', flag: '🇳🇦', minLength: 9, maxLength: 9),
    CountryCode(name: 'Mozambique', code: 'MZ', dialCode: '+258', flag: '🇲🇿', minLength: 9, maxLength: 9),
    CountryCode(name: 'Angola', code: 'AO', dialCode: '+244', flag: '🇦🇴', minLength: 9, maxLength: 9),
    CountryCode(name: 'Malawi', code: 'MW', dialCode: '+265', flag: '🇲🇼', minLength: 9, maxLength: 9),
    CountryCode(name: 'Lesotho', code: 'LS', dialCode: '+266', flag: '🇱🇸', minLength: 8, maxLength: 8),
    CountryCode(name: 'Eswatini', code: 'SZ', dialCode: '+268', flag: '🇸🇿', minLength: 8, maxLength: 8),
    CountryCode(name: 'Madagascar', code: 'MG', dialCode: '+261', flag: '🇲🇬', minLength: 9, maxLength: 10),
    CountryCode(name: 'Mauritius', code: 'MU', dialCode: '+230', flag: '🇲🇺', minLength: 7, maxLength: 8),
    CountryCode(name: 'Seychelles', code: 'SC', dialCode: '+248', flag: '🇸🇨', minLength: 7, maxLength: 7),
    CountryCode(name: 'Comoros', code: 'KM', dialCode: '+269', flag: '🇰🇲', minLength: 7, maxLength: 7),

    // North Africa
    CountryCode(name: 'Egypt', code: 'EG', dialCode: '+20', flag: '🇪🇬', minLength: 10, maxLength: 10),
    CountryCode(name: 'Morocco', code: 'MA', dialCode: '+212', flag: '🇲🇦', minLength: 9, maxLength: 9),
    CountryCode(name: 'Algeria', code: 'DZ', dialCode: '+213', flag: '🇩🇿', minLength: 9, maxLength: 9),
    CountryCode(name: 'Tunisia', code: 'TN', dialCode: '+216', flag: '🇹🇳', minLength: 8, maxLength: 8),
    CountryCode(name: 'Libya', code: 'LY', dialCode: '+218', flag: '🇱🇾', minLength: 9, maxLength: 9),

    // Central Africa
    CountryCode(name: 'Congo (DRC)', code: 'CD', dialCode: '+243', flag: '🇨🇩', minLength: 9, maxLength: 9),
    CountryCode(name: 'Congo', code: 'CG', dialCode: '+242', flag: '🇨🇬', minLength: 9, maxLength: 9),
    CountryCode(name: 'Gabon', code: 'GA', dialCode: '+241', flag: '🇬🇦', minLength: 7, maxLength: 8),
    CountryCode(name: 'Equatorial Guinea', code: 'GQ', dialCode: '+240', flag: '🇬🇶', minLength: 9, maxLength: 9),
    CountryCode(name: 'Central African Republic', code: 'CF', dialCode: '+236', flag: '🇨🇫', minLength: 8, maxLength: 8),
    CountryCode(name: 'Chad', code: 'TD', dialCode: '+235', flag: '🇹🇩', minLength: 8, maxLength: 8),
    CountryCode(name: 'São Tomé and Príncipe', code: 'ST', dialCode: '+239', flag: '🇸🇹', minLength: 7, maxLength: 7),
  ];

  /// Get default country (Nigeria)
  static CountryCode get defaultCountry => countries.first;

  /// Find country by code
  static CountryCode? findByCode(String code) {
    try {
      return countries.firstWhere((c) => c.code == code);
    } catch (_) {
      return null;
    }
  }

  /// Find country by dial code
  static CountryCode? findByDialCode(String dialCode) {
    try {
      return countries.firstWhere((c) => c.dialCode == dialCode);
    } catch (_) {
      return null;
    }
  }

  /// Search countries by name or dial code
  static List<CountryCode> search(String query) {
    if (query.isEmpty) return countries;
    final lowerQuery = query.toLowerCase();
    return countries.where((country) =>
        country.name.toLowerCase().contains(lowerQuery) ||
        country.dialCode.contains(query)).toList();
  }
}
