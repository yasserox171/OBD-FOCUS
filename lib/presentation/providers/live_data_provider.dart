import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/strings_ar.dart';
import '../../core/localization/strings_en.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/datasources/local/preferences_service.dart';
import '../../data/models/obd2_record.dart';
import '../../services/notification_service.dart';
import 'connection_provider.dart';
import 'settings_provider.dart';

/// Live telemetry state for the Dashboard.
class LiveDataState {
  const LiveDataState({this.current, this.isPolling = false});

  final Obd2Record? current;
  final bool isPolling;

  LiveDataState copyWith({Obd2Record? current, bool? isPolling}) =>
      LiveDataState(
        current: current ?? this.current,
        isPolling: isPolling ?? this.isPolling,
      );
}

/// Polls the vehicle once per second while connected, persists a record
/// every [AppConstants.recordPersistInterval], fires threshold alerts and
/// runs the daily retention job.
class LiveDataNotifier extends Notifier<LiveDataState> {
  Timer? _timer;
  bool _readInFlight = false;
  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastTempAlert = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFuelAlert = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  LiveDataState build() {
    ref.listen<ObdConnectionState>(connectionProvider, (previous, next) {
      if (next.isConnected && !(previous?.isConnected ?? false)) {
        _start();
      } else if (!next.isConnected) {
        _stop();
      }
    });
    ref.onDispose(_stop);
    return const LiveDataState();
  }

  void _start() {
    _timer?.cancel();
    state = state.copyWith(isPolling: true);
    _timer = Timer.periodic(AppConstants.liveDataInterval, (_) => _tick());
    _runRetentionIfDue();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    state = const LiveDataState();
  }

  Future<void> _tick() async {
    if (_readInFlight) return; // a slow adapter answer is still in flight
    _readInFlight = true;
    try {
      final obd = ref.read(connectionProvider.notifier).obd;
      final record = await obd.readLiveData();
      state = state.copyWith(current: record);

      await _checkAlerts(record);

      final now = DateTime.now();
      if (now.difference(_lastPersist) >=
          AppConstants.recordPersistInterval) {
        _lastPersist = now;
        await DatabaseHelper.instance.insertRecord(record);
      }
    } on StateError {
      ref.read(connectionProvider.notifier).markDisconnected();
    } catch (_) {
      // One bad frame must not kill the polling loop.
    } finally {
      _readInFlight = false;
    }
  }

  Future<void> _checkAlerts(Obd2Record record) async {
    final settings = ref.read(settingsProvider);
    final strings = settings.isArabic ? stringsAr : stringsEn;
    final notifications = NotificationService.instance;
    final now = DateTime.now();

    // Critical engine temperature — at most one alert per 5 minutes.
    if (settings.tempAlerts &&
        (record.engineTemp ?? 0) > AppConstants.engineTempCriticalC &&
        now.difference(_lastTempAlert) > const Duration(minutes: 5)) {
      _lastTempAlert = now;
      await notifications.showTempAlert(
        strings['tempAlertTitle']!,
        '${strings['tempAlertBody']!} '
        '(${record.engineTemp!.toStringAsFixed(0)}°C)',
      );
    }

    // Low fuel — at most one alert per 30 minutes.
    if (settings.fuelAlerts &&
        record.fuelLevel != null &&
        record.fuelLevel! < AppConstants.fuelLowPercent &&
        now.difference(_lastFuelAlert) > const Duration(minutes: 30)) {
      _lastFuelAlert = now;
      await notifications.showFuelAlert(
        strings['fuelAlertTitle']!,
        '${strings['fuelAlertBody']!} '
        '(${record.fuelLevel!.toStringAsFixed(0)}%)',
      );
    }
  }

  /// Runs the retention job at most once per calendar day.
  Future<void> _runRetentionIfDue() async {
    final prefs = PreferencesService.instance;
    final last = prefs.lastRetentionRun;
    final now = DateTime.now();
    if (last != null &&
        last.year == now.year &&
        last.month == now.month &&
        last.day == now.day) {
      return;
    }
    await DatabaseHelper.instance.enforceRetention();
    await prefs.setLastRetentionRun(now);
  }
}

final liveDataProvider =
    NotifierProvider<LiveDataNotifier, LiveDataState>(LiveDataNotifier.new);
