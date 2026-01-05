import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../core/auth/auth_state.dart';
import '../features/inm/services/inm_api_service.dart';
import '../features/inm/models/inm_sensor_reading.dart';
import '../shared/services/freshness_api_service.dart';
import '../shared/models/reading_model.dart';
import '../shared/models/prediction_model.dart';
import '../shared/services/sensor_service.dart';
import '../shared/models/sensor_data.dart';
import '../shared/utils/role_filter.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  String _selectedComponent = 'All';
  String _selectedTimeRange = 'Last 7 Days';

  List<String> _getAvailableComponents(BuildContext context) {
    final AuthState authState = context.watch<AuthState>();
    final List<String> roles = authState.roles;
    final List<String> components = ['All'];

    if (RoleFilter.isFarmer(roles) || RoleFilter.hasBothRoles(roles)) {
      components.addAll(['Nutrition', 'Environment', 'Disease']);
    }
    if (RoleFilter.isFlorist(roles) || RoleFilter.hasBothRoles(roles)) {
      components.add('Freshness');
    }

    return components;
  }

  final List<String> _timeRanges = ['Today', 'Last 7 Days', 'Last 30 Days'];

  // Services
  final InmApiService _inmApiService = InmApiService();
  final FreshnessApiService _freshnessApiService = FreshnessApiService();
  final SensorService _sensorService = SensorService();

  // Data state
  bool _isLoading = false;
  String? _errorMessage;
  List<String> _userRoles = [];

  List<InmSensorReading> _inmReadings = [];
  List<ReadingModel> _freshnessReadings = [];
  List<SensorReading> _sensorReadings = [];
  PredictionModel? _latestPrediction;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _freshnessApiService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch data from all sources in parallel
      List<InmSensorReading> inmData = [];
      List<ReadingModel> freshnessData = [];
      List<SensorReading> sensorData = [];

      try {
        inmData = await _inmApiService.fetchAllReadings();
      } catch (e) {
        // Ignore error, use empty list
      }

      try {
        freshnessData = await _fetchFreshnessData();
      } catch (e) {
        // Ignore error, use empty list
      }

      try {
        sensorData = await _sensorService.fetchLatestReadings(limit: 100);
      } catch (e) {
        // Ignore error, use empty list
      }

      setState(() {
        _inmReadings = inmData;
        _freshnessReadings = freshnessData;
        _sensorReadings = sensorData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load insights data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<List<ReadingModel>> _fetchFreshnessData() async {
    // For now, fetch latest with prediction to get current data
    // In a real scenario, you'd have a history endpoint
    try {
      final data = await _freshnessApiService.getLatestWithPrediction(
        'device_001',
        forceRefresh: true,
      );
      final reading = ReadingModel.fromJson(
        data['reading'] as Map<String, dynamic>,
      );
      final prediction = PredictionModel.fromJson(
        data['prediction'] as Map<String, dynamic>,
      );
      setState(() {
        _latestPrediction = prediction;
      });
      return [reading];
    } catch (e) {
      return [];
    }
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedTimeRange) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'Last 7 Days':
        return now.subtract(const Duration(days: 7));
      case 'Last 30 Days':
        return now.subtract(const Duration(days: 30));
      default:
        return now.subtract(const Duration(days: 7));
    }
  }

  List<InmSensorReading> _getFilteredInmReadings() {
    final startDate = _getStartDate();

    // Only show INM data if user is farmer or has both roles
    if (!RoleFilter.isFarmer(_userRoles) &&
        !RoleFilter.hasBothRoles(_userRoles)) {
      return [];
    }

    return _inmReadings.where((reading) {
      if (reading.timestamp == null) return false;
      if (_selectedComponent != 'All' && _selectedComponent != 'Nutrition') {
        return false;
      }
      return reading.timestamp!.isAfter(startDate);
    }).toList();
  }

  List<ReadingModel> _getFilteredFreshnessReadings() {
    final startDate = _getStartDate();

    // Only show Freshness data if user is florist or has both roles
    if (!RoleFilter.isFlorist(_userRoles) &&
        !RoleFilter.hasBothRoles(_userRoles)) {
      return [];
    }

    return _freshnessReadings.where((reading) {
      if (_selectedComponent != 'All' && _selectedComponent != 'Freshness') {
        return false;
      }
      return reading.timestamp.isAfter(startDate);
    }).toList();
  }

  List<SensorReading> _getFilteredSensorReadings() {
    final startDate = _getStartDate();

    // Only show Environment data if user is farmer or has both roles
    if (!RoleFilter.isFarmer(_userRoles) &&
        !RoleFilter.hasBothRoles(_userRoles)) {
      return [];
    }

    return _sensorReadings.where((reading) {
      if (_selectedComponent != 'All' && _selectedComponent != 'Environment') {
        return false;
      }
      return reading.timestamp.isAfter(startDate);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AuthState authState = context.watch<AuthState>();
    _userRoles = authState.roles;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerHighest,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorView(scheme)
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildHeader(scheme),
                    _buildFilterBar(scheme),
                    _buildKeyInsights(scheme),
                    _buildTrendCharts(scheme),
                    _buildSmartInsights(scheme),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildErrorView(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.error_outline, size: 64, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: scheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Insights',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Greenhouse trends & analysis',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showInfoTooltip(context);
            },
            tooltip: 'About Insights',
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme scheme) {
    final availableComponents = _getAvailableComponents(context);

    // Reset selection if current selection is not available
    if (!availableComponents.contains(_selectedComponent)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedComponent = 'All';
          });
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _buildFilterDropdown(
              label: 'Component',
              value: availableComponents.contains(_selectedComponent)
                  ? _selectedComponent
                  : 'All',
              items: availableComponents,
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _selectedComponent = value;
                  });
                }
              },
              scheme: scheme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterDropdown(
              label: 'Time Range',
              value: _selectedTimeRange,
              items: _timeRanges,
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _selectedTimeRange = value;
                  });
                }
              },
              scheme: scheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required ColorScheme scheme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.3)),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: InputBorder.none,
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        icon: Icon(Icons.arrow_drop_down, color: scheme.primary),
        dropdownColor: scheme.surface,
      ),
    );
  }

  Widget _buildKeyInsights(ColorScheme scheme) {
    final List<_KeyInsight> insights = _getKeyInsights();

    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: insights.length,
        itemBuilder: (BuildContext context, int index) {
          final _KeyInsight insight = insights[index];
          return _buildKeyInsightCard(insight, scheme);
        },
      ),
    );
  }

  Widget _buildKeyInsightCard(_KeyInsight insight, ColorScheme scheme) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: insight.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(insight.icon, color: insight.color, size: 24),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: insight.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      insight.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: insight.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                insight.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                insight.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendCharts(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'System Trends',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          if (_shouldShowChart('Soil Moisture'))
            _buildTrendCard(
              title: 'Soil Moisture',
              unit: '%',
              color: scheme.primary,
              scheme: scheme,
              dataPoints: _getSoilMoistureData(),
            ),
          if (_shouldShowChart('Temperature'))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildTrendCard(
                title: 'Temperature',
                unit: '°C',
                color: Colors.orange,
                scheme: scheme,
                dataPoints: _getTemperatureData(),
              ),
            ),
          if (_shouldShowChart('EC'))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildTrendCard(
                title: 'EC (Electrical Conductivity)',
                unit: 'mS/cm',
                color: scheme.secondary,
                scheme: scheme,
                dataPoints: _getECData(),
              ),
            ),
          if (_shouldShowChart('Humidity'))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildTrendCard(
                title: 'Humidity',
                unit: '%',
                color: scheme.tertiary,
                scheme: scheme,
                dataPoints: _getHumidityData(),
              ),
            ),
        ],
      ),
    );
  }

  bool _shouldShowChart(String metric) {
    switch (_selectedComponent) {
      case 'Nutrition':
        if (!RoleFilter.isFarmer(_userRoles) &&
            !RoleFilter.hasBothRoles(_userRoles)) {
          return false;
        }
        return metric == 'Soil Moisture' || metric == 'EC';
      case 'Environment':
        if (!RoleFilter.isFarmer(_userRoles) &&
            !RoleFilter.hasBothRoles(_userRoles)) {
          return false;
        }
        return metric == 'Temperature' || metric == 'Humidity';
      case 'Freshness':
        if (!RoleFilter.isFlorist(_userRoles) &&
            !RoleFilter.hasBothRoles(_userRoles)) {
          return false;
        }
        return metric == 'Temperature' || metric == 'Humidity';
      default:
        // Show all charts if user has both roles, otherwise filter
        if (RoleFilter.hasBothRoles(_userRoles)) {
          return true;
        }
        if (RoleFilter.isFarmer(_userRoles)) {
          return metric == 'Soil Moisture' ||
              metric == 'EC' ||
              metric == 'Temperature' ||
              metric == 'Humidity';
        }
        if (RoleFilter.isFlorist(_userRoles)) {
          return metric == 'Temperature' || metric == 'Humidity';
        }
        return false;
    }
  }

  Widget _buildTrendCard({
    required String title,
    required String unit,
    required Color color,
    required ColorScheme scheme,
    required List<_ChartDataPoint> dataPoints,
  }) {
    if (dataPoints.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No data available for selected time range',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  format: 'point.y $unit',
                ),
                primaryXAxis: DateTimeAxis(
                  dateFormat: DateFormat('MMM d'),
                  intervalType: DateTimeIntervalType.days,
                  majorGridLines: const MajorGridLines(
                    width: 0.5,
                    color: Color(0xFFE0E0E0),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                primaryYAxis: NumericAxis(
                  labelFormat: '{value} $unit',
                  majorGridLines: const MajorGridLines(
                    width: 0.5,
                    color: Color(0xFFE0E0E0),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                series: <CartesianSeries<_ChartDataPoint, DateTime>>[
                  LineSeries<_ChartDataPoint, DateTime>(
                    dataSource: dataPoints,
                    xValueMapper: (_ChartDataPoint point, _) => point.time,
                    yValueMapper: (_ChartDataPoint point, _) => point.value,
                    color: color,
                    width: 2.5,
                    markerSettings: MarkerSettings(
                      isVisible: dataPoints.length <= 20,
                      color: color,
                      borderColor: scheme.surface,
                      borderWidth: 2,
                      height: 6,
                      width: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartInsights(ColorScheme scheme) {
    final List<_SmartInsight> insights = _getSmartInsights();

    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Smart Insights',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ...insights.map(
            (_SmartInsight insight) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSmartInsightCard(insight, scheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartInsightCard(_SmartInsight insight, ColorScheme scheme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: insight.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(insight.icon, color: insight.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                insight.message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_KeyInsight> _getKeyInsights() {
    final List<_KeyInsight> insights = <_KeyInsight>[];

    // EC Trend from INM (Farmer only)
    final inmReadings = _getFilteredInmReadings();
    if (inmReadings.length >= 2) {
      final recent = inmReadings.take(5).toList();
      final oldest = recent.last.ec;
      final newest = recent.first.ec;
      final diff = newest - oldest;

      String status = 'Normal';
      Color color = Colors.green;
      String message = 'EC stable';

      if (diff.abs() > 0.3) {
        if (diff > 0) {
          status = 'Watch';
          color = Colors.orange;
          message = 'EC rising steadily';
        } else {
          status = 'Watch';
          color = Colors.orange;
          message = 'EC decreasing';
        }
      }

      insights.add(
        _KeyInsight(
          icon: Icons.water_drop,
          title: 'Soil EC Trend',
          message: message,
          status: status,
          color: color,
        ),
      );
    }

    // Moisture Level from INM
    if (inmReadings.isNotEmpty) {
      final latest = inmReadings.first;
      final moisture = latest.soilMoisture;

      String status = 'Normal';
      Color color = Colors.green;
      String message = 'Moisture stable';

      if (moisture < 30 || moisture > 70) {
        status = 'Action Recommended';
        color = Colors.red;
        message = moisture < 30 ? 'Moisture too low' : 'Moisture too high';
      } else if (moisture < 40 || moisture > 60) {
        status = 'Watch';
        color = Colors.orange;
        message = 'Moisture outside optimal range';
      }

      insights.add(
        _KeyInsight(
          icon: Icons.thermostat,
          title: 'Moisture Level',
          message: message,
          status: status,
          color: color,
        ),
      );
    }

    // Temperature from multiple sources (Farmer only)
    final sensorReadings = _getFilteredSensorReadings();
    if (sensorReadings.isNotEmpty) {
      final temps = sensorReadings.map((r) => r.temperature).toList();
      final avg = temps.reduce((a, b) => a + b) / temps.length;
      final min = temps.reduce((a, b) => a < b ? a : b);
      final max = temps.reduce((a, b) => a > b ? a : b);
      final range = max - min;

      String status = 'Normal';
      Color color = Colors.green;
      String message = 'Temperature stable';

      if (range > 5) {
        status = 'Watch';
        color = Colors.orange;
        message = 'Temperature fluctuating';
      }
      if (avg < 18 || avg > 28) {
        status = 'Action Recommended';
        color = Colors.red;
        message = 'Temperature outside optimal range';
      }

      insights.add(
        _KeyInsight(
          icon: Icons.wb_sunny,
          title: 'Temperature',
          message: message,
          status: status,
          color: color,
        ),
      );
    }

    return insights;
  }

  List<_SmartInsight> _getSmartInsights() {
    final List<_SmartInsight> insights = <_SmartInsight>[];

    // Freshness prediction insight (Florist only)
    if (_latestPrediction != null &&
        (RoleFilter.isFlorist(_userRoles) ||
            RoleFilter.hasBothRoles(_userRoles))) {
      final score = _latestPrediction!.freshnessScore;
      if (score >= 70) {
        insights.add(
          _SmartInsight(
            icon: Icons.local_florist,
            message: 'Flower freshness is excellent',
            color: Colors.green,
          ),
        );
      } else if (score >= 40) {
        insights.add(
          _SmartInsight(
            icon: Icons.local_florist,
            message: 'Flower freshness is good, monitor closely',
            color: Colors.orange,
          ),
        );
      }
    }

    // EC trend insight (Farmer only)
    final inmReadings = _getFilteredInmReadings();
    if (inmReadings.length >= 2) {
      final recent = inmReadings.take(3).toList();
      final avg =
          recent.map((r) => r.ec).reduce((a, b) => a + b) / recent.length;
      if (avg >= 1.5 && avg <= 2.5) {
        insights.add(
          _SmartInsight(
            icon: Icons.eco,
            message: 'Nutrient levels are within optimal range',
            color: Colors.green,
          ),
        );
      }
    }

    // Disease risk (based on environment) (Farmer only)
    final sensorReadings = _getFilteredSensorReadings();
    if (sensorReadings.isNotEmpty) {
      final avgHumidity =
          sensorReadings.map((r) => r.humidity).reduce((a, b) => a + b) /
          sensorReadings.length;
      if (avgHumidity >= 50 && avgHumidity <= 75) {
        insights.add(
          _SmartInsight(
            icon: Icons.shield,
            message: 'Disease risk remains low',
            color: Colors.green,
          ),
        );
      }
    }

    // Irrigation insight (Farmer only)
    if (inmReadings.isNotEmpty) {
      final latest = inmReadings.first;
      if (latest.soilMoisture >= 40 && latest.soilMoisture <= 60) {
        insights.add(
          _SmartInsight(
            icon: Icons.water_drop_outlined,
            message: 'Irrigation timing optimized',
            color: Colors.blue,
          ),
        );
      }
    }

    return insights;
  }

  List<_ChartDataPoint> _getSoilMoistureData() {
    final readings = _getFilteredInmReadings();
    return readings
        .where((r) => r.timestamp != null)
        .map((r) => _ChartDataPoint(r.timestamp!, r.soilMoisture))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  List<_ChartDataPoint> _getTemperatureData() {
    final List<_ChartDataPoint> points = <_ChartDataPoint>[];

    // From INM readings
    final inmReadings = _getFilteredInmReadings();
    points.addAll(
      inmReadings
          .where((r) => r.timestamp != null)
          .map((r) => _ChartDataPoint(r.timestamp!, r.airTemp)),
    );

    // From sensor readings
    final sensorReadings = _getFilteredSensorReadings();
    points.addAll(
      sensorReadings.map((r) => _ChartDataPoint(r.timestamp, r.temperature)),
    );

    // From freshness readings
    final freshnessReadings = _getFilteredFreshnessReadings();
    points.addAll(
      freshnessReadings.map((r) => _ChartDataPoint(r.timestamp, r.temperature)),
    );

    points.sort((a, b) => a.time.compareTo(b.time));
    return points;
  }

  List<_ChartDataPoint> _getECData() {
    final readings = _getFilteredInmReadings();
    return readings
        .where((r) => r.timestamp != null)
        .map((r) => _ChartDataPoint(r.timestamp!, r.ec))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  List<_ChartDataPoint> _getHumidityData() {
    final List<_ChartDataPoint> points = <_ChartDataPoint>[];

    // From INM readings
    final inmReadings = _getFilteredInmReadings();
    points.addAll(
      inmReadings
          .where((r) => r.timestamp != null)
          .map((r) => _ChartDataPoint(r.timestamp!, r.airHum)),
    );

    // From sensor readings
    final sensorReadings = _getFilteredSensorReadings();
    points.addAll(
      sensorReadings.map((r) => _ChartDataPoint(r.timestamp, r.humidity)),
    );

    // From freshness readings
    final freshnessReadings = _getFilteredFreshnessReadings();
    points.addAll(
      freshnessReadings.map((r) => _ChartDataPoint(r.timestamp, r.humidity)),
    );

    points.sort((a, b) => a.time.compareTo(b.time));
    return points;
  }

  void _showInfoTooltip(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About Insights'),
          content: const Text(
            'Insights provides analytics and trends across all SmartRose components. '
            'Use filters to view specific components and time ranges. '
            'Key insights highlight important changes, while trend charts show historical data patterns.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }
}

class _KeyInsight {
  const _KeyInsight({
    required this.icon,
    required this.title,
    required this.message,
    required this.status,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final String status;
  final Color color;
}

class _SmartInsight {
  const _SmartInsight({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;
}

class _ChartDataPoint {
  const _ChartDataPoint(this.time, this.value);

  final DateTime time;
  final double value;
}
