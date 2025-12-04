import 'package:flutter/material.dart';

class FreshnessHomeScreen extends StatelessWidget {
  const FreshnessHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Freshness Monitoring'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.local_florist, size: 64, color: scheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Freshness Module',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Monitor bloom freshness, life cycle, and vitality metrics from sensors.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // TODO: Replace with actual Freshness analytics dashboard.
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.construction),
                label: const Text('Feature in progress'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

