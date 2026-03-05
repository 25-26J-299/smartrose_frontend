// File: lib/features/inm/screens/tabs/inm_recommendations_tab.dart
// Purpose: Recommendations tab - mobile-first decision and action focused page (2026 design)

import 'package:flutter/material.dart';

import '../../widgets/growth_stage_selector.dart';
import '../../services/inm_api_service.dart';
import '../../models/inm_status.dart';
import '../../../../shared/services/weather_api_service.dart';

class InmRecommendationsTab extends StatefulWidget {
  /// [deviceId] and [token] scope all API calls to the selected INM device.
  const InmRecommendationsTab({
    super.key,
    required this.deviceId,
    required this.token,
    this.onActionTaken,
  });

  final String deviceId;
  final String token;
  final VoidCallback? onActionTaken;

  @override
  State<InmRecommendationsTab> createState() => _InmRecommendationsTabState();
}

class _InmRecommendationsTabState extends State<InmRecommendationsTab>
    with AutomaticKeepAliveClientMixin {
  final InmApiService _apiService = InmApiService();
  final WeatherApiService _weatherService = WeatherApiService();
  late Future<List<dynamic>> _combinedFuture;
  bool _isActionTaken = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _weatherService.dispose();
    super.dispose();
  }

  void _loadData() {
    _combinedFuture = Future.wait([
      _apiService.fetchStatus(widget.deviceId, widget.token),
      _apiService.fetchGrowthStage(widget.deviceId, widget.token),
      // Weather fetch never throws – returns null on failure so INM still loads
      _weatherService.fetchCurrentWeather().catchError((_) => null),
    ]);
  }

  @override
  bool get wantKeepAlive => true;

  void _refresh() {
    setState(() {
      _loadData();
      _isActionTaken = false;
    });
  }

  Future<void> _confirmAction(String type) async {
    final isApply = type == 'applied';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isApply ? Icons.check_circle_outline : Icons.schedule_rounded,
              color: isApply ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 10),
            Text(isApply ? 'Did you apply it?' : 'Skip for now?'),
          ],
        ),
        content: Text(
          isApply
              ? 'Confirm that you applied the fertilizer today.\nThis will be saved to your activity history.'
              : 'That\'s okay! You can apply it later.\nThe recommendation will stay in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: isApply ? Colors.green : Colors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isApply ? 'Yes, I Applied It' : 'Yes, Skip'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (type == 'applied') {
        _markAsApplied();
      } else {
        _skipRecommendations();
      }
    }
  }

  Future<void> _markAsApplied() async {
    final results = await _combinedFuture;
    final status = results[0] as InmStatus;
    final weather = results.length > 2 ? results[2] as WeatherModel? : null;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await _apiService.saveAction(
          widget.deviceId, widget.token, status, 'applied',
          weather: weather);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isActionTaken = success;
        });

        if (success) {
          widget.onActionTaken?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '✓ Action recorded and synced',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _skipRecommendations() async {
    final results = await _combinedFuture;
    final status = results[0] as InmStatus;
    final weather = results.length > 2 ? results[2] as WeatherModel? : null;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await _apiService.saveAction(
          widget.deviceId, widget.token, status, 'ignored',
          weather: weather);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isActionTaken = success;
        });

        if (success) {
          widget.onActionTaken?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Recommendation skipped',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return FutureBuilder<List<dynamic>>(
      future: _combinedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(theme, snapshot.error.toString());
        }

        if (!snapshot.hasData) {
          return _buildErrorState(theme, 'No data available');
        }

        final results = snapshot.data!;
        final status = results[0] as InmStatus;
        final growthStage = results[1] as String;
        final weather = results.length > 2 ? results[2] as WeatherModel? : null;

        return _buildContent(theme, status, growthStage, weather);
      },
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load recommendations',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    InmStatus status,
    String currentGrowthStage,
    WeatherModel? weather,
  ) {
    // Only show actionable recommendations when the device has real sensor data
    final hasRecommendations = status.hasSensorData &&
        (status.ecAction.isNotEmpty ||
            status.phAction.isNotEmpty ||
            status.npkRecommendation.isNotEmpty);

    // Use currentGrowthStage if status.growthStage is null
    final displayGrowthStage = status.growthStage ?? currentGrowthStage;

    // Determine weather advisory level to gate the apply button
    final advisoryLevel = _WeatherAdvisoryBanner.computeLevel(weather);
    final isPostponeAdvisory = advisoryLevel == WeatherAdvisoryLevel.postpone;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Growth Stage Section
                GrowthStageSelector(
                  deviceId: widget.deviceId,
                  token: widget.token,
                ),

                const SizedBox(height: 16),

                // Weather Advisory Banner
                _WeatherAdvisoryBanner(weather: weather),

                const SizedBox(height: 16),

                // Recommendations
                if (hasRecommendations) ...[
                  // Priority: EC Action
                  if (status.ecAction.isNotEmpty) ...[
                    _CompactRecommendationCard(
                      title: 'EC Level',
                      recommendation: status.ecAction,
                      icon: Icons.electric_bolt,
                      color: Colors.purple,
                      statusType: status.statusType,
                      growthStage: displayGrowthStage,
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // pH Action
                  if (status.phAction.isNotEmpty) ...[
                    _CompactRecommendationCard(
                      title: 'pH Balance',
                      recommendation: status.phAction,
                      icon: Icons.opacity,
                      color: Colors.teal,
                      statusType: EcStatusType.optimal, // pH usually not critical
                      growthStage: displayGrowthStage,
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // NPK Recommendation - Split into N, P, K rows
                  if (status.npkRecommendation.isNotEmpty) ...[
                    _NpkRecommendationCard(
                      recommendation: status.npkRecommendation,
                      growthStage: displayGrowthStage,
                    ),
                  ],
                ] else ...[
                  // No sensor data vs. genuinely all good
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: status.hasSensorData
                          ? Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_circle,
                                    size: 64,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'All Good!',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No actions needed at the moment.\nYour plants are thriving!',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.sensors_off,
                                    size: 64,
                                    color: Colors.orange.shade600,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No Sensor Data',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Waiting for data from the device.\nPlease ensure the device is connected and sending readings.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 80), // Space for bottom buttons
              ],
            ),
          ),
        ),
        
        // Action Buttons (fixed at bottom)
        if (hasRecommendations && !_isActionTaken)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPostponeAdvisory) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.umbrella_rounded,
                              size: 16, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'It\'s raining – wait for dry weather before applying fertilizer.',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => _confirmAction('ignored'),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.schedule_rounded, size: 18),
                          label: const Text('Do Later'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: (_isSubmitting || isPostponeAdvisory)
                              ? null
                              : () => _confirmAction('applied'),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_rounded,
                                  size: 20),
                          label: const Text('I Applied It'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        
        // Action taken state
        if (_isActionTaken)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(
                top: BorderSide(color: Colors.green.shade200, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.green.shade600, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Great job! Response saved.',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your action has been added to the activity history.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Get New Recommendations'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade700,
                        side: BorderSide(color: Colors.green.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Weather Advisory
// ---------------------------------------------------------------------------

enum WeatherAdvisoryLevel { good, caution, postpone }

/// Evaluates live weather data and shows a colour-coded fertilizer advisory.
///
/// Decision table:
///   • Rain / Drizzle / Thunder, or precipitation > 2 mm  → postpone
///     (Rain washes nutrients out of the root zone and can cause post-rain
///      salinity spikes once the soil dries.)
///   • Humidity > 85 % OR temperature > 33 °C             → caution
///     (High evaporation concentrates EC; risk of salinity build-up.)
///   • Otherwise                                           → good
class _WeatherAdvisoryBanner extends StatelessWidget {
  const _WeatherAdvisoryBanner({this.weather});

  final WeatherModel? weather;

  static WeatherAdvisoryLevel computeLevel(WeatherModel? w) {
    if (w == null) return WeatherAdvisoryLevel.good;

    final condition = w.condition.toLowerCase();
    final isRaining = condition.contains('rain') ||
        condition.contains('drizzle') ||
        condition.contains('thunder') ||
        w.precipitation > 2.0;

    if (isRaining) return WeatherAdvisoryLevel.postpone;

    if (w.humidity > 85 || w.temperature > 33) {
      return WeatherAdvisoryLevel.caution;
    }

    return WeatherAdvisoryLevel.good;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // No weather data – show a subtle neutral tile
    if (weather == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 18, color: theme.colorScheme.onSurface.withOpacity(0.4)),
            const SizedBox(width: 10),
            Text(
              'Weather data unavailable – check connectivity',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    final level = computeLevel(weather);

    final Color bgColor;
    final Color borderColor;
    final Color iconColor;
    final IconData iconData;
    final String title;
    final String subtitle;

    switch (level) {
      case WeatherAdvisoryLevel.postpone:
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade200;
        iconColor = Colors.red.shade700;
        iconData = Icons.umbrella_rounded;
        title = 'Don\'t apply today — rain detected';
        subtitle = _buildPostponeReason();
        break;
      case WeatherAdvisoryLevel.caution:
        bgColor = Colors.amber.shade50;
        borderColor = Colors.amber.shade200;
        iconColor = Colors.amber.shade800;
        iconData = Icons.thermostat_rounded;
        title = 'Be careful — hot or humid conditions';
        subtitle = _buildCautionReason();
        break;
      case WeatherAdvisoryLevel.good:
        bgColor = Colors.green.shade50;
        borderColor = Colors.green.shade200;
        iconColor = Colors.green.shade700;
        iconData = Icons.wb_sunny_rounded;
        title = 'Good time to apply fertilizer today';
        subtitle = _buildGoodReason();
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconData, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: iconColor.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 8),
          // Live weather stats row
          Row(
            children: [
              _WeatherStat(
                icon: Icons.thermostat_rounded,
                label: '${weather!.temperature.toStringAsFixed(1)}°C',
                color: iconColor,
              ),
              const SizedBox(width: 16),
              _WeatherStat(
                icon: Icons.water_drop_outlined,
                label: '${weather!.humidity.toStringAsFixed(0)}% RH',
                color: iconColor,
              ),
              const SizedBox(width: 16),
              _WeatherStat(
                icon: Icons.grain_rounded,
                label: '${weather!.precipitation.toStringAsFixed(1)} mm',
                color: iconColor,
              ),
              if (weather!.locationName != null) ...[
                const Spacer(),
                Icon(Icons.location_on_outlined,
                    size: 12, color: iconColor.withOpacity(0.6)),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    weather!.locationName!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: iconColor.withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _buildPostponeReason() {
    final condition = weather!.condition;
    final precip = weather!.precipitation;
    if (precip > 2.0) {
      return 'There is ${precip.toStringAsFixed(1)} mm of rain right now. '
          'Fertilizer applied during rain gets washed away — wait until it dries.';
    }
    return '$condition conditions detected. '
        'Applying fertilizer now will waste it. Wait for dry weather first.';
  }

  String _buildCautionReason() {
    final parts = <String>[];
    if (weather!.humidity > 85) {
      parts.add(
          'humidity is high (${weather!.humidity.toStringAsFixed(0)}%) — nutrients may not absorb well');
    }
    if (weather!.temperature > 33) {
      parts.add(
          'temperature is hot (${weather!.temperature.toStringAsFixed(1)}°C) — apply smaller amounts and check EC after');
    }
    return parts.isNotEmpty
        ? parts.join(' and ') +
            '. Try applying in the early morning or late evening.'
        : 'Conditions are borderline. Apply smaller doses and check your plants after.';
  }

  String _buildGoodReason() {
    return 'Weather is clear — ${weather!.temperature.toStringAsFixed(1)}°C, '
        '${weather!.humidity.toStringAsFixed(0)}% humidity, '
        '${weather!.precipitation.toStringAsFixed(1)} mm rain. '
        'Safe to apply the full recommended dose.';
  }
}

class _WeatherStat extends StatelessWidget {
  const _WeatherStat({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color.withOpacity(0.8)),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Compact recommendation card for EC/pH
// ---------------------------------------------------------------------------

class _CompactRecommendationCard extends StatefulWidget {
  final String title;
  final String recommendation;
  final IconData icon;
  final Color color;
  final EcStatusType statusType;
  final String? growthStage;

  const _CompactRecommendationCard({
    required this.title,
    required this.recommendation,
    required this.icon,
    required this.color,
    required this.statusType,
    this.growthStage,
  });

  @override
  State<_CompactRecommendationCard> createState() =>
      _CompactRecommendationCardState();
}

class _CompactRecommendationCardState
    extends State<_CompactRecommendationCard> {
  bool _isExpanded = false;

  // Derive a short plain-language action hint from the recommendation text.
  // Returns a label + icon pair a farmer immediately understands.
  ({String label, IconData icon, Color color}) _getActionHint(
      String rec, Color baseColor) {
    final lower = rec.toLowerCase();
    if (lower.contains('increase') ||
        lower.contains('add more') ||
        lower.contains('top up') ||
        lower.contains('apply more')) {
      return (
        label: 'Increase',
        icon: Icons.arrow_upward_rounded,
        color: Colors.orange.shade700,
      );
    }
    if (lower.contains('decrease') ||
        lower.contains('reduce') ||
        lower.contains('dilute') ||
        lower.contains('flush') ||
        lower.contains('lower')) {
      return (
        label: 'Decrease',
        icon: Icons.arrow_downward_rounded,
        color: Colors.blue.shade700,
      );
    }
    if (lower.contains('adjust') ||
        lower.contains('correct') ||
        lower.contains('balance')) {
      return (
        label: 'Adjust',
        icon: Icons.tune_rounded,
        color: Colors.amber.shade800,
      );
    }
    if (lower.contains('maintain') ||
        lower.contains('no action') ||
        lower.contains('continue') ||
        lower.contains('stable')) {
      return (
        label: 'Maintain',
        icon: Icons.check_circle_outline_rounded,
        color: Colors.green.shade700,
      );
    }
    if (lower.contains('monitor') || lower.contains('watch')) {
      return (
        label: 'Monitor',
        icon: Icons.visibility_outlined,
        color: Colors.teal.shade700,
      );
    }
    // Fallback: use baseColor with generic action
    return (
      label: 'Action needed',
      icon: Icons.notification_important_outlined,
      color: baseColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCritical = widget.statusType == EcStatusType.criticalLow ||
        widget.statusType == EcStatusType.criticalHigh;
    final isWarning = widget.statusType == EcStatusType.low ||
        widget.statusType == EcStatusType.high;

    final rec = widget.recommendation;
    final sentences = rec.split('. ');
    // Show first 2 sentences upfront; rest goes into expandable section
    final mainText = sentences.take(2).join('. ') +
        (sentences.length >= 2 ? '.' : '');
    final detailText = sentences.length > 2
        ? sentences.sublist(2).join('. ').trim()
        : '';

    final actionHint = _getActionHint(rec, widget.color);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCritical
              ? widget.color.withOpacity(0.4)
              : widget.color.withOpacity(0.2),
          width: isCritical ? 2 : 1,
        ),
        boxShadow: isCritical
            ? [
                BoxShadow(
                  color: widget.color.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isCritical)
                            _StatusChip(
                              label: 'Act Now',
                              color: Colors.red.shade600,
                            )
                          else if (isWarning)
                            _StatusChip(
                              label: 'Check Today',
                              color: Colors.orange.shade600,
                            )
                          else
                            _StatusChip(
                              label: 'Info',
                              color: Colors.blue.shade600,
                            ),
                        ],
                      ),
                      if (widget.growthStage != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${widget.growthStage![0].toUpperCase()}${widget.growthStage!.substring(1).toLowerCase()} growth stage',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Action hint banner ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: actionHint.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: actionHint.color.withOpacity(0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(actionHint.icon,
                      size: 15, color: actionHint.color),
                  const SizedBox(width: 6),
                  Text(
                    actionHint.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: actionHint.color,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Main recommendation text ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mainText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.87),
                    height: 1.45,
                  ),
                ),

                // Expandable full detail
                if (detailText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () =>
                        setState(() => _isExpanded = !_isExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _isExpanded ? 'Show less' : 'Full details',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isExpanded) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.color.withOpacity(0.15),
                        ),
                      ),
                      child: Text(
                        detailText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.72),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// NPK card with N, P, K rows
class _NpkRecommendationCard extends StatelessWidget {
  final String recommendation;
  final String? growthStage;

  const _NpkRecommendationCard({
    required this.recommendation,
    this.growthStage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final npkData = _parseNpkRecommendation(recommendation);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.eco, color: Colors.green, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nutrients (NPK)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (growthStage != null)
                          Text(
                            'For: ${growthStage![0].toUpperCase()}${growthStage!.substring(1).toLowerCase()} Stage',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                const Spacer(),
                _StatusChip(
                  label: 'Info',
                  color: Colors.blue.shade600,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // N, P, K rows — fallback to full text if individual parsing fails
          if (npkData['n'] != null || npkData['p'] != null || npkData['k'] != null) ...[
            if (npkData['n'] != null) _NutrientRow(
              nutrient: 'Nitrogen (N)',
              recommendation: npkData['n']!,
              color: Colors.green,
            ),
            if (npkData['p'] != null) _NutrientRow(
              nutrient: 'Phosphorus (P)',
              recommendation: npkData['p']!,
              color: Colors.amber,
            ),
            if (npkData['k'] != null) _NutrientRow(
              nutrient: 'Potassium (K)',
              recommendation: npkData['k']!,
              color: Colors.pink,
            ),
          ] else ...[
            // Fallback: show full NPK text when keyword parsing finds nothing
            Padding(
              padding: const EdgeInsets.all(14),
              child: Builder(builder: (context) {
                final theme = Theme.of(context);
                return Text(
                  recommendation,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.82),
                    height: 1.45,
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, String?> _parseNpkRecommendation(String rec) {
    final Map<String, String?> result = {'n': null, 'p': null, 'k': null};

    // Split by sentences
    final sentences = rec.split('. ');

    List<String> nSentences = [];
    List<String> pSentences = [];
    List<String> kSentences = [];
    String? currentNutrient;

    for (var sentence in sentences) {
      final lower = sentence.toLowerCase();
      
      // Check which nutrient this sentence belongs to
      if (lower.contains('nitrogen') || (lower.contains(' n ') && currentNutrient == 'n')) {
        currentNutrient = 'n';
        nSentences.add(sentence.trim());
      } else if (lower.contains('phosphorus') || (lower.contains(' p ') && currentNutrient == 'p')) {
        currentNutrient = 'p';
        pSentences.add(sentence.trim());
      } else if (lower.contains('potassium') || (lower.contains(' k ') && currentNutrient == 'k')) {
        currentNutrient = 'k';
        kSentences.add(sentence.trim());
      } else if (currentNutrient != null && sentence.trim().isNotEmpty) {
        // Continue with the current nutrient context
        if (currentNutrient == 'n') {
          nSentences.add(sentence.trim());
        } else if (currentNutrient == 'p') {
          pSentences.add(sentence.trim());
        } else if (currentNutrient == 'k') {
          kSentences.add(sentence.trim());
        }
      }
    }

    // Join sentences for each nutrient
    if (nSentences.isNotEmpty) {
      result['n'] = nSentences.take(2).join('. ') + '.';
    }
    if (pSentences.isNotEmpty) {
      result['p'] = pSentences.take(2).join('. ') + '.';
    }
    if (kSentences.isNotEmpty) {
      result['k'] = kSentences.take(2).join('. ') + '.';
    }

    return result;
  }
}

class _NutrientRow extends StatelessWidget {
  final String nutrient;
  final String recommendation;
  final Color color;

  const _NutrientRow({
    required this.nutrient,
    required this.recommendation,
    required this.color,
  });

  ({String label, IconData icon}) _actionHint() {
    final lower = recommendation.toLowerCase();
    if (lower.contains('increase') ||
        lower.contains('add') ||
        lower.contains('apply more') ||
        lower.contains('top up')) {
      return (label: 'Increase', icon: Icons.arrow_upward_rounded);
    }
    if (lower.contains('decrease') ||
        lower.contains('reduce') ||
        lower.contains('cut back') ||
        lower.contains('lower')) {
      return (label: 'Decrease', icon: Icons.arrow_downward_rounded);
    }
    if (lower.contains('maintain') ||
        lower.contains('no change') ||
        lower.contains('optimal') ||
        lower.contains('stable')) {
      return (label: 'Maintain', icon: Icons.check_rounded);
    }
    if (lower.contains('monitor') || lower.contains('watch')) {
      return (label: 'Monitor', icon: Icons.visibility_outlined);
    }
    return (label: 'Review', icon: Icons.info_outline_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = _actionHint();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nutrient color dot
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nutrient name + action badge on same line
                Row(
                  children: [
                    Text(
                      nutrient,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(hint.icon, size: 11, color: color),
                          const SizedBox(width: 3),
                          Text(
                            hint.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  recommendation.isNotEmpty
                      ? recommendation
                      : 'No action available',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.78),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }
}
