// File: lib/features/inm/screens/tabs/inm_history_tab.dart
// Purpose: History tab - mobile-first activity timeline + trend charts (2026 design)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../models/inm_sensor_reading.dart';
import '../../models/inm_action_history.dart';
import '../../services/inm_api_service.dart';

class InmHistoryTab extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;

  const InmHistoryTab({super.key, this.refreshNotifier});

  @override
  State<InmHistoryTab> createState() => _InmHistoryTabState();
}

class _InmHistoryTabState extends State<InmHistoryTab>
    with AutomaticKeepAliveClientMixin {
  final InmApiService _apiService = InmApiService();
  
  List<InmSensorReading> _allReadings = [];
  List<InmActionHistory>? _actionHistory;
  bool _isLoading = true;
  bool _isLoadingActions = true;
  
  // Chart parameter selector
  String _selectedChartParameter = 'EC';
  
  // Auto-refresh
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _actionHistory = [];
    _loadData();
    _startAutoRefresh();
    widget.refreshNotifier?.addListener(_onManualRefresh);
  }

  void _onManualRefresh() {
    if (mounted) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    widget.refreshNotifier?.removeListener(_onManualRefresh);
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) {
        if (mounted) {
          _loadData(showLoading: false);
        }
      },
    );
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _isLoadingActions = true;
      });
    }

    // Load sensor data and action history in parallel
    await Future.wait([
      _loadSensorData(),
      _loadActionHistory(),
    ]);
  }

  Future<void> _loadSensorData() async {
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
        });
      }
    }
  }

  Future<void> _loadActionHistory() async {
    try {
      final actions = await _apiService.fetchActionHistory();
      if (mounted) {
        setState(() {
          _actionHistory = actions;
          _isLoadingActions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionHistory = [];
          _isLoadingActions = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity Timeline Section
            Text(
              'Activity Timeline',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildActivityTimeline(theme),
            
            const SizedBox(height: 32),
            
            // Trend Charts Section
            Text(
              'Sensor Trends',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTrendCharts(theme),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTimeline(ThemeData theme) {
    if (_isLoadingActions) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_actionHistory?.isEmpty ?? true) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No activity history yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build timeline with action history
    return Column(
      children: _actionHistory!.asMap().entries.map((entry) {
        final index = entry.key;
        final action = entry.value;
        final isLast = index == _actionHistory!.length - 1;
        
        return _TimelineItem(
          action: action,
          isLast: isLast,
        );
      }).toList(),
    );
  }

  Widget _buildTrendCharts(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_allReadings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.show_chart,
                size: 48,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No sensor data available',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Parameter selector chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
          children: [
            'N',
            'P',
            'K',
            'EC',
            'pH',
            'Soil Moisture',
            'Soil Temp',
            'Air Temp',
            'Air Humidity',
          ].map((param) {
              final isSelected = _selectedChartParameter == param;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(param),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedChartParameter = param;
                      });
                    }
                  },
                  backgroundColor: theme.colorScheme.surface,
                  selectedColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Chart
        Container(
          height: 280,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: _buildChart(theme),
        ),
      ],
    );
  }

  Widget _buildChart(ThemeData theme) {
    final chartData = _getChartData();
    final config = _getChartConfig();

    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('MMM dd'),
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          fontSize: 11,
        ),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(
          text: config['unit'],
          textStyle: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        majorGridLines: MajorGridLines(
          width: 1,
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          fontSize: 11,
        ),
      ),
      plotAreaBorderWidth: 0,
      series: <CartesianSeries<_ChartData, DateTime>>[
        SplineAreaSeries<_ChartData, DateTime>(
          dataSource: chartData,
          xValueMapper: (_ChartData data, _) => data.time,
          yValueMapper: (_ChartData data, _) => data.value,
          color: config['color'].withOpacity(0.3),
          borderColor: config['color'],
          borderWidth: 2.5,
          markerSettings: MarkerSettings(
            isVisible: chartData.length <= 20,
            color: config['color'],
            borderColor: Colors.white,
            borderWidth: 2,
            height: 6,
            width: 6,
          ),
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        color: config['color'],
        textStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      zoomPanBehavior: ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        zoomMode: ZoomMode.x,
      ),
    );
  }

  List<_ChartData> _getChartData() {
    return _allReadings.map((reading) {
      double value;
      switch (_selectedChartParameter) {
        case 'N':
          value = reading.nitrogen;
          break;
        case 'P':
          value = reading.phosphorus;
          break;
        case 'K':
          value = reading.potassium;
          break;
        case 'EC':
          value = reading.ec;
          break;
        case 'pH':
          value = reading.ph;
          break;
        case 'Moisture':
          value = reading.soilMoisture;
          break;
        case 'Soil Temp':
          value = reading.soilTemp;
          break;
        case 'Air Temp':
          value = reading.airTemp;
          break;
        case 'Air Humidity':
          value = reading.airHum;
          break;
        default:
          value = reading.ec;
      }
      return _ChartData(reading.timestamp ?? DateTime.now(), value);
    }).toList();
  }

  Map<String, dynamic> _getChartConfig() {
    switch (_selectedChartParameter) {
      case 'N':
        return {'unit': 'mg/kg', 'color': Colors.green};
      case 'P':
        return {'unit': 'mg/kg', 'color': Colors.amber};
      case 'K':
        return {'unit': 'mg/kg', 'color': Colors.pink};
      case 'EC':
        return {'unit': 'mS/cm', 'color': Colors.purple};
      case 'pH':
        return {'unit': 'pH', 'color': Colors.teal};
      case 'Soil Moisture':
        return {'unit': '%', 'color': Colors.brown};
      case 'Soil Temp':
        return {'unit': '°C', 'color': Colors.deepOrange};
      case 'Air Temp':
        return {'unit': '°C', 'color': Colors.orange};
      case 'Air Humidity':
        return {'unit': '%', 'color': Colors.blue};
      default:
        return {'unit': 'mS/cm', 'color': Colors.purple};
    }
  }
}

class _TimelineItem extends StatelessWidget {
  final InmActionHistory action;
  final bool isLast;

  const _TimelineItem({
    required this.action,
    required this.isLast,
  });

  String _capitalizeString(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isApplied = action.actionTaken == 'applied';
    final iconColor = isApplied ? Colors.green : Colors.orange;
    final icon = isApplied ? Icons.check_circle : Icons.cancel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isApplied ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isApplied ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                isApplied ? Icons.check_circle : Icons.block, 
                color: isApplied ? Colors.green : Colors.grey, 
                size: 20
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
          ],
        ),
        
        const SizedBox(width: 16),
        
        // Content
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isApplied ? Colors.green.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isApplied ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isApplied ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isApplied ? 'Applied' : 'Skipped',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isApplied ? Colors.green.shade700 : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      action.formattedTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _truncateText(action.recommendationText, 100),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (action.growthStage != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.eco,
                        size: 14,
                        color: theme.colorScheme.primary.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _capitalizeString(action.growthStage),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _truncateText(String? text, int maxLength) {
    if (text == null || text.isEmpty) return 'No recommendation text';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

class _ChartData {
  final DateTime time;
  final double value;

  _ChartData(this.time, this.value);
}
