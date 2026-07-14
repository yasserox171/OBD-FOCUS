import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/status_banner.dart';

/// Home: device scanning/list, favorites, connection state and vehicle info.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(deviceScanProvider);
    final connection = ref.watch(connectionProvider);

    // Surface connection errors as SnackBars.
    ref.listen<ObdConnectionState>(connectionProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('connectionFailed')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('appName'))),
      body: Column(
        children: [
          const StatusBanner(),
          if (connection.isConnected) _ConnectedCard(connection: connection),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(deviceScanProvider.notifier).scan(),
              child: _DeviceList(scan: scan),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: scan.isScanning
            ? () => ref.read(deviceScanProvider.notifier).stopScan()
            : () => ref.read(deviceScanProvider.notifier).scan(),
        icon: scan.isScanning
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.bluetooth_searching),
        label: Text(
            context.tr(scan.isScanning ? 'scanning' : 'scanDevices')),
      ),
    );
  }
}

class _ConnectedCard extends ConsumerWidget {
  const _ConnectedCard({required this.connection});

  final ObdConnectionState connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryBlue.withValues(alpha: 0.18),
              AppColors.accentCyan.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car,
                    color: AppColors.accentCyan, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.tr('connectedTo')} '
                        '${connection.deviceName ?? ''}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (connection.protocol != null)
                        Text(
                          '${context.tr('protocol')}: ${connection.protocol}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/dashboard'),
                    icon: const Icon(Icons.speed, size: 18),
                    label: Text(context.tr('goToDashboard')),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(connectionProvider.notifier).disconnect(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  child: Text(context.tr('disconnect')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceList extends ConsumerWidget {
  const _DeviceList({required this.scan});

  final DeviceScanState scan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = <Widget>[];

    if (!scan.permissionsGranted) {
      children.add(_HintCard(
        icon: Icons.lock_outline,
        text: context.tr('permissionsNeeded'),
        actionLabel: context.tr('grantPermissions'),
        onAction: () => ref.read(deviceScanProvider.notifier).scan(),
      ));
    }
    if (!scan.bluetoothEnabled) {
      children.add(_HintCard(
        icon: Icons.bluetooth_disabled,
        text: context.tr('bluetoothOff'),
        actionLabel: context.tr('enableBluetooth'),
        onAction: () => ref.read(deviceScanProvider.notifier).scan(),
      ));
    }

    final favorites = scan.devices.where((d) => d.isFavorite).toList();
    final others = scan.devices.where((d) => !d.isFavorite).toList();

    if (favorites.isNotEmpty) {
      children.add(_SectionHeader(title: context.tr('favoriteDevices')));
      children.addAll(favorites.map((d) => _DeviceTile(device: d)));
    }
    children.add(_SectionHeader(title: context.tr('availableDevices')));
    if (others.isEmpty && favorites.isEmpty) {
      children.add(_HintCard(
        icon: Icons.search_off,
        text: '${context.tr('noDevices')}\n${context.tr('noDevicesHint')}',
      ));
    } else {
      children.addAll(others.map((d) => _DeviceTile(device: d)));
    }

    // Demo mode entry point.
    children.add(const SizedBox(height: 8));
    children.add(Card(
      child: ListTile(
        leading: const Icon(Icons.play_circle_outline,
            color: AppColors.accentCyan),
        title: Text(context.tr('demoMode')),
        subtitle: Text(context.tr('demoModeDesc'),
            style: Theme.of(context).textTheme.bodySmall),
        onTap: () async {
          await ref.read(connectionProvider.notifier).connectDemo();
          if (context.mounted) context.go('/dashboard');
        },
      ),
    ));
    children.add(const SizedBox(height: 90)); // FAB clearance

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({required this.device});

  final ScannedDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final isThisConnected = connection.isConnected &&
        connection.deviceAddress == device.address;
    final isBusy = connection.status == ObdConnectionStatus.connecting ||
        connection.status == ObdConnectionStatus.initializing;

    final subtitle = StringBuffer(device.address);
    if (device.lastConnected != null) {
      subtitle.write(
          '\n${context.tr('lastConnected')}: '
          '${DateFormat.yMMMd(context.l10n.locale.languageCode).add_Hm().format(device.lastConnected!)}'
          ' • ${context.tr('connectionCount')}: ${device.connectionCount}');
    }

    return Card(
      child: ListTile(
        leading: Icon(
          isThisConnected ? Icons.bluetooth_connected : Icons.bluetooth,
          color: isThisConnected
              ? AppColors.success
              : AppColors.textSecondary,
        ),
        title: Text(device.name),
        subtitle: Text(subtitle.toString(),
            style: Theme.of(context).textTheme.bodySmall),
        isThreeLine: device.lastConnected != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                device.isFavorite ? Icons.star : Icons.star_border,
                color: device.isFavorite
                    ? AppColors.warning
                    : AppColors.textSecondary,
              ),
              tooltip: context
                  .tr(device.isFavorite ? 'removeFavorite' : 'addFavorite'),
              onPressed: () =>
                  ref.read(deviceScanProvider.notifier).toggleFavorite(device),
            ),
            isThisConnected
                ? TextButton(
                    onPressed: () =>
                        ref.read(connectionProvider.notifier).disconnect(),
                    child: Text(context.tr('disconnect')),
                  )
                : TextButton(
                    onPressed: isBusy
                        ? null
                        : () async {
                            await ref
                                .read(connectionProvider.notifier)
                                .connect(device.address, device.name);
                            final state = ref.read(connectionProvider);
                            if (state.isConnected && context.mounted) {
                              context.go('/dashboard');
                            }
                          },
                    child: Text(context.tr('connect')),
                  ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppColors.textSecondary),
            const SizedBox(height: 10),
            Text(text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
