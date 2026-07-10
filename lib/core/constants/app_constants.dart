/// Application-wide constants: thresholds, retention policy, timings.
abstract class AppConstants {
  static const String appName = 'Focus OBD2 Scanner';
  static const String appVersion = '1.0.0';

  // ── Live data ────────────────────────────────────────────────────────────
  /// Interval between live PID polling cycles (Dashboard refresh).
  static const Duration liveDataInterval = Duration(seconds: 1);

  /// A record is persisted to SQLite once per this interval while connected
  /// (persisting 1 Hz data would blow past the retention budget).
  static const Duration recordPersistInterval = Duration(seconds: 30);

  // ── Alert thresholds ─────────────────────────────────────────────────────
  /// Engine coolant temperature above this (°C) triggers a critical alert.
  static const double engineTempCriticalC = 110;

  /// Fuel level below this (%) triggers the low-fuel warning.
  static const double fuelLowPercent = 15;

  /// Battery voltage healthy window.
  static const double batteryLowV = 11.8;
  static const double batteryHighV = 14.8;

  // ── Data retention ───────────────────────────────────────────────────────
  /// Maximum number of raw records kept (≈ 14 days of typical driving).
  static const int maxRecords = 500;

  /// Records older than this many days are deleted (after compaction into
  /// daily averages).
  static const int retentionDays = 30;

  /// History page size.
  static const int pageSize = 50;

  // ── Reports ──────────────────────────────────────────────────────────────
  /// Default hour (24h clock) for the daily report notification: 11 PM.
  static const int defaultReportHour = 23;

  /// Number of past reports kept and listed.
  static const int maxReports = 30;

  // ── Google Drive ─────────────────────────────────────────────────────────
  static const String driveFolderName = 'Focus OBD2 Scanner';

  // ── Hive boxes ───────────────────────────────────────────────────────────
  static const String settingsBox = 'settings';
  static const String cacheBox = 'cache';
}
