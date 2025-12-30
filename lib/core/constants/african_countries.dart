/// African country data with dial codes and currencies
class AfricanCountry {
  final String name;
  final String code; // ISO 3166-1 alpha-2
  final String dialCode;
  final String flag; // Emoji flag
  final String currencyCode;
  final String currencySymbol;
  final String currencyName;

  const AfricanCountry({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
    required this.currencyCode,
    required this.currencySymbol,
    required this.currencyName,
  });

  /// Get full phone prefix with dial code
  String get phonePrefix => dialCode;

  /// Display name with flag
  String get displayName => '$flag $name';

  /// Display for dropdown (flag + dial code)
  String get dropdownDisplay => '$flag $dialCode';
}

/// List of African countries
class AfricanCountries {
  static const List<AfricanCountry> all = [
    AfricanCountry(
      name: 'Nigeria',
      code: 'NG',
      dialCode: '+234',
      flag: '🇳🇬',
      currencyCode: 'NGN',
      currencySymbol: '₦',
      currencyName: 'Nigerian Naira',
    ),
    AfricanCountry(
      name: 'Kenya',
      code: 'KE',
      dialCode: '+254',
      flag: '🇰🇪',
      currencyCode: 'KES',
      currencySymbol: 'KSh',
      currencyName: 'Kenyan Shilling',
    ),
    AfricanCountry(
      name: 'South Africa',
      code: 'ZA',
      dialCode: '+27',
      flag: '🇿🇦',
      currencyCode: 'ZAR',
      currencySymbol: 'R',
      currencyName: 'South African Rand',
    ),
    AfricanCountry(
      name: 'Ghana',
      code: 'GH',
      dialCode: '+233',
      flag: '🇬🇭',
      currencyCode: 'GHS',
      currencySymbol: 'GH₵',
      currencyName: 'Ghanaian Cedi',
    ),
    AfricanCountry(
      name: 'Egypt',
      code: 'EG',
      dialCode: '+20',
      flag: '🇪🇬',
      currencyCode: 'EGP',
      currencySymbol: 'E£',
      currencyName: 'Egyptian Pound',
    ),
    AfricanCountry(
      name: 'Tanzania',
      code: 'TZ',
      dialCode: '+255',
      flag: '🇹🇿',
      currencyCode: 'TZS',
      currencySymbol: 'TSh',
      currencyName: 'Tanzanian Shilling',
    ),
    AfricanCountry(
      name: 'Uganda',
      code: 'UG',
      dialCode: '+256',
      flag: '🇺🇬',
      currencyCode: 'UGX',
      currencySymbol: 'USh',
      currencyName: 'Ugandan Shilling',
    ),
    AfricanCountry(
      name: 'Rwanda',
      code: 'RW',
      dialCode: '+250',
      flag: '🇷🇼',
      currencyCode: 'RWF',
      currencySymbol: 'FRw',
      currencyName: 'Rwandan Franc',
    ),
    AfricanCountry(
      name: 'Ethiopia',
      code: 'ET',
      dialCode: '+251',
      flag: '🇪🇹',
      currencyCode: 'ETB',
      currencySymbol: 'Br',
      currencyName: 'Ethiopian Birr',
    ),
    AfricanCountry(
      name: 'Morocco',
      code: 'MA',
      dialCode: '+212',
      flag: '🇲🇦',
      currencyCode: 'MAD',
      currencySymbol: 'DH',
      currencyName: 'Moroccan Dirham',
    ),
    AfricanCountry(
      name: 'Algeria',
      code: 'DZ',
      dialCode: '+213',
      flag: '🇩🇿',
      currencyCode: 'DZD',
      currencySymbol: 'DA',
      currencyName: 'Algerian Dinar',
    ),
    AfricanCountry(
      name: 'Tunisia',
      code: 'TN',
      dialCode: '+216',
      flag: '🇹🇳',
      currencyCode: 'TND',
      currencySymbol: 'DT',
      currencyName: 'Tunisian Dinar',
    ),
    AfricanCountry(
      name: 'Cameroon',
      code: 'CM',
      dialCode: '+237',
      flag: '🇨🇲',
      currencyCode: 'XAF',
      currencySymbol: 'FCFA',
      currencyName: 'Central African CFA Franc',
    ),
    AfricanCountry(
      name: 'Ivory Coast',
      code: 'CI',
      dialCode: '+225',
      flag: '🇨🇮',
      currencyCode: 'XOF',
      currencySymbol: 'CFA',
      currencyName: 'West African CFA Franc',
    ),
    AfricanCountry(
      name: 'Senegal',
      code: 'SN',
      dialCode: '+221',
      flag: '🇸🇳',
      currencyCode: 'XOF',
      currencySymbol: 'CFA',
      currencyName: 'West African CFA Franc',
    ),
    AfricanCountry(
      name: 'Zimbabwe',
      code: 'ZW',
      dialCode: '+263',
      flag: '🇿🇼',
      currencyCode: 'ZWL',
      currencySymbol: 'Z\$',
      currencyName: 'Zimbabwean Dollar',
    ),
    AfricanCountry(
      name: 'Zambia',
      code: 'ZM',
      dialCode: '+260',
      flag: '🇿🇲',
      currencyCode: 'ZMW',
      currencySymbol: 'ZK',
      currencyName: 'Zambian Kwacha',
    ),
    AfricanCountry(
      name: 'Botswana',
      code: 'BW',
      dialCode: '+267',
      flag: '🇧🇼',
      currencyCode: 'BWP',
      currencySymbol: 'P',
      currencyName: 'Botswana Pula',
    ),
    AfricanCountry(
      name: 'Namibia',
      code: 'NA',
      dialCode: '+264',
      flag: '🇳🇦',
      currencyCode: 'NAD',
      currencySymbol: 'N\$',
      currencyName: 'Namibian Dollar',
    ),
    AfricanCountry(
      name: 'Mozambique',
      code: 'MZ',
      dialCode: '+258',
      flag: '🇲🇿',
      currencyCode: 'MZN',
      currencySymbol: 'MT',
      currencyName: 'Mozambican Metical',
    ),
    AfricanCountry(
      name: 'Angola',
      code: 'AO',
      dialCode: '+244',
      flag: '🇦🇴',
      currencyCode: 'AOA',
      currencySymbol: 'Kz',
      currencyName: 'Angolan Kwanza',
    ),
    AfricanCountry(
      name: 'DR Congo',
      code: 'CD',
      dialCode: '+243',
      flag: '🇨🇩',
      currencyCode: 'CDF',
      currencySymbol: 'FC',
      currencyName: 'Congolese Franc',
    ),
    AfricanCountry(
      name: 'Sudan',
      code: 'SD',
      dialCode: '+249',
      flag: '🇸🇩',
      currencyCode: 'SDG',
      currencySymbol: 'SDG',
      currencyName: 'Sudanese Pound',
    ),
    AfricanCountry(
      name: 'Libya',
      code: 'LY',
      dialCode: '+218',
      flag: '🇱🇾',
      currencyCode: 'LYD',
      currencySymbol: 'LD',
      currencyName: 'Libyan Dinar',
    ),
    AfricanCountry(
      name: 'Mali',
      code: 'ML',
      dialCode: '+223',
      flag: '🇲🇱',
      currencyCode: 'XOF',
      currencySymbol: 'CFA',
      currencyName: 'West African CFA Franc',
    ),
    AfricanCountry(
      name: 'Benin',
      code: 'BJ',
      dialCode: '+229',
      flag: '🇧🇯',
      currencyCode: 'XOF',
      currencySymbol: 'CFA',
      currencyName: 'West African CFA Franc',
    ),
    AfricanCountry(
      name: 'Togo',
      code: 'TG',
      dialCode: '+228',
      flag: '🇹🇬',
      currencyCode: 'XOF',
      currencySymbol: 'CFA',
      currencyName: 'West African CFA Franc',
    ),
    AfricanCountry(
      name: 'Burkina Faso',
      code: 'BF',
      dialCode: '+226',
      flag: '🇧🇫',
      currencyCode: 'XOF',
      currencySymbol: 'CFA',
      currencyName: 'West African CFA Franc',
    ),
    AfricanCountry(
      name: 'Niger',
      code: 'NE',
      dialCode: '+227',
      flag: '🇳🇪',
      currencyCode: 'XOF',
      currencySymbol: 'CFA',
      currencyName: 'West African CFA Franc',
    ),
    AfricanCountry(
      name: 'Mauritius',
      code: 'MU',
      dialCode: '+230',
      flag: '🇲🇺',
      currencyCode: 'MUR',
      currencySymbol: 'Rs',
      currencyName: 'Mauritian Rupee',
    ),
    AfricanCountry(
      name: 'Malawi',
      code: 'MW',
      dialCode: '+265',
      flag: '🇲🇼',
      currencyCode: 'MWK',
      currencySymbol: 'MK',
      currencyName: 'Malawian Kwacha',
    ),
    AfricanCountry(
      name: 'Sierra Leone',
      code: 'SL',
      dialCode: '+232',
      flag: '🇸🇱',
      currencyCode: 'SLL',
      currencySymbol: 'Le',
      currencyName: 'Sierra Leonean Leone',
    ),
    AfricanCountry(
      name: 'Liberia',
      code: 'LR',
      dialCode: '+231',
      flag: '🇱🇷',
      currencyCode: 'LRD',
      currencySymbol: 'L\$',
      currencyName: 'Liberian Dollar',
    ),
    AfricanCountry(
      name: 'Gambia',
      code: 'GM',
      dialCode: '+220',
      flag: '🇬🇲',
      currencyCode: 'GMD',
      currencySymbol: 'D',
      currencyName: 'Gambian Dalasi',
    ),
    AfricanCountry(
      name: 'Guinea',
      code: 'GN',
      dialCode: '+224',
      flag: '🇬🇳',
      currencyCode: 'GNF',
      currencySymbol: 'FG',
      currencyName: 'Guinean Franc',
    ),
    AfricanCountry(
      name: 'Gabon',
      code: 'GA',
      dialCode: '+241',
      flag: '🇬🇦',
      currencyCode: 'XAF',
      currencySymbol: 'FCFA',
      currencyName: 'Central African CFA Franc',
    ),
    AfricanCountry(
      name: 'Congo',
      code: 'CG',
      dialCode: '+242',
      flag: '🇨🇬',
      currencyCode: 'XAF',
      currencySymbol: 'FCFA',
      currencyName: 'Central African CFA Franc',
    ),
    AfricanCountry(
      name: 'Equatorial Guinea',
      code: 'GQ',
      dialCode: '+240',
      flag: '🇬🇶',
      currencyCode: 'XAF',
      currencySymbol: 'FCFA',
      currencyName: 'Central African CFA Franc',
    ),
    AfricanCountry(
      name: 'Chad',
      code: 'TD',
      dialCode: '+235',
      flag: '🇹🇩',
      currencyCode: 'XAF',
      currencySymbol: 'FCFA',
      currencyName: 'Central African CFA Franc',
    ),
    AfricanCountry(
      name: 'Central African Republic',
      code: 'CF',
      dialCode: '+236',
      flag: '🇨🇫',
      currencyCode: 'XAF',
      currencySymbol: 'FCFA',
      currencyName: 'Central African CFA Franc',
    ),
    AfricanCountry(
      name: 'Burundi',
      code: 'BI',
      dialCode: '+257',
      flag: '🇧🇮',
      currencyCode: 'BIF',
      currencySymbol: 'FBu',
      currencyName: 'Burundian Franc',
    ),
    AfricanCountry(
      name: 'Eritrea',
      code: 'ER',
      dialCode: '+291',
      flag: '🇪🇷',
      currencyCode: 'ERN',
      currencySymbol: 'Nfk',
      currencyName: 'Eritrean Nakfa',
    ),
    AfricanCountry(
      name: 'Djibouti',
      code: 'DJ',
      dialCode: '+253',
      flag: '🇩🇯',
      currencyCode: 'DJF',
      currencySymbol: 'Fdj',
      currencyName: 'Djiboutian Franc',
    ),
    AfricanCountry(
      name: 'Somalia',
      code: 'SO',
      dialCode: '+252',
      flag: '🇸🇴',
      currencyCode: 'SOS',
      currencySymbol: 'Sh.So.',
      currencyName: 'Somali Shilling',
    ),
    AfricanCountry(
      name: 'South Sudan',
      code: 'SS',
      dialCode: '+211',
      flag: '🇸🇸',
      currencyCode: 'SSP',
      currencySymbol: 'SSP',
      currencyName: 'South Sudanese Pound',
    ),
    AfricanCountry(
      name: 'Lesotho',
      code: 'LS',
      dialCode: '+266',
      flag: '🇱🇸',
      currencyCode: 'LSL',
      currencySymbol: 'L',
      currencyName: 'Lesotho Loti',
    ),
    AfricanCountry(
      name: 'Eswatini',
      code: 'SZ',
      dialCode: '+268',
      flag: '🇸🇿',
      currencyCode: 'SZL',
      currencySymbol: 'E',
      currencyName: 'Swazi Lilangeni',
    ),
    AfricanCountry(
      name: 'Madagascar',
      code: 'MG',
      dialCode: '+261',
      flag: '🇲🇬',
      currencyCode: 'MGA',
      currencySymbol: 'Ar',
      currencyName: 'Malagasy Ariary',
    ),
    AfricanCountry(
      name: 'Seychelles',
      code: 'SC',
      dialCode: '+248',
      flag: '🇸🇨',
      currencyCode: 'SCR',
      currencySymbol: 'Rs',
      currencyName: 'Seychellois Rupee',
    ),
    AfricanCountry(
      name: 'Comoros',
      code: 'KM',
      dialCode: '+269',
      flag: '🇰🇲',
      currencyCode: 'KMF',
      currencySymbol: 'CF',
      currencyName: 'Comorian Franc',
    ),
    AfricanCountry(
      name: 'Mauritania',
      code: 'MR',
      dialCode: '+222',
      flag: '🇲🇷',
      currencyCode: 'MRU',
      currencySymbol: 'UM',
      currencyName: 'Mauritanian Ouguiya',
    ),
    AfricanCountry(
      name: 'Cape Verde',
      code: 'CV',
      dialCode: '+238',
      flag: '🇨🇻',
      currencyCode: 'CVE',
      currencySymbol: '\$',
      currencyName: 'Cape Verdean Escudo',
    ),
    AfricanCountry(
      name: 'Guinea-Bissau',
      code: 'GW',
      dialCode: '+245',
      flag: '🇬🇼',
      currencyCode: 'XOF',
      currencySymbol: 'CFA',
      currencyName: 'West African CFA Franc',
    ),
    AfricanCountry(
      name: 'Sao Tome and Principe',
      code: 'ST',
      dialCode: '+239',
      flag: '🇸🇹',
      currencyCode: 'STN',
      currencySymbol: 'Db',
      currencyName: 'Sao Tome and Principe Dobra',
    ),
  ];

  /// Get country by ISO code
  static AfricanCountry? getByCode(String code) {
    try {
      return all.firstWhere((c) => c.code == code.toUpperCase());
    } catch (e) {
      return null;
    }
  }

  /// Get country by dial code
  static AfricanCountry? getByDialCode(String dialCode) {
    try {
      return all.firstWhere((c) => c.dialCode == dialCode);
    } catch (e) {
      return null;
    }
  }

  /// Default country (Nigeria)
  static AfricanCountry get defaultCountry => all.first;

  /// Search countries by name
  static List<AfricanCountry> search(String query) {
    if (query.isEmpty) return all;
    final lowerQuery = query.toLowerCase();
    return all.where((c) =>
      c.name.toLowerCase().contains(lowerQuery) ||
      c.dialCode.contains(query) ||
      c.code.toLowerCase().contains(lowerQuery)
    ).toList();
  }
}
