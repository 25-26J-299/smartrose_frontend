// File: lib/features/inm/screens/inm_dashboard_screen.dart
// Purpose: Main screen displaying INM sensor readings with latest card and history table

import 'dart:async';
import 'package:flutter/material.dart';

import '../models/inm_sensor_reading.dart';
import '../services/inm_api_service.dart';
import '../widgets/inm_latest_card.dart';
import '../widgets/inm_history_table.dart';
import '../widgets/inm_status_card.dart';

class InmDashboardScreen extends StatefulWidget {
  const InmDashboardScreen({super.key});

  @override
  State<InmDashboardScreen> createState() => _InmDashboardScreenState();
}

class _InmDashboardScreenState extends State<InmDashboardScreen> {
  final InmApiService _apiService = InmApiService();
  
  List<InmSensorReading> _allReadings = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Auto-refresh every 30 seconds
  Timer? _autoRefreshTimer;
  static const int _refreshIntervalSeconds = 30;

  // Date range filter for history
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Default to "All Time" - show all history records
    _startDate = null;
    _endDate = null;
    _loadSensorData();
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

  /// Get history readings filtered by date range
  List<InmSensorReading> get _historyReadings {
    if (_allReadings.length <= 1) return [];
    
    final history = _allReadings.sublist(1);
    
    // If no date filter, return all history
    if (_startDate == null && _endDate == null) {
      debugPrint('📋 INM History: No filter, showing all ${history.length} records');
      return history;
    }
    
    // Filter by date range
    final filtered = history.where((reading) {
      if (reading.timestamp == null) return false;
      
      final timestamp = reading.timestamp!;
      
      if (_startDate != null && timestamp.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && timestamp.isAfter(_endDate!)) {
        return false;
      }
      return true;
    }).toList();
    
    debugPrint('📋 INM History: Filter applied, showing ${filtered.length}/${history.length} records');
    return filtered;
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Start Date',
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select End Date',
    );
    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('INM Sensor Dashboard'),
        centerTitle: true,
        actions: [
          // Manual refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh now',
            onPressed: _isLoading ? null : _loadSensorData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSensorData,
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
          height: MediaQuery.of(context).size.height - 150,
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
          height: MediaQuery.of(context).size.height - 150,
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

    // Data state - show status, latest card and history table
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: INM Status Card (EC values & recommendation)
          const InmStatusCard(),
          const SizedBox(height: 24),
          
          // Section 2: Latest Sensor Readings Card
          if (_latestReading != null) ...[
            InmLatestCard(reading: _latestReading!),
            const SizedBox(height: 24),
          ],

          // Section 3: Date Range Filter
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.filter_list,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Filter History by Date',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Start Date
                      Expanded(
                        child: InkWell(
                          onTap: _selectStartDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Start Date',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                      Text(
                                        _formatDate(_startDate),
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // End Date
                      Expanded(
                        child: InkWell(
                          onTap: _selectEndDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'End Date',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                      Text(
                                        _formatDate(_endDate),
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Quick filter buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QuickFilterChip(
                        label: 'Today',
                        onTap: () {
                          final now = DateTime.now();
                          setState(() {
                            _startDate = DateTime(now.year, now.month, now.day);
                            _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
                          });
                        },
                      ),
                      _QuickFilterChip(
                        label: 'Last 7 Days',
                        onTap: () {
                          final now = DateTime.now();
                          setState(() {
                            _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
                            _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
                          });
                        },
                      ),
                      _QuickFilterChip(
                        label: 'Last 30 Days',
                        onTap: () {
                          final now = DateTime.now();
                          setState(() {
                            _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
                            _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
                          });
                        },
                      ),
                      _QuickFilterChip(
                        label: 'All Time',
                        onTap: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // Section 4: Sensor History Table
          InmHistoryTable(readings: _historyReadings),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickFilterChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

