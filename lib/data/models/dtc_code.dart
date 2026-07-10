/// Severity classes for diagnostic trouble codes.
enum DtcSeverity { critical, moderate, low }

/// Reporting status per SAE J1979 read modes:
/// Mode 03 → confirmed, Mode 07 → pending, Mode 0A → permanent.
enum DtcStatus { confirmed, pending, permanent }

/// A diagnostic trouble code, persisted to `dtc_codes`.
class DtcCode {
  const DtcCode({
    this.id,
    required this.code,
    required this.description,
    this.severity = DtcSeverity.moderate,
    this.status = DtcStatus.confirmed,
    required this.detectedDate,
    this.clearedDate,
    DateTime? firstSeen,
    DateTime? lastSeen,
  })  : firstSeen = firstSeen ?? detectedDate,
        lastSeen = lastSeen ?? detectedDate;

  final int? id;
  final String code; // e.g. "P0301"
  final String description;
  final DtcSeverity severity;
  final DtcStatus status;
  final DateTime detectedDate;
  final DateTime? clearedDate;
  final DateTime firstSeen;
  final DateTime lastSeen;

  bool get isActive => clearedDate == null;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'code': code,
        'description': description,
        'severity': severity.name,
        'status': status.name,
        'detected_date': detectedDate.millisecondsSinceEpoch,
        'cleared_date': clearedDate?.millisecondsSinceEpoch,
        'first_seen': firstSeen.millisecondsSinceEpoch,
        'last_seen': lastSeen.millisecondsSinceEpoch,
      };

  factory DtcCode.fromMap(Map<String, Object?> map) => DtcCode(
        id: map['id'] as int?,
        code: map['code'] as String,
        description: map['description'] as String? ?? '',
        severity: DtcSeverity.values.firstWhere(
          (s) => s.name == map['severity'],
          orElse: () => DtcSeverity.moderate,
        ),
        status: DtcStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => DtcStatus.confirmed,
        ),
        detectedDate:
            DateTime.fromMillisecondsSinceEpoch(map['detected_date'] as int),
        clearedDate: map['cleared_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['cleared_date'] as int)
            : null,
        firstSeen: map['first_seen'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['first_seen'] as int)
            : null,
        lastSeen: map['last_seen'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['last_seen'] as int)
            : null,
      );

  DtcCode copyWith({
    int? id,
    DtcStatus? status,
    DateTime? clearedDate,
    DateTime? lastSeen,
  }) =>
      DtcCode(
        id: id ?? this.id,
        code: code,
        description: description,
        severity: severity,
        status: status ?? this.status,
        detectedDate: detectedDate,
        clearedDate: clearedDate ?? this.clearedDate,
        firstSeen: firstSeen,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}
