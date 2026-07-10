import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/datasources/local/preferences_service.dart';
import '../../data/models/obd2_record.dart';
import '../../services/drive_service.dart';
import '../../services/export_service.dart';

enum HistoryRange { all, today, week, month }

class HistoryState {
  const HistoryState({
    this.records = const [],
    this.stats = RecordStats.empty,
    this.range = HistoryRange.all,
    this.isLoading = false,
    this.hasMore = true,
    this.isExporting = false,
  });

  final List<Obd2Record> records;
  final RecordStats stats;
  final HistoryRange range;
  final bool isLoading;
  final bool hasMore;
  final bool isExporting;

  HistoryState copyWith({
    List<Obd2Record>? records,
    RecordStats? stats,
    HistoryRange? range,
    bool? isLoading,
    bool? hasMore,
    bool? isExporting,
  }) =>
      HistoryState(
        records: records ?? this.records,
        stats: stats ?? this.stats,
        range: range ?? this.range,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        isExporting: isExporting ?? this.isExporting,
      );
}

class HistoryNotifier extends Notifier<HistoryState> {
  @override
  HistoryState build() {
    Future.microtask(refresh);
    return const HistoryState();
  }

  DateTime? get _rangeStart => switch (state.range) {
        HistoryRange.all => null,
        HistoryRange.today => DateTime.now().copyWith(
            hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0),
        HistoryRange.week =>
          DateTime.now().subtract(const Duration(days: 7)),
        HistoryRange.month =>
          DateTime.now().subtract(const Duration(days: 30)),
      };

  Future<void> setRange(HistoryRange range) async {
    state = state.copyWith(range: range);
    await refresh();
  }

  /// Reloads the first page and the aggregate stats for the active range.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    final db = DatabaseHelper.instance;
    final records = await db.getRecords(
      limit: AppConstants.pageSize,
      offset: 0,
      from: _rangeStart,
    );
    final stats = await db.recordStats(from: _rangeStart);
    state = state.copyWith(
      records: records,
      stats: stats,
      isLoading: false,
      hasMore: records.length == AppConstants.pageSize,
    );
  }

  /// Appends the next page (pagination, 50 at a time).
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    final next = await DatabaseHelper.instance.getRecords(
      limit: AppConstants.pageSize,
      offset: state.records.length,
      from: _rangeStart,
    );
    state = state.copyWith(
      records: [...state.records, ...next],
      isLoading: false,
      hasMore: next.length == AppConstants.pageSize,
    );
  }

  Future<void> deleteAll() async {
    await DatabaseHelper.instance.deleteAllRecords();
    await refresh();
  }

  /// Exports to Drive. Returns:
  /// 'ok' — uploaded, 'queued' — offline (queued for later),
  /// 'signin' — Drive not signed in, 'error' — failed.
  Future<String> exportToDrive(String format) async {
    state = state.copyWith(isExporting: true);
    try {
      final online = await _isOnline();
      if (!online) {
        await PreferencesService.instance.queueExport(format);
        return 'queued';
      }
      if (!DriveService.instance.isSignedIn) {
        final account = await DriveService.instance.signIn();
        if (account == null) return 'signin';
      }
      final file = await _buildExport(format);
      final ok = await DriveService.instance.uploadFile(
        file,
        mimeType: format == 'csv' ? 'text/csv' : 'application/json',
      );
      if (ok) {
        await PreferencesService.instance.setLastBackup(DateTime.now());
      }
      return ok ? 'ok' : 'error';
    } catch (_) {
      return 'error';
    } finally {
      state = state.copyWith(isExporting: false);
    }
  }

  /// Builds a local export file for sharing (no network needed).
  Future<File> buildLocalExport(String format) => _buildExport(format);

  Future<File> _buildExport(String format) => format == 'csv'
      ? ExportService.instance.exportCsv()
      : ExportService.instance.exportJson();

  /// Flushes exports queued while offline. Called on connectivity restore.
  Future<void> flushPendingExports() async {
    final prefs = PreferencesService.instance;
    final pending = prefs.pendingExports;
    if (pending.isEmpty || !DriveService.instance.isSignedIn) return;
    if (!await _isOnline()) return;

    for (final format in pending) {
      final file = await _buildExport(format);
      await DriveService.instance.uploadFile(
        file,
        mimeType: format == 'csv' ? 'text/csv' : 'application/json',
      );
    }
    await prefs.clearPendingExports();
    await prefs.setLastBackup(DateTime.now());
  }

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}

final historyProvider =
    NotifierProvider<HistoryNotifier, HistoryState>(HistoryNotifier.new);

/// Emits `true` while the device has any network connectivity.
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
        (results) => !results.contains(ConnectivityResult.none),
      );
});
