import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../shared/models/prediction_model.dart';
import '../../../shared/models/reading_model.dart';
import '../../../shared/services/freshness_api_service.dart';

class FreshnessHomeScreen extends StatefulWidget {
  const FreshnessHomeScreen({super.key});

  @override
  State<FreshnessHomeScreen> createState() => _FreshnessHomeScreenState();
}

class _FreshnessHomeScreenState extends State<FreshnessHomeScreen> {
  final FreshnessApiService _apiService = FreshnessApiService();
  String _currentDeviceId = 'device_001';

  ReadingModel? _latestReading;
  PredictionModel? _prediction;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFreshnessData(forceRefresh: true);
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _loadFreshnessData({bool forceRefresh = true}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch latest reading from database (sorted by timestamp descending)
      // and get ML model prediction in a single call
      final data = await _apiService.getLatestWithPrediction(
        _currentDeviceId,
        forceRefresh: forceRefresh,
      );

      // Parse the response
      final reading = ReadingModel.fromJson(
        data['reading'] as Map<String, dynamic>,
      );
      final prediction = PredictionModel.fromJson(
        data['prediction'] as Map<String, dynamic>,
      );

      setState(() {
        _latestReading = reading;
        _prediction = prediction;
        _isLoading = false;
      });
    } on DioException catch (e) {
      String errorMsg = e.error?.toString() ?? 'Failed to load freshness data';

      // Provide more helpful error messages
      final statusCode = e.response?.statusCode;
      if (statusCode == 404 ||
          errorMsg.contains('404') ||
          errorMsg.toLowerCase().contains('not found')) {
        errorMsg =
            'No data found for device "$_currentDeviceId". '
            'Please ensure the device exists and has sensor readings.';
      } else if (errorMsg.contains('Cannot connect') ||
          errorMsg.contains('ERR_NAME_NOT_RESOLVED') ||
          errorMsg.contains('Connection refused')) {
        errorMsg =
            'Cannot connect to backend server at http://localhost:8000. '
            'Please ensure the backend is running.';
      }

      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Freshness Monitoring'),
            Text(
              'Device: $_currentDeviceId',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: scheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_location),
            onPressed: _isLoading ? null : _showDeviceSelector,
            tooltip: 'Change device',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading
                ? null
                : () => _loadFreshnessData(forceRefresh: true),
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView(scheme)
          : _buildContent(scheme),
    );
  }

  Widget _buildErrorView(ColorScheme scheme) {
    final errorMsg = _errorMessage ?? '';
    final is404 =
        errorMsg.contains('No data found') ||
        errorMsg.contains('404') ||
        errorMsg.toLowerCase().contains('not found');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              is404 ? Icons.sensors_off : Icons.error_outline,
              size: 64,
              color: is404 ? scheme.primary : scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              is404 ? 'No Data Available' : 'Error Loading Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: is404 ? scheme.onSurface : scheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _loadFreshnessData(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeviceSelector() async {
    final TextEditingController controller = TextEditingController(
      text: _currentDeviceId,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Device ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Device ID',
            hintText: 'e.g., device_001',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(context).pop(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Load'),
          ),
        ],
      ),
    );

    if (result != null && result != _currentDeviceId) {
      setState(() {
        _currentDeviceId = result;
      });
      await _loadFreshnessData(forceRefresh: true);
    }
  }

  Widget _buildContent(ColorScheme scheme) {
    if (_latestReading == null || _prediction == null) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadFreshnessData(forceRefresh: true),
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

  Widget _buildFreshnessScoreCard(ColorScheme scheme) {
    final score = _prediction!.freshnessScore;
    final scoreColor = score >= 70
        ? Colors.green
        : score >= 40
        ? Colors.orange
        : Colors.red;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.local_florist, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Freshness Score',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
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
                Column(
                  children: [
                    Text(
                      score.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      '/ 100',
                      style: TextStyle(
                        fontSize: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getFreshnessStatus(score),
              style: TextStyle(
                fontSize: 16,
                color: scoreColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaseLifeCard(ColorScheme scheme) {
    final hours = _prediction!.vaseLifeHours;
    final days = (hours / 24).toStringAsFixed(1);

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
                  Text(
                    'Estimated Vase Life',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$days days',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    '(${hours.toStringAsFixed(1)} hours)',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
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

  Widget _buildSensorReadingsCard(ColorScheme scheme) {
    final reading = _latestReading!;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sensors, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Sensor Readings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSensorRow(
              scheme,
              Icons.thermostat,
              'Temperature',
              '${reading.temperature.toStringAsFixed(1)}°C',
              reading.temperature >= 15 && reading.temperature <= 25
                  ? Colors.green
                  : Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildSensorRow(
              scheme,
              Icons.water_drop,
              'Humidity',
              '${reading.humidity.toStringAsFixed(1)}%',
              reading.humidity >= 40 && reading.humidity <= 80
                  ? Colors.green
                  : Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildSensorRow(
              scheme,
              Icons.air,
              'Gas Value',
              reading.gasValue.toStringAsFixed(1),
              reading.gasValue < 100 ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 12),
            _buildSensorRow(
              scheme,
              Icons.water,
              'Water Level',
              '${reading.waterLevel}%',
              reading.waterLevel >= 20 ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            Divider(color: scheme.outline),
            const SizedBox(height: 8),
            Text(
              'Last Updated: ${_formatTimestamp(reading.timestamp)}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorRow(
    ColorScheme scheme,
    IconData icon,
    String label,
    String value,
    Color statusColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
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
            Row(
              children: [
                Icon(Icons.warning, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Text(
                  'Alerts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._prediction!.alerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: scheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alert,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFreshnessStatus(double score) {
    if (score >= 70) {
      return 'Excellent';
    } else if (score >= 40) {
      return 'Good';
    } else {
      return 'Needs Attention';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    // Use UTC for comparison to avoid timezone issues
    final now = DateTime.now().toUtc();
    final timestampUtc = timestamp.isUtc ? timestamp : timestamp.toUtc();
    final difference = now.difference(timestampUtc);

    // Handle negative differences (future timestamps)
    if (difference.isNegative) {
      final absDiff = -difference;
      if (absDiff.inMinutes < 1) {
        return 'In a moment';
      } else if (absDiff.inMinutes < 60) {
        return 'In ${absDiff.inMinutes} minutes';
      } else if (absDiff.inHours < 24) {
        return 'In ${absDiff.inHours} hours';
      } else {
        return 'In ${absDiff.inDays} days';
      }
    }

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}
