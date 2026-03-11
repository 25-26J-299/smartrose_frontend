import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../../../shared/models/prediction_model.dart';
import '../../../shared/models/reading_model.dart';
import '../../../shared/services/freshness_api_service.dart';

class FreshnessHomeScreen extends StatefulWidget {
  const FreshnessHomeScreen({super.key});

  @override
  State<FreshnessHomeScreen> createState() => _FreshnessHomeScreenState();
}

class _FreshnessHomeScreenState extends State<FreshnessHomeScreen>
    with WidgetsBindingObserver {
  final FreshnessApiService _apiService = FreshnessApiService();

  // Device list
  bool _loadingDevices = true;
  String? _devicesError;
  List<FmLocationWithDevices> _locations = [];
  FmDevice? _selectedDevice;

  // Sensor data
  bool _loadingData = false;
  String? _dataError;
  ReadingModel? _latestReading;
  PredictionModel? _prediction;

  Timer? _autoRefreshTimer;
  bool _isScreenVisible = true;
  static const Duration _refreshInterval = Duration(seconds: 30);
  String? _requestedDeviceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDevices());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['deviceId'] != null) {
      _requestedDeviceId = args['deviceId']?.toString();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoRefresh();
    _apiService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isScreenVisible = false;
      _stopAutoRefresh();
    } else if (state == AppLifecycleState.resumed) {
      _isScreenVisible = true;
      if (_selectedDevice != null) _loadSensorData(silent: true);
      _startAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _stopAutoRefresh();
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (_isScreenVisible && mounted && !_loadingData && _selectedDevice != null) {
        _loadSensorData(silent: true);
      }
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _loadDevices() async {
    final token = context.read<AuthState>().token;
    if (token == null) {
      setState(() {
        _loadingDevices = false;
        _devicesError = 'Not authenticated. Please log in again.';
      });
      return;
    }

    setState(() {
      _loadingDevices = true;
      _devicesError = null;
    });

    try {
      final locations = await _apiService.getMyFmDevices(token);
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _loadingDevices = false;
      });

      if (_requestedDeviceId != null && _requestedDeviceId!.isNotEmpty) {
        for (final loc in locations) {
          for (final rawDevice in loc.devices) {
            if (rawDevice.deviceSerialNumber == _requestedDeviceId) {
              final device = rawDevice.copyWithLocationName(loc.locationName);
              setState(() => _selectedDevice = device);
              await _loadSensorData();
              _startAutoRefresh();
              return;
            }
          }
        }
      }

      // Auto-select first FM device
      for (final loc in locations) {
        if (loc.devices.isNotEmpty) {
          final device = loc.devices.first.copyWithLocationName(loc.locationName);
          setState(() => _selectedDevice = device);
          await _loadSensorData();
          _startAutoRefresh();
          break;
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDevices = false;
        _devicesError = e.error?.toString() ?? 'Failed to load devices';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDevices = false;
        _devicesError = 'Unexpected error: ${e.toString()}';
      });
    }
  }

  Future<void> _loadSensorData({bool silent = false}) async {
    final device = _selectedDevice;
    if (device == null) return;

    if (!silent) {
      setState(() {
        _loadingData = true;
        _dataError = null;
      });
    }

    try {
      final data = await _apiService.getLatestWithPrediction(
        device.deviceSerialNumber,
        forceRefresh: true,
      );
      if (!mounted) return;

      if (data['reading'] == null || data['prediction'] == null) {
        throw Exception('No sensor data found for this device');
      }

      final reading = ReadingModel.fromJson(data['reading'] as Map<String, dynamic>);
      final prediction = PredictionModel.fromJson(data['prediction'] as Map<String, dynamic>);

      setState(() {
        _latestReading = reading;
        _prediction = prediction;
        if (!silent) _loadingData = false;
      });
    } on DioException catch (e) {
      if (!silent && mounted) {
        String msg = e.error?.toString() ?? 'Failed to load sensor data';
        if (e.response?.statusCode == 404 || msg.toLowerCase().contains('not found')) {
          msg = 'No sensor data yet for "${device.name}".\n';
        }
        setState(() {
          _dataError = msg;
          _loadingData = false;
        });
      }
    } catch (e) {
      if (!silent && mounted) {
        // Hide technical error details like type cast errors
        String userFriendlyMsg = 'Failed to load data for "${device.name}"';
        if (e.toString().contains('Null') || e.toString().contains('subtype')) {
          userFriendlyMsg = 'No sensor data yet for "${device.name}".\n'
              'Make sure the ESP32 is powered on and sending data.';
        }
        setState(() {
          _dataError = userFriendlyMsg;
          _loadingData = false;
        });
      }
    }
  }

  void _onDeviceSelected(FmDevice device) {
    if (_selectedDevice?.id == device.id) return;
    setState(() {
      _selectedDevice = device;
      _latestReading = null;
      _prediction = null;
      _dataError = null;
    });
    _loadSensorData();
    _startAutoRefresh();
  }

  // ───────────────────────────── BUILD ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerHighest,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Freshness Monitoring'),
            if (_selectedDevice != null)
              Text(
                '${_selectedDevice!.locationName} · ${_selectedDevice!.name}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: scheme.onSurface.withOpacity(0.65),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: (_loadingData || _selectedDevice == null)
                ? null
                : () => _loadSensorData(),
          ),
        ],
      ),
      body: _loadingDevices
          ? const Center(child: CircularProgressIndicator())
          : _devicesError != null
              ? _buildError(scheme, _devicesError!, _loadDevices)
              : _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    final allDevices = _locations
        .expand((l) => l.devices.map((d) => d.copyWithLocationName(l.locationName)))
        .toList();

    return Column(
      children: [
        if (allDevices.isNotEmpty) _buildDeviceSelector(scheme),
        Expanded(
          child: allDevices.isEmpty
              ? _buildNoDevices(scheme)
              : _buildSensorContent(scheme),
        ),
      ],
    );
  }

  Widget _buildDeviceSelector(ColorScheme scheme) {
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _locations
            .where((loc) => loc.devices.isNotEmpty)
            .map((loc) => _buildLocationRow(scheme, loc))
            .toList(),
      ),
    );
  }

  Widget _buildLocationRow(ColorScheme scheme, FmLocationWithDevices loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Row(
            children: [
              Icon(
                loc.locationType == 'flower_shop' ? Icons.store : Icons.park,
                size: 14,
                color: scheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                loc.locationName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: loc.devices
              .map((d) => _buildDeviceChip(scheme, d, loc.locationName))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildDeviceChip(ColorScheme scheme, FmDevice device, String locationName) {
    final isSelected = _selectedDevice?.id == device.id;
    return ChoiceChip(
      label: Text(device.name),
      selected: isSelected,
      avatar: Icon(Icons.sensors, size: 14,
          color: isSelected ? scheme.onSecondaryContainer : scheme.onSurface),
      onSelected: (_) => _onDeviceSelected(device.copyWithLocationName(locationName)),
    );
  }

  Widget _buildNoDevices(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 56, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              'No FM Devices Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask your admin to assign an FM device to your flower shop.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorContent(ColorScheme scheme) {
    if (_loadingData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_dataError != null) {
      return _buildError(scheme, _dataError!, () => _loadSensorData(), isInfo: true);
    }
    if (_latestReading == null || _prediction == null) {
      return Center(
        child: Text(
          'Select a device above to view data.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadSensorData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFreshnessScoreCard(scheme),
            const SizedBox(height: 16),
            _buildVaseLifeCard(scheme),
            const SizedBox(height: 16),
            _buildSensorReadingsCard(scheme),
            const SizedBox(height: 16),
            if (_prediction!.alerts.isNotEmpty) _buildAlertsCard(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildError(
    ColorScheme scheme,
    String message,
    VoidCallback onRetry, {
    bool isInfo = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isInfo ? Icons.sensors_off : Icons.error_outline,
              size: 56,
              color: isInfo ? scheme.primary : scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              isInfo ? 'No Data Available' : 'Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreshnessScoreCard(ColorScheme scheme) {
    final score = _prediction!.freshnessScore;
    final scoreColor = score >= 70 ? Colors.green : score >= 40 ? Colors.orange : Colors.red;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(children: [
              Icon(Icons.local_florist, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Freshness Score',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 12,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                ),
                Column(children: [
                  Text(score.toStringAsFixed(1),
                      style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: scoreColor)),
                  Text('/ 100',
                      style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant)),
                ]),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getFreshnessStatus(score),
              style: TextStyle(fontSize: 16, color: scoreColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaseLifeCard(ColorScheme scheme) {
    final hours = _prediction!.vaseLifeHours;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.access_time, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimated Vase Life',
                      style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('${(hours / 24).toStringAsFixed(1)} days',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface)),
                  Text('(${hours.toStringAsFixed(1)} hours)',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorReadingsCard(ColorScheme scheme) {
    final r = _latestReading!;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.sensors, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Sensor Readings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            _sensorRow(scheme, Icons.thermostat, 'Air Temperature',
                '${r.airTemperature.toStringAsFixed(2)}°C',
                r.airTemperature >= 15 && r.airTemperature <= 25 ? Colors.green : Colors.orange),
            const SizedBox(height: 12),
            _sensorRow(scheme, Icons.water, 'Water Temperature',
                '${r.waterTemperature.toStringAsFixed(2)}°C',
                r.waterTemperature >= 15 && r.waterTemperature <= 25 ? Colors.green : Colors.orange),
            const SizedBox(height: 12),
            _sensorRow(scheme, Icons.water_drop, 'Humidity',
                '${r.humidity.toStringAsFixed(2)}%',
                r.humidity >= 40 && r.humidity <= 80 ? Colors.green : Colors.orange),
            const SizedBox(height: 12),
            _sensorRow(scheme, Icons.air, 'Gas Value',
                r.gasValue.toStringAsFixed(2),
                r.gasValue < 100 ? Colors.green : Colors.red),
            const SizedBox(height: 12),
            _sensorRow(scheme, Icons.opacity, 'Water Level',
                '${r.waterLevel}%',
                r.waterLevel >= 20 ? Colors.green : Colors.red),
            const SizedBox(height: 16),
            Divider(color: scheme.outline),
            const SizedBox(height: 8),
            Text('Last Updated: ${_formatTimestamp(r.timestamp)}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _sensorRow(ColorScheme scheme, IconData icon, String label,
      String value, Color statusColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusColor)),
        ),
      ],
    );
  }

  Widget _buildAlertsCard(ColorScheme scheme) {
    return Card(
      elevation: 2,
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.warning, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Text('Alerts',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: scheme.onErrorContainer)),
            ]),
            const SizedBox(height: 12),
            ..._prediction!.alerts.map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: scheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(alert,
                            style: TextStyle(
                                fontSize: 14, color: scheme.onErrorContainer)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  String _getFreshnessStatus(double score) {
    if (score >= 70) return 'Excellent';
    if (score >= 40) return 'Good';
    return 'Needs Attention';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final local = timestamp.isUtc ? timestamp.toLocal() : timestamp;
    final diff = now.difference(local);
    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}
