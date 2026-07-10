import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../providers/connection_provider.dart';
import '../providers/history_provider.dart';

/// Slim status strip under the app bar: Bluetooth connection state on the
/// left, online/offline indicator on the right.
class StatusBanner extends ConsumerWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final online = ref.watch(connectivityProvider).value ?? true;

    final (btColor, btLabel) = switch (connection.status) {
      ObdConnectionStatus.connected => (
          AppColors.success,
          '${context.tr('connected')}'
              '${connection.isDemo ? ' • ${context.tr('demoMode')}' : ''}'
        ),
      ObdConnectionStatus.connecting => (
          AppColors.warning,
          context.tr('connecting')
        ),
      ObdConnectionStatus.initializing => (
          AppColors.warning,
          context.tr('initializing')
        ),
      ObdConnectionStatus.disconnected => (
          AppColors.textSecondary,
          context.tr('disconnected')
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _Dot(color: btColor),
          const SizedBox(width: 6),
          Text(btLabel, style: Theme.of(context).textTheme.labelSmall),
          const Spacer(),
          Icon(
            online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            size: 14,
            color: online ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            context.tr(online ? 'online' : 'offline'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
      ),
    );
  }
}
