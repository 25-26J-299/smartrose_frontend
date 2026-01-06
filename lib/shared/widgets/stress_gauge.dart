import 'dart:math' as math;

import 'package:flutter/material.dart';

class GaugeSegment {
  const GaugeSegment({required this.to, required this.color});
  final double to;
  final Color color;
}

// Start of EOSM
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color primaryColor = segments.isNotEmpty ? segments.first.color : scheme.primary;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            primaryColor.withOpacity(0.15),
                            primaryColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            value.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                              letterSpacing: -1,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            unit,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    if (size.width <= 0 || size.height <= 0) return;

    final Offset center = Offset(size.width / 2, size.height * 0.92);
    final double radius = size.width * 0.32;
    if (radius <= 0) return;

    const double startAngle = math.pi;
    const double sweepAngle = math.pi;

    // Draw background arc (subtle gray)
    final Paint bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final Rect arcRect = Rect.fromCircle(center: center, radius: radius);
    
    canvas.drawArc(
      arcRect,
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Draw gradient segments
    double currentStart = startAngle;
    double lastBound = min;
    for (final GaugeSegment segment in segments) {
      final double range = max - min;
      if (range <= 0) continue;

      final double segmentSweep =
          sweepAngle * ((segment.to - lastBound) / range).clamp(0.0, 1.0);
      
      if (segmentSweep > 0.001) {
        // Create gradient for the segment
        final Paint paint = Paint()
          ..shader = SweepGradient(
            startAngle: currentStart,
            endAngle: currentStart + segmentSweep,
            colors: <Color>[
              segment.color,
              segment.color.withOpacity(0.7),
              segment.color,
            ],
          ).createShader(arcRect)
          ..strokeWidth = 16
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        
        canvas.drawArc(
          arcRect,
          currentStart,
          segmentSweep,
          false,
          paint,
        );
      }
      currentStart += segmentSweep;
      lastBound = segment.to;
    }

    // Draw needle
    final double range = max - min;
    final double normalized = range > 0 ? ((value - min) / range).clamp(0.0, 1.0) : 0.5;
    final double needleAngle = startAngle + sweepAngle * normalized;
    final Offset needleEnd = center +
        Offset(
          radius * math.cos(needleAngle),
          radius * math.sin(needleAngle),
        );

    // Needle shadow (simplified, avoiding MaskFilter.blur which can cause Impeller errors)
    final Paint needleShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(
      center + const Offset(1, 1),
      needleEnd + const Offset(1, 1),
      needleShadowPaint,
    );

    // Main needle
    final Paint needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);

    // Center circle with gradient
    final Rect centerRect = Rect.fromCircle(center: center, radius: 8);
    final Paint centerPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white,
          Colors.grey.shade300,
        ],
      ).createShader(centerRect);
    canvas.drawCircle(center, 8, centerPaint);
    
    // Center circle border
    final Paint centerBorderPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 8, centerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.segments != segments;
  }
}
// End of EOSM


