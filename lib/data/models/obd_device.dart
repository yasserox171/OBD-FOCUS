/// A known Bluetooth OBD2 adapter, persisted to `devices`.
class ObdDevice {
  const ObdDevice({
    this.id,
    required this.macAddress,
    required this.name,
    this.isFavorite = false,
    this.lastConnected,
    this.connectionCount = 0,
  });

  final int? id;
  final String macAddress;
  final String name;
  final bool isFavorite;
  final DateTime? lastConnected;
  final int connectionCount;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'mac_address': macAddress,
        'name': name,
        'is_favorite': isFavorite ? 1 : 0,
        'last_connected': lastConnected?.millisecondsSinceEpoch,
        'connection_count': connectionCount,
      };

  factory ObdDevice.fromMap(Map<String, Object?> map) => ObdDevice(
        id: map['id'] as int?,
        macAddress: map['mac_address'] as String,
        name: map['name'] as String? ?? 'Unknown',
        isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
        lastConnected: map['last_connected'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['last_connected'] as int)
            : null,
        connectionCount: map['connection_count'] as int? ?? 0,
      );

  ObdDevice copyWith({
    int? id,
    String? name,
    bool? isFavorite,
    DateTime? lastConnected,
    int? connectionCount,
  }) =>
      ObdDevice(
        id: id ?? this.id,
        macAddress: macAddress,
        name: name ?? this.name,
        isFavorite: isFavorite ?? this.isFavorite,
        lastConnected: lastConnected ?? this.lastConnected,
        connectionCount: connectionCount ?? this.connectionCount,
      );
}
