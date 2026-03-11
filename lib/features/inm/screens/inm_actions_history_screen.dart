// File: lib/features/inm/screens/inm_actions_history_screen.dart
// Purpose: INM Actions & History page.
//
// Receives route arguments: Map<String, String> {deviceId, token}
// These are forwarded to both tabs so every API call is scoped to the
// correct device and carries a valid Bearer token.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../models/inm_status.dart';
import '../services/inm_api_service.dart';
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
  final InmApiService _apiService = InmApiService();

  // Resolved from route arguments or AuthState
  late String _deviceId;
  late String _token;
  Future<InmStatus>? _statusFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final authToken = Provider.of<AuthState>(context, listen: false).token ?? '';
    if (args is Map) {
      _deviceId = args['deviceId'] as String? ?? '';
      _token = args['token'] as String? ?? authToken;
    } else {
      // Fallback: try to read token from AuthState (deviceId will be empty)
      _deviceId = '';
      _token = authToken;
    }

    if (_deviceId.isNotEmpty && _token.isNotEmpty) {
      _statusFuture ??= _apiService.fetchStatus(_deviceId, _token);
    }
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

    // Guard: if deviceId is missing, show a clear error
    if (_deviceId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Actions & History'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 64,
                    color: theme.colorScheme.error.withOpacity(0.7)),
                const SizedBox(height: 16),
                const Text(
                  'No device selected.\nPlease go back and select a device first.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Actions & History'),
        centerTitle: true,
      ),
      body: FutureBuilder<InmStatus>(
        future: _statusFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64,
                        color: theme.colorScheme.error.withOpacity(0.7)),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load device data.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _statusFuture = _apiService.fetchStatus(_deviceId, _token);
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final status = snapshot.data;
          if (status != null && !status.hasSensorData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sensors_off,
                        size: 64,
                        color: theme.colorScheme.onSurface.withOpacity(0.35)),
                    const SizedBox(height: 16),
                    Text(
                      'No data available',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Modern pill-shaped tab selector
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
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

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    InmRecommendationsTab(
                      deviceId: _deviceId,
                      token: _token,
                      onActionTaken: _triggerHistoryRefresh,
                    ),
                    InmHistoryTab(
                      deviceId: _deviceId,
                      token: _token,
                      refreshNotifier: _refreshHistoryNotifier,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
