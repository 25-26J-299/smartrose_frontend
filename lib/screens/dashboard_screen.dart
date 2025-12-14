import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../shared/widgets/dashboard_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static final List<_DashboardEntry> _entries = <_DashboardEntry>[
    _DashboardEntry(
      title: 'INM Sensors',
      subtitle: 'View real-time sensor readings for temperature, humidity & soil.',
      icon: Icons.sensors,
      route: AppRoutes.inmSensors,
    ),
    _DashboardEntry(
      title: 'Freshness Monitoring',
      subtitle: 'Track bloom quality with live freshness insights.',
      icon: Icons.local_florist,
      route: AppRoutes.freshness,
    ),
    _DashboardEntry(
      title: 'Stress Monitoring',
      subtitle: 'Detect environmental stressors early.',
      icon: Icons.monitor_heart,
      route: AppRoutes.stress,
    ),
    _DashboardEntry(
      title: 'Disease Detection',
      subtitle: 'Identify disease risks with ML-assisted insights.',
      icon: Icons.bug_report,
      route: AppRoutes.disease,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 700;
        final bool isUltraWide = constraints.maxWidth >= 1100;
        final int crossAxisCount = isUltraWide
            ? 3
            : isWide
            ? 2
            : 1;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: isWide ? 1.4 : 1.1,
            children: _entries
                .map(
                  (_DashboardEntry entry) => DashboardCard(
                    title: entry.title,
                    subtitle: entry.subtitle,
                    icon: entry.icon,
                    onTap: () => Navigator.of(context).pushNamed(entry.route),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _DashboardEntry {
  const _DashboardEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}
