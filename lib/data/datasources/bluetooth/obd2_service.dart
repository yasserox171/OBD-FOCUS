import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../../../core/utils/obd_utils.dart';
import '../../models/dtc_code.dart';
import '../../models/obd2_record.dart';

/// One polled frame of live telemetry (not yet persisted).
typedef LiveDataFrame = Obd2Record;

/// Raw DTC read result grouped by SAE J1979 mode.
class DtcReadResult {
  const DtcReadResult({
    this.confirmed = const [],
    this.pending = const [],
    this.permanent = const [],
  });

  final List<String> confirmed; // Mode 03
  final List<String> pending; // Mode 07
  final List<String> permanent; // Mode 0A

  bool get isEmpty =>
      confirmed.isEmpty && pending.isEmpty && permanent.isEmpty;
}

/// Abstraction over the vehicle link so the app can run against a real
/// ELM327 adapter or the built-in simulator (demo mode) interchangeably.
abstract class ObdInterface {
  bool get isConnected;
  Future<void> connect(String address);
  Future<void> disconnect();
  Future<LiveDataFrame> readLiveData();
  Future<DtcReadResult> readDtcs();
  Future<bool> clearDtcs();
  String get protocolName;
}

/// Real ELM327 adapter over Bluetooth classic SPP.
///
/// Commands are serialized (one in flight at a time); responses are
/// buffered until the `>` prompt character arrives.
class Obd2Service implements ObdInterface {
  BluetoothConnection? _connection;
  final StringBuffer _rxBuffer = StringBuffer();
  Completer<String>? _pendingResponse;
  Future<void> _commandQueue = Future.value();
  String _protocol = 'Auto (ATSP0)';

  @override
  bool get isConnected => _connection?.isConnected ?? false;

  @override
  String get protocolName => _protocol;

  @override
  Future<void> connect(String address) async {
    await disconnect();
    _connection = await BluetoothConnection.toAddress(address)
        .timeout(const Duration(seconds: 15));

    _connection!.input?.listen(
      _onData,
      onDone: () => _connection = null,
      onError: (_) => _connection = null,
    );

    await _initializeAdapter();
  }

  void _onData(Uint8List data) {
    _rxBuffer.write(ascii.decode(data, allowInvalid: true));
    final text = _rxBuffer.toString();
    if (text.contains('>')) {
      _rxBuffer.clear();
      final pending = _pendingResponse;
      if (pending != null && !pending.isCompleted) {
        pending.complete(text);
      }
    }
  }

  /// ELM327 init: reset, disable echo/linefeeds/spaces/headers, auto protocol.
  Future<void> _initializeAdapter() async {
    await _send('ATZ', timeout: const Duration(seconds: 5));
    await _send('ATE0');
    await _send('ATL0');
    await _send('ATS0');
    await _send('ATH0');
    await _send('ATSP0');
    // First real query lets the adapter search for the protocol.
    await _send('0100', timeout: const Duration(seconds: 10));
    final dp = await _send('ATDP');
    if (!ObdUtils.isError(dp) && dp.trim().isNotEmpty) {
      _protocol = dp.replaceAll('>', '').trim();
    }
  }

