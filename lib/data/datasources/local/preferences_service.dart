import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_constants.dart';

/// Hive-backed key/value store for user settings and fast caches
/// (favorites, last live values, offline export queue).
class PreferencesService {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();

  late Box _settings;
  late Box _cache;

  Future<void> init() async {
    await Hive.initFlutter();
    _settings = await Hive.openBox(AppConstants.settingsBox);
    _cache = await Hive.openBox(AppConstants.cacheBox);
  }

  // ── Settings ─────────────────────────────────────────────────────

  String get languageCode => _settings.get('language', defaultValue: 'ar');
  Future<void> setLanguageCode(String code) => _settings.put('language', code);

  bool get isDarkMode => _settings.get('darkMode', defaultValue: true);
  Future<void> setDarkMode(bool value) => _settings.put('darkMode', value);

  bool get tempAlertsEnabled =>
      _settings.get('tempAlerts', defaultValue: true);
  Future<void> setTempAlerts(bool v) => _settings.put('tempAlerts', v);

  bool get dtcAlertsEnabled => _settings.get('dtcAlerts', defaultValue: true);
  Future<void> setDtcAlerts(bool v) => _settings.put('dtcAlerts', v);

  bool get fuelAlertsEnabled =>
      _settings.get('fuelAlerts', defaultValue: true);
  Future<void> setFuelAlerts(bool v) => _settings.put('fuelAlerts', v);

  bool get dailyReportEnabled =>
      _settings.get('dailyReport', defaultValue: true);
  Future<void> setDailyReport(bool v) => _settings.put('dailyReport', v);

  int get reportHour =>
      _settings.get('reportHour', defaultValue: AppConstants.defaultReportHour);
  int get reportMinute => _settings.get('reportMinute', defaultValue: 0);
  Future<void> setReportTime(int hour, int minute) async {
    await _settings.put('reportHour', hour);
    await _settings.put('reportMinute', minute);
  }

  // ── Cache ────────────────────────────────────────────────────────

  String? get lastDeviceAddress => _cache.get('lastDeviceAddress');
  Future<void> setLastDeviceAddress(String address) =>
      _cache.put('lastDeviceAddress', address);

  DateTime? get lastRetentionRun {
    final ms = _cache.get('lastRetentionRun') as int?;
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> setLastRetentionRun(DateTime time) =>
      _cache.put('lastRetentionRun', time.millisecondsSinceEpoch);

  DateTime? get lastBackup {
    final ms = _cache.get('lastBackup') as int?;
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> setLastBackup(DateTime time) =>
      _cache.put('lastBackup', time.millisecondsSinceEpoch);

  /// Offline export queue: list of pending export kinds ('csv' | 'json' |
  /// 'pdf:<path>'), flushed when connectivity returns.
  List<String> get pendingExports =>
      (_cache.get('pendingExports', defaultValue: <String>[]) as List)
          .cast<String>();

  Future<void> queueExport(String kind) async {
    final queue = [...pendingExports];
    if (!queue.contains(kind)) queue.add(kind);
    await _cache.put('pendingExports', queue);
  }

  Future<void> clearPendingExports() => _cache.put('pendingExports', <String>[]);
}
