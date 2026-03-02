/// African country codes for phone number input
class CountryCode {
  final String name;
  final String code;
  final String dialCode;
  final String flag;
  final String currency;

  const CountryCode({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
    required this.currency,
  });

  @override
  String toString() => '$flag $dialCode';
}

/// List of African countries with their dial codes and currencies
class AfricanCountryCodes {
  static const List<CountryCode> countries = [
    CountryCode(name: 'Nigeria', code: 'NG', dialCode: '+234', flag: '🇳🇬', currency: 'NGN'),
    CountryCode(name: 'South Africa', code: 'ZA', dialCode: '+27', flag: '🇿🇦', currency: 'ZAR'),
    CountryCode(name: 'Kenya', code: 'KE', dialCode: '+254', flag: '🇰🇪', currency: 'KES'),
    CountryCode(name: 'Ghana', code: 'GH', dialCode: '+233', flag: '🇬🇭', currency: 'GHS'),
    CountryCode(name: 'Egypt', code: 'EG', dialCode: '+20', flag: '🇪🇬', currency: 'EGP'),
    CountryCode(name: 'Morocco', code: 'MA', dialCode: '+212', flag: '🇲🇦', currency: 'MAD'),
    CountryCode(name: 'Tanzania', code: 'TZ', dialCode: '+255', flag: '🇹🇿', currency: 'TZS'),
    CountryCode(name: 'Uganda', code: 'UG', dialCode: '+256', flag: '🇺🇬', currency: 'UGX'),
    CountryCode(name: 'Algeria', code: 'DZ', dialCode: '+213', flag: '🇩🇿', currency: 'DZD'),
    CountryCode(name: 'Ethiopia', code: 'ET', dialCode: '+251', flag: '🇪🇹', currency: 'ETB'),
    CountryCode(name: 'Cameroon', code: 'CM', dialCode: '+237', flag: '🇨🇲', currency: 'XAF'),
    CountryCode(name: 'Ivory Coast', code: 'CI', dialCode: '+225', flag: '🇨🇮', currency: 'XOF'),
    CountryCode(name: 'Senegal', code: 'SN', dialCode: '+221', flag: '🇸🇳', currency: 'XOF'),
    CountryCode(name: 'Zimbabwe', code: 'ZW', dialCode: '+263', flag: '🇿🇼', currency: 'ZWG'),
    CountryCode(name: 'Rwanda', code: 'RW', dialCode: '+250', flag: '🇷🇼', currency: 'RWF'),
    CountryCode(name: 'Tunisia', code: 'TN', dialCode: '+216', flag: '🇹🇳', currency: 'TND'),
    CountryCode(name: 'Libya', code: 'LY', dialCode: '+218', flag: '🇱🇾', currency: 'LYD'),
    CountryCode(name: 'Sudan', code: 'SD', dialCode: '+249', flag: '🇸🇩', currency: 'SDG'),
    CountryCode(name: 'Zambia', code: 'ZM', dialCode: '+260', flag: '🇿🇲', currency: 'ZMW'),
    CountryCode(name: 'Botswana', code: 'BW', dialCode: '+267', flag: '🇧🇼', currency: 'BWP'),
    CountryCode(name: 'Namibia', code: 'NA', dialCode: '+264', flag: '🇳🇦', currency: 'NAD'),
    CountryCode(name: 'Mozambique', code: 'MZ', dialCode: '+258', flag: '🇲🇿', currency: 'MZN'),
    CountryCode(name: 'Angola', code: 'AO', dialCode: '+244', flag: '🇦🇴', currency: 'AOA'),
    CountryCode(name: 'Mali', code: 'ML', dialCode: '+223', flag: '🇲🇱', currency: 'XOF'),
    CountryCode(name: 'Burkina Faso', code: 'BF', dialCode: '+226', flag: '🇧🇫', currency: 'XOF'),
    CountryCode(name: 'Niger', code: 'NE', dialCode: '+227', flag: '🇳🇪', currency: 'XOF'),
    CountryCode(name: 'Malawi', code: 'MW', dialCode: '+265', flag: '🇲🇼', currency: 'MWK'),
    CountryCode(name: 'Benin', code: 'BJ', dialCode: '+229', flag: '🇧🇯', currency: 'XOF'),
    CountryCode(name: 'Togo', code: 'TG', dialCode: '+228', flag: '🇹🇬', currency: 'XOF'),
    CountryCode(name: 'Sierra Leone', code: 'SL', dialCode: '+232', flag: '🇸🇱', currency: 'SLL'),
    CountryCode(name: 'Liberia', code: 'LR', dialCode: '+231', flag: '🇱🇷', currency: 'LRD'),
    CountryCode(name: 'Mauritius', code: 'MU', dialCode: '+230', flag: '🇲🇺', currency: 'MUR'),
    CountryCode(name: 'Congo (DRC)', code: 'CD', dialCode: '+243', flag: '🇨🇩', currency: 'CDF'),
    CountryCode(name: 'Congo', code: 'CG', dialCode: '+242', flag: '🇨🇬', currency: 'XAF'),
    CountryCode(name: 'Gabon', code: 'GA', dialCode: '+241', flag: '🇬🇦', currency: 'XAF'),
    CountryCode(name: 'Equatorial Guinea', code: 'GQ', dialCode: '+240', flag: '🇬🇶', currency: 'XAF'),
    CountryCode(name: 'Central African Republic', code: 'CF', dialCode: '+236', flag: '🇨🇫', currency: 'XAF'),
    CountryCode(name: 'Chad', code: 'TD', dialCode: '+235', flag: '🇹🇩', currency: 'XAF'),
    CountryCode(name: 'Somalia', code: 'SO', dialCode: '+252', flag: '🇸🇴', currency: 'SOS'),
    CountryCode(name: 'Djibouti', code: 'DJ', dialCode: '+253', flag: '🇩🇯', currency: 'DJF'),
    CountryCode(name: 'Eritrea', code: 'ER', dialCode: '+291', flag: '🇪🇷', currency: 'ERN'),
    CountryCode(name: 'Gambia', code: 'GM', dialCode: '+220', flag: '🇬🇲', currency: 'GMD'),
    CountryCode(name: 'Guinea', code: 'GN', dialCode: '+224', flag: '🇬🇳', currency: 'GNF'),
    CountryCode(name: 'Guinea-Bissau', code: 'GW', dialCode: '+245', flag: '🇬🇼', currency: 'XOF'),
    CountryCode(name: 'Lesotho', code: 'LS', dialCode: '+266', flag: '🇱🇸', currency: 'LSL'),
    CountryCode(name: 'Madagascar', code: 'MG', dialCode: '+261', flag: '🇲🇬', currency: 'MGA'),
    CountryCode(name: 'Mauritania', code: 'MR', dialCode: '+222', flag: '🇲🇷', currency: 'MRU'),
    CountryCode(name: 'Seychelles', code: 'SC', dialCode: '+248', flag: '🇸🇨', currency: 'SCR'),
    CountryCode(name: 'South Sudan', code: 'SS', dialCode: '+211', flag: '🇸🇸', currency: 'SSP'),
    CountryCode(name: 'Eswatini', code: 'SZ', dialCode: '+268', flag: '🇸🇿', currency: 'SZL'),
    CountryCode(name: 'Cape Verde', code: 'CV', dialCode: '+238', flag: '🇨🇻', currency: 'CVE'),
    CountryCode(name: 'Comoros', code: 'KM', dialCode: '+269', flag: '🇰🇲', currency: 'KMF'),
    CountryCode(name: 'São Tomé and Príncipe', code: 'ST', dialCode: '+239', flag: '🇸🇹', currency: 'STN'),
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
}
