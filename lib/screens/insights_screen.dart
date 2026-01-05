import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
      appBar: AppBar(
        title: const Text('Insights'),
        centerTitle: false,
        titleTextStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoTooltip(context),
            tooltip: 'Summarized trends across all SmartRose components',
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Text(
                            'Greenhouse trends & analysis',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        _buildFilterBar(scheme),
                        const SizedBox(height: 16),
                        _buildKeyInsights(scheme),
                        const SizedBox(height: 24),
                        _buildSystemHealthOverview(scheme),
                        const SizedBox(height: 24),
                        _buildSmartInsights(scheme),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
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

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: availableComponents.length,
            itemBuilder: (context, index) {
              final component = availableComponents[index];
              final isSelected = _selectedComponent == component;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(component),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedComponent = component;
                      });
                    }
                  },
                  backgroundColor: scheme.surface,
                  selectedColor: scheme.primary.withOpacity(0.2),
                  checkmarkColor: scheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? scheme.primary : scheme.outline.withOpacity(0.3),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _timeRanges.length,
            itemBuilder: (context, index) {
              final range = _timeRanges[index];
              final isSelected = _selectedTimeRange == range;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(range),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedTimeRange = range;
                      });
                    }
                  },
                  backgroundColor: scheme.surface,
                  selectedColor: scheme.primary.withOpacity(0.2),
                  checkmarkColor: scheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? scheme.primary : scheme.outline.withOpacity(0.3),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKeyInsights(ColorScheme scheme) {
    final List<_KeyInsight> insights = _getKeyInsights();

    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 110,
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
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outline.withOpacity(0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: Container(color: insight.color),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Row(
                  children: [
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            insight.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            insight.message,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.2,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemHealthOverview(ColorScheme scheme) {
    final isFarmer = RoleFilter.isFarmer(_userRoles) || RoleFilter.hasBothRoles(_userRoles);
    final isFlorist = RoleFilter.isFlorist(_userRoles) || RoleFilter.hasBothRoles(_userRoles);

    final List<Widget> gauges = [];

    if (isFarmer) {
      gauges.add(_buildHealthGaugeCard(
        title: 'Soil Nutrition Health',
        status: 'Improving',
        value: 0.8,
        color: Colors.green,
        scheme: scheme,
      ));
      gauges.add(_buildHealthGaugeCard(
        title: 'Water Management Efficiency',
        status: 'Stable',
        value: 0.7,
        color: scheme.primary,
        scheme: scheme,
      ));
      gauges.add(_buildHealthGaugeCard(
        title: 'Greenhouse Climate Stability',
        status: 'Fluctuating',
        value: 0.4,
        color: Colors.orange,
        scheme: scheme,
      ));
    }

    if (isFlorist) {
      gauges.add(_buildHealthGaugeCard(
        title: 'Overall Freshness',
        status: 'Excellent',
        value: 0.9,
        color: Colors.green,
        scheme: scheme,
      ));
    }

    if (RoleFilter.hasBothRoles(_userRoles)) {
      gauges.add(_buildHealthGaugeCard(
        title: 'Overall System Health',
        status: 'Good',
        value: 0.9,
        color: Colors.green,
        scheme: scheme,
      ));
    }

    if (gauges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Health Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.75, // Increased height relative to width
            children: gauges,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthGaugeCard({
    required String title,
    required String status,
    required double value,
    required Color color,
    required ColorScheme scheme,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outline.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              width: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 8,
                    color: color,
                    backgroundColor: color.withOpacity(0.1),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Icon(
                      value > 0.7 ? Icons.check_circle_outline : (value > 0.4 ? Icons.info_outline : Icons.warning_amber_rounded),
                      color: color,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
            (insight) => Padding(
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
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline.withOpacity(0.1)),
      ),
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
                      fontSize: 15,
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
    final isFarmer = RoleFilter.isFarmer(_userRoles) || RoleFilter.hasBothRoles(_userRoles);
    final isFlorist = RoleFilter.isFlorist(_userRoles) || RoleFilter.hasBothRoles(_userRoles);

    if (isFarmer) {
      final inmReadings = _getFilteredInmReadings();
      if (inmReadings.isNotEmpty) {
        insights.add(
          const _KeyInsight(
            icon: Icons.eco_outlined,
            title: 'Soil Nutrition',
            message: 'Nutrient balance improving',
            status: 'Normal',
            color: Colors.green,
          ),
        );
        insights.add(
          const _KeyInsight(
            icon: Icons.water_drop_outlined,
            title: 'Water Management',
            message: 'Moisture levels stable',
            status: 'Normal',
            color: Colors.green,
          ),
        );
      }

      final sensorReadings = _getFilteredSensorReadings();
      if (sensorReadings.isNotEmpty) {
        insights.add(
          const _KeyInsight(
            icon: Icons.thermostat_outlined,
            title: 'Greenhouse Climate',
            message: 'Temperature fluctuating',
            status: 'Watch',
            color: Colors.orange,
          ),
        );
      }
    }

    if (isFlorist) {
      final freshnessReadings = _getFilteredFreshnessReadings();
      if (freshnessReadings.isNotEmpty) {
        insights.add(
          const _KeyInsight(
            icon: Icons.local_florist_outlined,
            title: 'Flower Freshness',
            message: 'Flower freshness is optimal',
            status: 'Normal',
            color: Colors.green,
          ),
        );
      }
    }

    return insights;
  }

  List<_SmartInsight> _getSmartInsights() {
    final List<_SmartInsight> insights = <_SmartInsight>[];
    final isFarmer = RoleFilter.isFarmer(_userRoles) || RoleFilter.hasBothRoles(_userRoles);
    final isFlorist = RoleFilter.isFlorist(_userRoles) || RoleFilter.hasBothRoles(_userRoles);

    if (isFarmer) {
      insights.add(
        const _SmartInsight(
          icon: Icons.trending_up,
          message: 'Fertilizer efficiency improved this week',
          color: Colors.green,
        ),
      );

      insights.add(
        const _SmartInsight(
          icon: Icons.schedule,
          message: 'Irrigation timing remains optimal',
          color: Colors.green,
        ),
      );

      insights.add(
        const _SmartInsight(
          icon: Icons.shield_outlined,
          message: 'Disease risk remains low',
          color: Colors.green,
        ),
      );
    }

    if (isFlorist) {
      insights.add(
        const _SmartInsight(
          icon: Icons.auto_awesome,
          message: 'Storage conditions are perfect for vase life',
          color: Colors.blue,
        ),
      );
    }

    return insights;
  }

  void _showInfoTooltip(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About Insights'),
          content: const Text(
            'Summarized trends across all SmartRose components. Insights provide a high-level overview of greenhouse health and performance patterns without operational technicalities.',
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
