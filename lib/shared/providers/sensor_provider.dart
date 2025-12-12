import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sensor_reading.dart';
import '../services/sensor_api.dart';
import '../utils/collection_extensions.dart';

class SensorProvider extends ChangeNotifier {
  SensorProvider({SensorApi? api, this.basestationId = 'basestation_01'})
      : _api = api ?? SensorApi(defaultBasestationId: basestationId);

  final SensorApi _api;
  final String basestationId;

  List<SensorReading> _readings = <SensorReading>[]; // all readings (all greenhouses)
  SensorReading? _latest;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;
  String? _selectedGreenhouseId; // null = not set; 'ALL' = aggregate

  List<SensorReading> get readings => _readings;
  SensorReading? get latest => _latest;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedGreenhouseId => _selectedGreenhouseId;

  /// Unique sorted greenhouse ids from loaded data.
  List<String> get availableGreenhouseIds {
    final Set<String> ids = _readings
        .map((SensorReading r) => r.greenhouseId)
        .whereType<String>()
        .toSet();
    final List<String> sorted = ids.toList()..sort();
    return sorted;
  }

  /// Map of greenhouseId -> basestationId (first seen)
  Map<String, String?> get greenhouseBaseStations {
    final Map<String, String?> map = <String, String?>{};
    for (final SensorReading r in _readings) {
      if ((r.greenhouseId ?? '').isNotEmpty && !map.containsKey(r.greenhouseId)) {
        map[r.greenhouseId!] = r.basestationId;
      }
    }
    return map;
  }

  /// Latest reading respecting selection. If "ALL" or unset, uses overall latest.
  SensorReading? get latestForSelected {
    if (_readings.isEmpty) return null;
    if (_selectedGreenhouseId == 'ALL' || _selectedGreenhouseId == null) {
      return _latest ?? _readings.first;
    }
    return _readings.firstWhere(
      (SensorReading r) => r.greenhouseId == _selectedGreenhouseId,
      orElse: () => _latest ?? _readings.first,
    );
  }

  /// History respecting selection. "ALL" returns capped list for UI.
  List<SensorReading> get readingsForSelected {
    if (_readings.isEmpty) return <SensorReading>[];
    if (_selectedGreenhouseId == 'ALL' || _selectedGreenhouseId == null) {
      return _readings.take(50).toList();
    }
    return _readings
        .where((SensorReading r) => r.greenhouseId == _selectedGreenhouseId)
        .take(50)
        .toList();
  }

  void setSelectedGreenhouse(String? id) {
    _selectedGreenhouseId = (id == null || id.isEmpty) ? 'ALL' : id;
    notifyListeners();
  }

  double? get averageTemperature {
    final List<SensorReading> source = readingsForSelected;
    if (source.isEmpty) return null;
    final double sum = source.fold<double>(
      0,
      (double acc, SensorReading reading) => acc + reading.temperature,
    );
    return sum / source.length;
  }

  double? get averageHumidity {
    final List<SensorReading> source = readingsForSelected;
    if (source.isEmpty) return null;
    final double sum = source.fold<double>(
      0,
      (double acc, SensorReading reading) => acc + reading.humidity,
    );
    return sum / source.length;
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
      final List<SensorReading> history =
          await _api.fetchHistory(sensorId: null, limit: historyLimit);

      if (history.isNotEmpty) {
        _readings = history;
        _latest = history.first;
      } else {
        _latest = null;
        _readings = <SensorReading>[];
        _errorMessage = 'No sensor readings available yet.';
      }

      // Initialize default selection
      _selectedGreenhouseId ??= _latest?.greenhouseId ?? availableGreenhouseIds.firstOrNull ?? 'ALL';
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
