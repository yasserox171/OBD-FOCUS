import 'dart:async';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/datasources/bluetooth/obd2_service.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/datasources/local/preferences_service.dart';
import '../../data/models/obd_device.dart';

enum ObdConnectionStatus { disconnected, connecting, initializing, connected }

/// UI-facing snapshot of the Bluetooth link.
class ObdConnectionState {
  const ObdConnectionState({
    this.status = ObdConnectionStatus.disconnected,
    this.deviceName,
    this.deviceAddress,
    this.protocol,
    this.isDemo = false,
    this.error,
  });

  final ObdConnectionStatus status;
  final String? deviceName;
  final String? deviceAddress;
  final String? protocol;
  final bool isDemo;
  final String? error;

  bool get isConnected => status == ObdConnectionStatus.connected;

  ObdConnectionState copyWith({
    ObdConnectionStatus? status,
    String? deviceName,
    String? deviceAddress,
    String? protocol,
    bool? isDemo,
    String? error,
  }) =>
      ObdConnectionState(
        status: status ?? this.status,
        deviceName: deviceName ?? this.deviceName,
        deviceAddress: deviceAddress ?? this.deviceAddress,
        protocol: protocol ?? this.protocol,
        isDemo: isDemo ?? this.isDemo,
        error: error,
      );
}

class ConnectionNotifier extends Notifier<ObdConnectionState> {
  ObdInterface _obd = Obd2Service();

  /// The active vehicle link (real adapter or demo simulator).
  ObdInterface get obd => _obd;

  @override
  ObdConnectionState build() => const ObdConnectionState();

  /// Requests the runtime permissions needed for scanning/connecting.
  Future<bool> ensurePermissions() async {
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // needed on Android 6–11 for discovery
    ].request();
    // Older Android versions report scan/connect as not applicable
    // (permanently denied without a dialog) — treat granted OR restricted
    // location as sufficient there.
    final scanOk = results[Permission.bluetoothScan]?.isGranted ?? false;
    final connectOk = results[Permission.bluetoothConnect]?.isGranted ?? false;
    final locationOk =
        results[Permission.locationWhenInUse]?.isGranted ?? false;
    return (scanOk && connectOk) || locationOk;
  }

  Future<bool> isBluetoothEnabled() async =>
      await FlutterBluetoothSerial.instance.isEnabled ?? false;

  Future<void> requestEnableBluetooth() async {
    await FlutterBluetoothSerial.instance.requestEnable();
  }

  Future<void> connect(String address, String name) async {
    if (state.status == ObdConnectionStatus.connecting) return;
    _obd = Obd2Service();
    state = ObdConnectionState(
      status: ObdConnectionStatus.connecting,
      deviceName: name,
      deviceAddress: address,
    );
    try {
      state = state.copyWith(status: ObdConnectionStatus.initializing);
      await _obd.connect(address);
      state = state.copyWith(
        status: ObdConnectionStatus.connected,
        protocol: _obd.protocolName,
      );
      await DatabaseHelper.instance.recordConnection(address, name);
      await PreferencesService.instance.setLastDeviceAddress(address);
    } catch (e) {
      _obd = Obd2Service();
      state = ObdConnectionState(
        status: ObdConnectionStatus.disconnected,
        error: e.toString(),
      );
    }
  }

  /// Starts demo mode with simulated vehicle data.
  Future<void> connectDemo() async {
    _obd = DemoObdService();
    state = const ObdConnectionState(
      status: ObdConnectionStatus.connecting,
      deviceName: 'Demo Vehicle',
      isDemo: true,
    );
    await _obd.connect('demo');
    state = ObdConnectionState(
      status: ObdConnectionStatus.connected,
      deviceName: 'Demo Vehicle',
      protocol: _obd.protocolName,
      isDemo: true,
    );
  }

  Future<void> disconnect() async {
    await _obd.disconnect();
    state = const ObdConnectionState();
  }

  /// Called by the live-data loop when the link drops mid-poll.
  void markDisconnected() {
    if (state.status != ObdConnectionStatus.disconnected) {
      state = const ObdConnectionState(error: 'connection_lost');
    }
  }
}

final connectionProvider =
    NotifierProvider<ConnectionNotifier, ObdConnectionState>(
        ConnectionNotifier.new);

// ── Device scanning ────────────────────────────────────────────────────────

/// A device shown on the Home screen (bonded, discovered or remembered).
class ScannedDevice {
  const ScannedDevice({
    required this.name,
    required this.address,
    this.isBonded = false,
    this.isFavorite = false,
    this.lastConnected,
    this.connectionCount = 0,
  });

  final String name;
  final String address;
  final bool isBonded;
  final bool isFavorite;
  final DateTime? lastConnected;
  final int connectionCount;

