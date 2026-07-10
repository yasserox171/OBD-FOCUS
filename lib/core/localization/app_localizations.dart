import 'package:flutter/material.dart';

import 'strings_ar.dart';
import 'strings_en.dart';

/// Lightweight, dependency-free localization.
///
/// All strings live in [stringsEn] / [stringsAr]; lookups fall back to the
/// English table, then to the key itself, so a missing translation never
/// crashes the UI.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('ar')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      AppLocalizations(const Locale('en'));

  Map<String, String> get _table =>
      locale.languageCode == 'ar' ? stringsAr : stringsEn;

  bool get isArabic => locale.languageCode == 'ar';

  /// Translate [key]; optional `{placeholders}` are substituted from [args].
  String tr(String key, [Map<String, String>? args]) {
    var value = _table[key] ?? stringsEn[key] ?? key;
    args?.forEach((k, v) => value = value.replaceAll('{$k}', v));
    return value;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// `context.tr('key')` convenience extension.
extension LocalizationX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key, [Map<String, String>? args]) => l10n.tr(key, args);
}
