import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/sensor_reading.dart';
import '../../../shared/providers/sensor_provider.dart';
import '../../../shared/utils/collection_extensions.dart';
import '../../../shared/widgets/snapshot_card.dart';
import '../../../shared/widgets/stress_gauge.dart';
import '../../../shared/widgets/trend_chart.dart';

class EosmDashboardScreen extends StatefulWidget {
  const EosmDashboardScreen({super.key});

  @override
  State<EosmDashboardScreen> createState() => _EosmDashboardScreenState();
}

class _EosmDashboardScreenState extends State<EosmDashboardScreen> {
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
        final SensorReading? latest = provider.latestForSelected;
        final List<SensorReading> history = provider.readingsForSelected;
        final List<String> greenhouseOptions = <String>[
          'ALL',
          ...provider.availableGreenhouseIds,
        ];
        final Map<String, String?> ghStations = provider.greenhouseBaseStations;
        final String selectedGh = provider.selectedGreenhouseId ?? 'ALL';

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
                  selectedGreenhouse: selectedGh,
                  lastUpdated: latest?.displayTime,
                  baseStationId: latest?.basestationId,
                  scheme: scheme,
                  greenhouseOptions: greenhouseOptions,
                  greenhouseStations: ghStations,
                  onSelect: provider.setSelectedGreenhouse,
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
                ] else
                  _EmptyState(
                    message: 'No readings for this selection.',
                    onRetry: () => provider.refresh(force: true),
                  ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('History', style: textTheme.titleMedium),
                    TextButton.icon(
                      onPressed: () => _showHistoryDialog(context, provider),
                      icon: const Icon(Icons.list_alt),
                      label: const Text('View full history'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _showHistoryDialog(BuildContext context, SensorProvider provider) {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      String selectedGh = provider.selectedGreenhouseId ?? 'ALL';
      final List<String> ghOptions = <String>[
        'ALL',
        ...provider.availableGreenhouseIds,
      ];
      final ScrollController verticalController = ScrollController();
      final ScrollController horizontalController = ScrollController();
      return StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setState) {
          final List<SensorReading> rows = (selectedGh == 'ALL'
                  ? provider.readings
                  : provider.readings
                      .where((SensorReading r) => r.greenhouseId == selectedGh))
              .toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: AlertDialog(
                contentPadding: const EdgeInsets.all(16),
                insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text(
                            'Full History',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(
                            width: 240,
                            child: DropdownButtonFormField<String>(
                              initialValue: ghOptions.contains(selectedGh) ? selectedGh : 'ALL',
                              items: ghOptions
                                  .map(
                                    (String gh) => DropdownMenuItem<String>(
                                      value: gh,
                                      child: Text(gh == 'ALL' ? 'All Greenhouses' : gh),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (String? value) => setState(() => selectedGh = value ?? 'ALL'),
                              decoration: const InputDecoration(
                                labelText: 'Greenhouse',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Scrollbar(
                            controller: verticalController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: verticalController,
                              primary: false,
                              child: Scrollbar(
                                controller: horizontalController,
                                thumbVisibility: true,
                                notificationPredicate: (ScrollNotification notification) =>
                                    notification.depth == 1,
                                child: SingleChildScrollView(
                                  controller: horizontalController,
                                  primary: false,
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const <DataColumn>[
                                      DataColumn(label: Text('Time')),
                                      DataColumn(label: Text('Greenhouse')),
                                      DataColumn(label: Text('Basestation')),
                                      DataColumn(label: Text('Temp °C')),
                                      DataColumn(label: Text('Hum %')),
                                      DataColumn(label: Text('Soil V')),
                                      DataColumn(label: Text('UV V')),
                                      DataColumn(label: Text('Gas V')),
                                    ],
                                    rows: rows
                                        .map(
                                          (SensorReading r) => DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text(
                                                  DateFormat('MMM d HH:mm:ss').format(_toSriLanka(r.displayTime)))),
                                              DataCell(Text(r.greenhouseId ?? '—')),
                                              DataCell(Text(r.basestationId)),
                                              DataCell(Text(r.temperature.toStringAsFixed(1))),
                                              DataCell(Text(r.humidity.toStringAsFixed(1))),
                                              DataCell(Text(r.soilVoltage?.toStringAsFixed(2) ?? '—')),
                                              DataCell(Text(r.uvVoltage?.toStringAsFixed(2) ?? '—')),
                                              DataCell(Text(r.mqVoltage?.toStringAsFixed(2) ?? '—')),
                                            ],
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

DateTime _toSriLanka(DateTime dt) =>
    dt.toUtc().add(const Duration(hours: 5, minutes: 30));

class _Header extends StatelessWidget {
  const _Header({
    required this.selectedGreenhouse,
    required this.lastUpdated,
    required this.baseStationId,
    required this.scheme,
    required this.greenhouseOptions,
    required this.greenhouseStations,
    required this.onSelect,
  });

  final String selectedGreenhouse;
  final DateTime? lastUpdated;
  final String? baseStationId;
  final ColorScheme scheme;
  final List<String> greenhouseOptions;
  final Map<String, String?> greenhouseStations;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final String formatted = lastUpdated != null
        ? DateFormat('MMM d, yyyy • HH:mm').format(_toSriLanka(lastUpdated!))
        : 'Waiting for first reading';
    final String titleSuffix =
        selectedGreenhouse == 'ALL' ? 'All Greenhouses' : selectedGreenhouse;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'SmartRose · $titleSuffix Dashboard',
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
            if (baseStationId != null) ...<Widget>[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.sensors, size: 14),
                    const SizedBox(width: 4),
                    Text('Base Station: $baseStationId'),
                  ],
                ),
              ),
            ],
          ],
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            initialValue: greenhouseOptions.contains(selectedGreenhouse)
                ? selectedGreenhouse
                : greenhouseOptions.firstOrNull,
            items: greenhouseOptions
                .map(
                  (String id) => DropdownMenuItem<String>(
                    value: id,
                    child: Text(
                      id == 'ALL'
                          ? 'All Greenhouses'
                          : '$id${greenhouseStations[id] != null ? ' · ${greenhouseStations[id]}' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onSelect,
            decoration: const InputDecoration(
              labelText: 'Greenhouse',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
                segments: <GaugeSegment>[
                  GaugeSegment(to: 40, color: scheme.primary),
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
                segments: <GaugeSegment>[
                  GaugeSegment(to: 100, color: scheme.secondary),
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
            ? 5
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
                color: Theme.of(context).colorScheme.primary,
                icon: Icons.thermostat,
              ),
            ),
            SizedBox(
              width: width,
              child: SnapshotCard(
                title: 'Humidity',
                value: '${latest.humidity.toStringAsFixed(1)} %',
                color: Theme.of(context).colorScheme.secondary,
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
                color: Theme.of(context).colorScheme.primary,
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
                color: Theme.of(context).colorScheme.primary,
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
                color: Theme.of(context).colorScheme.primary,
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
              color: scheme.primary,
              width: width,
            ),
            _RawCard(
              title: 'UV Sensor',
              value: latest.uvVoltage != null
                  ? '${latest.uvVoltage!.toStringAsFixed(2)} V'
                  : '—',
              color: const Color(0xFFFFC107),
              width: width,
            ),
            _RawCard(
              title: 'Gas Sensor',
              value: latest.mqVoltage != null
                  ? '${latest.mqVoltage!.toStringAsFixed(2)} V'
                  : '—',
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
    required this.color,
    required this.width,
  });

  final String title;
  final String value;
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
            ],
          ),
        ),
      ),
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
                optimalMin: null,
                optimalMax: null,
                points: _map(readings, (SensorReading r) => r.temperature),
              ),
            ),
            SizedBox(
              width: width,
              child: TrendChart(
                title: 'Humidity (%)',
                unit: '%',
                color: scheme.secondary,
                optimalMin: null,
                optimalMax: null,
                points: _map(readings, (SensorReading r) => r.humidity),
              ),
            ),
            SizedBox(
              width: width,
              child: TrendChart(
                title: 'Soil Voltage (V)',
                unit: 'V',
                color: const Color(0xFF4CAF50),
                optimalMin: null,
                optimalMax: null,
                points: _map(readings, (SensorReading r) => r.soilVoltage),
              ),
            ),
            SizedBox(
              width: width,
              child: TrendChart(
                title: 'Gas Voltage (V)',
                unit: 'V',
                color: const Color(0xFF9C27B0),
                optimalMin: null,
                optimalMax: null,
                points: _map(readings, (SensorReading r) => r.mqVoltage),
              ),
            ),
            SizedBox(
              width: width,
              child: TrendChart(
                title: 'UV Voltage (V)',
                unit: 'V',
                color: const Color(0xFFFFC107),
                optimalMin: null,
                optimalMax: null,
                points: _map(readings, (SensorReading r) => r.uvVoltage),
              ),
            ),
          ],
        );
      },
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


