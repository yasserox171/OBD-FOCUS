import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/datasources/local/database_helper.dart';
import '../data/models/obd2_record.dart';

/// Serializes stored records to CSV / JSON files in the app documents dir.
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  static final _fileStamp = DateFormat('yyyyMMdd_HHmmss');

  Future<List<Obd2Record>> _allRecords() =>
      DatabaseHelper.instance.getRecords(limit: 100000, offset: 0);

  Future<File> exportCsv() async {
    final records = await _allRecords();
    final buffer = StringBuffer()
      ..writeln('timestamp,engine_temp_c,rpm,speed_kmh,fuel_percent,'
          'throttle_percent,intake_air_temp_c,oxygen_sensor_v,'
          'battery_voltage_v,check_engine_light');
    for (final r in records) {
      buffer.writeln([
        r.timestamp.toIso8601String(),
        r.engineTemp ?? '',
        r.rpm ?? '',
        r.speed ?? '',
        r.fuelLevel?.toStringAsFixed(1) ?? '',
        r.throttlePosition?.toStringAsFixed(1) ?? '',
        r.intakeAirTemp?.toStringAsFixed(1) ?? '',
        r.oxygenSensor?.toStringAsFixed(3) ?? '',
        r.batteryVoltage?.toStringAsFixed(2) ?? '',
        r.checkEngineLight ? 1 : 0,
      ].join(','));
    }
    return _writeFile(
        'obd2_records_${_fileStamp.format(DateTime.now())}.csv',
        buffer.toString());
  }

  Future<File> exportJson() async {
    final records = await _allRecords();
    final payload = const JsonEncoder.withIndent('  ').convert({
      'app': 'Focus OBD2 Scanner',
      'exportedAt': DateTime.now().toIso8601String(),
      'recordCount': records.length,
      'records': records.map((r) => r.toJson()).toList(),
    });
    return _writeFile(
        'obd2_records_${_fileStamp.format(DateTime.now())}.json', payload);
  }

  Future<File> _writeFile(String name, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(p.join(dir.path, 'exports'));
    if (!exportsDir.existsSync()) exportsDir.createSync(recursive: true);
    final file = File(p.join(exportsDir.path, name));
    return file.writeAsString(content);
  }
}
