import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../shared/widgets/dashboard_card.dart';
import '../shared/services/freshness_api_service.dart';
import '../shared/models/prediction_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final FreshnessApiService _freshnessApiService = FreshnessApiService();

  // TODO: make device ID configurable from app-wide settings if needed.
  String _currentDeviceId = 'device_001';

  PredictionModel? _prediction;
  bool _isFreshnessLoading = false;
  String? _freshnessError;

  Timer? _autoRefreshTimer;
  bool _isScreenVisible = true;

  // Auto-refresh interval (30 seconds)
  static const Duration _refreshInterval = Duration(seconds: 30);

  static final List<_DashboardEntry> _entries = <_DashboardEntry>[
    _DashboardEntry(
      title: 'INM Sensors',
      subtitle:
          'View real-time sensor readings for temperature, humidity & soil.',
      icon: Icons.sensors,
      route: AppRoutes.inmSensors,
    ),
    _DashboardEntry(
      title: 'Freshness Monitoring',
      subtitle: 'Track bloom quality with live freshness insights.',
      icon: Icons.local_florist,
      route: AppRoutes.freshness,
    ),
    _DashboardEntry(
      title: 'Stress Monitoring',
      subtitle: 'Detect environmental stressors early.',
      icon: Icons.monitor_heart,
      route: AppRoutes.stress,
    ),
    _DashboardEntry(
      title: 'Disease Detection',
      subtitle: 'Identify disease risks with ML-assisted insights.',
      icon: Icons.bug_report,
      route: AppRoutes.disease,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFreshnessSummary();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoRefresh();
    _freshnessApiService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Pause updates when app is in background, resume when in foreground
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isScreenVisible = false;
      _stopAutoRefresh();
    } else if (state == AppLifecycleState.resumed) {
      _isScreenVisible = true;
      _loadFreshnessSummary(forceRefresh: true);
      _startAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _stopAutoRefresh(); // Cancel any existing timer
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (_isScreenVisible && mounted && !_isFreshnessLoading) {
        _loadFreshnessSummary(forceRefresh: true, silent: true);
      }
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _loadFreshnessSummary({
    bool forceRefresh = true,
    bool silent = false,
  }) async {
    if (!silent) {
      setState(() {
        _isFreshnessLoading = true;
        _freshnessError = null;
      });
    }

    try {
      final Map<String, dynamic> data = await _freshnessApiService
          .getLatestWithPrediction(
            _currentDeviceId,
            forceRefresh: forceRefresh,
          );

      final PredictionModel prediction = PredictionModel.fromJson(
        data['prediction'] as Map<String, dynamic>,
      );

      // Only update state if data actually changed (for silent updates)
      final bool hasChanged = silent
          ? (_prediction?.freshnessScore != prediction.freshnessScore ||
                _prediction?.vaseLifeHours != prediction.vaseLifeHours)
          : true;

      if (hasChanged) {
        setState(() {
          _prediction = prediction;
          if (!silent) {
            _isFreshnessLoading = false;
          }
        });
      } else if (!silent) {
        setState(() {
          _isFreshnessLoading = false;
        });
      }
    } catch (e) {
      // Only show errors for non-silent updates
      if (!silent) {
        setState(() {
          _freshnessError = 'Failed to load freshness summary';
          _isFreshnessLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 700;
        final bool isUltraWide = constraints.maxWidth >= 1100;
        final int crossAxisCount = isUltraWide
            ? 3
            : isWide
            ? 2
            : 1;

        final ColorScheme scheme = Theme.of(context).colorScheme;

        return RefreshIndicator(
          onRefresh: () => _loadFreshnessSummary(forceRefresh: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth < 400 ? 12 : 16,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildFreshnessSummaryCard(scheme),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    // Adjust aspect ratio for smaller screens
                    final double aspectRatio = constraints.maxWidth < 400
                        ? 0.9
                        : isWide
                            ? 1.4
                            : 1.1;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: aspectRatio,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: _entries
                          .map(
                            (_DashboardEntry entry) => DashboardCard(
                              title: entry.title,
                              subtitle: entry.subtitle,
                              icon: entry.icon,
                              onTap: () =>
                                  Navigator.of(context).pushNamed(entry.route),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFreshnessSummaryCard(ColorScheme scheme) {
    if (_isFreshnessLoading) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Loading freshness summary...',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_freshnessError != null) {
      return Card(
        elevation: 2,
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Freshness summary unavailable',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _freshnessError!,
                      style: TextStyle(color: scheme.onErrorContainer),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () =>
                          _loadFreshnessSummary(forceRefresh: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onErrorContainer,
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

    if (_prediction == null) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.local_florist, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Freshness Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'No freshness data available yet for $_currentDeviceId.',
                style: TextStyle(color: scheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    final double score = _prediction!.freshnessScore;
    final double vaseLifeHours = _prediction!.vaseLifeHours;
    final _StatusInfo status = _getStatusInfo(score, scheme);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.local_florist, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Freshness Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status.backgroundColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: status.textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _buildMetricTile(
                    scheme: scheme,
                    label: 'Freshness Score',
                    value: '${score.toStringAsFixed(1)}%',
                    icon: Icons.insights,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricTile(
                    scheme: scheme,
                    label: 'Vase Life',
                    value: '${vaseLifeHours.toStringAsFixed(1)} h',
                    icon: Icons.access_time,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Freshness Monitoring" below for detailed insights.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required ColorScheme scheme,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo(double score, ColorScheme scheme) {
    if (score >= 70) {
      return _StatusInfo(
        label: 'Fresh',
        backgroundColor: Colors.green.withOpacity(0.1),
        textColor: Colors.green.shade800,
      );
    } else if (score >= 40) {
      return _StatusInfo(
        label: 'Moderate',
        backgroundColor: Colors.orange.withOpacity(0.1),
        textColor: Colors.orange.shade800,
      );
    } else {
      return _StatusInfo(
        label: 'Poor',
        backgroundColor: Colors.red.withOpacity(0.1),
        textColor: Colors.red.shade800,
      );
    }
  }
}

class _StatusInfo {
  const _StatusInfo({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
}

class _DashboardEntry {
  const _DashboardEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}
