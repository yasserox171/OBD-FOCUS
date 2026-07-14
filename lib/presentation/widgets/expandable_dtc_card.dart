import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/models/dtc_code.dart';

/// Expandable card for one diagnostic trouble code: collapsed shows the
/// code + severity; expanded reveals description, status and dates.
class ExpandableDtcCard extends StatefulWidget {
  const ExpandableDtcCard({super.key, required this.dtc});

  final DtcCode dtc;

  @override
  State<ExpandableDtcCard> createState() => _ExpandableDtcCardState();
}

class _ExpandableDtcCardState extends State<ExpandableDtcCard> {
  bool _expanded = false;

  Color get _severityColor => switch (widget.dtc.severity) {
        DtcSeverity.critical => AppColors.danger,
        DtcSeverity.moderate => AppColors.warning,
        DtcSeverity.low => AppColors.success,
      };

  String _severityLabel(BuildContext context) =>
      switch (widget.dtc.severity) {
        DtcSeverity.critical => context.tr('severityCritical'),
        DtcSeverity.moderate => context.tr('severityModerate'),
        DtcSeverity.low => context.tr('severityLow'),
      };

  String _statusLabel(BuildContext context) => switch (widget.dtc.status) {
        DtcStatus.confirmed => context.tr('statusConfirmed'),
        DtcStatus.pending => context.tr('statusPending'),
        DtcStatus.permanent => context.tr('statusPermanent'),
      };

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd(context.l10n.locale.languageCode).add_Hm();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _severityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.dtc.code,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(
                              color: _severityColor,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [],
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _Chip(
                        label: _statusLabel(context),
                        color: AppColors.primaryBlue),
                    const SizedBox(width: 6),
                    _Chip(label: _severityLabel(context), color: _severityColor),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(Icons.expand_more, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.dtc.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: _expanded ? null : 1,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                ),
                if (_expanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: context.tr('detectedOn'),
                    value: dateFmt.format(widget.dtc.detectedDate),
                  ),
                  _DetailRow(
                    label: context.tr('firstSeen'),
                    value: dateFmt.format(widget.dtc.firstSeen),
                  ),
                  _DetailRow(
                    label: context.tr('lastSeen'),
                    value: dateFmt.format(widget.dtc.lastSeen),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(color: color),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
