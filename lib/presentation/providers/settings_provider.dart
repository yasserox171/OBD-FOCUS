import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/strings_ar.dart';
import '../../core/localization/strings_en.dart';
import '../../data/datasources/local/preferences_service.dart';
import '../../services/notification_service.dart';

/// Immutable snapshot of user settings.
class SettingsState {
  const SettingsState({
    required this.locale,
    required this.isDarkMode,
    required this.tempAlerts,
    required this.dtcAlerts,
    required this.fuelAlerts,
    required this.dailyReport,
    required this.reportHour,
    required this.reportMinute,
  });

  final Locale locale;
  final bool isDarkMode;
  final bool tempAlerts;
  final bool dtcAlerts;
  final bool fuelAlerts;
  final bool dailyReport;
  final int reportHour;
  final int reportMinute;

  bool get isArabic => locale.languageCode == 'ar';

  SettingsState copyWith({
    Locale? locale,
    bool? isDarkMode,
    bool? tempAlerts,
    bool? dtcAlerts,
    bool? fuelAlerts,
    bool? dailyReport,
    int? reportHour,
    int? reportMinute,
  }) =>
      SettingsState(
        locale: locale ?? this.locale,
        isDarkMode: isDarkMode ?? this.isDarkMode,
        tempAlerts: tempAlerts ?? this.tempAlerts,
        dtcAlerts: dtcAlerts ?? this.dtcAlerts,
        fuelAlerts: fuelAlerts ?? this.fuelAlerts,
        dailyReport: dailyReport ?? this.dailyReport,
        reportHour: reportHour ?? this.reportHour,
        reportMinute: reportMinute ?? this.reportMinute,
      );
}

class SettingsNotifier extends Notifier<SettingsState> {
  PreferencesService get _prefs => PreferencesService.instance;

  @override
  SettingsState build() => SettingsState(
        locale: Locale(_prefs.languageCode),
        isDarkMode: _prefs.isDarkMode,
        tempAlerts: _prefs.tempAlertsEnabled,
        dtcAlerts: _prefs.dtcAlertsEnabled,
        fuelAlerts: _prefs.fuelAlertsEnabled,
        dailyReport: _prefs.dailyReportEnabled,
        reportHour: _prefs.reportHour,
        reportMinute: _prefs.reportMinute,
      );

  Future<void> setLanguage(String code) async {
    await _prefs.setLanguageCode(code);
    state = state.copyWith(locale: Locale(code));
    if (state.dailyReport) await _rescheduleDailyReport();
  }

  Future<void> setDarkMode(bool value) async {
    await _prefs.setDarkMode(value);
    state = state.copyWith(isDarkMode: value);
  }

  Future<void> setTempAlerts(bool v) async {
    await _prefs.setTempAlerts(v);
    state = state.copyWith(tempAlerts: v);
  }

  Future<void> setDtcAlerts(bool v) async {
    await _prefs.setDtcAlerts(v);
    state = state.copyWith(dtcAlerts: v);
  }

  Future<void> setFuelAlerts(bool v) async {
    await _prefs.setFuelAlerts(v);
    state = state.copyWith(fuelAlerts: v);
  }

  Future<void> setDailyReport(bool v) async {
    await _prefs.setDailyReport(v);
    state = state.copyWith(dailyReport: v);
    if (v) {
      await _rescheduleDailyReport();
    } else {
      await NotificationService.instance.cancelDailyReport();
    }
  }

  Future<void> setReportTime(int hour, int minute) async {
    await _prefs.setReportTime(hour, minute);
    state = state.copyWith(reportHour: hour, reportMinute: minute);
    if (state.dailyReport) await _rescheduleDailyReport();
  }

  Future<void> _rescheduleDailyReport() {
    final strings = state.isArabic ? stringsAr : stringsEn;
    return NotificationService.instance.scheduleDailyReport(
      hour: state.reportHour,
      minute: state.reportMinute,
      title: strings['reportNotifTitle']!,
      body: strings['reportNotifBody']!,
    );
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
