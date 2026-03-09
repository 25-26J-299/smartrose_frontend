import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/auth/auth_state.dart';
import '../../services/auth_service.dart';
import '../shared/models/weather_model.dart';
import '../shared/services/weather_api_service.dart';
import '../shared/utils/role_filter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  Timer? _autoRefreshTimer;
  final WeatherApiService _weatherApiService = WeatherApiService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  WeatherModel? _weather;
  bool _isWeatherLoading = false;
  String? _weatherError;
  String _searchQuery = '';

  /// Device types assigned to this user (e.g. {'INM', 'FM'}).
  /// null = still loading. empty set = loaded, no devices.
  Set<String>? _assignedDeviceTypes;
  bool _isDevicesLoading = true;

  /// Maps componentType → backend device type string (uppercase)
  static const Map<String, String> _componentToDeviceType = <String, String>{
    'inm': 'INM',
    'disease': 'EDAS',
    'environment': 'EOSM',
    'freshness': 'FM',
  };

  static final List<_ComponentCard> _allComponents = <_ComponentCard>[
    _ComponentCard(
      name: 'Intelligent Nutrition Management',
      icon: Icons.eco_rounded,
      route: AppRoutes.inmSensors,
      status: ComponentStatus.normal,
      accentColor: const Color(0xFF4CAF50),
      componentType: 'inm',
    ),
    _ComponentCard(
      name: 'Disease Detection',
      icon: Icons.bug_report_rounded,
      route: AppRoutes.disease,
      status: ComponentStatus.warning,
      accentColor: const Color(0xFFFFB300),
      componentType: 'disease',
    ),
    _ComponentCard(
      name: 'Environmental Monitoring',
      icon: Icons.sensors_rounded,
      route: AppRoutes.stress,
      status: ComponentStatus.normal,
      accentColor: const Color(0xFF42A5F5),
      componentType: 'environment',
    ),
    _ComponentCard(
      name: 'Freshness Monitoring',
      icon: Icons.local_florist_rounded,
      route: AppRoutes.freshness,
      status: ComponentStatus.normal,
      accentColor: const Color(0xFFE91E63),
      componentType: 'freshness',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWeather();
    _startAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAssignedDeviceTypes();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoRefresh();
    _weatherApiService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Pause updates when app is in background, resume when in foreground
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopAutoRefresh();
    } else if (state == AppLifecycleState.resumed) {
      _startAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _stopAutoRefresh(); // Cancel any existing timer
    // Auto-refresh can be implemented here if needed
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _loadAssignedDeviceTypes() async {
    if (!mounted) return;
    final String? token = context.read<AuthState>().token;
    if (token == null) {
      setState(() {
        _assignedDeviceTypes = <String>{};
        _isDevicesLoading = false;
      });
      return;
    }
    setState(() => _isDevicesLoading = true);
    try {
      final List<Map<String, dynamic>> devices =
          await _authService.fetchMyDevices(token);
      if (!mounted) return;
      final Set<String> types = devices
          .map((Map<String, dynamic> d) =>
              (d['type'] as String? ?? '').toUpperCase())
          .where((String t) => t.isNotEmpty)
          .toSet();
      setState(() {
        _assignedDeviceTypes = types;
        _isDevicesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // On error fall back to empty — no services shown rather than a crash
      setState(() {
        _assignedDeviceTypes = <String>{};
        _isDevicesLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ColorScheme scheme = Theme.of(context).colorScheme;

        return Container(
          color: const Color(0xFFF5F5F5), // Light neutral grey background
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadWeather();
            },
            color: scheme.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildGreetingHeader(context, scheme),
                      const SizedBox(height: 16),
                      _buildSearchBar(context, scheme),
                      const SizedBox(height: 20),
                      _buildWeatherCard(context, scheme),
                      const SizedBox(height: 24),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth < 400 ? 16 : 20,
                        ),
                        child: _buildSectionTitle('SmartRose Services', scheme),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth < 400 ? 16 : 20,
                        ),
                        child: _buildComponentCards(context, scheme),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Widget _buildGreetingHeader(BuildContext context, ColorScheme scheme) {
    final AuthState authState = context.watch<AuthState>();
    final String userName = authState.user?.name ?? 'User';
    final String greeting = _getGreeting();
    final String todayDate = DateFormat(
      'EEEE, dd MMM yyyy',
    ).format(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.secondary],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $greeting',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          todayDate,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Profile Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
    );
  }

  Widget _buildSearchBar(BuildContext context, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search components…',
            hintStyle: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 16,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: scheme.primary,
              size: 24,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: scheme.primary,
                      size: 24,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : IconButton(
                    icon: Icon(
                      Icons.mic_rounded,
                      color: scheme.primary,
                      size: 24,
                    ),
                    onPressed: () {
                      // Voice search functionality
                    },
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase().trim();
            });
          },
        ),
      ),
    );
  }

  Future<void> _loadWeather() async {
    if (!mounted) return;

    setState(() {
      _isWeatherLoading = true;
      _weatherError = null;
    });

    try {
      final WeatherModel? weather = await _weatherApiService
          .fetchCurrentWeather();
      if (mounted) {
        setState(() {
          if (weather != null) {
            _weather = weather;
            _weatherError = null;
          } else {
            _weather = null;
            _weatherError =
                'Failed to load weather data. Please check your internet connection.';
          }
          _isWeatherLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weather = null;
          _weatherError = 'Failed to load weather data: ${e.toString()}';
          _isWeatherLoading = false;
        });
      }
    }
  }

  Widget _buildWeatherCard(BuildContext context, ColorScheme scheme) {
    if (_isWeatherLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }

    if (_weatherError != null || _weather == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                _weatherError ?? 'Weather data unavailable',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadWeather, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final weather = _weather!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_cloudy_rounded, size: 32, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    weather.locationName ?? 'Current Location Weather',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Temperature Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weather.temperature.toStringAsFixed(1)}°',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                    height: 1.0,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                            color: Colors.red.shade400,
                          ),
                          Text(
                            '${weather.highTemp.toStringAsFixed(0)}°',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 18,
                            color: Colors.blue.shade400,
                          ),
                          Text(
                            '${weather.lowTemp.toStringAsFixed(0)}°',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(
                  weather.getConditionIcon(),
                  size: 64,
                  color: Colors.amber.shade400,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Weather Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _buildWeatherMetric(
                    icon: Icons.water_drop_rounded,
                    label: 'Humidity',
                    value: '${weather.humidity.toStringAsFixed(0)}%',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildWeatherMetric(
                    icon: Icons.grain_rounded,
                    label: 'Rain',
                    value: '${weather.precipitation.toStringAsFixed(1)}mm',
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildWeatherMetric(
                    icon: Icons.compress_rounded,
                    label: 'Pressure',
                    value: '${weather.pressure.toStringAsFixed(1)} hPa',
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildWeatherMetric(
                    icon: Icons.air_rounded,
                    label: 'Wind',
                    value: '${weather.windSpeed.toStringAsFixed(1)} km/h',
                    color: Colors.cyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Sunrise/Sunset Row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.wb_twilight_rounded,
                        size: 24,
                        color: Colors.orange.shade600,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sunrise',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            weather.sunrise,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: scheme.outline.withValues(alpha: 0.2),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.wb_twilight_rounded,
                        size: 24,
                        color: Colors.deepPurple.shade300,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sunset',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            weather.sunset,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme scheme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
        letterSpacing: -0.4,
      ),
    );
  }

  Widget _buildComponentCards(BuildContext context, ColorScheme scheme) {
    // Show loading indicator while fetching assigned devices
    if (_isDevicesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Get user roles for role-based filtering
    final AuthState authState = context.watch<AuthState>();
    final List<String> roles = authState.roles;

    // 1. Filter by role
    final List<_ComponentCard> roleFilteredComponents =
        RoleFilter.filterComponents(
      allComponents: _allComponents,
      roles: roles,
      getComponentType: (component) => component.componentType,
    );

    // 2. Filter by assigned devices — only show cards whose device type the
    //    user actually has assigned
    final Set<String> assigned = _assignedDeviceTypes ?? <String>{};
    final List<_ComponentCard> deviceFilteredComponents =
        roleFilteredComponents.where((_ComponentCard c) {
      final String? deviceType = _componentToDeviceType[c.componentType];
      return deviceType != null && assigned.contains(deviceType);
    }).toList();

    // 3. Filter by search query
    final List<_ComponentCard> filteredComponents = _searchQuery.isEmpty
        ? deviceFilteredComponents
        : deviceFilteredComponents
            .where((component) =>
                component.name.toLowerCase().contains(_searchQuery))
            .toList();

    if (filteredComponents.isEmpty) {
      // Different messages for "no devices assigned" vs "search returned nothing"
      final bool hasDevices = deviceFilteredComponents.isNotEmpty;
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              hasDevices ? Icons.search_off_rounded : Icons.devices_other_rounded,
              size: 64,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              hasDevices ? 'No components found' : 'No services available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasDevices
                  ? 'Try searching with different keywords'
                  : 'No devices have been assigned to your account yet.\nPlease contact your administrator.',
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasDevices) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _loadAssignedDeviceTypes,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredComponents.length,
      itemBuilder: (BuildContext context, int index) {
        final _ComponentCard component = filteredComponents[index];
        return _buildComponentCard(context, scheme, component);
      },
    );
  }

  Widget _buildComponentCard(
    BuildContext context,
    ColorScheme scheme,
    _ComponentCard component,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(component.route),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: component.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  component.icon,
                  size: 28,
                  color: component.accentColor,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  component.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum ComponentStatus { normal, warning, attention }

class _ComponentCard {
  const _ComponentCard({
    required this.name,
    required this.icon,
    required this.route,
    required this.status,
    required this.accentColor,
    required this.componentType,
  });

  final String name;
  final IconData icon;
  final String route;
  final ComponentStatus status;
  final Color accentColor;
  final String componentType;
}
