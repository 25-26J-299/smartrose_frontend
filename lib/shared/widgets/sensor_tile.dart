import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/sensor_reading.dart';

class SensorTile extends StatelessWidget {
  const SensorTile({required this.reading, super.key});

  final SensorReading reading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime ts = reading.receivedAt ?? reading.timestamp;
    final String subtitle =
        '${DateFormat('MMM d, HH:mm').format(ts.toLocal())} • ${reading.sensorId}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.sensors, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Sensor ${reading.sensorId}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: <Widget>[
                _metricChip(
                  context,
                  icon: Icons.thermostat,
                  label: '${reading.temperature.toStringAsFixed(1)} °C',
                ),
                _metricChip(
                  context,
                  icon: Icons.water_drop,
                  label: '${reading.humidity.toStringAsFixed(1)} %',
                ),
                if (reading.uvVoltage != null)
                  _metricChip(
                    context,
                    icon: Icons.wb_sunny,
                    label: '${reading.uvVoltage!.toStringAsFixed(2)} V UV',
                  ),
                if (reading.soilVoltage != null)
                  _metricChip(
                    context,
                    icon: Icons.grass,
                    label: '${reading.soilVoltage!.toStringAsFixed(2)} V soil',
                  ),
                if (reading.mqVoltage != null)
                  _metricChip(
                    context,
                    icon: Icons.cloud,
                    label: '${reading.mqVoltage!.toStringAsFixed(2)} V gas',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label),
      avatar: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
      backgroundColor: scheme.surfaceVariant.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
