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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(
              height: 220,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                tooltipBehavior: TooltipBehavior(enable: true),
                primaryXAxis: DateTimeAxis(
                  dateFormat: DateFormat('HH:mm'),
                  intervalType: DateTimeIntervalType.hours,
                  majorGridLines: const MajorGridLines(width: 0.2),
                ),
                primaryYAxis: NumericAxis(
                  labelFormat: unit != null ? '{value} $unit' : '{value}',
                  majorGridLines: const MajorGridLines(width: 0.2),
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
                        color.withOpacity(0.35),
                        color.withOpacity(0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderColor: color,
                    borderWidth: 2,
                    markerSettings: const MarkerSettings(isVisible: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// End of EOSM

