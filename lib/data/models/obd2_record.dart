/// One snapshot of live vehicle telemetry, persisted to `obd2_records`.
class Obd2Record {
  const Obd2Record({
    this.id,
    required this.timestamp,
    this.engineTemp,
    this.rpm,
    this.speed,
    this.fuelLevel,
    this.throttlePosition,
    this.intakeAirTemp,
    this.oxygenSensor,
    this.batteryVoltage,
    this.checkEngineLight = false,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final DateTime timestamp;
  final double? engineTemp; // °C
  final int? rpm;
  final int? speed; // km/h
  final double? fuelLevel; // %
  final double? throttlePosition; // %
  final double? intakeAirTemp; // °C
  final double? oxygenSensor; // V
  final double? batteryVoltage; // V
  final bool checkEngineLight;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'engine_temp': engineTemp,
        'rpm': rpm,
        'speed': speed,
        'fuel_level': fuelLevel,
        'throttle_position': throttlePosition,
        'intake_air_temp': intakeAirTemp,
        'oxygen_sensor': oxygenSensor,
        'battery_voltage': batteryVoltage,
        'check_engine_light': checkEngineLight ? 1 : 0,
        'created_at': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
        'updated_at': (updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
      };

  factory Obd2Record.fromMap(Map<String, Object?> map) => Obd2Record(
        id: map['id'] as int?,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        engineTemp: (map['engine_temp'] as num?)?.toDouble(),
        rpm: map['rpm'] as int?,
        speed: map['speed'] as int?,
        fuelLevel: (map['fuel_level'] as num?)?.toDouble(),
        throttlePosition: (map['throttle_position'] as num?)?.toDouble(),
        intakeAirTemp: (map['intake_air_temp'] as num?)?.toDouble(),
        oxygenSensor: (map['oxygen_sensor'] as num?)?.toDouble(),
        batteryVoltage: (map['battery_voltage'] as num?)?.toDouble(),
        checkEngineLight: (map['check_engine_light'] as int? ?? 0) == 1,
        createdAt: map['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
            : null,
      );

  Map<String, Object?> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'engineTemp': engineTemp,
        'rpm': rpm,
        'speed': speed,
        'fuelLevel': fuelLevel,
        'throttlePosition': throttlePosition,
        'intakeAirTemp': intakeAirTemp,
        'oxygenSensor': oxygenSensor,
        'batteryVoltage': batteryVoltage,
        'checkEngineLight': checkEngineLight,
      };

  Obd2Record copyWith({
    int? id,
    DateTime? timestamp,
    double? engineTemp,
    int? rpm,
    int? speed,
    double? fuelLevel,
    double? throttlePosition,
    double? intakeAirTemp,
    double? oxygenSensor,
    double? batteryVoltage,
    bool? checkEngineLight,
  }) =>
      Obd2Record(
        id: id ?? this.id,
        timestamp: timestamp ?? this.timestamp,
        engineTemp: engineTemp ?? this.engineTemp,
        rpm: rpm ?? this.rpm,
        speed: speed ?? this.speed,
        fuelLevel: fuelLevel ?? this.fuelLevel,
        throttlePosition: throttlePosition ?? this.throttlePosition,
        intakeAirTemp: intakeAirTemp ?? this.intakeAirTemp,
        oxygenSensor: oxygenSensor ?? this.oxygenSensor,
        batteryVoltage: batteryVoltage ?? this.batteryVoltage,
        checkEngineLight: checkEngineLight ?? this.checkEngineLight,
      );
}
