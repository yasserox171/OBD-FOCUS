import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/datasources/local/database_helper.dart';

/// Builds and shares the WhatsApp-friendly summary message and files.
/// share_plus opens the system share sheet, where WhatsApp is one target;
/// this keeps the flow working even when WhatsApp isn't installed.
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  /// The message template from the product spec, filled from [stats].
  String buildSummaryMessage({
    required RecordStats stats,
    required int dtcCount,
    required DateTime from,
    required DateTime to,
    required bool arabic,
  }) {
    String n(double? v, {int digits = 0}) =>
        v == null ? '—' : v.toStringAsFixed(digits);

    if (arabic) {
      return '''
🚗 تقرير Focus OBD2 Scanner
📊 البيانات المختارة:
🌡️ درجة الحرارة: المتوسط ${n(stats.avgTemp)}°م، الأعلى ${n(stats.maxTemp)}°م، الأدنى ${n(stats.minTemp)}°م
⚙️ RPM: المتوسط ${n(stats.avgRpm)}، الأعلى ${n(stats.maxRpm)}
🚗 السرعة: الأعلى ${n(stats.maxSpeed)} كم/س، المتوسط ${n(stats.avgSpeed)} كم/س
🛢️ الوقود: من ${n(stats.minFuel)}٪ إلى ${n(stats.maxFuel)}٪
⚠️ الأكواد: عدد الأكواد $dtcCount
📅 الفترة: من ${_dateFmt.format(from)} إلى ${_dateFmt.format(to)}
تم من Focus OBD2 Scanner''';
    }
    return '''
🚗 Focus OBD2 Scanner Report
📊 Selected data:
🌡️ Temperature: avg ${n(stats.avgTemp)}°C, max ${n(stats.maxTemp)}°C, min ${n(stats.minTemp)}°C
⚙️ RPM: avg ${n(stats.avgRpm)}, max ${n(stats.maxRpm)}
🚗 Speed: max ${n(stats.maxSpeed)} km/h, avg ${n(stats.avgSpeed)} km/h
🛢️ Fuel: from ${n(stats.minFuel)}% to ${n(stats.maxFuel)}%
⚠️ Codes: $dtcCount trouble codes
📅 Period: ${_dateFmt.format(from)} — ${_dateFmt.format(to)}
Sent from Focus OBD2 Scanner''';
  }

  Future<void> shareText(String text) => Share.share(text);

  Future<void> shareFile(String path, {String? text}) =>
      Share.shareXFiles([XFile(path)], text: text);
}
