import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../models/edas_models.dart';
import '../providers/edas_provider.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../../shared/widgets/trend_chart.dart';

class EdasDashboardScreen extends StatefulWidget {
  const EdasDashboardScreen({super.key});

  @override
  State<EdasDashboardScreen> createState() => _EdasDashboardScreenState();
}

class _EdasDashboardScreenState extends State<EdasDashboardScreen> {
  late final EdasProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = EdasProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        _provider.startAutoRefresh(
          tick: () => _provider.refresh(
            force: true,
            token: context.read<AuthState>().token,
            greenhouseId: null,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EdasProvider>.value(
      value: _provider,
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return Consumer<EdasProvider>(
      builder: (BuildContext context, EdasProvider provider, Widget? _) {
        final EdasSensorReading? latest = provider.latestForSelected;
        final EdasDiseasePrediction? prediction = provider.latestPrediction;
        final List<EdasSensorReading> history = provider.readingsForSelected;

        if (provider.isLoading && latest == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: GradientHeader.buildAppBar(
            context: context,
            title: 'EDAS - Early Disease Alert',
            onBackPressed: () => Navigator.of(context).pop(),
          ),
          body: RefreshIndicator(
            onRefresh: () => provider.refresh(
              force: true,
              token: context.read<AuthState>().token,
              greenhouseId: null,
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isMobile = constraints.maxWidth < 600;
                final double padding = isMobile ? 16.0 : 24.0;
                return ListView(
                  padding: EdgeInsets.fromLTRB(padding, 8, padding, padding),
                  children: <Widget>[
                    if (prediction != null) ...[
                      _DiseasePredictionCard(
                        prediction: prediction,
                        isMobile: isMobile,
                        lastUpdated: latest?.displayTime,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (provider.errorMessage != null && latest == null)
                      _ErrorBanner(message: provider.errorMessage!),
                    if (latest != null) ...<Widget>[
                      _SensorMetricsGrid(
                        key: ValueKey(
                          '${latest.id}_${latest.displayTime.millisecondsSinceEpoch}',
                        ),
                        latest: latest,
                        isMobile: isMobile,
                      ),
                      SizedBox(height: isMobile ? 16 : 24),
                      _TemperatureDifferenceCard(
                        key: ValueKey(
                          'temp_diff_${latest.id}_${latest.displayTime.millisecondsSinceEpoch}',
                        ),
                        latest: latest,
                        isMobile: isMobile,
                      ),
                      SizedBox(height: isMobile ? 16 : 24),
                    ] else
                      _EmptyState(
                        message: 'No readings for this selection.',
                        onRetry: () => provider.refresh(
                          force: true,
                          token: context.read<AuthState>().token,
                          greenhouseId: null,
                        ),
                      ),
                    _buildSectionHeader(context, 'Trends', isMobile),
                    SizedBox(height: isMobile ? 8 : 12),
                    if (history.length >= 2)
                      _TrendGrid(readings: history, isMobile: isMobile)
                    else
                      _EmptyState(
                        message:
                            'Not enough history yet. Ingest more readings.',
                        onRetry: () => provider.refresh(
                          force: true,
                          token: context.read<AuthState>().token,
                          greenhouseId: null,
                        ),
                      ),
                    SizedBox(height: isMobile ? 24 : 32),
                    _buildSectionHeader(
                      context,
                      'History',
                      isMobile,
                      trailing: GestureDetector(
                        onTap: () => _showHistoryDialog(context, provider),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF4CAF50).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'See All',
                                style: TextStyle(
                                  color: const Color(0xFF1B5E20),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 14,
                                color: Color(0xFF1B5E20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _RecentActivityLog(
                      readings: history.take(5).toList(),
                      isMobile: isMobile,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _DiseasePredictionCard extends StatelessWidget {
  const _DiseasePredictionCard({
    required this.prediction,
    required this.isMobile,
    this.lastUpdated,
  });

  final EdasDiseasePrediction prediction;
  final bool isMobile;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final Color riskColor = prediction.riskColor;
    final String formatted = lastUpdated != null
        ? _formatDateTime(lastUpdated!, isMobile: isMobile)
        : 'Waiting for first reading';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white, riskColor, 0.05),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: riskColor.withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: riskColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ML DISEASE PREDICTION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade500,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Text(
                formatted,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.health_and_safety,
                      color: riskColor,
                      size: isMobile
                          ? (MediaQuery.of(context).size.width < 340 ? 32 : 42)
                          : 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        prediction.displayRiskLevel,
                        style: TextStyle(
                          fontSize: isMobile
                              ? (MediaQuery.of(context).size.width < 340
                                    ? 28
                                    : 34)
                              : 40,
                          fontWeight: FontWeight.w900,
                          color: riskColor,
                          letterSpacing: -1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${(prediction.highestProbability * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.w900,
                      color: riskColor,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'CONFIDENCE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: riskColor.withOpacity(0.8),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (prediction.diseaseType != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: riskColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bug_report, size: 16, color: riskColor),
                  const SizedBox(width: 8),
                  Text(
                    'Disease: ${prediction.diseaseType}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: riskColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (prediction.recommendations != null &&
              prediction.recommendations!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border(left: BorderSide(color: riskColor, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: riskColor, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        'RECOMMENDATIONS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: riskColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...prediction.recommendations!.map(
                    (rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: riskColor)),
                          Expanded(
                            child: Text(
                              rec,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt, {bool isMobile = false}) {
    final String dayName = DateFormat('EEE', 'en_US').format(dt);
    final String month = DateFormat('MMM', 'en_US').format(dt);
    final String day = dt.day.toString();
    final String year = dt.year.toString();
    final String hour = dt.hour.toString().padLeft(2, '0');
    final String minute = dt.minute.toString().padLeft(2, '0');

    if (isMobile) {
      return '$dayName, $day $month • $hour:$minute';
    } else {
      return '$dayName, $day $month $year • $hour:$minute';
    }
  }
}

class _SensorMetricsGrid extends StatelessWidget {
  const _SensorMetricsGrid({
    Key? key,
    required this.latest,
    required this.isMobile,
  }) : super(key: key);

  final EdasSensorReading latest;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final List<_MetricItem> metrics = <_MetricItem>[
      _MetricItem(
        title: 'Plant Temperature',
        value: '${latest.plantTemperature.toStringAsFixed(2)}°C',
        icon: Icons.thermostat,
        color: const Color(0xFFFF6B6B),
        bgColor: const Color(0xFFFFE5E5),
      ),
      _MetricItem(
        title: 'Air Temperature',
        value: '${latest.airTemperature.toStringAsFixed(2)}°C',
        icon: Icons.ac_unit,
        color: const Color(0xFF4ECDC4),
        bgColor: const Color(0xFFE0F7F5),
      ),
      _MetricItem(
        title: 'Humidity',
        value: '${latest.humidity.toStringAsFixed(2)}%',
        icon: Icons.water_drop,
        color: const Color(0xFF90CAF9),
        bgColor: const Color(0xFFE3F2FD),
      ),
      if (latest.greenhouseId != null)
        _MetricItem(
          title: 'Greenhouse',
          value: latest.greenhouseId!,
          icon: Icons.local_florist,
          color: const Color(0xFFA5D6A7),
          bgColor: const Color(0xFFE8F5E9),
        ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        int columns;
        if (isMobile) {
          columns = constraints.maxWidth < 340 ? 1 : 2;
        } else {
          columns = metrics.length > 4 ? 4 : metrics.length;
          if (constraints.maxWidth < 600)
            columns = 2;
          else if (constraints.maxWidth < 900)
            columns = 3;
        }

        final double spacing = isMobile ? 12 : 16;
        final double cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics.map((_MetricItem metric) {
            return SizedBox(
              width: cardWidth,
              child: _ModernMetricCard(metric: metric, isMobile: isMobile),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TemperatureDifferenceCard extends StatelessWidget {
  const _TemperatureDifferenceCard({
    Key? key,
    required this.latest,
    required this.isMobile,
  }) : super(key: key);

  final EdasSensorReading latest;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final double tempDiff = latest.temperatureDifference;
    final Color diffColor = tempDiff > 2
        ? const Color(0xFFFF6B6B)
        : tempDiff < -2
        ? const Color(0xFF4ECDC4)
        : const Color(0xFF4CAF50);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  diffColor.withOpacity(0.2),
                  diffColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.compare_arrows,
              color: diffColor,
              size: isMobile ? 28 : 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Temperature Difference',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tempDiff > 0 ? '+' : ''}${tempDiff.toStringAsFixed(2)}°C',
                  style: TextStyle(
                    fontSize: isMobile ? 24 : 32,
                    fontWeight: FontWeight.w900,
                    color: diffColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tempDiff > 2
                      ? 'Plant warmer than air'
                      : tempDiff < -2
                      ? 'Plant cooler than air'
                      : 'Normal difference',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem {
  const _MetricItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
}

class _ModernMetricCard extends StatelessWidget {
  const _ModernMetricCard({required this.metric, required this.isMobile});

  final _MetricItem metric;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  metric.bgColor,
                  metric.bgColor.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              metric.icon,
              color: metric.color,
              size: isMobile ? 22 : 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  metric.title,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  metric.value,
                  style: TextStyle(
                    fontSize: isMobile
                        ? (MediaQuery.of(context).size.width < 340 ? 16 : 18)
                        : 22,
                    fontWeight: FontWeight.bold,
                    color: metric.color,
                    letterSpacing: 0.2,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _MetricType {
  plantTemperature,
  airTemperature,
  humidity,
  temperatureDifference,
}

class _TrendGrid extends StatefulWidget {
  const _TrendGrid({required this.readings, required this.isMobile});

  final List<EdasSensorReading> readings;
  final bool isMobile;

  @override
  State<_TrendGrid> createState() => _TrendGridState();
}

class _TrendGridState extends State<_TrendGrid> {
  _MetricType _selectedMetric = _MetricType.plantTemperature;

  List<TrendPoint> _map(
    List<EdasSensorReading> source,
    double Function(EdasSensorReading) selector,
  ) {
    return source
        .map((EdasSensorReading r) => TrendPoint(r.displayTime, selector(r)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    String title;
    String unit;
    Color color;
    List<TrendPoint> points;

    switch (_selectedMetric) {
      case _MetricType.plantTemperature:
        title = 'Plant Temperature (°C)';
        unit = '°C';
        color = const Color(0xFFFF6B6B);
        points = _map(widget.readings, (r) => r.plantTemperature);
        break;
      case _MetricType.airTemperature:
        title = 'Air Temperature (°C)';
        unit = '°C';
        color = const Color(0xFF4ECDC4);
        points = _map(widget.readings, (r) => r.airTemperature);
        break;
      case _MetricType.humidity:
        title = 'Humidity (%)';
        unit = '%';
        color = const Color(0xFF90CAF9);
        points = _map(widget.readings, (r) => r.humidity);
        break;
      case _MetricType.temperatureDifference:
        title = 'Temperature Difference (°C)';
        unit = '°C';
        color = const Color(0xFF4CAF50);
        points = _map(widget.readings, (r) => r.temperatureDifference);
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            children: <Widget>[
              _buildMetricTab(
                _MetricType.plantTemperature,
                'Plant Temp',
                Icons.thermostat,
                const Color(0xFFFF6B6B),
              ),
              _buildMetricTab(
                _MetricType.airTemperature,
                'Air Temp',
                Icons.ac_unit,
                const Color(0xFF4ECDC4),
              ),
              _buildMetricTab(
                _MetricType.humidity,
                'Humidity',
                Icons.water_drop,
                const Color(0xFF90CAF9),
              ),
              _buildMetricTab(
                _MetricType.temperatureDifference,
                'Temp Diff',
                Icons.compare_arrows,
                const Color(0xFF4CAF50),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TrendChart(
          title: title,
          unit: unit,
          color: color,
          optimalMin: null,
          optimalMax: null,
          points: points,
        ),
      ],
    );
  }

  Widget _buildMetricTab(
    _MetricType type,
    String label,
    IconData icon,
    Color color,
  ) {
    final bool isSelected = _selectedMetric == type;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: () => setState(() => _selectedMetric = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? color : Colors.grey.shade500,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.black : Colors.grey.shade500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityLog extends StatelessWidget {
  const _RecentActivityLog({required this.readings, required this.isMobile});

  final List<EdasSensorReading> readings;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: readings.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: Colors.grey.shade100,
        ),
        itemBuilder: (context, index) {
          final reading = readings[index];
          return _ActivityLogItem(reading: reading, isMobile: isMobile);
        },
      ),
    );
  }
}

class _ActivityLogItem extends StatelessWidget {
  const _ActivityLogItem({required this.reading, required this.isMobile});

  final EdasSensorReading reading;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm:ss').format(reading.displayTime);
    final dateStr = DateFormat('MMM d').format(reading.displayTime);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: isMobile ? 75 : 85,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade400,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildMiniMetric(
                    Icons.thermostat,
                    '${reading.plantTemperature.toStringAsFixed(2)}°',
                    const Color(0xFFFF6B6B),
                  ),
                  const SizedBox(width: 12),
                  _buildMiniMetric(
                    Icons.ac_unit,
                    '${reading.airTemperature.toStringAsFixed(2)}°',
                    const Color(0xFF4ECDC4),
                  ),
                  const SizedBox(width: 12),
                  _buildMiniMetric(
                    Icons.water_drop,
                    '${reading.humidity.toStringAsFixed(2)}%',
                    const Color(0xFF90CAF9),
                  ),
                  const SizedBox(width: 12),
                  _buildMiniMetric(
                    Icons.compare_arrows,
                    '${reading.temperatureDifference > 0 ? '+' : ''}${reading.temperatureDifference.toStringAsFixed(2)}°',
                    const Color(0xFF4CAF50),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFA5D6A7),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

Widget _buildSectionHeader(
  BuildContext context,
  String title,
  bool isMobile, {
  Widget? trailing,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Container(
            width: 4,
            height: isMobile ? 18 : 22,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      if (trailing != null) trailing,
    ],
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(Icons.warning_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        const SizedBox(height: 12),
        Icon(Icons.sensors_off, size: 42, color: scheme.onSurfaceVariant),
        const SizedBox(height: 6),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

void _showHistoryDialog(BuildContext context, EdasProvider provider) {
  final bool isMobile = MediaQuery.of(context).size.width < 600;

  if (isMobile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _HistoryDialogContent(provider: provider),
      ),
    );
  } else {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          _HistoryDialogContent(provider: provider),
    );
  }
}

class _HistoryDialogContent extends StatefulWidget {
  const _HistoryDialogContent({required this.provider});

  final EdasProvider provider;

  @override
  State<_HistoryDialogContent> createState() => _HistoryDialogContentState();
}

class _HistoryDialogContentState extends State<_HistoryDialogContent> {
  late final ScrollController verticalController;
  late DateTime startDate;
  late DateTime endDate;
  List<EdasSensorReading> allRows = <EdasSensorReading>[];
  List<EdasSensorReading> displayedRows = <EdasSensorReading>[];
  bool isLoadingHistory = false;
  bool _initialLoadDone = false;
  int _displayedCount = 20;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    verticalController = ScrollController();
    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    startDate = todayStart;
    endDate = todayStart.add(const Duration(days: 1));

    WidgetsBinding.instance.addPostFrameCallback((_) => loadHistory());
  }

  @override
  void dispose() {
    verticalController.dispose();
    super.dispose();
  }

  Future<void> loadHistory({bool resetPagination = true}) async {
    setState(() {
      isLoadingHistory = true;
    });
    final String? token =
        Provider.of<AuthState>(context, listen: false).token;
    final List<EdasSensorReading> fetched = await widget.provider
        .fetchHistoryForDateRange(
          token: token,
          startDate: startDate,
          endDate: endDate,
          greenhouseId: null,
          limit: 2000,
        );
    if (mounted) {
      setState(() {
        allRows = fetched;
        if (resetPagination) {
          _displayedCount = _pageSize;
        }
        displayedRows = allRows.take(_displayedCount).toList();
        isLoadingHistory = false;
        _initialLoadDone = true;
      });
    }
  }

  void _loadMore() {
    setState(() {
      _displayedCount += _pageSize;
      displayedRows = allRows.take(_displayedCount).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);

    Widget buildContent() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePicker(
                          label: 'From',
                          date: startDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => startDate = picked);
                              loadHistory();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDatePicker(
                          label: 'To',
                          date: endDate.subtract(const Duration(days: 1)),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: endDate.subtract(
                                const Duration(days: 1),
                              ),
                              firstDate: startDate,
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(
                                () => endDate = picked.add(
                                  const Duration(days: 1),
                                ),
                              );
                              loadHistory();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: isLoadingHistory && !_initialLoadDone
                ? const Center(child: CircularProgressIndicator())
                : allRows.isEmpty
                ? _buildEmptyState('No records found for this period.')
                : ListView.separated(
                    controller: verticalController,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 24,
                      vertical: 8,
                    ),
                    itemCount:
                        displayedRows.length +
                        (displayedRows.length < allRows.length ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == displayedRows.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: OutlinedButton(
                            onPressed: _loadMore,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.3,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Load More (${allRows.length - displayedRows.length} left)',
                            ),
                          ),
                        );
                      }
                      return _DetailedHistoryCard(
                        reading: displayedRows[index],
                        isMobile: isMobile,
                      );
                    },
                  ),
          ),
        ],
      );
    }

    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: GradientHeader.buildAppBar(
          context: context,
          title: 'Full Activity Log',
          onBackPressed: () => Navigator.of(context).pop(),
        ),
        body: buildContent(),
      );
    }

    return Dialog(
      backgroundColor: const Color(0xFFF5F5F5),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: 800,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Full Activity Log',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.black87,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(child: buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailedHistoryCard extends StatelessWidget {
  const _DetailedHistoryCard({required this.reading, required this.isMobile});
  final EdasSensorReading reading;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(reading.displayTime);
    final timeStr = DateFormat('h:mm:ss a').format(reading.displayTime);

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (reading.greenhouseId != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8E6C9).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reading.greenhouseId!,
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildMetricItem(
                  Icons.thermostat,
                  '${reading.plantTemperature.toStringAsFixed(2)}°',
                  'Plant Temp',
                  const Color(0xFFFF6B6B),
                ),
                const SizedBox(width: 16),
                _buildMetricItem(
                  Icons.ac_unit,
                  '${reading.airTemperature.toStringAsFixed(2)}°',
                  'Air Temp',
                  const Color(0xFF4ECDC4),
                ),
                const SizedBox(width: 16),
                _buildMetricItem(
                  Icons.water_drop,
                  '${reading.humidity.toStringAsFixed(2)}%',
                  'Humidity',
                  const Color(0xFF90CAF9),
                ),
                const SizedBox(width: 16),
                _buildMetricItem(
                  Icons.compare_arrows,
                  '${reading.temperatureDifference > 0 ? '+' : ''}${reading.temperatureDifference.toStringAsFixed(2)}°',
                  'Temp Diff',
                  const Color(0xFF4CAF50),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
