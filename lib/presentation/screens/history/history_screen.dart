import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/obd2_record.dart';
import '../../providers/dtc_provider.dart';
import '../../providers/history_provider.dart';
import '../../services_glue.dart';
import '../../widgets/status_banner.dart';

/// History: date-filtered record list (paginated, 50 at a time), historical
/// charts (line/bar/area), export to Drive, WhatsApp share and delete.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('navHistory')),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) => _handleAction(context, ref, action),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'drive_csv',
                child: _MenuRow(
                    icon: Icons.cloud_upload_outlined,
                    text: '${context.tr('exportDrive')} (CSV)'),
              ),
              PopupMenuItem(
                value: 'drive_json',
                child: _MenuRow(
                    icon: Icons.cloud_upload_outlined,
                    text: '${context.tr('exportDrive')} (JSON)'),
              ),
              PopupMenuItem(
                value: 'whatsapp',
                child: _MenuRow(
                    icon: Icons.share, text: context.tr('shareWhatsApp')),
              ),
              PopupMenuItem(
                value: 'delete',
                child: _MenuRow(
                    icon: Icons.delete_outline,
                    text: context.tr('deleteData'),
                    color: AppColors.danger),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const StatusBanner(),
          _RangeChips(history: history),
          Expanded(
            child: history.records.isEmpty && !history.isLoading
                ? _EmptyState()
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(historyProvider.notifier).refresh(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        if (history.records.isNotEmpty) ...[
                          _ChartsSection(records: history.records),
                          _StatsCard(history: history),
                          _RecordsHeader(count: history.stats.count),
                          ...history.records
                              .map((r) => _RecordTile(record: r)),
                          if (history.hasMore)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: OutlinedButton(
                                onPressed: history.isLoading
                                    ? null
                                    : () => ref
                                        .read(historyProvider.notifier)
                                        .loadMore(),
                                child: Text(context.tr('loadMore')),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, String action) async {
    final notifier = ref.read(historyProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    switch (action) {
      case 'drive_csv':
      case 'drive_json':
        final format = action == 'drive_csv' ? 'csv' : 'json';
        final result = await notifier.exportToDrive(format);
        if (!context.mounted) return;
        final (key, color) = switch (result) {
          'ok' => ('exportSuccess', AppColors.success),
          'queued' => ('queuedOffline', AppColors.warning),
          _ => ('exportFailed', AppColors.danger),
        };
        messenger.showSnackBar(SnackBar(
            content: Text(context.tr(key)), backgroundColor: color));

      case 'whatsapp':
        final history = ref.read(historyProvider);
        final message = ServicesGlue.buildShareMessage(
          context: context,
          stats: history.stats,
          records: history.records,
          dtcCount: ref.read(dtcProvider).codes.length,
        );
        await ServicesGlue.shareText(message);

      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('deleteConfirmTitle')),
            content: Text(context.tr('deleteConfirmBody')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.tr('cancel')),
              ),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.tr('delete')),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await notifier.deleteAll();
          if (context.mounted) {
            messenger.showSnackBar(SnackBar(
              content: Text(context.tr('deleteSuccess')),
              backgroundColor: AppColors.success,
            ));
          }
        }
    }
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Text(text, style: TextStyle(color: color)),
    ]);
  }
}

class _RangeChips extends ConsumerWidget {
  const _RangeChips({required this.history});

  final HistoryState history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = {
      HistoryRange.all: context.tr('allTime'),
      HistoryRange.today: context.tr('today'),
      HistoryRange.week: context.tr('last7Days'),
      HistoryRange.month: context.tr('last30Days'),
    };
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final entry in labels.entries)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: history.range == entry.key,
                onSelected: (_) =>
                    ref.read(historyProvider.notifier).setRange(entry.key),
              ),
            ),
        ],
      ),
    );
  }
}

/// Line chart (temperature), bar chart (RPM) and area chart (speed) over
/// the loaded records, oldest → newest.
class _ChartsSection extends StatelessWidget {
  const _ChartsSection({required this.records});

  final List<Obd2Record> records;

  @override
  Widget build(BuildContext context) {
    // Records arrive newest-first; charts read left→right in time.
    final chrono = records.reversed.toList();
    // Downsample to at most 60 points to keep painting cheap.
    final step = (chrono.length / 60).ceil().clamp(1, 1 << 30);
    final points = [
      for (var i = 0; i < chrono.length; i += step) chrono[i]
    ];

    return Column(
      children: [
        _ChartCard(
          title: context.tr('tempChart'),
          child: _tempLineChart(points),
        ),
        _ChartCard(
          title: context.tr('rpmChart'),
          child: _rpmBarChart(points),
        ),
        _ChartCard(
          title: context.tr('speedChart'),
          child: _speedAreaChart(points),
        ),
      ],
    );
  }

