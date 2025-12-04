import 'package:flutter/material.dart';

import '../core/app_routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final List<_DashboardEntry> _entries = <_DashboardEntry>[
    _DashboardEntry(
      title: 'Freshness Monitoring',
      subtitle: 'Track bloom quality with live freshness insights.',
      icon: Icons.local_florist,
      route: AppRoutes.freshness,
    ),
    _DashboardEntry(
      title: 'Nutrition Monitoring',
      subtitle: 'Review nutrient balance and fertilizer guidance.',
      icon: Icons.eco,
      route: AppRoutes.nutrition,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartRose Dashboard'),
      ),
      body: LayoutBuilder(
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
                    (_DashboardEntry entry) => _DashboardCard(entry: entry),
                  )
                  .toList(),
            ),
          );
        },
      ),
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

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.entry});

  final _DashboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(entry.route),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                entry.icon,
                size: 40,
                color: scheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                entry.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  entry.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.bottomRight,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(entry.route),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Open'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