  ScannedDevice copyWith({bool? isFavorite}) => ScannedDevice(
        name: name,
        address: address,
        isBonded: isBonded,
        isFavorite: isFavorite ?? this.isFavorite,
        lastConnected: lastConnected,
        connectionCount: connectionCount,
      );
}

class DeviceScanState {
  const DeviceScanState({
    this.devices = const [],
    this.isScanning = false,
    this.bluetoothEnabled = true,
    this.permissionsGranted = true,
  });

  final List<ScannedDevice> devices;
  final bool isScanning;
  final bool bluetoothEnabled;
  final bool permissionsGranted;

  DeviceScanState copyWith({
    List<ScannedDevice>? devices,
    bool? isScanning,
    bool? bluetoothEnabled,
    bool? permissionsGranted,
  }) =>
      DeviceScanState(
        devices: devices ?? this.devices,
        isScanning: isScanning ?? this.isScanning,
        bluetoothEnabled: bluetoothEnabled ?? this.bluetoothEnabled,
        permissionsGranted: permissionsGranted ?? this.permissionsGranted,
      );
}

class DeviceScanNotifier extends Notifier<DeviceScanState> {
  StreamSubscription<BluetoothDiscoveryResult>? _discovery;

  @override
  DeviceScanState build() {
    ref.onDispose(() => _discovery?.cancel());
    // Load remembered devices immediately so the list is never empty.
    Future.microtask(loadKnownDevices);
    return const DeviceScanState();
  }

  Future<void> loadKnownDevices() async {
    final known = await DatabaseHelper.instance.getDevices();
    _merge(known.map((d) => ScannedDevice(
          name: d.name,
          address: d.macAddress,
          isFavorite: d.isFavorite,
          lastConnected: d.lastConnected,
          connectionCount: d.connectionCount,
        )));
  }

  /// Scans: bonded devices instantly, then live discovery for new ones.
  Future<void> scan() async {
    final connection = ref.read(connectionProvider.notifier);

    final granted = await connection.ensurePermissions();
    if (!granted) {
      state = state.copyWith(permissionsGranted: false, isScanning: false);
      return;
    }
    final btOn = await connection.isBluetoothEnabled();
    if (!btOn) {
      await connection.requestEnableBluetooth();
      if (!await connection.isBluetoothEnabled()) {
        state = state.copyWith(bluetoothEnabled: false, isScanning: false);
        return;
      }
    }
    state = state.copyWith(
      isScanning: true,
      bluetoothEnabled: true,
      permissionsGranted: true,
    );

    await loadKnownDevices();
    try {
      final bonded =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      _merge(bonded.map((d) => ScannedDevice(
            name: d.name ?? 'Unknown',
            address: d.address,
            isBonded: true,
          )));

      await _discovery?.cancel();
      _discovery =
          FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
        _merge([
          ScannedDevice(
            name: result.device.name ?? 'Unknown',
            address: result.device.address,
            isBonded: result.device.isBonded,
          )
        ]);
      }, onDone: () {
        state = state.copyWith(isScanning: false);
      });
    } catch (_) {
      state = state.copyWith(isScanning: false);
    }
  }

  Future<void> stopScan() async {
    await FlutterBluetoothSerial.instance.cancelDiscovery();
    await _discovery?.cancel();
    state = state.copyWith(isScanning: false);
  }

  Future<void> toggleFavorite(ScannedDevice device) async {
    await DatabaseHelper.instance.saveDevice(ObdDevice(
      macAddress: device.address,
      name: device.name,
      isFavorite: !device.isFavorite,
    ));
    await DatabaseHelper.instance
        .setFavorite(device.address, !device.isFavorite);
    state = state.copyWith(
      devices: [
        for (final d in state.devices)
          d.address == device.address
              ? d.copyWith(isFavorite: !device.isFavorite)
              : d
      ],
    );
  }

  /// Merges [incoming] into the list, deduplicating by MAC address and
  /// keeping favorites first.
  void _merge(Iterable<ScannedDevice> incoming) {
    final byAddress = {for (final d in state.devices) d.address: d};
    for (final d in incoming) {
      final existing = byAddress[d.address];
      byAddress[d.address] = ScannedDevice(
        name: d.name != 'Unknown' ? d.name : existing?.name ?? d.name,
        address: d.address,
        isBonded: d.isBonded || (existing?.isBonded ?? false),
        isFavorite: d.isFavorite || (existing?.isFavorite ?? false),
        lastConnected: d.lastConnected ?? existing?.lastConnected,
        connectionCount:
            d.connectionCount > 0 ? d.connectionCount : existing?.connectionCount ?? 0,
      );
    }
    final list = byAddress.values.toList()
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    state = state.copyWith(devices: list);
  }
}

final deviceScanProvider =
    NotifierProvider<DeviceScanNotifier, DeviceScanState>(
        DeviceScanNotifier.new);
