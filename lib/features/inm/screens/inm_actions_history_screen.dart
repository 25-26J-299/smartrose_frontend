// File: lib/features/inm/screens/inm_actions_history_screen.dart
// Purpose: INM Actions & History page with modern pill-shaped tabs (2026 design)

import 'package:flutter/material.dart';

import 'tabs/inm_recommendations_tab.dart';
import 'tabs/inm_history_tab.dart';

class InmActionsHistoryScreen extends StatefulWidget {
  const InmActionsHistoryScreen({super.key});

  @override
  State<InmActionsHistoryScreen> createState() =>
      _InmActionsHistoryScreenState();
}

class _InmActionsHistoryScreenState extends State<InmActionsHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ValueNotifier<int> _refreshHistoryNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _triggerHistoryRefresh() {
    _refreshHistoryNotifier.value++;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshHistoryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Actions & History'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Modern pill-shaped tab selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor:
                  theme.colorScheme.onSurface.withOpacity(0.6),
              labelStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Recommendations'),
                Tab(text: 'History'),
              ],
            ),
          ),
          
          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                InmRecommendationsTab(onActionTaken: _triggerHistoryRefresh),
                InmHistoryTab(refreshNotifier: _refreshHistoryNotifier),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

