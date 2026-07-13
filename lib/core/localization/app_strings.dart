import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings(this.bangla);
  final bool bangla;

  static AppStrings of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'bn'
      ? const AppStrings(true)
      : const AppStrings(false);

  String t(String english, String banglaText) => bangla ? banglaText : english;
  String get appName => t('Smart Hisab', 'স্মার্ট হিসাব');
  String get home => t('Home', 'হোম');
  String get transactions => t('Transactions', 'লেনদেন');
  String get reports => t('Reports', 'রিপোর্ট');
  String get more => t('More', 'আরও');
  String get add => t('Add', 'যোগ করুন');
}
