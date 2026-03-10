// File: lib/features/inm/screens/inm_overview_screen.dart
// Purpose: INM Overview — glanceable status with per-device scoping.
//
// On load:
//   1. Reads JWT token from AuthState.
//   2. Fetches the user's INM devices from GET /auth/my-devices?device_type=INM.
//   3. Auto-selects the first device (or shows picker if >1).
//   4. Fetches sensor readings + status scoped to the selected device.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../../../services/auth_service.dart';
import '../models/inm_sensor_reading.dart';
import '../models/inm_status.dart';
import '../services/inm_api_service.dart';
import '../widgets/hero_ml_insight_card.dart';
import '../widgets/live_sensor_snapshot.dart';
import '../widgets/top_recommendation_preview.dart';

class InmOverviewScreen extends StatefulWidget {
  const InmOverviewScreen({super.key});

  @override
  State<InmOverviewScreen> createState() => _InmOverviewScreenState();
}

class _InmOverviewScreenState extends State<InmOverviewScreen> {
  final InmApiService _apiService = InmApiService();
  final AuthService _authService = AuthService();

  // Device list
  List<Map<String, dynamic>> _inmDevices = [];
  String? _selectedDeviceId;
  bool _isLoadingDevices = true;

  // Sensor data
  List<InmSensorReading> _allReadings = [];
  InmStatus? _currentStatus;
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _autoRefreshTimer;
  static const int _refreshIntervalSeconds = 30;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  String? get _token =>
      Provider.of<AuthState>(context, listen: false).token;

  // ---------------------------------------------------------------------------
  // Device loading
  // ---------------------------------------------------------------------------

  Future<void> _loadDevices() async {
    setState(() {
      _isLoadingDevices = true;
      _errorMessage = null;
    });

    final token = _token;
    if (token == null) {
      setState(() {
        _isLoadingDevices = false;
        _errorMessage = 'Not logged in.';
      });
      return;
    }

    final devices = await _authService.fetchMyDevices(token, deviceType: 'INM');
    if (!mounted) return;

    if (devices.isEmpty) {
      setState(() {
        _isLoadingDevices = false;
        _inmDevices = [];
        _selectedDeviceId = null;
      });
      return;
    }

    setState(() {
      _inmDevices = devices;
      // Auto-select the first device
      _selectedDeviceId =
          devices.first['device_serial_number'] as String? ??
          devices.first['device_id'] as String?;
      _isLoadingDevices = false;
    });

    await _loadAllData();
    _startAutoRefresh();
  }

  void _onDeviceChanged(String? deviceId) {
    if (deviceId == null || deviceId == _selectedDeviceId) return;
    _autoRefreshTimer?.cancel();
    setState(() {
      _selectedDeviceId = deviceId;
      _allReadings = [];
      _currentStatus = null;
    });
    _loadAllData();
    _startAutoRefresh();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: _refreshIntervalSeconds),
      (_) {
        if (mounted) _loadAllData(showLoading: false);
      },
    );
  }

  Future<void> _loadAllData({bool showLoading = true}) async {
    final token = _token;
    final deviceId = _selectedDeviceId;
    if (token == null || deviceId == null) return;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        _apiService.fetchAllReadings(deviceId, token),
        _apiService.fetchStatus(deviceId, token),
      ]);

      if (mounted) {
        setState(() {
          _allReadings = results[0] as List<InmSensorReading>;
          _currentStatus = results[1] as InmStatus;
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

  InmSensorReading? get _latestReading =>
      _allReadings.isNotEmpty ? _allReadings.first : null;

  void _navigateToActionsHistory() {
    if (_selectedDeviceId == null || _token == null) return;
    Navigator.of(context).pushNamed(
      '/inm-actions-history',
      arguments: {
        'deviceId': _selectedDeviceId!,
        'token': _token!,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('INM Overview'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAllData(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoadingDevices
          ? const Center(child: CircularProgressIndicator())
          : _inmDevices.isEmpty
              ? _buildNoDevicesState(theme)
              : RefreshIndicator(
                  onRefresh: () => _loadAllData(),
                  child: _buildBody(theme),
                ),
    );
  }

  Widget _buildNoDevicesState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sensors_off,
                size: 72, color: theme.colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 24),
            Text(
              'No INM Devices Assigned',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Ask your admin to assign an INM device to your greenhouse.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Syncing INM data...'),
          ],
        ),
      );
    }

    if (_errorMessage != null && _allReadings.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height - 200,
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off,
                    size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 24),
                Text('Backend Unreachable',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _loadAllData(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Connection'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hasDeviceData =
        (_currentStatus?.hasSensorData ?? false) || _allReadings.isNotEmpty;

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Device picker (only shown when user has >1 INM device)
              if (_inmDevices.length > 1) ...[
                _DevicePicker(
                  devices: _inmDevices,
                  selectedDeviceId: _selectedDeviceId,
                  onChanged: _onDeviceChanged,
                ),
                const SizedBox(height: 16),
              ],

              if (!hasDeviceData) ...[
                _buildNoDataState(theme),
                const SizedBox(height: 20),
              ] else ...[
              // Hero ML Insight Card
              if (_currentStatus != null)
                HeroMlInsightCard(status: _currentStatus!),

              const SizedBox(height: 24),

              // Live Sensor Snapshot
              if (_latestReading != null) ...[
                LiveSensorSnapshot(reading: _latestReading!),
                const SizedBox(height: 24),
              ],

              // Top Recommendation Preview
              if (_currentStatus != null)
                TopRecommendationPreview(
                  status: _currentStatus!,
                  onViewRecommendations: _navigateToActionsHistory,
                ),

              const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoDataState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.sensors_off,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.35),
            ),
            const SizedBox(height: 12),
            Text(
              'No data available',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Device picker widget
// ---------------------------------------------------------------------------

class _DevicePicker extends StatelessWidget {
  const _DevicePicker({
    required this.devices,
    required this.selectedDeviceId,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> devices;
  final String? selectedDeviceId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surface,
      ),
      child: Row(
        children: [
          Icon(Icons.sensors,
              size: 20,
              color: theme.colorScheme.primary.withOpacity(0.8)),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedDeviceId,
                hint: const Text('Select device'),
                items: devices.map((device) {
                  final id = (device['device_serial_number'] ??
                      device['device_id'] ??
                      '') as String;
                  final name =
                      (device['name'] ?? id) as String;
                  return DropdownMenuItem(
                    value: id,
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
