import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../models/daily_report.dart';
import '../../models/dtc_code.dart';
import '../../models/obd2_record.dart';
import '../../models/obd_device.dart';

/// Aggregate statistics over a range of [Obd2Record]s (used by reports,
/// history summaries and WhatsApp share text).
class RecordStats {
  const RecordStats({
    required this.count,
    this.avgTemp,
    this.maxTemp,
    this.minTemp,
    this.avgRpm,
    this.maxRpm,
    this.avgFuel,
    this.minFuel,
    this.maxFuel,
    this.maxSpeed,
    this.avgSpeed,
  });

  final int count;
  final double? avgTemp, maxTemp, minTemp;
  final double? avgRpm, maxRpm;
  final double? avgFuel, minFuel, maxFuel;
  final double? maxSpeed, avgSpeed;

  static const empty = RecordStats(count: 0);
}

/// Single access point to the SQLite database.
///
/// Owns schema creation/migration, CRUD for the four tables and the smart
/// retention policy (row cap + age-based compaction).
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'focus_obd2.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async =>
      _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createSchema,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE obd2_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        engine_temp REAL,
        rpm INTEGER,
        speed INTEGER,
        fuel_level REAL,
        throttle_position REAL,
        intake_air_temp REAL,
        oxygen_sensor REAL,
        battery_voltage REAL,
        check_engine_light INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_records_timestamp ON obd2_records(timestamp)');

    await db.execute('''
      CREATE TABLE dtc_codes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        description TEXT NOT NULL,
        severity TEXT NOT NULL,
        status TEXT NOT NULL,
        detected_date INTEGER NOT NULL,
        cleared_date INTEGER,
        first_seen INTEGER NOT NULL,
        last_seen INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_dtc_code ON dtc_codes(code)');
    await db
        .execute('CREATE INDEX idx_dtc_cleared ON dtc_codes(cleared_date)');

    await db.execute('''
      CREATE TABLE daily_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date INTEGER NOT NULL UNIQUE,
        pdf_path TEXT,
        summary TEXT,
        average_temp REAL,
        max_temp REAL,
        min_temp REAL,
        average_rpm REAL,
        max_rpm REAL,
        average_fuel REAL,
        min_fuel REAL,
        max_speed REAL,
        dtc_count INTEGER NOT NULL DEFAULT 0,
        record_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mac_address TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        last_connected INTEGER,
        connection_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ── obd2_records ─────────────────────────────────────────────────────────

  Future<int> insertRecord(Obd2Record record) async {
    final db = await database;
    return db.insert('obd2_records', record.toMap());
  }

  /// Paginated fetch, newest first. [from]/[to] filter by timestamp.
  Future<List<Obd2Record>> getRecords({
    int limit = AppConstants.pageSize,
    int offset = 0,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object>[];
    if (from != null) {
      where.add('timestamp >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('timestamp <= ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await db.query(
      'obd2_records',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Obd2Record.fromMap).toList();
  }

  Future<int> recordCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM obd2_records');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Aggregate stats for records in [from, to].
  Future<RecordStats> recordStats({DateTime? from, DateTime? to}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object>[];
    if (from != null) {
      where.add('timestamp >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('timestamp <= ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final clause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS c,
             AVG(engine_temp) AS avg_temp, MAX(engine_temp) AS max_temp,
             MIN(engine_temp) AS min_temp,
             AVG(rpm) AS avg_rpm, MAX(rpm) AS max_rpm,
             AVG(fuel_level) AS avg_fuel, MIN(fuel_level) AS min_fuel,
             MAX(fuel_level) AS max_fuel,
             MAX(speed) AS max_speed, AVG(speed) AS avg_speed
      FROM obd2_records $clause
    ''', args);
    final r = rows.first;
    double? d(String key) => (r[key] as num?)?.toDouble();
    return RecordStats(
      count: (r['c'] as int?) ?? 0,
      avgTemp: d('avg_temp'),
      maxTemp: d('max_temp'),
      minTemp: d('min_temp'),
      avgRpm: d('avg_rpm'),
      maxRpm: d('max_rpm'),
      avgFuel: d('avg_fuel'),
      minFuel: d('min_fuel'),
      maxFuel: d('max_fuel'),
      maxSpeed: d('max_speed'),
      avgSpeed: d('avg_speed'),
    );
  }

  Future<void> deleteAllRecords() async {
    final db = await database;
    await db.delete('obd2_records');
  }

  /// Smart retention:
  ///  1. Compact records older than [AppConstants.retentionDays] into one
  ///     averaged record per day, then delete the raw rows.
  ///  2. Enforce the [AppConstants.maxRecords] row cap (oldest rows first).
  Future<void> enforceRetention() async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: AppConstants.retentionDays))
        .millisecondsSinceEpoch;

    // 1) Compact: one averaged row per old day.
    final oldDays = await db.rawQuery('''
      SELECT DATE(timestamp / 1000, 'unixepoch') AS day,
             MIN(timestamp) AS day_start,
             AVG(engine_temp) AS engine_temp, AVG(rpm) AS rpm,
             AVG(speed) AS speed, AVG(fuel_level) AS fuel_level,
             AVG(throttle_position) AS throttle_position,
             AVG(intake_air_temp) AS intake_air_temp,
             AVG(oxygen_sensor) AS oxygen_sensor,
             AVG(battery_voltage) AS battery_voltage,
             MAX(check_engine_light) AS mil,
             COUNT(*) AS c
      FROM obd2_records
      WHERE timestamp < ?
      GROUP BY day
      HAVING c > 1
    ''', [cutoff]);

    final batch = db.batch();
    for (final day in oldDays) {
      batch.insert('obd2_records', {
        'timestamp': day['day_start'],
        'engine_temp': day['engine_temp'],
        'rpm': (day['rpm'] as num?)?.round(),
        'speed': (day['speed'] as num?)?.round(),
        'fuel_level': day['fuel_level'],
        'throttle_position': day['throttle_position'],
        'intake_air_temp': day['intake_air_temp'],
        'oxygen_sensor': day['oxygen_sensor'],
        'battery_voltage': day['battery_voltage'],
        'check_engine_light': day['mil'] ?? 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
    if (oldDays.isNotEmpty) {
      // Delete the raw rows that were compacted (insert happened after the
      // select, so exclude the freshly inserted averages via created_at).
      batch.rawDelete(
        'DELETE FROM obd2_records WHERE timestamp < ? AND created_at < ?',
        [cutoff, DateTime.now().millisecondsSinceEpoch - 1000],
      );
      await batch.commit(noResult: true);
    }

    // 2) Row cap.
    await db.rawDelete('''
      DELETE FROM obd2_records WHERE id NOT IN (
        SELECT id FROM obd2_records ORDER BY timestamp DESC LIMIT ?
      )
    ''', [AppConstants.maxRecords]);
  }

  // ── dtc_codes ────────────────────────────────────────────────────────────

  /// Upsert a detected code: updates `last_seen`/status if an active row for
  /// the same code exists, otherwise inserts a new row.
  /// Returns `true` if this is a newly detected code (for alerting).
  Future<bool> upsertDtc(DtcCode dtc) async {
    final db = await database;
    final existing = await db.query(
      'dtc_codes',
      where: 'code = ? AND cleared_date IS NULL',
      whereArgs: [dtc.code],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('dtc_codes', dtc.toMap());
      return true;
    }
    await db.update(
      'dtc_codes',
      {
        'last_seen': dtc.lastSeen.millisecondsSinceEpoch,
        'status': dtc.status.name,
      },
      where: 'id = ?',
      whereArgs: [existing.first['id']],
    );
    return false;
  }

  Future<List<DtcCode>> getDtcs({bool activeOnly = true}) async {
    final db = await database;
    final rows = await db.query(
      'dtc_codes',
      where: activeOnly ? 'cleared_date IS NULL' : null,
      orderBy: 'last_seen DESC',
    );
    return rows.map(DtcCode.fromMap).toList();
  }

  /// Marks all active codes as cleared (after a successful Mode 04).
  Future<void> markDtcsCleared() async {
    final db = await database;
    await db.update(
      'dtc_codes',
      {'cleared_date': DateTime.now().millisecondsSinceEpoch},
      where: 'cleared_date IS NULL',
    );
  }

  Future<int> dtcCountSince(DateTime since) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM dtc_codes WHERE detected_date >= ?',
      [since.millisecondsSinceEpoch],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── daily_reports ────────────────────────────────────────────────────────

  Future<int> upsertReport(DailyReport report) async {
    final db = await database;
    return db.insert(
      'daily_reports',
      report.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DailyReport>> getReports(
      {int limit = AppConstants.maxReports}) async {
    final db = await database;
    final rows = await db.query(
      'daily_reports',
      orderBy: 'date DESC',
      limit: limit,
    );
    return rows.map(DailyReport.fromMap).toList();
  }

  /// Keep only the newest [AppConstants.maxReports] reports.
  Future<void> pruneReports() async {
    final db = await database;
    await db.rawDelete('''
      DELETE FROM daily_reports WHERE id NOT IN (
        SELECT id FROM daily_reports ORDER BY date DESC LIMIT ?
      )
    ''', [AppConstants.maxReports]);
  }

  // ── devices ──────────────────────────────────────────────────────────────

  Future<List<ObdDevice>> getDevices() async {
    final db = await database;
    final rows = await db.query(
      'devices',
      orderBy: 'is_favorite DESC, last_connected DESC',
    );
    return rows.map(ObdDevice.fromMap).toList();
  }

  Future<void> saveDevice(ObdDevice device) async {
    final db = await database;
    await db.insert(
      'devices',
      device.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> recordConnection(String macAddress, String name) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = await db.rawUpdate('''
      UPDATE devices
      SET last_connected = ?, connection_count = connection_count + 1, name = ?
      WHERE mac_address = ?
    ''', [now, name, macAddress]);
    if (updated == 0) {
      await db.insert('devices', {
        'mac_address': macAddress,
        'name': name,
        'is_favorite': 0,
        'last_connected': now,
        'connection_count': 1,
      });
    }
  }

  Future<void> setFavorite(String macAddress, bool favorite) async {
    final db = await database;
    await db.update(
      'devices',
      {'is_favorite': favorite ? 1 : 0},
      where: 'mac_address = ?',
      whereArgs: [macAddress],
    );
  }

  // ── misc ─────────────────────────────────────────────────────────────────

  /// Approximate database file size in bytes.
  Future<int> databaseSizeBytes() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT page_count * page_size AS size FROM pragma_page_count(), pragma_page_size()');
    return (rows.first['size'] as int?) ?? 0;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
