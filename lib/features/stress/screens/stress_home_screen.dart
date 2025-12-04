import 'package:flutter/material.dart';

class StressHomeScreen extends StatelessWidget {
  const StressHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stress Monitoring'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.monitor_heart, size: 64, color: scheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Stress Module',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Detect and respond to environmental stress factors in real time.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // TODO: Render stress alerts and mitigation recommendations.
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

