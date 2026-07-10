import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications: critical engine-temp alerts, new DTC alerts,
/// low-fuel warnings and the quiet daily-report reminder.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Set by the app shell to deep-link when a notification is tapped
  /// (payload = route, e.g. '/reports').
  void Function(String route)? onNotificationTap;

  static const _tempChannel = AndroidNotificationDetails(
    'temp_alerts',
    'Engine temperature alerts',
    channelDescription: 'Critical engine overheating alerts',
    importance: Importance.max,
    priority: Priority.max,
    enableVibration: true,
    playSound: true,
    color: Color.fromARGB(255, 239, 68, 68),
  );

  static const _dtcChannel = AndroidNotificationDetails(
    'dtc_alerts',
    'Trouble code alerts',
    channelDescription: 'New diagnostic trouble code detected',
    importance: Importance.high,
    priority: Priority.high,
    enableVibration: true,
    playSound: true,
    color: Color.fromARGB(255, 245, 158, 11),
  );

  static const _fuelChannel = AndroidNotificationDetails(
    'fuel_alerts',
    'Low fuel alerts',
    channelDescription: 'Fuel level warnings',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    enableVibration: false,
    playSound: false,
    color: Color.fromARGB(255, 245, 158, 11),
  );

  static const _reportChannel = AndroidNotificationDetails(
    'daily_report',
    'Daily report',
    channelDescription: 'Daily vehicle report is ready',
    importance: Importance.low,
    priority: Priority.low,
    enableVibration: false,
    playSound: false,
  );

  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // Unknown zone — scheduling falls back to UTC wall time.
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTap?.call(payload);
        }
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showTempAlert(String title, String body) => _plugin.show(
      1, title, body, const NotificationDetails(android: _tempChannel));

  Future<void> showDtcAlert(String title, String body) => _plugin.show(
      2, title, body,
      const NotificationDetails(android: _dtcChannel),
      payload: '/dtc');

  Future<void> showFuelAlert(String title, String body) => _plugin.show(
      3, title, body, const NotificationDetails(android: _fuelChannel));

  Future<void> showReportReady(String title, String body) => _plugin.show(
      4, title, body,
      const NotificationDetails(android: _reportChannel),
      payload: '/reports');

  /// (Re)schedules the repeating daily-report notification at [hour]:[minute].
  Future<void> scheduleDailyReport({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await _plugin.cancel(100);
    final now = tz.TZDateTime.now(tz.local);
    var fireAt =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (fireAt.isBefore(now)) fireAt = fireAt.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      100,
      title,
      body,
      fireAt,
      const NotificationDetails(android: _reportChannel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '/reports',
    );
  }

  Future<void> cancelDailyReport() => _plugin.cancel(100);
}
