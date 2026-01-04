// File: lib/features/inm/screens/inm_overview_screen.dart
// Purpose: INM Overview page - glanceable status at a glance (mobile-first 2026 design)

import 'dart:async';
import 'package:flutter/material.dart';

import '../models/inm_sensor_reading.dart';
import '../models/inm_status.dart';
import '../services/inm_api_service.dart';
import '../widgets/hero_ml_insight_card.dart';
import '../widgets/live_sensor_snapshot.dart';
import '../widgets/top_recommendation_preview.dart';

class InmOverviewScreen extends StatefulWidget {
  const InmOverviewScreen({super.key});

  @override
  State<InmOverviewScreen> createState() => _InmOverviewScreenState();
}

class _InmOverviewScreenState extends State<InmOverviewScreen> {
  final InmApiService _apiService = InmApiService();
  
  List<InmSensorReading> _allReadings = [];
  InmStatus? _currentStatus;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Auto-refresh every 30 seconds
  Timer? _autoRefreshTimer;
  static const int _refreshIntervalSeconds = 30;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: _refreshIntervalSeconds),
      (timer) {
        if (mounted) {
          _loadAllData(showLoading: false);
        }
      },
    );
  }

  Future<void> _loadAllData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        _apiService.fetchAllReadings(),
        _apiService.fetchStatus(),
      ]);

      if (mounted) {
        setState(() {
          _allReadings = results[0] as List<InmSensorReading>;
          _currentStatus = results[1] as InmStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  InmSensorReading? get _latestReading =>
      _allReadings.isNotEmpty ? _allReadings.first : null;

  void _navigateToActionsHistory() {
    Navigator.of(context).pushNamed('/inm-actions-history');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('INM Overview'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAllData(),
            tooltip: 'Refresh all data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadAllData(),
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // Loading state
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Syncing INM data...'),
          ],
        ),
      );
    }

    // Error state
    if (_errorMessage != null && _allReadings.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height - 200,
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'Backend Unreachable',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _loadAllData(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Connection'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Data state - show overview
    return Stack(
      children: [
        SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero ML Insight Card
              if (_currentStatus != null)
                HeroMlInsightCard(status: _currentStatus!),
              
              const SizedBox(height: 24),
              
              // Live Sensor Snapshot
              if (_latestReading != null) ...[
                LiveSensorSnapshot(reading: _latestReading!),
                const SizedBox(height: 24),
              ],
              
              // Top Recommendation Preview with CTA
              if (_currentStatus != null)
                TopRecommendationPreview(
                  status: _currentStatus!,
                  onViewRecommendations: _navigateToActionsHistory,
                ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

