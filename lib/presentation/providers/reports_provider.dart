import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/strings_ar.dart';
import '../../core/localization/strings_en.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/models/daily_report.dart';
import '../../services/drive_service.dart';
import '../../services/notification_service.dart';
import '../../services/report_service.dart';
import 'settings_provider.dart';

class ReportsState {
  const ReportsState({
    this.reports = const [],
    this.isGenerating = false,
    this.isUploading = false,
  });

  final List<DailyReport> reports;
  final bool isGenerating;
  final bool isUploading;

  ReportsState copyWith({
    List<DailyReport>? reports,
    bool? isGenerating,
    bool? isUploading,
  }) =>
      ReportsState(
        reports: reports ?? this.reports,
        isGenerating: isGenerating ?? this.isGenerating,
        isUploading: isUploading ?? this.isUploading,
      );
}

class ReportsNotifier extends Notifier<ReportsState> {
  @override
  ReportsState build() {
    Future.microtask(() async {
      await _generateMissedReports();
      await refresh();
    });
    return const ReportsState();
  }

  Future<void> refresh() async {
    final reports = await DatabaseHelper.instance.getReports();
    state = state.copyWith(reports: reports);
  }

  /// Generates the report for [day] (defaults to today). Returns it, or
  /// null when the day has no data.
  Future<DailyReport?> generate({DateTime? day, bool notify = false}) async {
    if (state.isGenerating) return null;
    state = state.copyWith(isGenerating: true);
    try {
      final report =
          await ReportService.instance.generateDailyReport(day ?? DateTime.now());
      await refresh();
      if (report != null && notify) {
        final settings = ref.read(settingsProvider);
        final strings = settings.isArabic ? stringsAr : stringsEn;
        await NotificationService.instance.showReportReady(
          strings['reportNotifTitle']!,
          strings['reportNotifBody']!,
        );
      }
      return report;
    } finally {
      state = state.copyWith(isGenerating: false);
    }
  }

  /// On launch, backfill yesterday's report if the app wasn't running at the
  /// scheduled time (Android can't run Dart in the background reliably
  /// without a foreground service; this keeps the report list complete).
  Future<void> _generateMissedReports() async {
    final existing = await DatabaseHelper.instance.getReports(limit: 1);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yDay = DateTime(yesterday.year, yesterday.month, yesterday.day);
    final alreadyHave = existing.isNotEmpty &&
        !existing.first.date.isBefore(yDay);
    if (!alreadyHave) {
      await ReportService.instance.generateDailyReport(yDay);
    }
  }

  /// Uploads a report PDF to Google Drive. Returns success.
  Future<bool> uploadToDrive(DailyReport report) async {
    if (report.pdfPath == null) return false;
    final file = File(report.pdfPath!);
    if (!file.existsSync()) return false;

    state = state.copyWith(isUploading: true);
    try {
      if (!DriveService.instance.isSignedIn) {
        final account = await DriveService.instance.signIn();
        if (account == null) return false;
      }
      return await DriveService.instance
          .uploadFile(file, mimeType: 'application/pdf');
    } finally {
      state = state.copyWith(isUploading: false);
    }
  }
}

final reportsProvider =
    NotifierProvider<ReportsNotifier, ReportsState>(ReportsNotifier.new);
