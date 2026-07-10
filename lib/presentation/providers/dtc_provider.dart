import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/strings_ar.dart';
import '../../core/localization/strings_en.dart';
import '../../data/datasources/bluetooth/obd2_service.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/dtc/dtc_database.dart';
import '../../data/models/dtc_code.dart';
import '../../services/notification_service.dart';
import 'connection_provider.dart';
import 'settings_provider.dart';

enum DtcFilter { all, confirmed, pending, permanent }

class DtcState {
  const DtcState({
    this.codes = const [],
    this.isReading = false,
    this.isClearing = false,
    this.filter = DtcFilter.all,
    this.lastError,
  });

  final List<DtcCode> codes;
  final bool isReading;
  final bool isClearing;
  final DtcFilter filter;
  final String? lastError;

  List<DtcCode> get filtered => switch (filter) {
        DtcFilter.all => codes,
        DtcFilter.confirmed =>
          codes.where((c) => c.status == DtcStatus.confirmed).toList(),
        DtcFilter.pending =>
          codes.where((c) => c.status == DtcStatus.pending).toList(),
        DtcFilter.permanent =>
          codes.where((c) => c.status == DtcStatus.permanent).toList(),
      };

  DtcState copyWith({
    List<DtcCode>? codes,
    bool? isReading,
    bool? isClearing,
    DtcFilter? filter,
    String? lastError,
  }) =>
      DtcState(
        codes: codes ?? this.codes,
        isReading: isReading ?? this.isReading,
        isClearing: isClearing ?? this.isClearing,
        filter: filter ?? this.filter,
        // Preserved unless explicitly replaced; cleared by starting a new
        // read/clear operation (which constructs a fresh state).
        lastError: lastError ?? this.lastError,
      );
}

class DtcNotifier extends Notifier<DtcState> {
  @override
  DtcState build() {
    Future.microtask(loadStored);
    return const DtcState();
  }

  Future<void> loadStored() async {
    final codes = await DatabaseHelper.instance.getDtcs();
    state = state.copyWith(codes: codes);
  }

  void setFilter(DtcFilter filter) => state = state.copyWith(filter: filter);

  /// Reads Modes 03/07/0A from the vehicle, stores results and alerts on
  /// newly detected codes.
  Future<void> readCodes() async {
    final connection = ref.read(connectionProvider);
    if (!connection.isConnected || state.isReading) return;

    state = DtcState(codes: state.codes, filter: state.filter, isReading: true);
    try {
      final obd = ref.read(connectionProvider.notifier).obd;
      final result = await obd.readDtcs();
      final settings = ref.read(settingsProvider);
      final now = DateTime.now();

      final newCodes = <String>[];
      for (final entry in result.all) {
        final dtc = DtcCode(
          code: entry.code,
          description:
              DtcDatabase.describe(entry.code, arabic: settings.isArabic),
          severity: DtcDatabase.severityOf(entry.code),
          status: entry.status,
          detectedDate: now,
        );
        final isNew = await DatabaseHelper.instance.upsertDtc(dtc);
        if (isNew) newCodes.add(entry.code);
      }

      if (newCodes.isNotEmpty && settings.dtcAlerts) {
        final strings = settings.isArabic ? stringsAr : stringsEn;
        await NotificationService.instance.showDtcAlert(
          strings['dtcAlertTitle']!,
          '${strings['dtcAlertBody']!}: ${newCodes.join(', ')}',
        );
      }
      await loadStored();
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    } finally {
      state = state.copyWith(isReading: false);
    }
  }

  /// Sends Mode 04 (clear codes + turn off MIL). Returns success.
  Future<bool> clearCodes() async {
    final connection = ref.read(connectionProvider);
    if (!connection.isConnected || state.isClearing) return false;

    state =
        DtcState(codes: state.codes, filter: state.filter, isClearing: true);
    try {
      final obd = ref.read(connectionProvider.notifier).obd;
      final ok = await obd.clearDtcs();
      if (ok) {
        await DatabaseHelper.instance.markDtcsCleared();
        await loadStored();
      }
      return ok;
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
      return false;
    } finally {
      state = state.copyWith(isClearing: false);
    }
  }
}

final dtcProvider = NotifierProvider<DtcNotifier, DtcState>(DtcNotifier.new);
