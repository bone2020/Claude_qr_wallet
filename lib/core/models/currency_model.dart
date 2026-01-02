/// Model representing a currency with its details
class CurrencyModel {
  final String code;
  final String symbol;
  final String name;
  final String countryCode;
  final String flag;

  const CurrencyModel({
    required this.code,
    required this.symbol,
    required this.name,
    required this.countryCode,
    required this.flag,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'symbol': symbol,
      'name': name,
      'countryCode': countryCode,
      'flag': flag,
    };
  }

  factory CurrencyModel.fromMap(Map<String, dynamic> map) {
    return CurrencyModel(
      code: map['code'] ?? '',
      symbol: map['symbol'] ?? '',
      name: map['name'] ?? '',
      countryCode: map['countryCode'] ?? '',
      flag: map['flag'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CurrencyModel && other.code == code;
  }

  @override
  int get hashCode => code.hashCode;
}
