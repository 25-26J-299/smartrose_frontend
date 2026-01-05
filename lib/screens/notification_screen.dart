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
import '../shared/widgets/gradient_header.dart';

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
        final double score = freshnessPrediction.freshnessScore;
        if (score < 40) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.critical,
              title: 'Critical Freshness',
              description: 'Freshness score is critical (${score.toStringAsFixed(0)}%)',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.warning,
              route: AppRoutes.freshness,
            ),
          );
        } else if (score < 70) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.warning,
              title: 'Freshness Update',
              description: 'Freshness score is decreasing (${score.toStringAsFixed(0)}%)',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.local_florist,
              route: AppRoutes.freshness,
            ),
          );
        }

        // Vase life notifications
        final double vaseLifeHours = freshnessPrediction.vaseLifeHours;
        if (vaseLifeHours < 48) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.warning,
              title: 'Vase Life Alert',
              description: 'Predicted vase life is under 48 hours',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.access_time,
              route: AppRoutes.freshness,
            ),
          );
        }

        // Temperature alerts from freshness readings
        if (freshnessReading.temperature < 15 || freshnessReading.temperature > 25) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.critical,
              title: 'Temperature Alert',
              description: 'Storage temperature outside optimal range',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.thermostat,
              route: AppRoutes.freshness,
            ),
          );
        }

        // Gas value alerts (ethylene detection)
        if (freshnessReading.gasValue > 70) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.warning,
              title: 'Ethylene Alert',
              description: 'Elevated gas levels detected near flowers',
              timestamp: freshnessReading.timestamp,
              component: 'Freshness',
              icon: Icons.air,
              route: AppRoutes.freshness,
            ),
          );
        }

        // Water level alerts
        if (freshnessReading.waterLevel < 40) {
          notifications.add(
            _NotificationItem(
              type: NotificationType.warning,
              title: 'Water Level Alert',
              description: 'Vase water level is low',
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
        // Critical/Warning EC status
        if (inmStatus.statusType != EcStatusType.optimal) {
          notifications.add(
            _NotificationItem(
              type: (inmStatus.statusType == EcStatusType.criticalLow || 
                     inmStatus.statusType == EcStatusType.criticalHigh) 
                    ? NotificationType.critical 
                    : NotificationType.warning,
              title: 'EC Level Alert',
              description: 'EC level is ${inmStatus.statusLabel.toLowerCase()}',
              timestamp: inmReadings.isNotEmpty && inmReadings.first.timestamp != null
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
              title: 'pH Alert',
              description: 'pH adjustment required immediately',
              timestamp: inmReadings.isNotEmpty && inmReadings.first.timestamp != null
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
              title: 'Nutrient Update',
              description: 'New nutrient balance recommendation available',
              timestamp: inmReadings.isNotEmpty && inmReadings.first.timestamp != null
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
        for (final SensorReading reading in sensorReadings.take(5)) {
          if (reading.temperature < 18 || reading.temperature > 28) {
            notifications.add(
              _NotificationItem(
                type: NotificationType.critical,
                title: 'Climate Alert',
                description: 'Greenhouse temperature is outside limits',
                timestamp: reading.timestamp,
                component: 'Environment',
                icon: Icons.thermostat,
                route: AppRoutes.stress,
              ),
            );
          }

          if (reading.humidity < 50 || reading.humidity > 85) {
            notifications.add(
              _NotificationItem(
                type: NotificationType.critical,
                title: 'Humidity Alert',
                description: 'Air humidity level requires attention',
                timestamp: reading.timestamp,
                component: 'Environment',
                icon: Icons.water_drop,
                route: AppRoutes.stress,
              ),
            );
          }
        }
      }

      // Disease Component Notifications (Farmer only)
      if (RoleFilter.isFarmer(_userRoles) ||
          RoleFilter.hasBothRoles(_userRoles)) {
        notifications.add(
          _NotificationItem(
            type: NotificationType.info,
            title: 'Disease Risk Low',
            description: 'Environmental conditions are safe from fungal growth',
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
            component: 'Disease',
            icon: Icons.shield_outlined,
            route: AppRoutes.disease,
          ),
        );
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
      appBar: GradientHeader.buildAppBar(
        context: context,
        title: 'Notifications',
        onBackPressed: () => Navigator.of(context).pop(),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorView(scheme)
            : Column(
                children: <Widget>[
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