  /// Sends [command] and resolves with the raw response text. Commands are
  /// chained on [_commandQueue] so concurrent callers never interleave.
  Future<String> _send(
    String command, {
    Duration timeout = const Duration(seconds: 3),
  }) {
    final result = _commandQueue.then((_) async {
      final conn = _connection;
      if (conn == null || !conn.isConnected) {
        throw StateError('Not connected');
      }
      _rxBuffer.clear();
      final completer = Completer<String>();
      _pendingResponse = completer;
      conn.output.add(Uint8List.fromList(ascii.encode('$command\r')));
      await conn.output.allSent;
      try {
        return await completer.future.timeout(timeout);
      } on TimeoutException {
        return 'NO DATA';
      } finally {
        _pendingResponse = null;
      }
    });
    // Keep the queue alive even if this command fails.
    _commandQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<LiveDataFrame> readLiveData() async {
    final temp = ObdUtils.coolantTemp(await _send('0105'));
    final rpm = ObdUtils.rpm(await _send('010C'));
    final speed = ObdUtils.speed(await _send('010D'));
    final fuel = ObdUtils.fuelLevel(await _send('012F'));
    final throttle = ObdUtils.throttle(await _send('0111'));
    final intake = ObdUtils.intakeAirTemp(await _send('010F'));
    final o2 = ObdUtils.oxygenSensor(await _send('0114'));
    final mil = ObdUtils.milOn(await _send('0101'));
    final battery = ObdUtils.batteryVoltage(await _send('ATRV'));

    return Obd2Record(
      timestamp: DateTime.now(),
      engineTemp: temp,
      rpm: rpm,
      speed: speed,
      fuelLevel: fuel,
      throttlePosition: throttle,
      intakeAirTemp: intake,
      oxygenSensor: o2,
      batteryVoltage: battery,
      checkEngineLight: mil ?? false,
    );
  }

  @override
  Future<DtcReadResult> readDtcs() async {
    final confirmed = ObdUtils.decodeDtcs(
        await _send('03', timeout: const Duration(seconds: 6)), 0x03);
    final pending = ObdUtils.decodeDtcs(
        await _send('07', timeout: const Duration(seconds: 6)), 0x07);
    final permanent = ObdUtils.decodeDtcs(
        await _send('0A', timeout: const Duration(seconds: 6)), 0x0A);
    return DtcReadResult(
      confirmed: confirmed,
      pending: pending,
      permanent: permanent,
    );
  }

  @override
  Future<bool> clearDtcs() async {
    final response = await _send('04', timeout: const Duration(seconds: 6));
    return !ObdUtils.isError(response) &&
        ObdUtils.normalize(response).contains('44');
  }

  @override
  Future<void> disconnect() async {
    try {
      await _connection?.close();
    } catch (_) {
      // Already closed — nothing to clean up.
    }
    _connection = null;
  }
}

/// Simulator used by demo mode: produces a plausible drive cycle so every
/// screen can be exercised without an adapter or a car.
class DemoObdService implements ObdInterface {
  final Random _random = Random();
  bool _connected = false;
  double _temp = 62;
  double _speed = 0;
  double _fuel = 78;
  final List<String> _storedDtcs = ['P0301', 'P0420'];

  @override
  bool get isConnected => _connected;

  @override
  String get protocolName => 'Demo (simulated)';

  @override
  Future<void> connect(String address) async {
    await Future.delayed(const Duration(milliseconds: 600));
    _connected = true;
  }

  @override
  Future<void> disconnect() async => _connected = false;

  @override
  Future<LiveDataFrame> readLiveData() async {
    if (!_connected) throw StateError('Not connected');
    // Warm up towards ~92°C, then wander.
    _temp += _temp < 90 ? 0.8 : (_random.nextDouble() - 0.5) * 1.2;
    _temp = _temp.clamp(20, 118);
    // Random accelerate/brake around city speeds.
    _speed += (_random.nextDouble() - 0.45) * 12;
    _speed = _speed.clamp(0, 140);
    _fuel = (_fuel - 0.01).clamp(0, 100);
    final throttle = (_speed / 140 * 60 + _random.nextDouble() * 10)
        .clamp(0.0, 100.0);
    final rpm = _speed < 1
        ? 800 + _random.nextInt(80)
        : (900 + _speed * 32 + _random.nextDouble() * 200).round();

    return Obd2Record(
      timestamp: DateTime.now(),
      engineTemp: double.parse(_temp.toStringAsFixed(1)),
      rpm: rpm,
      speed: _speed.round(),
      fuelLevel: double.parse(_fuel.toStringAsFixed(1)),
      throttlePosition: double.parse(throttle.toStringAsFixed(1)),
      intakeAirTemp: 25 + _random.nextDouble() * 15,
      oxygenSensor: 0.1 + _random.nextDouble() * 0.8,
      batteryVoltage: 13.8 + (_random.nextDouble() - 0.5) * 0.6,
      checkEngineLight: _storedDtcs.isNotEmpty,
    );
  }

  @override
  Future<DtcReadResult> readDtcs() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return DtcReadResult(
      confirmed: List.of(_storedDtcs),
      pending: _storedDtcs.isEmpty ? const [] : const ['P0171'],
    );
  }

  @override
  Future<bool> clearDtcs() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _storedDtcs.clear();
    return true;
  }
}

/// Maps a raw read result to [DtcCode] models with status per mode.
extension DtcReadResultX on DtcReadResult {
  List<({String code, DtcStatus status})> get all => [
        for (final c in confirmed) (code: c, status: DtcStatus.confirmed),
        for (final c in pending) (code: c, status: DtcStatus.pending),
        for (final c in permanent) (code: c, status: DtcStatus.permanent),
      ];
}
