/// African country codes for phone number input
class CountryCode {
  final String name;
  final String code;
  final String dialCode;
  final String flag;

  const CountryCode({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
  });

  @override
  String toString() => '$flag $dialCode';
}

/// List of African countries with their dial codes
class AfricanCountryCodes {
  static const List<CountryCode> countries = [
    CountryCode(name: 'Nigeria', code: 'NG', dialCode: '+234', flag: '🇳🇬'),
    CountryCode(name: 'South Africa', code: 'ZA', dialCode: '+27', flag: '🇿🇦'),
    CountryCode(name: 'Kenya', code: 'KE', dialCode: '+254', flag: '🇰🇪'),
    CountryCode(name: 'Ghana', code: 'GH', dialCode: '+233', flag: '🇬🇭'),
    CountryCode(name: 'Egypt', code: 'EG', dialCode: '+20', flag: '🇪🇬'),
    CountryCode(name: 'Morocco', code: 'MA', dialCode: '+212', flag: '🇲🇦'),
    CountryCode(name: 'Tanzania', code: 'TZ', dialCode: '+255', flag: '🇹🇿'),
    CountryCode(name: 'Uganda', code: 'UG', dialCode: '+256', flag: '🇺🇬'),
    CountryCode(name: 'Algeria', code: 'DZ', dialCode: '+213', flag: '🇩🇿'),
    CountryCode(name: 'Ethiopia', code: 'ET', dialCode: '+251', flag: '🇪🇹'),
    CountryCode(name: 'Cameroon', code: 'CM', dialCode: '+237', flag: '🇨🇲'),
    CountryCode(name: 'Ivory Coast', code: 'CI', dialCode: '+225', flag: '🇨🇮'),
    CountryCode(name: 'Senegal', code: 'SN', dialCode: '+221', flag: '🇸🇳'),
    CountryCode(name: 'Zimbabwe', code: 'ZW', dialCode: '+263', flag: '🇿🇼'),
    CountryCode(name: 'Rwanda', code: 'RW', dialCode: '+250', flag: '🇷🇼'),
    CountryCode(name: 'Tunisia', code: 'TN', dialCode: '+216', flag: '🇹🇳'),
    CountryCode(name: 'Libya', code: 'LY', dialCode: '+218', flag: '🇱🇾'),
    CountryCode(name: 'Sudan', code: 'SD', dialCode: '+249', flag: '🇸🇩'),
    CountryCode(name: 'Zambia', code: 'ZM', dialCode: '+260', flag: '🇿🇲'),
    CountryCode(name: 'Botswana', code: 'BW', dialCode: '+267', flag: '🇧🇼'),
    CountryCode(name: 'Namibia', code: 'NA', dialCode: '+264', flag: '🇳🇦'),
    CountryCode(name: 'Mozambique', code: 'MZ', dialCode: '+258', flag: '🇲🇿'),
    CountryCode(name: 'Angola', code: 'AO', dialCode: '+244', flag: '🇦🇴'),
    CountryCode(name: 'Mali', code: 'ML', dialCode: '+223', flag: '🇲🇱'),
    CountryCode(name: 'Burkina Faso', code: 'BF', dialCode: '+226', flag: '🇧🇫'),
    CountryCode(name: 'Niger', code: 'NE', dialCode: '+227', flag: '🇳🇪'),
    CountryCode(name: 'Malawi', code: 'MW', dialCode: '+265', flag: '🇲🇼'),
    CountryCode(name: 'Benin', code: 'BJ', dialCode: '+229', flag: '🇧🇯'),
    CountryCode(name: 'Togo', code: 'TG', dialCode: '+228', flag: '🇹🇬'),
    CountryCode(name: 'Sierra Leone', code: 'SL', dialCode: '+232', flag: '🇸🇱'),
    CountryCode(name: 'Liberia', code: 'LR', dialCode: '+231', flag: '🇱🇷'),
    CountryCode(name: 'Mauritius', code: 'MU', dialCode: '+230', flag: '🇲🇺'),
    CountryCode(name: 'Congo (DRC)', code: 'CD', dialCode: '+243', flag: '🇨🇩'),
    CountryCode(name: 'Congo', code: 'CG', dialCode: '+242', flag: '🇨🇬'),
    CountryCode(name: 'Gabon', code: 'GA', dialCode: '+241', flag: '🇬🇦'),
    CountryCode(name: 'Equatorial Guinea', code: 'GQ', dialCode: '+240', flag: '🇬🇶'),
    CountryCode(name: 'Central African Republic', code: 'CF', dialCode: '+236', flag: '🇨🇫'),
    CountryCode(name: 'Chad', code: 'TD', dialCode: '+235', flag: '🇹🇩'),
    CountryCode(name: 'Somalia', code: 'SO', dialCode: '+252', flag: '🇸🇴'),
    CountryCode(name: 'Djibouti', code: 'DJ', dialCode: '+253', flag: '🇩🇯'),
    CountryCode(name: 'Eritrea', code: 'ER', dialCode: '+291', flag: '🇪🇷'),
    CountryCode(name: 'Gambia', code: 'GM', dialCode: '+220', flag: '🇬🇲'),
    CountryCode(name: 'Guinea', code: 'GN', dialCode: '+224', flag: '🇬🇳'),
    CountryCode(name: 'Guinea-Bissau', code: 'GW', dialCode: '+245', flag: '🇬🇼'),
    CountryCode(name: 'Lesotho', code: 'LS', dialCode: '+266', flag: '🇱🇸'),
    CountryCode(name: 'Madagascar', code: 'MG', dialCode: '+261', flag: '🇲🇬'),
    CountryCode(name: 'Mauritania', code: 'MR', dialCode: '+222', flag: '🇲🇷'),
    CountryCode(name: 'Seychelles', code: 'SC', dialCode: '+248', flag: '🇸🇨'),
    CountryCode(name: 'South Sudan', code: 'SS', dialCode: '+211', flag: '🇸🇸'),
    CountryCode(name: 'Eswatini', code: 'SZ', dialCode: '+268', flag: '🇸🇿'),
    CountryCode(name: 'Cape Verde', code: 'CV', dialCode: '+238', flag: '🇨🇻'),
    CountryCode(name: 'Comoros', code: 'KM', dialCode: '+269', flag: '🇰🇲'),
    CountryCode(name: 'São Tomé and Príncipe', code: 'ST', dialCode: '+239', flag: '🇸🇹'),
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
