import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_state.dart';
import '../features/inm/services/inm_api_service.dart';
import '../features/inm/models/inm_status.dart';
import '../features/inm/models/inm_sensor_reading.dart';
import '../shared/services/freshness_api_service.dart';
import '../shared/models/prediction_model.dart';
import '../shared/models/reading_model.dart';
import '../shared/services/sensor_service.dart';
import '../shared/models/sensor_data.dart';
import '../core/app_routes.dart';
import '../shared/utils/role_filter.dart';

enum NotificationType { critical, warning, info }

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  NotificationType? _selectedFilter;

  // Services
  final InmApiService _inmApiService = InmApiService();
  final FreshnessApiService _freshnessApiService = FreshnessApiService();
  final SensorService _sensorService = SensorService();

  // Data state
  bool _isLoading = false;
  String? _errorMessage;
  List<String> _userRoles = [];
  List<_NotificationItem> _allNotifications = [];

  List<String> _previousRoles = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AuthState authState = context.watch<AuthState>();
    final List<String> currentRoles = authState.roles;

    // Reload notifications if roles changed
    if (_previousRoles.toString() != currentRoles.toString()) {
      _previousRoles = List<String>.from(currentRoles);
      _userRoles = List<String>.from(currentRoles);
      _loadNotifications();
    }
  }

  @override
  void dispose() {
    _freshnessApiService.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<_NotificationItem> notifications = <_NotificationItem>[];

      // Fetch data from all sources
      List<InmSensorReading> inmReadings = [];
      InmStatus? inmStatus;
      PredictionModel? freshnessPrediction;
      ReadingModel? freshnessReading;
      List<SensorReading> sensorReadings = [];

      try {
        inmReadings = await _inmApiService.fetchAllReadings();
        if (inmReadings.isNotEmpty) {
          inmStatus = await _inmApiService.fetchStatus();
        }
      } catch (e) {
        // Ignore INM errors
      }

      try {
        final data = await _freshnessApiService.getLatestWithPrediction(
          'device_001',
          forceRefresh: true,
        );
        freshnessReading = ReadingModel.fromJson(
          data['reading'] as Map<String, dynamic>,
        );
        freshnessPrediction = PredictionModel.fromJson(
          data['prediction'] as Map<String, dynamic>,
        );
      } catch (e) {
        // Ignore freshness errors
      }

      try {
        sensorReadings = await _sensorService.fetchLatestReadings(limit: 20);
      } catch (e) {
        // Ignore sensor errors
      }

      // Generate notifications from Freshness alerts (Florist only)
      if (freshnessPrediction != null &&
          freshnessReading != null &&
          (RoleFilter.isFlorist(_userRoles) ||
              RoleFilter.hasBothRoles(_userRoles))) {
        // Freshness score notifications with different severity levels
        final double score = freshnessPrediction.freshnessScore;
        if (score < 40) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.critical,
              title: 'Critical Freshness Score',
              description:
                  'Flower freshness is ${score.toStringAsFixed(1)}%. Immediate attention required to prevent quality degradation.',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.warning,
              route: AppRoutes.freshness,
            ),
          );
        } else if (score >= 40 && score < 60) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.warning,
              title: 'Low Freshness Score',
              description:
                  'Flower freshness is ${score.toStringAsFixed(1)}%. Monitor closely and consider taking action.',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.local_florist,
              route: AppRoutes.freshness,
            ),
          );
        } else if (score >= 60 && score < 70) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.info,
              title: 'Moderate Freshness Score',
              description:
                  'Flower freshness is ${score.toStringAsFixed(1)}%. Conditions are acceptable but could be improved.',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.local_florist,
              route: AppRoutes.freshness,
            ),
          );
        }

        // Vase life notifications
        final double vaseLifeHours = freshnessPrediction.vaseLifeHours;
        if (vaseLifeHours < 24) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.critical,
              title: 'Short Vase Life Predicted',
              description:
                  'Predicted vase life is ${vaseLifeHours.toStringAsFixed(1)} hours. Immediate action needed to extend flower life.',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.access_time,
              route: AppRoutes.freshness,
            ),
          );
        } else if (vaseLifeHours >= 24 && vaseLifeHours < 48) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.warning,
              title: 'Limited Vase Life',
              description:
                  'Predicted vase life is ${vaseLifeHours.toStringAsFixed(1)} hours. Consider optimizing storage conditions.',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.access_time,
              route: AppRoutes.freshness,
            ),
          );
        }

        // Alerts from prediction model
        for (final String alert in freshnessPrediction.alerts) {
          // Determine alert type based on keywords
          NotificationType alertType = NotificationType.warning;
          if (alert.toLowerCase().contains('critical') ||
              alert.toLowerCase().contains('urgent') ||
              alert.toLowerCase().contains('immediate')) {
            alertType = NotificationType.critical;
          } else if (alert.toLowerCase().contains('info') ||
              alert.toLowerCase().contains('note')) {
            alertType = NotificationType.info;
          }

          notifications.add(
            _NotificationItem(
              type: alertType,
              title: 'Freshness Alert',
              description: alert,
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.local_florist,
              route: AppRoutes.freshness,
            ),
          );
        }

        // Temperature alerts from freshness readings
        if (freshnessReading.temperature < 15 ||
            freshnessReading.temperature > 25) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.critical,
              title: 'Freshness: Temperature Out of Range',
              description:
                  'Temperature is ${freshnessReading.temperature.toStringAsFixed(1)}°C. Optimal range for flowers is 15-25°C.',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.thermostat,
              route: AppRoutes.freshness,
            ),
          );
        } else if (freshnessReading.temperature < 18 ||
            freshnessReading.temperature > 22) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.warning,
              title: 'Freshness: Temperature Warning',
              description:
                  'Temperature is ${freshnessReading.temperature.toStringAsFixed(1)}°C. Consider adjusting to optimal range (18-22°C).',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.thermostat,
              route: AppRoutes.freshness,
            ),
          );
        }

        // Humidity alerts from freshness readings
        if (freshnessReading.humidity < 40 || freshnessReading.humidity > 80) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.critical,
              title: 'Freshness: Humidity Out of Range',
              description:
                  'Humidity is ${freshnessReading.humidity.toStringAsFixed(1)}%. Optimal range for flowers is 40-80%.',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.water_drop,
              route: AppRoutes.freshness,
            ),
          );
        } else if (freshnessReading.humidity < 50 ||
            freshnessReading.humidity > 70) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.warning,
              title: 'Freshness: Humidity Warning',
              description:
                  'Humidity is ${freshnessReading.humidity.toStringAsFixed(1)}%. Consider adjusting to optimal range (50-70%).',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.water_drop,
              route: AppRoutes.freshness,
            ),
          );
        }

        // Gas value alerts (ethylene detection)
        if (freshnessReading.gasValue > 100) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.critical,
              title: 'High Gas Level Detected',
              description:
                  'Gas sensor reading is ${freshnessReading.gasValue.toStringAsFixed(1)}. High levels may accelerate flower aging. Improve ventilation.',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.air,
              route: AppRoutes.freshness,
            ),
          );
        } else if (freshnessReading.gasValue > 70) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.warning,
              title: 'Elevated Gas Level',
              description:
                  'Gas sensor reading is ${freshnessReading.gasValue.toStringAsFixed(1)}. Monitor and ensure proper ventilation.',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.air,
              route: AppRoutes.freshness,
            ),
          );
        }

        // Water level alerts
        if (freshnessReading.waterLevel < 20) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.critical,
              title: 'Low Water Level',
              description:
                  'Water level is ${freshnessReading.waterLevel}%. Flowers need adequate water to maintain freshness.',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.water_drop_outlined,
              route: AppRoutes.freshness,
            ),
          );
        } else if (freshnessReading.waterLevel < 40) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.warning,
              title: 'Water Level Low',
              description:
                  'Water level is ${freshnessReading.waterLevel}%. Consider refilling to maintain optimal freshness.',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.water_drop_outlined,
              route: AppRoutes.freshness,
            ),
          );
        }
      }

      // Generate notifications from INM status (Farmer only)
      if (inmStatus != null &&
          (RoleFilter.isFarmer(_userRoles) ||
              RoleFilter.hasBothRoles(_userRoles))) {
        // Critical EC status
        if (inmStatus.statusType == EcStatusType.criticalLow ||
            inmStatus.statusType == EcStatusType.criticalHigh) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.critical,
              title: 'Critical EC Level',
              description:
                  'EC is ${inmStatus.statusLabel.toLowerCase()} (${inmStatus.currentEc.toStringAsFixed(2)} mS/cm). ${inmStatus.ecAction}',
              timestamp:
                  inmReadings.isNotEmpty && inmReadings.first.timestamp != null
                  ? inmReadings.first.timestamp!
                  : DateTime.now(),
              component: 'Nutrition',
              icon: Icons.water_drop,
              route: AppRoutes.inmSensors,
            ),
          );
        }

        // Warning EC status
        if (inmStatus.statusType == EcStatusType.low ||
            inmStatus.statusType == EcStatusType.high) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.warning,
              title: 'EC Level ${inmStatus.statusLabel}',
              description:
                  'EC is ${inmStatus.statusLabel.toLowerCase()} (${inmStatus.currentEc.toStringAsFixed(2)} mS/cm). ${inmStatus.ecAction}',
              timestamp:
                  inmReadings.isNotEmpty && inmReadings.first.timestamp != null
                  ? inmReadings.first.timestamp!
                  : DateTime.now(),
              component: 'Nutrition',
              icon: Icons.water_drop,
              route: AppRoutes.inmSensors,
            ),
          );
        }

        // pH action notification
        if (inmStatus.phAction.isNotEmpty &&
            inmStatus.phAction != 'No pH action available' &&
            inmStatus.phAction.toLowerCase().contains('adjust')) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.warning,
              title: 'pH Adjustment Needed',
              description: inmStatus.phAction,
              timestamp:
                  inmReadings.isNotEmpty && inmReadings.first.timestamp != null
                  ? inmReadings.first.timestamp!
                  : DateTime.now(),
              component: 'Nutrition',
              icon: Icons.science,
              route: AppRoutes.inmSensors,
            ),
          );
        }

        // NPK recommendation
        if (inmStatus.npkRecommendation.isNotEmpty &&
            inmStatus.npkRecommendation != 'No NPK recommendation available') {
          notifications.add(
            _NotificationItem(
              type: NotificationType.info,
              title: 'Nutrient Recommendation',
              description: inmStatus.npkRecommendation,
              timestamp:
                  inmReadings.isNotEmpty && inmReadings.first.timestamp != null
                  ? inmReadings.first.timestamp!
                  : DateTime.now(),
              component: 'Nutrition',
              icon: Icons.eco,
              route: AppRoutes.inmSensors,
            ),
          );
        }
      }

      // Generate notifications from sensor readings (Farmer only - Environment)
      if (RoleFilter.isFarmer(_userRoles) ||
          RoleFilter.hasBothRoles(_userRoles)) {
        for (final SensorReading reading in sensorReadings) {
          // Temperature critical
          if (reading.temperature < 18 || reading.temperature > 28) {
            notifications.add(
              _NotificationItem(
                type: NotificationType.critical,
                title: 'Critical Temperature',
                description:
                    'Temperature is ${reading.temperature.toStringAsFixed(1)}°C, outside optimal range (18-28°C).',
                timestamp: reading.timestamp,
                component: 'Environment',
                icon: Icons.thermostat,
                route: AppRoutes.stress,
              ),
            );
          }

          // Temperature warning
          if (reading.temperature > 24 && reading.temperature <= 28) {
            notifications.add(
              _NotificationItem(
                type: NotificationType.warning,
                title: 'Temperature Warning',
                description:
                    'Temperature is ${reading.temperature.toStringAsFixed(1)}°C, approaching limits.',
                timestamp: reading.timestamp,
                component: 'Environment',
                icon: Icons.thermostat,
                route: AppRoutes.stress,
              ),
            );
          }

          // Humidity critical
          if (reading.humidity < 50 || reading.humidity > 85) {
            notifications.add(
              _NotificationItem(
                type: NotificationType.critical,
                title: 'Critical Humidity',
                description:
                    'Humidity is ${reading.humidity.toStringAsFixed(1)}%, outside optimal range (50-85%).',
                timestamp: reading.timestamp,
                component: 'Environment',
                icon: Icons.water_drop,
                route: AppRoutes.stress,
              ),
            );
          }

          // Humidity warning
          if (reading.humidity > 75 && reading.humidity <= 85) {
            notifications.add(
              _NotificationItem(
                type: NotificationType.warning,
                title: 'Humidity Warning',
                description:
                    'Humidity is ${reading.humidity.toStringAsFixed(1)}%, approaching limits.',
                timestamp: reading.timestamp,
                component: 'Environment',
                icon: Icons.water_drop,
                route: AppRoutes.stress,
              ),
            );
          }

          // Soil critical
          if (reading.soilVoltage != null) {
            final double v = reading.soilVoltage!;
            if (v < 2.0 || v > 3.1) {
              notifications.add(
                _NotificationItem(
                  type: NotificationType.critical,
                  title: 'Critical Soil Condition',
                  description:
                      'Soil sensor reading is ${v.toStringAsFixed(2)}V, outside optimal range.',
                  timestamp: reading.timestamp,
                  component: 'Environment',
                  icon: Icons.agriculture,
                  route: AppRoutes.stress,
                ),
              );
            }
          }

          // UV critical
          if (reading.uvVoltage != null && reading.uvVoltage! > 1.0) {
            notifications.add(
              _NotificationItem(
                type: NotificationType.critical,
                title: 'High UV Exposure',
                description:
                    'UV sensor reading is ${reading.uvVoltage!.toStringAsFixed(2)}V, indicating high exposure.',
                timestamp: reading.timestamp,
                component: 'Environment',
                icon: Icons.wb_sunny,
                route: AppRoutes.stress,
              ),
            );
          }

          // Gas critical
          if (reading.mqVoltage != null && reading.mqVoltage! > 1.0) {
            notifications.add(
              _NotificationItem(
                type: NotificationType.critical,
                title: 'High Gas Level Detected',
                description:
                    'Gas sensor reading is ${reading.mqVoltage!.toStringAsFixed(2)}V, indicating elevated levels.',
                timestamp: reading.timestamp,
                component: 'Environment',
                icon: Icons.air,
                route: AppRoutes.stress,
              ),
            );
          }
        }
      }

      // Sort by timestamp (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _allNotifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load notifications: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<_NotificationItem> _getFilteredNotifications() {
    if (_selectedFilter == null) {
      return _allNotifications;
    }
    return _allNotifications.where((n) => n.type == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AuthState authState = context.watch<AuthState>();
    _userRoles = authState.roles;
    final filteredNotifications = _getFilteredNotifications();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerHighest,
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorView(scheme)
            : Column(
                children: <Widget>[
                  _buildHeader(scheme),
                  _buildFilterChips(scheme),
                  Expanded(
                    child: filteredNotifications.isEmpty
                        ? _buildEmptyState(scheme)
                        : _buildNotificationList(filteredNotifications, scheme),
                  ),
                ],
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
              'Error Loading Notifications',
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
              onPressed: _loadNotifications,
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
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'System alerts & updates',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (_allNotifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                // Filter menu could be added here
              },
              tooltip: 'Filter options',
              color: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _buildFilterChip(
              label: 'All',
              isSelected: _selectedFilter == null,
              count: _allNotifications.length,
              onTap: () {
                setState(() {
                  _selectedFilter = null;
                });
              },
              scheme: scheme,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Critical',
              isSelected: _selectedFilter == NotificationType.critical,
              count: _allNotifications
                  .where((n) => n.type == NotificationType.critical)
                  .length,
              onTap: () {
                setState(() {
                  _selectedFilter = NotificationType.critical;
                });
              },
              scheme: scheme,
              color: Colors.red,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Warnings',
              isSelected: _selectedFilter == NotificationType.warning,
              count: _allNotifications
                  .where((n) => n.type == NotificationType.warning)
                  .length,
              onTap: () {
                setState(() {
                  _selectedFilter = NotificationType.warning;
                });
              },
              scheme: scheme,
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Info',
              isSelected: _selectedFilter == NotificationType.info,
              count: _allNotifications
                  .where((n) => n.type == NotificationType.info)
                  .length,
              onTap: () {
                setState(() {
                  _selectedFilter = NotificationType.info;
                });
              },
              scheme: scheme,
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required int count,
    required VoidCallback onTap,
    required ColorScheme scheme,
    Color? color,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? (color ?? scheme.primary).withOpacity(0.2)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? (color ?? scheme.primary)
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: (color ?? scheme.primary).withOpacity(0.15),
      checkmarkColor: color ?? scheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? (color ?? scheme.primary) : scheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildNotificationList(
    List<_NotificationItem> notifications,
    ColorScheme scheme,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: notifications.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildNotificationCard(notifications[index], scheme);
      },
    );
  }

  Widget _buildNotificationCard(
    _NotificationItem notification,
    ColorScheme scheme,
  ) {
    Color iconColor;
    Color backgroundColor;
    IconData iconData;

    switch (notification.type) {
      case NotificationType.critical:
        iconColor = Colors.red;
        backgroundColor = Colors.red.withOpacity(0.1);
        iconData = Icons.error;
        break;
      case NotificationType.warning:
        iconColor = Colors.orange;
        backgroundColor = Colors.orange.withOpacity(0.1);
        iconData = Icons.warning;
        break;
      case NotificationType.info:
        iconColor = Colors.blue;
        backgroundColor = Colors.blue.withOpacity(0.1);
        iconData = Icons.info;
        break;
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: notification.route != null
            ? () {
                Navigator.of(context).pushNamed(notification.route!);
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  notification.icon ?? iconData,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            notification.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onSurface,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: scheme.primary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            notification.component,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimestamp(notification.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (notification.route != null) ...[
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pushNamed(notification.route!);
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'View details',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildEmptyState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 64,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'All good!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No alerts at the moment.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final localTimestamp = timestamp.isUtc ? timestamp.toLocal() : timestamp;
    final difference = now.difference(localTimestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} mins ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      // Format as date
      final dateFormat = difference.inDays < 365
          ? 'MMM d, h:mm a'
          : 'MMM d, y, h:mm a';
      return DateFormat(dateFormat).format(localTimestamp);
    }
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.component,
    this.icon,
    this.route,
  });

  final NotificationType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final String component;
  final IconData? icon;
  final String? route;
}