  Widget _tempLineChart(List<Obd2Record> points) {
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        if (points[i].engineTemp != null)
          FlSpot(i.toDouble(), points[i].engineTemp!)
    ];
    if (spots.isEmpty) return const SizedBox.shrink();
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Colors.white.withOpacity(0.06), strokeWidth: 1),
        ),
        titlesData: _leftTitlesOnly(),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.warning,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _rpmBarChart(List<Obd2Record> points) {
    final groups = <BarChartGroupData>[
      for (var i = 0; i < points.length; i++)
        if (points[i].rpm != null)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: points[i].rpm!.toDouble(),
              color: AppColors.primaryBlue,
              width: 3,
              borderRadius: BorderRadius.circular(2),
            ),
          ]),
    ];
    if (groups.isEmpty) return const SizedBox.shrink();
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: _leftTitlesOnly(),
        borderData: FlBorderData(show: false),
        barGroups: groups,
      ),
    );
  }

  Widget _speedAreaChart(List<Obd2Record> points) {
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        if (points[i].speed != null)
          FlSpot(i.toDouble(), points[i].speed!.toDouble())
    ];
    if (spots.isEmpty) return const SizedBox.shrink();
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: _leftTitlesOnly(),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.accentCyan,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.accentCyan.withOpacity(0.35),
                  AppColors.accentCyan.withOpacity(0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  FlTitlesData _leftTitlesOnly() => const FlTitlesData(
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 42),
        ),
      );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(height: 160, child: child),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.history});

  final HistoryState history;

  @override
  Widget build(BuildContext context) {
    final s = history.stats;
    String n(double? v, [String unit = '']) =>
        v == null ? '—' : '${v.toStringAsFixed(0)}$unit';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _Stat(
                label:
                    '${context.tr('engineTemp')} (${context.tr('avg')}/${context.tr('max')})',
                value: '${n(s.avgTemp)}/${n(s.maxTemp)}°C'),
            _Stat(
                label:
                    '${context.tr('rpm')} (${context.tr('avg')}/${context.tr('max')})',
                value: '${n(s.avgRpm)}/${n(s.maxRpm)}'),
            _Stat(
                label: '${context.tr('speed')} (${context.tr('max')})',
                value: '${n(s.maxSpeed)} ${context.tr('kmh')}'),
            _Stat(
                label:
                    '${context.tr('fuelLevel')} (${context.tr('min')}/${context.tr('max')})',
                value: '${n(s.minFuel)}%/${n(s.maxFuel)}%'),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

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

class _RecordsHeader extends StatelessWidget {
  const _RecordsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        '$count ${context.tr('records')}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final Obd2Record record;

  @override
  Widget build(BuildContext context) {
    final fmt =
        DateFormat.yMMMd(context.l10n.locale.languageCode).add_Hms();
    String n(num? v, [String unit = '']) => v == null ? '—' : '$v$unit';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(fmt.format(record.timestamp),
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                if (record.checkEngineLight)
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.danger),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Mini(label: '🌡️', value: n(record.engineTemp?.round(), '°C')),
                _Mini(label: '⚙️', value: n(record.rpm)),
                _Mini(
                    label: '🚗',
                    value: n(record.speed, ' ${context.tr('kmh')}')),
                _Mini(label: '🛢️', value: n(record.fuelLevel?.round(), '%')),
                _Mini(
                    label: '🎚️',
                    value: n(record.throttlePosition?.round(), '%')),
                _Mini(
                    label: '🌬️',
                    value: n(record.intakeAirTemp?.round(), '°C')),
                _Mini(
                    label: 'O₂',
                    value: n(
                        record.oxygenSensor == null
                            ? null
                            : double.parse(
                                record.oxygenSensor!.toStringAsFixed(2)),
                        'V')),
                _Mini(
                    label: '🔋',
                    value: n(
                        record.batteryVoltage == null
                            ? null
                            : double.parse(
                                record.batteryVoltage!.toStringAsFixed(1)),
                        'V')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text('$label $value',
        style: Theme.of(context).textTheme.bodySmall);
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
            const Icon(Icons.history,
                size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(context.tr('noRecords'),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(context.tr('noRecordsDesc'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
