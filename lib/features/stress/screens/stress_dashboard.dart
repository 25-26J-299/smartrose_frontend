import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/sensor_reading.dart';
import '../../../shared/providers/sensor_provider.dart';
import '../../../shared/widgets/snapshot_card.dart';
import '../../../shared/widgets/stress_gauge.dart';
import '../../../shared/widgets/trend_chart.dart';

class StressDashboardScreen extends StatefulWidget {
  const StressDashboardScreen({super.key});

  @override
  State<StressDashboardScreen> createState() => _StressDashboardScreenState();
}

class _StressDashboardScreenState extends State<StressDashboardScreen> {
  late final SensorProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = SensorProvider();
    // Kick off initial and periodic refresh.
    unawaited(_provider.startAutoRefresh());
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SensorProvider>.value(
      value: _provider,
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Consumer<SensorProvider>(
      builder: (BuildContext context, SensorProvider provider, Widget? _) {
        final SensorReading? latest = provider.latest;
        final List<SensorReading> history = provider.readings;

        if (provider.isLoading && latest == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () => provider.refresh(force: true),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _Header(
                  lastUpdated: latest?.displayTime,
                  scheme: scheme,
                ),
                const SizedBox(height: 12),
                if (provider.errorMessage != null && latest == null)
                  _ErrorBanner(message: provider.errorMessage!),
                if (latest != null) ...<Widget>[
                  _GaugeRow(latest: latest),
                  const SizedBox(height: 12),
                  _SnapshotRow(latest: latest),
                  const SizedBox(height: 12),
                  _RawPanels(latest: latest),
                  const SizedBox(height: 16),
                ],
                Text('Trends', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                if (history.length >= 2)
                  _TrendGrid(readings: history)
                else
                  _EmptyState(
                    message: 'Not enough history yet. Ingest more readings.',
                    onRetry: () => provider.refresh(force: true),
                  ),
                const SizedBox(height: 16),
                Text('Recent readings', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                _HistoryList(readings: history),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.lastUpdated, required this.scheme});

  final DateTime? lastUpdated;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final String formatted = lastUpdated != null
        ? DateFormat('MMM d, yyyy • HH:mm').format(lastUpdated!)
        : 'Waiting for first reading';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'SmartRose · Raw Sensor Dashboard',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'Last updated: $formatted',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
        
      ],
    );
  }
}

class _GaugeRow extends StatelessWidget {
  const _GaugeRow({required this.latest});

  final SensorReading latest;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth > 900;
        final double width = wide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: <Widget>[
            SizedBox(
              width: width,
              child: StressGauge(
                title: 'Temperature',
                value: latest.temperature,
                unit: '°C',
                min: 0,
                max: 40,
                segments: const <GaugeSegment>[
                  GaugeSegment(to: 24, color: Color(0xFF4CAF50)),
                  GaugeSegment(to: 28, color: Color(0xFFFFC107)),
                  GaugeSegment(to: 40, color: Color(0xFFF44336)),
                ],
              ),
            ),
            SizedBox(
              width: width,
              child: StressGauge(
                title: 'Humidity',
                value: latest.humidity,
                unit: '%',
                min: 0,
                max: 100,
                segments: const <GaugeSegment>[
                  GaugeSegment(to: 60, color: Color(0xFFF44336)),
                  GaugeSegment(to: 75, color: Color(0xFF4CAF50)),
                  GaugeSegment(to: 85, color: Color(0xFFFFC107)),
                  GaugeSegment(to: 100, color: Color(0xFFF44336)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.latest});

  final SensorReading latest;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth > 1100
            ? 6
            : constraints.maxWidth > 900
                ? 3
                : constraints.maxWidth > 600
                    ? 3
                    : 2;
        const int cardCount = 5; // current snapshot cards
        final int effectiveColumns = columns > cardCount ? cardCount : columns;
        final double width =
            (constraints.maxWidth - (12 * (effectiveColumns - 1))) / effectiveColumns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            SizedBox(
              width: width,
              child: SnapshotCard(
                title: 'Temperature',
                value: '${latest.temperature.toStringAsFixed(1)} °C',
                subtitle: latest.temperatureStatus.label,
                color: latest.temperatureStatus.color,
                icon: Icons.thermostat,
              ),
            ),
            SizedBox(
              width: width,
              child: SnapshotCard(
                title: 'Humidity',
                value: '${latest.humidity.toStringAsFixed(1)} %',
                subtitle: latest.humidityStatus.label,
                color: latest.humidityStatus.color,
                icon: Icons.water_drop,
              ),
            ),
            SizedBox(
              width: width,
              child: SnapshotCard(
                title: 'Soil Voltage',
                value: latest.soilVoltage != null
                    ? '${latest.soilVoltage!.toStringAsFixed(2)} V'
                    : '—',
                subtitle: latest.soilStatus.label,
                color: latest.soilStatus.color,
                icon: Icons.grass,
              ),
            ),
            SizedBox(
              width: width,
              child: SnapshotCard(
                title: 'UV Voltage',
                value: latest.uvVoltage != null
                    ? '${latest.uvVoltage!.toStringAsFixed(2)} V'
                    : '—',
                subtitle: latest.uvStatus.label,
                color: latest.uvStatus.color,
                icon: Icons.wb_sunny,
              ),
            ),
            SizedBox(
              width: width,
              child: SnapshotCard(
                title: 'Gas Voltage',
                value: latest.mqVoltage != null
                    ? '${latest.mqVoltage!.toStringAsFixed(2)} V'
                    : '—',
                subtitle: latest.gasStatus.label,
                color: latest.gasStatus.color,
                icon: Icons.cloud,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RawPanels extends StatelessWidget {
  const _RawPanels({required this.latest});

  final SensorReading latest;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth > 1000;
        final double width = wide ? (constraints.maxWidth - 16) / 3 : constraints.maxWidth;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _RawCard(
              title: 'Soil Moisture',
              value: latest.soilVoltage != null
                  ? '${latest.soilVoltage!.toStringAsFixed(2)} V'
                  : '—',
              status: latest.soilStatus,
              color: scheme.primary,
              width: width,
            ),
            _RawCard(
              title: 'UV Sensor',
              value: latest.uvVoltage != null
                  ? '${latest.uvVoltage!.toStringAsFixed(2)} V'
                  : '—',
              status: latest.uvStatus,
              color: const Color(0xFFFFC107),
              width: width,
            ),
            _RawCard(
              title: 'Gas Sensor',
              value: latest.mqVoltage != null
                  ? '${latest.mqVoltage!.toStringAsFixed(2)} V'
                  : '—',
              status: latest.gasStatus,
              color: const Color(0xFF9C27B0),
              width: width,
            ),
          ],
        );
      },
    );
  }
}

class _RawCard extends StatelessWidget {
  const _RawCard({
    required this.title,
    required this.value,
    required this.status,
    required this.color,
    required this.width,
  });

