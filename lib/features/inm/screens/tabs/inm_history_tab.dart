// File: lib/features/inm/screens/tabs/inm_history_tab.dart
// Purpose: History tab - comprehensive historical review and analysis with tables and charts

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../models/inm_sensor_reading.dart';
import '../../models/inm_action_history.dart';
import '../../services/inm_api_service.dart';
import '../../widgets/inm_history_table.dart';

class InmHistoryTab extends StatefulWidget {
  const InmHistoryTab({super.key});

  @override
  State<InmHistoryTab> createState() => _InmHistoryTabState();
}

class _InmHistoryTabState extends State<InmHistoryTab> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final InmApiService _apiService = InmApiService();
  late TabController _tabController;
  
  List<InmSensorReading> _allReadings = [];
  List<InmActionHistory>? _actionHistory;
  bool _isLoading = true;
  bool _isLoadingActions = true;
  String? _errorMessage;
  
  // Auto-refresh every 30 seconds
  Timer? _autoRefreshTimer;
  static const int _refreshIntervalSeconds = 30;

  // Date range filter for history
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Chart parameter selector
  String _selectedChartParameter = 'EC';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Initialize action history to empty list
    _actionHistory = [];
    // Default to "All Time" - show all history records
    _startDate = null;
    _endDate = null;
    _loadSensorData();
    _loadActionHistory();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _loadActionHistory({bool showLoading = true}) async {
    debugPrint('🔄 INM History Tab: Starting to load action history...');
    if (showLoading) {
      setState(() {
        _isLoadingActions = true;
      });
    }

    try {
      final actions = await _apiService.fetchActionHistory();
      debugPrint('📊 INM History Tab: Loaded ${actions.length} action records');
      if (mounted) {
        setState(() {
          _actionHistory = actions;
          _isLoadingActions = false;
        });
      }
    } catch (e) {
      debugPrint('❌ INM History Tab: Error loading action history: $e');
      if (mounted) {
        setState(() {
          _actionHistory = [];
          _isLoadingActions = false;
        });
      }
    }
  }

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
    super.build(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        // Sub-TabBar for History sections
        Container(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.table_chart, size: 20),
                text: 'Sensor Data',
              ),
              Tab(
                icon: Icon(Icons.history, size: 20),
                text: 'Actions',
              ),
              Tab(
                icon: Icon(Icons.show_chart, size: 20),
                text: 'Trends',
              ),
            ],
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            indicatorSize: TabBarIndicatorSize.tab,
          ),
        ),
        // TabBarView content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Sensor Reading History
              RefreshIndicator(
                onRefresh: _loadSensorData,
                child: _buildSensorHistoryTab(theme),
              ),
              // Tab 2: Recommendation & Action History
              RefreshIndicator(
                onRefresh: _loadActionHistory,
                child: _buildActionHistoryTab(theme),
              ),
              // Tab 3: Charts (Visual Trends)
              RefreshIndicator(
                onRefresh: _loadSensorData,
                child: _buildTrendsTab(theme),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSensorHistoryTab(ThemeData theme) {
    // Loading state
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading history...'),
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
                  'Failed to load history',
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

    // Data state - show date filter and history table
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date Range Filter
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

          // Sensor History Table
          InmHistoryTable(readings: _historyReadings),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildActionHistoryTab(ThemeData theme) {
    // Loading state
    if (_isLoadingActions) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading action history...'),
          ],
        ),
      );
    }

    // Empty state - add null safety check
    if (_actionHistory?.isEmpty ?? true) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No Action History Yet',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start applying or ignoring recommendations\nto build your action history.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Data state - show action history table
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with count
          Card(
            elevation: 2,
            color: Colors.blue.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history, color: Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Action History',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_actionHistory?.length ?? 0} action${(_actionHistory?.length ?? 0) == 1 ? '' : 's'} recorded',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Action history list
          ...(_actionHistory?.map((action) => _buildActionCard(action, theme)) ?? []),
        ],
      ),
    );
  }

  Widget _buildActionCard(InmActionHistory action, ThemeData theme) {
    final isApplied = action.actionTaken.toLowerCase() == 'applied';
    final actionColor = isApplied ? Colors.green : Colors.orange;
    final actionIcon = isApplied ? Icons.check_circle : Icons.block;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and action badge
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      const SizedBox(width: 6),
                      Text(
                        action.formattedTime,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: actionColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(actionIcon, size: 14, color: actionColor),
                      const SizedBox(width: 4),
                      Text(
                        action.actionLabel,
                        style: TextStyle(
                          color: actionColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (action.growthStage != null && action.growthStage!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.eco, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    'Growth Stage: ${_capitalizeString(action.growthStage)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            
            // Recommendations summary
            _buildRecommendationSummary('EC', action.ecAction, Colors.orange, theme),
            const SizedBox(height: 8),
            _buildRecommendationSummary('pH', action.phAction, Colors.teal, theme),
            const SizedBox(height: 8),
            _buildRecommendationSummary('NPK', action.npkRecommendation, Colors.green, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationSummary(String label, String content, Color color, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            content,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendsTab(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading trend data...'),
          ],
        ),
      );
    }

    if (_errorMessage != null || _allReadings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart,
                size: 64,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No data available for trends',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sensor data is required to display trend charts',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Parameter Selector
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
                        Icons.tune,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Select Parameter',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildParameterChip('EC', Icons.electric_bolt, Colors.orange),
                      _buildParameterChip('pH', Icons.water_drop, Colors.teal),
                      _buildParameterChip('Soil Moisture', Icons.water, Colors.blue),
                      _buildParameterChip('Soil Temperature', Icons.thermostat, Colors.red),
                      _buildParameterChip('N', Icons.eco, Colors.green),
                      _buildParameterChip('P', Icons.eco, Colors.purple),
                      _buildParameterChip('K', Icons.eco, Colors.brown),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Chart Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_selectedChartParameter Trend Over Time',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 300,
                    child: _buildChart(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterChip(String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    final isSelected = _selectedChartParameter == label;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedChartParameter = label;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(isSelected ? 1.0 : 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? Colors.white : color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    // Get chart data based on selected parameter
    final chartData = _getChartData();
    
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('MM/dd HH:mm'),
        intervalType: DateTimeIntervalType.auto,
        majorGridLines: const MajorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: _getYAxisLabel()),
        majorGridLines: const MajorGridLines(width: 1, dashArray: [5, 5]),
      ),
      series: <CartesianSeries<_ChartData, DateTime>>[
        LineSeries<_ChartData, DateTime>(
          dataSource: chartData,
          xValueMapper: (_ChartData data, _) => data.timestamp,
          yValueMapper: (_ChartData data, _) => data.value,
          name: _selectedChartParameter,
          color: _getChartColor(),
          width: 3,
          markerSettings: const MarkerSettings(
            isVisible: true,
            height: 6,
            width: 6,
            shape: DataMarkerType.circle,
            borderWidth: 2,
            borderColor: Colors.white,
          ),
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x : point.y ${_getUnit()}',
      ),
      zoomPanBehavior: ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        zoomMode: ZoomMode.x,
      ),
    );
  }

  List<_ChartData> _getChartData() {
    return _allReadings.where((reading) => reading.timestamp != null).map((reading) {
      double value = 0.0;
      switch (_selectedChartParameter) {
        case 'EC':
          value = reading.ec;
          break;
        case 'pH':
          value = reading.ph;
          break;
        case 'Soil Moisture':
          value = reading.soilMoisture;
          break;
        case 'Soil Temperature':
          value = reading.soilTemp;
          break;
        case 'N':
          value = reading.nitrogen;
          break;
        case 'P':
          value = reading.phosphorus;
          break;
        case 'K':
          value = reading.potassium;
          break;
      }
      return _ChartData(reading.timestamp!, value);
    }).toList();
  }

  String _getYAxisLabel() {
    switch (_selectedChartParameter) {
      case 'EC':
        return 'EC (mS/cm)';
      case 'pH':
        return 'pH';
      case 'Soil Moisture':
        return 'Soil Moisture (%)';
      case 'Soil Temperature':
        return 'Temperature (°C)';
      case 'N':
      case 'P':
      case 'K':
        return '$_selectedChartParameter (mg/kg)';
      default:
        return '';
    }
  }

  String _getUnit() {
    switch (_selectedChartParameter) {
      case 'EC':
        return 'mS/cm';
      case 'pH':
        return '';
      case 'Soil Moisture':
        return '%';
      case 'Soil Temperature':
        return '°C';
      case 'N':
      case 'P':
      case 'K':
        return 'mg/kg';
      default:
        return '';
    }
  }

  Color _getChartColor() {
    switch (_selectedChartParameter) {
      case 'EC':
        return Colors.orange;
      case 'pH':
        return Colors.teal;
      case 'Soil Moisture':
        return Colors.blue;
      case 'Soil Temperature':
        return Colors.red;
      case 'N':
        return Colors.green;
      case 'P':
        return Colors.purple;
      case 'K':
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }

  /// Helper function to capitalize first letter of a string
  String _capitalizeString(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}

// Chart data model
class _ChartData {
  final DateTime timestamp;
  final double value;

  _ChartData(this.timestamp, this.value);
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

