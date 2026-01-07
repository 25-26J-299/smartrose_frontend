import 'package:flutter/material.dart';

import '../../edas/screens/edas_dashboard.dart';

/// Disease Detection Screen - Uses EDAS (Early Disease Alert System) Dashboard
/// Displays plant temperature, air temperature, humidity, temperature difference, and history records
class DiseaseHomeScreen extends StatelessWidget {
  const DiseaseHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the EDAS dashboard which contains all required features:
    // - Plant temperature
    // - Air temperature
    // - Humidity
    // - Temperature difference
    // - History records
    // All styled to match the environmental monitoring dashboard (EOSM)
    return const EdasDashboardScreen();
  }
}
