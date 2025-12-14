// File: lib/features/inm/widgets/inm_latest_card.dart
// Purpose: Card widget displaying the latest INM sensor reading with ALL values

import 'package:flutter/material.dart';
import '../models/inm_sensor_reading.dart';

class InmLatestCard extends StatelessWidget {
  final InmSensorReading reading;

  const InmLatestCard({super.key, required this.reading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.sensors,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Latest Sensor Readings',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Last updated: ${reading.timeAgo}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Device ID and Timestamp row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.device_hub,
                          size: 14,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          reading.deviceId,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: theme.colorScheme.tertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          reading.formattedTime,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Section: Environmental Conditions
              _SectionHeader(title: 'Environmental Conditions', icon: Icons.cloud),
              const SizedBox(height: 12),
              
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  final tileWidth = isWide 
                      ? (constraints.maxWidth - 24) / 3 
                      : (constraints.maxWidth - 12) / 2;
                  
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SensorValueTile(
                        icon: Icons.thermostat,
                        label: 'Air Temperature',
                        value: '${reading.airTemp.toStringAsFixed(1)}°C',
                        color: Colors.orange,
                        width: tileWidth,
                      ),
                      _SensorValueTile(
                        icon: Icons.water_drop,
                        label: 'Air Humidity',
                        value: '${reading.airHum.toStringAsFixed(1)}%',
                        color: Colors.blue,
                        width: tileWidth,
                      ),
                      _SensorValueTile(
                        icon: Icons.device_thermostat,
                        label: 'Soil Temperature',
                        value: '${reading.soilTemp.toStringAsFixed(1)}°C',
                        color: Colors.deepOrange,
                        width: tileWidth,
                      ),
                      _SensorValueTile(
                        icon: Icons.grass,
                        label: 'Soil Moisture',
                        value: '${reading.soilMoisture.toStringAsFixed(1)}%',
                        color: Colors.brown,
                        width: tileWidth,
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Section: Soil Chemistry
              _SectionHeader(title: 'Soil Chemistry', icon: Icons.science),
              const SizedBox(height: 12),
              
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  final tileWidth = isWide 
                      ? (constraints.maxWidth - 24) / 3 
                      : (constraints.maxWidth - 12) / 2;
                  
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SensorValueTile(
                        icon: Icons.electric_bolt,
                        label: 'EC Value',
                        value: reading.ec.toStringAsFixed(2),
                        color: Colors.purple,
                        width: tileWidth,
                      ),
                      _SensorValueTile(
                        icon: Icons.opacity,
                        label: 'pH Level',
                        value: reading.ph.toStringAsFixed(2),
                        color: Colors.teal,
                        width: tileWidth,
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Section: NPK Nutrients
              _SectionHeader(title: 'NPK Nutrients', icon: Icons.eco),
              const SizedBox(height: 12),
              
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  final tileWidth = isWide 
                      ? (constraints.maxWidth - 24) / 3 
                      : (constraints.maxWidth - 12) / 2;
                  
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SensorValueTile(
                        icon: Icons.fiber_manual_record,
                        label: 'Nitrogen (N)',
                        value: reading.nitrogen.toStringAsFixed(1),
                        color: Colors.green,
                        width: tileWidth,
                      ),
                      _SensorValueTile(
                        icon: Icons.fiber_manual_record,
                        label: 'Phosphorus (P)',
                        value: reading.phosphorus.toStringAsFixed(1),
                        color: Colors.amber,
                        width: tileWidth,
                      ),
                      _SensorValueTile(
                        icon: Icons.fiber_manual_record,
                        label: 'Potassium (K)',
                        value: reading.potassium.toStringAsFixed(1),
                        color: Colors.pink,
                        width: tileWidth,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.primary.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

class _SensorValueTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double width;

  const _SensorValueTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.9),
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