  final String title;
  final String value;
  final StressStatus status;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              _StatusDot(color: status.color, label: status.label),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, this.label});

  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        if (label != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            label!,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _TrendGrid extends StatelessWidget {
  const _TrendGrid({required this.readings});

  final List<SensorReading> readings;

  List<TrendPoint> _map(List<SensorReading> source, double? Function(SensorReading) selector) {
    return source
        .where((SensorReading r) => selector(r) != null)
        .map((SensorReading r) => TrendPoint(r.displayTime, selector(r)!))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth > 1100;
        final double width = wide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            SizedBox(
              width: width,
              child: TrendChart(
                title: 'Temperature (°C)',
                unit: '°C',
                color: scheme.primary,
                optimalMin: 18,
                optimalMax: 24,
                points: _map(readings, (SensorReading r) => r.temperature),
              ),
            ),
            SizedBox(
              width: width,
              child: TrendChart(
                title: 'Humidity (%)',
                unit: '%',
                color: scheme.secondary,
                optimalMin: 60,
                optimalMax: 75,
                points: _map(readings, (SensorReading r) => r.humidity),
              ),
            ),
            SizedBox(
              width: width,
              child: TrendChart(
                title: 'Soil Voltage (V)',
                unit: 'V',
                color: const Color(0xFF4CAF50),
                optimalMin: 2.4,
                optimalMax: 2.9,
                points: _map(readings, (SensorReading r) => r.soilVoltage),
              ),
            ),
            SizedBox(
              width: width,
              child: TrendChart(
                title: 'Gas Voltage (V)',
                unit: 'V',
                color: const Color(0xFF9C27B0),
                optimalMin: 0.0,
                optimalMax: 0.5,
                points: _map(readings, (SensorReading r) => r.mqVoltage),
              ),
            ),
            SizedBox(
              width: width,
              child: TrendChart(
                title: 'UV Voltage (V)',
                unit: 'V',
                color: const Color(0xFFFFC107),
                optimalMin: 0.0,
                optimalMax: 0.5,
                points: _map(readings, (SensorReading r) => r.uvVoltage),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.readings});

  final List<SensorReading> readings;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return _EmptyState(
        message: 'No readings yet.',
        onRetry: () => Provider.of<SensorProvider>(context, listen: false).refresh(force: true),
      );
    }
    return Column(
      children: readings
          .map(
            (SensorReading r) => Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: const Icon(Icons.sensors),
                title: Text(
                  DateFormat('MMM d, HH:mm:ss').format(r.displayTime),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  'Temp ${r.temperature.toStringAsFixed(1)} °C · Hum ${r.humidity.toStringAsFixed(1)} % · Soil ${r.soilVoltage?.toStringAsFixed(2) ?? '—'} V',
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: r.temperatureStatus.color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    r.temperatureStatus.label ?? '',
                    style: TextStyle(color: r.temperatureStatus.color),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(Icons.warning_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onErrorContainer),
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

