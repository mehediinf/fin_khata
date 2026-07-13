import 'package:intl/intl.dart';

class AppCurrency {
  const AppCurrency({
    required this.code,
    required this.name,
    required this.symbol,
  });

  final String code;
  final String name;
  final String symbol;

  static const supported = <AppCurrency>[
    AppCurrency(code: 'BDT', name: 'Bangladeshi Taka', symbol: '৳'),
    AppCurrency(code: 'USD', name: 'US Dollar', symbol: r'$'),
    AppCurrency(code: 'EUR', name: 'Euro', symbol: '€'),
    AppCurrency(code: 'GBP', name: 'British Pound', symbol: '£'),
    AppCurrency(code: 'INR', name: 'Indian Rupee', symbol: '₹'),
    AppCurrency(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ'),
    AppCurrency(code: 'SAR', name: 'Saudi Riyal', symbol: 'ر.س'),
    AppCurrency(code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM'),
    AppCurrency(code: 'SGD', name: 'Singapore Dollar', symbol: r'S$'),
    AppCurrency(code: 'JPY', name: 'Japanese Yen', symbol: '¥'),
    AppCurrency(code: 'CAD', name: 'Canadian Dollar', symbol: r'C$'),
    AppCurrency(code: 'AUD', name: 'Australian Dollar', symbol: r'A$'),
  ];

  static AppCurrency fromCode(String code) => supported.firstWhere(
    (currency) => currency.code == code,
    orElse: () => supported.first,
  );
}

String formatMoney(double value, String currencyCode) {
  final currency = AppCurrency.fromCode(currencyCode);
  return NumberFormat.currency(
    locale: 'en',
    symbol: currency.symbol,
    decimalDigits: currencyCode == 'JPY' || value % 1 == 0 ? 0 : 2,
  ).format(value);
}
