// File: lib/features/inm/screens/tabs/inm_dashboard_tab.dart
// Purpose: Dashboard tab showing live sensor readings and overall status

import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/inm_sensor_reading.dart';
import '../../services/inm_api_service.dart';
import '../../widgets/inm_latest_card.dart';
import '../../widgets/inm_status_summary_card.dart';

class InmDashboardTab extends StatefulWidget {
  const InmDashboardTab({super.key});

  @override
  State<InmDashboardTab> createState() => _InmDashboardTabState();
}

class _InmDashboardTabState extends State<InmDashboardTab> with AutomaticKeepAliveClientMixin {
  final InmApiService _apiService = InmApiService();
  
  List<InmSensorReading> _allReadings = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Auto-refresh every 30 seconds
  Timer? _autoRefreshTimer;
  static const int _refreshIntervalSeconds = 30;

  @override
  void initState() {
    super.initState();
    _loadSensorData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: _refreshIntervalSeconds),
      (timer) {
        if (mounted) {
          _loadSensorData(showLoading: false);
        }
      },
    );
  }

  Future<void> _loadSensorData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final readings = await _apiService.fetchAllReadings();
      if (mounted) {
        setState(() {
          _allReadings = readings;
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

  /// Get the latest reading (first item since list is sorted DESC)
  InmSensorReading? get _latestReading =>
      _allReadings.isNotEmpty ? _allReadings.first : null;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _loadSensorData,
      child: _buildBody(theme),
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
            Text('Loading sensor data...'),
          ],
        ),
      );
    }

    // Error state
    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height - 200,
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Failed to load sensor data',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '💡 Troubleshooting Tips',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Make sure your backend is running\n'
                        '• Check if CORS is enabled on your backend\n'
                        '• Verify the API endpoint is correct',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _loadSensorData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Empty state
    if (_allReadings.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height - 200,
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sensors_off,
                    size: 64,
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No sensor readings available',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'There are no INM sensor readings yet.\nWaiting for data from your sensors.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _loadSensorData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Data state - show status summary and latest sensor readings
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // INM Status Summary (EC values & status only - no detailed recommendations)
          const InmStatusSummaryCard(),
          const SizedBox(height: 24),
          
          // Latest Sensor Readings Card (EC, pH, Soil Moisture, Air Temp/Humidity, NPK)
          if (_latestReading != null) ...[
            InmLatestCard(reading: _latestReading!),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

