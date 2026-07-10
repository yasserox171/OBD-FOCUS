import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../providers/dtc_provider.dart';
import '../../widgets/expandable_dtc_card.dart';
import '../../widgets/status_banner.dart';

/// DTC screen: read (Mode 03/07/0A), list with filtering, and clear
/// (Mode 04) with an explicit confirmation dialog.
class DtcScreen extends ConsumerWidget {
  const DtcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dtc = ref.watch(dtcProvider);
    final connection = ref.watch(connectionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('navDtc'))),
      body: Column(
        children: [
          const StatusBanner(),
          _ActionsRow(dtc: dtc, connected: connection.isConnected),
          _FilterChips(dtc: dtc),
          Expanded(
            child: dtc.filtered.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    itemCount: dtc.filtered.length,
                    itemBuilder: (context, index) =>
                        ExpandableDtcCard(dtc: dtc.filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionsRow extends ConsumerWidget {
  const _ActionsRow({required this.dtc, required this.connected});

  final DtcState dtc;
  final bool connected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: connected && !dtc.isReading
                  ? () => ref.read(dtcProvider.notifier).readCodes()
                  : null,
              icon: dtc.isReading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search, size: 18),
              label: Text(
                  context.tr(dtc.isReading ? 'readingCodes' : 'readCodes')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: connected && !dtc.isClearing && dtc.codes.isNotEmpty
                  ? () => _confirmClear(context, ref)
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(
                  color: connected && dtc.codes.isNotEmpty
                      ? AppColors.danger
                      : AppColors.danger.withOpacity(0.3),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: dtc.isClearing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline, size: 18),
              label: Text(
                  context.tr(dtc.isClearing ? 'clearingCodes' : 'clearCodes')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('clearConfirmTitle')),
        content: Text(context.tr('clearConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref.read(dtcProvider.notifier).clearCodes();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr(ok ? 'clearSuccess' : 'clearFailed')),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips({required this.dtc});

  final DtcState dtc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = {
      DtcFilter.all: context.tr('all'),
      DtcFilter.confirmed: context.tr('statusConfirmed'),
      DtcFilter.pending: context.tr('statusPending'),
      DtcFilter.permanent: context.tr('statusPermanent'),
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
                selected: dtc.filter == entry.key,
                onSelected: (_) =>
                    ref.read(dtcProvider.notifier).setFilter(entry.key),
              ),
            ),
          Center(
            child: Text(
              '${dtc.filtered.length} ${context.tr('codesFound')}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
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
            const Icon(Icons.verified_outlined,
                size: 56, color: AppColors.success),
            const SizedBox(height: 16),
            Text(context.tr('noCodes'),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              context.tr('noCodesDesc'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
