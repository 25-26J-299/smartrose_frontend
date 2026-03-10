// File: lib/features/inm/widgets/inm_history_table.dart
// Purpose: Scrollable table widget displaying ALL INM sensor reading history

import 'package:flutter/material.dart';
import '../models/inm_sensor_reading.dart';

class InmHistoryTable extends StatelessWidget {
  const InmHistoryTable({
    super.key,
    required this.readings,
    this.serialToName,
  });

  final List<InmSensorReading> readings;
  /// Optional map of device serial -> display name for the Device column.
  final Map<String, String>? serialToName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (readings.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 48,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'No history available',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sensor History',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${readings.length} records',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Scrollable table - horizontal scroll with constrained width
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      theme.colorScheme.primary.withOpacity(0.05),
                    ),
                    headingTextStyle: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    dataTextStyle: theme.textTheme.bodySmall,
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    dataRowMinHeight: 40,
                    dataRowMaxHeight: 48,
                    headingRowHeight: 48,
                    columns: const [
                      DataColumn(label: Text('Date & Time')),
                      DataColumn(label: Text('Device')),
                      DataColumn(label: Text('Air °C'), numeric: true),
                      DataColumn(label: Text('Air %'), numeric: true),
                      DataColumn(label: Text('Soil °C'), numeric: true),
                      DataColumn(label: Text('Soil %'), numeric: true),
                      DataColumn(label: Text('EC'), numeric: true),
                      DataColumn(label: Text('pH'), numeric: true),
                      DataColumn(label: Text('N'), numeric: true),
                      DataColumn(label: Text('P'), numeric: true),
                      DataColumn(label: Text('K'), numeric: true),
                    ],
                    rows: readings.map((reading) {
                      return DataRow(
                        cells: [
                          // Date & Time
                          DataCell(
                            Text(
                              reading.formattedTime,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          // Device: show name when available
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                serialToName?[reading.deviceId] ?? reading.deviceId,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ),
                          ),
                          // Air Temperature
                          DataCell(
                            _ValueCell(
                              value: reading.airTemp.toStringAsFixed(1),
                              color: _getTempColor(reading.airTemp),
                            ),
                          ),
                          // Air Humidity
                          DataCell(
                            _ValueCell(
                              value: reading.airHum.toStringAsFixed(1),
                              color: _getHumidityColor(reading.airHum),
                            ),
                          ),
                          // Soil Temperature
                          DataCell(
                            _ValueCell(
                              value: reading.soilTemp.toStringAsFixed(1),
                              color: _getTempColor(reading.soilTemp),
                            ),
                          ),
                          // Soil Moisture
                          DataCell(
                            _ValueCell(
                              value: reading.soilMoisture.toStringAsFixed(1),
                              color: _getSoilMoistureColor(reading.soilMoisture),
                            ),
                          ),
                          // EC
                          DataCell(
                            _ValueCell(
                              value: reading.ec.toStringAsFixed(1),
                              color: Colors.purple,
                            ),
                          ),
                          // pH
                          DataCell(
                            _ValueCell(
                              value: reading.ph.toStringAsFixed(2),
                              color: _getPhColor(reading.ph),
                            ),
                          ),
                          // Nitrogen
                          DataCell(
                            _ValueCell(
                              value: reading.nitrogen.toStringAsFixed(0),
                              color: Colors.green,
                            ),
                          ),
                          // Phosphorus
                          DataCell(
                            _ValueCell(
                              value: reading.phosphorus.toStringAsFixed(0),
                              color: Colors.amber.shade700,
                            ),
                          ),
                          // Potassium
                          DataCell(
                            _ValueCell(
                              value: reading.potassium.toStringAsFixed(0),
                              color: Colors.pink,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getTempColor(double temp) {
    if (temp < 15) return Colors.blue;
    if (temp < 25) return Colors.green;
    if (temp < 35) return Colors.orange;
    return Colors.red;
  }

  Color _getHumidityColor(double humidity) {
    if (humidity < 30) return Colors.orange;
    if (humidity < 60) return Colors.green;
    return Colors.blue;
  }

  Color _getSoilMoistureColor(double moisture) {
    if (moisture < 20) return Colors.red;
    if (moisture < 40) return Colors.orange;
    if (moisture < 70) return Colors.green;
    return Colors.blue;
  }

  Color _getPhColor(double ph) {
    if (ph < 5.5) return Colors.red;
    if (ph < 6.5) return Colors.orange;
    if (ph < 7.5) return Colors.green;
    return Colors.blue;
  }
}

class _ValueCell extends StatelessWidget {
  final String value;
  final Color color;

  const _ValueCell({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.withOpacity(0.9),
        ),
      ),
    );
  }
}
