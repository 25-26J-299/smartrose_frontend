import 'package:flutter/material.dart';

class NutritionHomeScreen extends StatelessWidget {
  const NutritionHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.eco, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Nutrition Module',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Visualize nutrient uptake, soil balance, and feeding schedules.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // TODO: Replace with nutrient charts, alerts, and recommendations.
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.construction),
              label: const Text('Feature in progress'),
            ),
          ],
        ),
      ),
    );
  }
}
