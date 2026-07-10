/// Aggregated daily performance summary, persisted to `daily_reports`.
class DailyReport {
  const DailyReport({
    this.id,
    required this.date,
    this.pdfPath,
    this.summary = '',
    this.averageTemp,
    this.maxTemp,
    this.minTemp,
    this.averageRpm,
    this.maxRpm,
    this.averageFuel,
    this.minFuel,
    this.maxSpeed,
    this.dtcCount = 0,
    this.recordCount = 0,
  });

  final int? id;

  /// Report day (date only, `yyyy-MM-dd` semantics — time is midnight).
  final DateTime date;
  final String? pdfPath;
  final String summary;
  final double? averageTemp;
  final double? maxTemp;
  final double? minTemp;
  final double? averageRpm;
  final double? maxRpm;
  final double? averageFuel;
  final double? minFuel;
  final double? maxSpeed;
  final int dtcCount;
  final int recordCount;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'date': date.millisecondsSinceEpoch,
        'pdf_path': pdfPath,
        'summary': summary,
        'average_temp': averageTemp,
        'max_temp': maxTemp,
        'min_temp': minTemp,
        'average_rpm': averageRpm,
        'max_rpm': maxRpm,
        'average_fuel': averageFuel,
        'min_fuel': minFuel,
        'max_speed': maxSpeed,
        'dtc_count': dtcCount,
        'record_count': recordCount,
      };

  factory DailyReport.fromMap(Map<String, Object?> map) => DailyReport(
        id: map['id'] as int?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        pdfPath: map['pdf_path'] as String?,
        summary: map['summary'] as String? ?? '',
        averageTemp: (map['average_temp'] as num?)?.toDouble(),
        maxTemp: (map['max_temp'] as num?)?.toDouble(),
        minTemp: (map['min_temp'] as num?)?.toDouble(),
        averageRpm: (map['average_rpm'] as num?)?.toDouble(),
        maxRpm: (map['max_rpm'] as num?)?.toDouble(),
        averageFuel: (map['average_fuel'] as num?)?.toDouble(),
        minFuel: (map['min_fuel'] as num?)?.toDouble(),
        maxSpeed: (map['max_speed'] as num?)?.toDouble(),
        dtcCount: map['dtc_count'] as int? ?? 0,
        recordCount: map['record_count'] as int? ?? 0,
      );

  DailyReport copyWith({int? id, String? pdfPath, String? summary}) =>
      DailyReport(
        id: id ?? this.id,
        date: date,
        pdfPath: pdfPath ?? this.pdfPath,
        summary: summary ?? this.summary,
        averageTemp: averageTemp,
        maxTemp: maxTemp,
        minTemp: minTemp,
        averageRpm: averageRpm,
        maxRpm: maxRpm,
        averageFuel: averageFuel,
        minFuel: minFuel,
        maxSpeed: maxSpeed,
        dtcCount: dtcCount,
        recordCount: recordCount,
      );
}
