import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Horizontal progress bar with a title, animated fill and percentage label.
/// Used for fuel level and throttle position.
class LabeledProgressBar extends StatelessWidget {
  const LabeledProgressBar({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.warnBelow,
  });

  final String label;

  /// 0–100.
  final double value;
  final IconData? icon;
  final Color? color;

  /// When set, the bar turns red below this percentage (e.g. low fuel).
  final double? warnBelow;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0, 100).toDouble();
    final barColor = warnBelow != null && clamped < warnBelow!
        ? AppColors.danger
        : color ?? AppColors.accentCyan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: barColor),
              const SizedBox(width: 6),
            ],
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(
              '${clamped.toStringAsFixed(0)}%',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge!
                  .copyWith(color: barColor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: clamped / 100),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => LinearProgressIndicator(
              value: animated,
              minHeight: 10,
              backgroundColor:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white10
                      : Colors.black12,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
      ],
    );
  }
}
