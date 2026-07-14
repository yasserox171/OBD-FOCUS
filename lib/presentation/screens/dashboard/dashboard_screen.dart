import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../providers/live_data_provider.dart';
import '../../widgets/circular_gauge.dart';
import '../../widgets/labeled_progress_bar.dart';
import '../../widgets/metric_tile.dart';
import '../../widgets/status_banner.dart';

/// Dashboard: live gauges for temperature / RPM / speed plus fuel,
/// battery, throttle, O₂, intake air and check-engine status.
/// Values refresh every second while connected.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final live = ref.watch(liveDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('navDashboard')),
        actions: [
          if (connection.isConnected)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.tr('liveData'),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall!
                        .copyWith(color: AppColors.success),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const StatusBanner(),
          Expanded(
            child: connection.isConnected
                ? _LiveDashboard(live: live)
                : _NotConnected(),
          ),
        ],
      ),
    );
  }
}

class _NotConnected extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(context.tr('notConnected'),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              context.tr('connectFirst'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.bluetooth),
              label: Text(context.tr('navHome')),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveDashboard extends StatelessWidget {
  const _LiveDashboard({required this.live});

  final LiveDataState live;

  @override
  Widget build(BuildContext context) {
    final record = live.current;
    final temp = record?.engineTemp ?? 0;
    final rpm = record?.rpm ?? 0;
    final speed = record?.speed ?? 0;
    final battery = record?.batteryVoltage;
    final batteryHealthy = battery != null &&
        battery >= AppConstants.batteryLowV &&
        battery <= AppConstants.batteryHighV;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Primary gauges row: temperature + RPM.
        LayoutBuilder(builder: (context, constraints) {
          final gaugeSize = (constraints.maxWidth - 24) / 2;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircularGauge(
                value: temp,
                min: 0,
                max: 140,
                warnFrom: 100,
                dangerFrom: AppConstants.engineTempCriticalC,
                label: context.tr('engineTemp'),
                unit: context.tr('celsius'),
                size: gaugeSize.clamp(120, 190),
              ),
              CircularGauge(
                value: rpm.toDouble(),
                min: 0,
                max: 8000,
                warnFrom: 5500,
                dangerFrom: 6500,
                label: context.tr('rpm'),
                unit: 'RPM',
                valueText: '$rpm',
                size: gaugeSize.clamp(120, 190),
              ),
            ],
          );
        }),
        const SizedBox(height: 8),
        // Speedometer, full width.
        Center(
          child: CircularGauge(
            value: speed.toDouble(),
            min: 0,
            max: 240,
            warnFrom: 120,
            dangerFrom: 160,
            label: context.tr('speed'),
            unit: context.tr('kmh'),
            valueText: '$speed',
            size: 210,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LabeledProgressBar(
                  label: context.tr('fuelLevel'),
                  value: record?.fuelLevel ?? 0,
                  icon: Icons.local_gas_station,
                  color: AppColors.success,
                  warnBelow: AppConstants.fuelLowPercent,
                ),
                const SizedBox(height: 16),
                LabeledProgressBar(
                  label: context.tr('throttle'),
                  value: record?.throttlePosition ?? 0,
                  icon: Icons.speed,
                  color: AppColors.primaryBlue,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            MetricTile(
              icon: Icons.battery_charging_full,
              label: context.tr('batteryVoltage'),
              value: battery != null
                  ? '${battery.toStringAsFixed(1)} ${context.tr('volts')}'
                  : '—',
              subtitle: battery == null
                  ? null
                  : context.tr(batteryHealthy
                      ? 'batteryHealthy'
                      : battery < AppConstants.batteryLowV
                          ? 'batteryLow'
                          : 'batteryOvercharge'),
              color: battery == null || batteryHealthy
                  ? AppColors.success
                  : AppColors.warning,
            ),
            MetricTile(
              icon: Icons.air,
              label: context.tr('intakeTemp'),
              value: record?.intakeAirTemp != null
                  ? '${record!.intakeAirTemp!.toStringAsFixed(0)} ${context.tr('celsius')}'
                  : '—',
              color: AppColors.accentCyan,
            ),
            MetricTile(
              icon: Icons.bubble_chart_outlined,
              label: context.tr('oxygenSensor'),
              value: record?.oxygenSensor != null
                  ? '${record!.oxygenSensor!.toStringAsFixed(2)} ${context.tr('volts')}'
                  : '—',
              color: AppColors.primaryBlue,
            ),
            MetricTile(
              icon: Icons.warning_amber_rounded,
              label: context.tr('checkEngine'),
              value: context.tr(
                  (record?.checkEngineLight ?? false) ? 'on' : 'off'),
              color: (record?.checkEngineLight ?? false)
                  ? AppColors.danger
                  : AppColors.success,
              pulse: record?.checkEngineLight ?? false,
            ),
          ],
        ),
      ],
    );
  }
}
