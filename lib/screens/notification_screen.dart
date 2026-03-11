import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../core/auth/auth_state.dart';
import '../shared/services/notifications_api_service.dart';
import '../core/app_routes.dart';
import '../shared/widgets/gradient_header.dart';

enum NotificationType { critical, warning, info }

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  NotificationType? _selectedFilter;
  static const Duration _autoRefreshInterval = Duration(seconds: 30);
  Timer? _autoRefreshTimer;

  // Services
  final NotificationsApiService _notificationsApiService = NotificationsApiService();

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
    _startAutoRefresh();
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
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (!mounted || _isLoading) return;
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<_NotificationItem> notifications = <_NotificationItem>[];

      // Fetch in-app notifications from backend (EOSM and others)
      try {
        final token = Provider.of<AuthState>(context, listen: false).token;
        if (token != null) {
          final List<Map<String, dynamic>> backendNotifications =
              await _notificationsApiService.fetchNotifications(token: token);
          for (final Map<String, dynamic> n in backendNotifications) {
            final String typeStr = (n['type'] as String?) ?? '';
            final String severity = ((n['severity'] as String?) ?? 'INFO').toUpperCase();
            final dynamic rawMetadata = n['metadata'];
            final Map<String, dynamic> metadata = rawMetadata is Map
                ? Map<String, dynamic>.from(rawMetadata as Map)
                : <String, dynamic>{};
            final String deviceId = metadata['device_id']?.toString() ?? '';
            NotificationType notifType = NotificationType.info;
            if (severity == 'HIGH') {
              notifType = NotificationType.critical;
            } else if (severity == 'WARNING') {
              notifType = NotificationType.warning;
            }
            DateTime? createdAt;
            try {
              final String? created = n['created_at'] as String?;
              if (created != null && created.isNotEmpty) {
                createdAt = DateTime.parse(created);
              }
            } catch (_) {}
            final String? route = typeStr == 'EOSM'
                ? AppRoutes.stress
                : typeStr == 'INM' && deviceId.isNotEmpty
                    ? AppRoutes.inmActionsHistory
                    : null;
            final Object? routeArguments = typeStr == 'INM' && deviceId.isNotEmpty
                ? <String, String>{
                    'deviceId': deviceId,
                    'token': token,
                  }
                : null;
            notifications.add(
              _NotificationItem(
                type: notifType,
                title: (n['title'] as String?) ?? 'Notification',
                description: (n['message'] as String?) ?? '',
                timestamp: createdAt ?? DateTime.now(),
                component: typeStr.isNotEmpty ? typeStr : 'Alert',
                icon: typeStr == 'EOSM'
                    ? Icons.thermostat
                    : typeStr == 'INM'
                        ? Icons.sensors
                        : Icons.notifications,
                route: route,
                routeArguments: routeArguments,
              ),
            );
          }
        }
      } catch (e) {
        // Ignore backend notifications errors
      }

      // Disease: only add real alerts when EDAS/backend provides them; no static placeholder

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

  /// Clear all notifications on the server, then refresh the list.
  Future<void> _clearAllAlerts() async {
    final String? token = Provider.of<AuthState>(context, listen: false).token;
    if (token == null) return;
    setState(() => _isLoading = true);
    try {
      final bool ok = await _notificationsApiService.clearAll(token: token);
      if (mounted) {
        if (ok) {
          await _loadNotifications();
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to clear alerts';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to clear alerts';
        });
      }
    }
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
        showBackButton: false,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear all alerts',
            onPressed: _allNotifications.isEmpty ? null : _clearAllAlerts,
          ),
        ],
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
                Navigator.of(context).pushNamed(
                  notification.route!,
                  arguments: notification.routeArguments,
                );
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
                              ).pushNamed(
                                notification.route!,
                                arguments: notification.routeArguments,
                              );
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
    this.routeArguments,
  });

  final NotificationType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final String component;
  final IconData? icon;
  final String? route;
  final Object? routeArguments;
}
