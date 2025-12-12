import 'dart:math' as math;

import 'package:flutter/material.dart';

class GaugeSegment {
  const GaugeSegment({required this.to, required this.color});
  final double to;
  final Color color;
}

class StressGauge extends StatelessWidget {
  const StressGauge({
    required this.title,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.segments,
    super.key,
  });

  final String title;
  final double value;
  final String unit;
  final double min;
  final double max;
  final List<GaugeSegment> segments;

  @override
  Widget build(BuildContext context) {
    final double clamped = value.clamp(min, max);
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: CustomPaint(
                painter: _GaugePainter(
                  value: clamped,
                  min: min,
                  max: max,
                  segments: segments,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        value.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        unit,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.segments,
  });

  final double value;
  final double min;
  final double max;
  final List<GaugeSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.94);
    final double radius = size.width * 0.28;
    const double startAngle = math.pi;
    const double sweepAngle = math.pi;

    double currentStart = startAngle;
    double lastBound = min;
    for (final GaugeSegment segment in segments) {
      final double segmentSweep =
          sweepAngle * ((segment.to - lastBound) / (max - min)).clamp(0.0, 1.0);
      final Paint paint = Paint()
        ..color = segment.color.withOpacity(0.9)
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentStart,
        segmentSweep,
        false,
        paint,
      );
      currentStart += segmentSweep;
      lastBound = segment.to;
    }

    final double normalized = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final double needleAngle = startAngle + sweepAngle * normalized;
    final Offset needleEnd = center +
        Offset(
          radius * math.cos(needleAngle),
          radius * math.sin(needleAngle),
        );

    final Paint needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.segments != segments;
  }
}


