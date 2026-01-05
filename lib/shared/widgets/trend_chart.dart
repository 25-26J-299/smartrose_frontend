import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class TrendPoint {
  const TrendPoint(this.time, this.value);
  final DateTime time;
  final double value;
}

// Start of EOSM
class TrendChart extends StatelessWidget {
  const TrendChart({
    required this.title,
    required this.points,
    required this.color,
    this.unit,
    this.optimalMin,
    this.optimalMax,
    super.key,
  });

  final String title;
  final List<TrendPoint> points;
  final Color color;
  final String? unit;
  final double? optimalMin;
  final double? optimalMax;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.show_chart,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: SfCartesianChart(
              plotAreaBorderWidth: 0,
              backgroundColor: Colors.transparent,
              tooltipBehavior: TooltipBehavior(
                enable: true,
                color: Colors.grey.shade900,
                borderWidth: 0,
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                shadowColor: Colors.black.withOpacity(0.3),
              ),
              primaryXAxis: DateTimeAxis(
                dateFormat: DateFormat('HH:mm'),
                intervalType: DateTimeIntervalType.hours,
                majorGridLines: MajorGridLines(
                  width: 0.5,
                  color: Colors.grey.shade200,
                  dashArray: <double>[5, 5],
                ),
                axisLine: AxisLine(width: 0),
                majorTickLines: MajorTickLines(width: 0),
                labelStyle: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              primaryYAxis: NumericAxis(
                labelFormat: unit != null ? '{value} $unit' : '{value}',
                majorGridLines: MajorGridLines(
                  width: 0.5,
                  color: Colors.grey.shade200,
                  dashArray: <double>[5, 5],
                ),
                axisLine: AxisLine(width: 0),
                majorTickLines: MajorTickLines(width: 0),
                labelStyle: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                plotBands: (optimalMin != null && optimalMax != null)
                    ? <PlotBand>[
                        PlotBand(
                          start: optimalMin,
                          end: optimalMax,
                          color: color.withOpacity(0.08),
                        ),
                      ]
                    : const <PlotBand>[],
              ),
              series: <CartesianSeries<TrendPoint, DateTime>>[
                AreaSeries<TrendPoint, DateTime>(
                  dataSource: points,
                  xValueMapper: (TrendPoint p, _) => p.time,
                  yValueMapper: (TrendPoint p, _) => p.value,
                  gradient: LinearGradient(
                    colors: <Color>[
                      color.withOpacity(0.4),
                      color.withOpacity(0.15),
                      color.withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const <double>[0.0, 0.5, 1.0],
                  ),
                  borderColor: color,
                  borderWidth: 3,
                  borderDrawMode: BorderDrawMode.top,
                  markerSettings: MarkerSettings(
                    isVisible: true,
                    shape: DataMarkerType.circle,
                    color: color,
                    borderColor: Colors.white,
                    borderWidth: 2,
                    height: 6,
                    width: 6,
                  ),
                  animationDuration: 1000,
                  enableTooltip: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// End of EOSM

