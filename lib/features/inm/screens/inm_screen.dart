// File: lib/features/inm/screens/inm_screen.dart
// Purpose: Parent INM screen with TabBar navigation (Dashboard, Recommendations, History)

import 'package:flutter/material.dart';

import 'tabs/inm_dashboard_tab.dart';
import 'tabs/inm_recommendations_tab.dart';
import 'tabs/inm_history_tab.dart';

class InmScreen extends StatelessWidget {
  const InmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('INM'),
          centerTitle: true,
          bottom: TabBar(
            tabs: const [
              Tab(
                icon: Icon(Icons.dashboard),
                text: 'Dashboard',
              ),
              Tab(
                icon: Icon(Icons.recommend),
                text: 'Recommendations',
              ),
              Tab(
                icon: Icon(Icons.history),
                text: 'History',
              ),
            ],
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorWeight: 3,
          ),
        ),
        body: const TabBarView(
          children: [
            InmDashboardTab(),
            InmRecommendationsTab(),
            InmHistoryTab(),
          ],
        ),
      ),
    );
  }
}

