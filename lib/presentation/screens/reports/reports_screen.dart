import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/daily_report.dart';
import '../../providers/reports_provider.dart';
import '../../services_glue.dart';
import '../../widgets/status_banner.dart';

/// Reports: generate today's PDF report, browse the last 30 reports,
/// view/share PDFs and upload them to Google Drive.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('navReports'))),
      body: Column(
        children: [
          const StatusBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: reports.isGenerating
                    ? null
                    : () async {
                        final report = await ref
                            .read(reportsProvider.notifier)
                            .generate();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.tr(report != null
                                ? 'reportReady'
                                : 'noRecordsDesc')),
                            backgroundColor: report != null
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        );
                      },
                icon: reports.isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: Text(context.tr(
                    reports.isGenerating ? 'generating' : 'generateReport')),
              ),
            ),
          ),
          Expanded(
            child: reports.reports.isEmpty
                ? _EmptyState()
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(reportsProvider.notifier).refresh(),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: reports.reports.length,
                      itemBuilder: (context, index) =>
                          _ReportCard(report: reports.reports[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat.yMMMMEEEEd(context.l10n.locale.languageCode);
    final hasPdf =
        report.pdfPath != null && File(report.pdfPath!).existsSync();

    String n(double? v, [int digits = 0]) =>
        v == null ? '—' : v.toStringAsFixed(digits);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined,
                    color: AppColors.accentCyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${context.tr('reportFor')} ${dateFmt.format(report.date)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _Metric(
                    label: context.tr('avgTemp'),
                    value: '${n(report.averageTemp)}°C'),
                _Metric(
                    label: context.tr('maxTemp'),
                    value: '${n(report.maxTemp)}°C'),
                _Metric(
                    label: context.tr('avgRpm'), value: n(report.averageRpm)),
                _Metric(
                    label: context.tr('maxSpeed'),
                    value: '${n(report.maxSpeed)} ${context.tr('kmh')}'),
                _Metric(
                    label: context.tr('avgFuel'),
                    value: '${n(report.averageFuel)}%'),
                _Metric(
                    label: context.tr('newCodes'),
                    value: '${report.dtcCount}'),
              ],
            ),
            if (report.summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(context.tr('recommendations'),
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              // summary stores localization keys, one per line.
              ...report.summary
                  .split('\n')
                  .where((k) => k.isNotEmpty)
                  .map((key) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(
                              child: Text(context.tr(key),
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ),
                          ],
                        ),
                      )),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (hasPdf) ...[
                  TextButton.icon(
                    onPressed: () => Printing.layoutPdf(
                      onLayout: (_) => File(report.pdfPath!).readAsBytes(),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(context.tr('viewPdf')),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        ServicesGlue.shareFile(report.pdfPath!),
                    icon: const Icon(Icons.share, size: 18),
                    label: Text(context.tr('share')),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final ok = await ref
                          .read(reportsProvider.notifier)
                          .uploadToDrive(report);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context
                              .tr(ok ? 'exportSuccess' : 'exportFailed')),
                          backgroundColor:
                              ok ? AppColors.success : AppColors.danger,
                        ),
                      );
                    },
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: Text(context.tr('saveToDrive')),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(color: AppColors.accentCyan)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined,
                size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(context.tr('noReports'),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(context.tr('noReportsDesc'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
