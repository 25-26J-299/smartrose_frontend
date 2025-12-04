import 'package:flutter/material.dart';

class DiseaseHomeScreen extends StatelessWidget {
  const DiseaseHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disease Detection'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.bug_report, size: 64, color: scheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Disease Module',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Run ML models to flag potential infections from imagery and sensors.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // TODO: Integrate ML inference results and disease history.
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

