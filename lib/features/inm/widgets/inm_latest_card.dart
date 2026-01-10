// File: lib/features/inm/widgets/inm_latest_card.dart
// Purpose: Compact 2-column sensor cards for modern mobile dashboard (2026 design)

import 'package:flutter/material.dart';
import '../models/inm_sensor_reading.dart';

class InmLatestCard extends StatelessWidget {
  final InmSensorReading reading;

  const InmLatestCard({super.key, required this.reading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                'Live Readings',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade500,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Uniform 2-column grid for all sensors
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _CompactSensorCard(
              icon: Icons.fiber_manual_record,
              label: 'Nitrogen',
              value: reading.nitrogen.toStringAsFixed(0),
              unit: 'mg/kg',
              color: Colors.green,
            ),
            _CompactSensorCard(
              icon: Icons.fiber_manual_record,
              label: 'Phosphorus',
              value: reading.phosphorus.toStringAsFixed(0),
              unit: 'mg/kg',
              color: Colors.amber,
            ),
            _CompactSensorCard(
              icon: Icons.fiber_manual_record,
              label: 'Potassium',
              value: reading.potassium.toStringAsFixed(0),
              unit: 'mg/kg',
              color: Colors.pink,
            ),
            _CompactSensorCard(
              icon: Icons.electric_bolt,
              label: 'EC',
              value: reading.ec.toStringAsFixed(2),
              unit: 'mS/cm',
              color: Colors.purple,
            ),
            _CompactSensorCard(
              icon: Icons.opacity,
              label: 'pH',
              value: reading.ph.toStringAsFixed(1),
              unit: '',
              color: Colors.teal,
            ),
            _CompactSensorCard(
              icon: Icons.water_drop,
              label: 'Soil Moisture',
              value: reading.soilMoisture.toStringAsFixed(0),
              unit: '%',
              color: Colors.brown,
            ),
            _CompactSensorCard(
              icon: Icons.thermostat,
              label: 'Air Temp',
              value: reading.airTemp.toStringAsFixed(1),
              unit: '°C',
              color: Colors.orange,
            ),
            _CompactSensorCard(
              icon: Icons.water_drop_outlined,
              label: 'Air Humidity',
              value: reading.airHum.toStringAsFixed(0),
              unit: '%',
              color: Colors.blue,
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactSensorCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _CompactSensorCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon and label row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          // Value and unit
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 28,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      unit,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
