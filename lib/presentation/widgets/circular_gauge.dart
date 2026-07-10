import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Animated circular gauge with a sweeping needle, used for engine
/// temperature, RPM and the speedometer.
///
/// The needle animates smoothly between values ([TweenAnimationBuilder]),
/// and the arc is color-coded: green → orange → red as the value crosses
/// [warnFrom] / [dangerFrom].
class CircularGauge extends StatelessWidget {
  const CircularGauge({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.unit,
    this.warnFrom,
    this.dangerFrom,
    this.valueText,
    this.size = 160,
  });

  final double value;
  final double min;
  final double max;
  final String label;
  final String unit;

  /// Value where the orange zone starts (defaults to 75% of range).
  final double? warnFrom;

  /// Value where the red zone starts (defaults to 90% of range).
  final double? dangerFrom;

  /// Overrides the center text (e.g. rounded RPM); defaults to the value.
  final String? valueText;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max).toDouble();
    final warn = warnFrom ?? min + (max - min) * 0.75;
    final danger = dangerFrom ?? min + (max - min) * 0.90;
    final color = clamped >= danger
        ? AppColors.danger
        : clamped >= warn
            ? AppColors.warning
            : AppColors.success;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: clamped),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _GaugePainter(
                  value: animated,
                  min: min,
                  max: max,
                  warnFrom: warn,
                  dangerFrom: danger,
                  needleColor: color,
                  trackColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white10
                      : Colors.black12,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: size * 0.16),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium!
                        .copyWith(color: color, fontWeight: FontWeight.w700),
                    child: Text(valueText ?? animated.toStringAsFixed(0)),
                  ),
                  Text(unit, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.warnFrom,
    required this.dangerFrom,
    required this.needleColor,
    required this.trackColor,
  });

  final double value;
  final double min;
  final double max;
  final double warnFrom;
  final double dangerFrom;
  final Color needleColor;
  final Color trackColor;

  // Gauge sweeps 270° starting from 135° (bottom-left).
  static const _startAngle = 135 * math.pi / 180;
  static const _sweepAngle = 270 * math.pi / 180;

  double _angleFor(double v) =>
      _startAngle + ((v - min) / (max - min)).clamp(0.0, 1.0) * _sweepAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = size.width * 0.07;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, _startAngle, _sweepAngle, false, track);

    // Colored zones.
    void zone(double from, double to, Color color) {
      final a1 = _angleFor(from);
      final a2 = _angleFor(to);
      canvas.drawArc(
        rect,
        a1,
        a2 - a1,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = color.withOpacity(0.28),
      );
    }

    zone(min, warnFrom, AppColors.success);
    zone(warnFrom, dangerFrom, AppColors.warning);
    zone(dangerFrom, max, AppColors.danger);

    // Progress arc up to the current value.
    canvas.drawArc(
      rect,
      _startAngle,
      _angleFor(value) - _startAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = needleColor,
    );

    // Needle.
    final angle = _angleFor(value);
    final needleLength = radius - stroke;
    final tip = center +
        Offset(math.cos(angle), math.sin(angle)) * needleLength;
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = needleColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 6, Paint()..color = needleColor);

    // Tick marks.
    final tickPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 2;
    for (var i = 0; i <= 10; i++) {
      final a = _startAngle + _sweepAngle * i / 10;
      final outer = center + Offset(math.cos(a), math.sin(a)) * (radius + 6);
      final inner = center + Offset(math.cos(a), math.sin(a)) * (radius + 2);
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.needleColor != needleColor;
}
