import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sensor_reading.dart';
import '../services/sensor_api.dart';

class SensorProvider extends ChangeNotifier {
  SensorProvider({SensorApi? api, this.sensorId = 'gateway_01'})
      : _api = api ?? SensorApi(defaultSensorId: sensorId);

  final SensorApi _api;
  final String sensorId;

  List<SensorReading> _readings = <SensorReading>[];
  SensorReading? _latest;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;

  List<SensorReading> get readings => _readings;
  SensorReading? get latest => _latest;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double? get averageTemperature {
    if (_readings.isEmpty) return null;
    final double sum = _readings.fold<double>(
      0,
      (double acc, SensorReading reading) => acc + reading.temperature,
    );
    return sum / _readings.length;
  }

  double? get averageHumidity {
    if (_readings.isEmpty) return null;
    final double sum = _readings.fold<double>(
      0,
      (double acc, SensorReading reading) => acc + reading.humidity,
    );
    return sum / _readings.length;
  }

  Future<void> startAutoRefresh({Duration interval = const Duration(seconds: 15)}) async {
    await refresh(force: true);
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) => refresh(force: true));
  }

  Future<void> refresh({bool force = false, int historyLimit = 120}) async {
    if (_isLoading && !force) return;

    _isLoading = true;
    _errorMessage = null;
    if (!force) notifyListeners();

    try {
      final SensorReading? latestReading = await _api.fetchLatest(sensorId: sensorId);
      final List<SensorReading> history =
          await _api.fetchHistory(sensorId: sensorId, limit: historyLimit);

      if (latestReading != null) {
        _latest = latestReading;
      } else if (history.isNotEmpty) {
        _latest = history.first;
      }

      if (history.isNotEmpty) {
        _readings = history;
      } else if (_latest != null) {
        _readings = <SensorReading>[_latest!];
      } else {
        _readings = <SensorReading>[];
        _errorMessage = 'No sensor readings available yet.';
      }
    } catch (err) {
      _errorMessage = 'Unable to load sensor data. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
