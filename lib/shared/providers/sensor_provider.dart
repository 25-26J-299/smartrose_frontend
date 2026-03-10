import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sensor_reading.dart';
import '../models/eosm_stress_prediction.dart';
import '../models/eosm_energy_optimization.dart';
import '../services/sensor_api.dart';

// Start of EOSM
class SensorProvider extends ChangeNotifier {
  SensorProvider({SensorApi? api}) : _api = api ?? SensorApi();

  final SensorApi _api;

  List<SensorReading> _readings = <SensorReading>[]; // all readings (all devices)
  SensorReading? _latest;
  EosmStressPrediction? _latestPrediction;
  EosmEnergyOptimization? _latestEnergyOptimization;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;
  String? _selectedDeviceId; // null = not set; 'ALL' = aggregate
  String? _token; // JWT for authenticated EOSM API calls

  List<SensorReading> get readings => _readings;
  SensorReading? get latest => _latest;
  EosmStressPrediction? get latestPrediction => _latestPrediction;
  EosmEnergyOptimization? get latestEnergyOptimization => _latestEnergyOptimization;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedDeviceId => _selectedDeviceId;

  /// Unique sorted device serials from loaded readings (e.g. SR-EOSM-20250310).
  List<String> get availableDeviceIds {
    final Set<String> ids = _readings
        .map((SensorReading r) => r.deviceId)
        .whereType<String>()
        .where((String id) => id.isNotEmpty)
        .toSet();
    final List<String> sorted = ids.toList()..sort();
    return sorted;
  }

  /// Map of deviceId -> base station serial (first seen).
  Map<String, String?> get deviceBaseStations {
    final Map<String, String?> map = <String, String?>{};
    for (final SensorReading r in _readings) {
      final String? dId = r.deviceId;
      if ((dId ?? '').isNotEmpty && !map.containsKey(dId)) {
        map[dId!] = r.basestationId;
      }
    }
    return map;
  }

  /// Latest reading respecting selection. If "ALL" or unset, uses overall latest.
  SensorReading? get latestForSelected {
    if (_readings.isEmpty) return null;
    if (_selectedDeviceId == 'ALL' || _selectedDeviceId == null) {
      return _latest ?? _readings.first;
    }
    return _readings.firstWhere(
      (SensorReading r) => r.deviceId == _selectedDeviceId,
      orElse: () => _latest ?? _readings.first,
    );
  }

  /// History respecting selection. "ALL" returns capped list for UI.
  List<SensorReading> get readingsForSelected {
    if (_readings.isEmpty) return <SensorReading>[];
    if (_selectedDeviceId == 'ALL' || _selectedDeviceId == null) {
      return _readings.take(50).toList();
    }
    return _readings
        .where((SensorReading r) => r.deviceId == _selectedDeviceId)
        .take(50)
        .toList();
  }

  void setSelectedDevice(String? id) {
    _selectedDeviceId = (id == null || id.isEmpty) ? 'ALL' : id;
    unawaited(refresh(force: true));
  }

  /// Set the JWT token for authenticated API calls (e.g. from AuthState).
  void setToken(String? token) {
    _token = token;
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
    if (_refreshTimer != null) return; // already running
    await refresh(force: true);
    _refreshTimer = Timer.periodic(interval, (_) => refresh(force: true));
  }

  Future<void> refresh({bool force = false, int historyLimit = 120}) async {
    if (_isLoading && !force) return;

    _isLoading = true;
    _errorMessage = null;
    if (!force) notifyListeners();

    try {
      // Fetch latest sensor data and prediction together
      final String? devId = _selectedDeviceId == 'ALL' ? null : _selectedDeviceId;
      final Map<String, dynamic>? latestWithPrediction = await _api.fetchLatestWithPrediction(
        deviceId: devId,
        token: _token,
      );

      if (latestWithPrediction != null) {
        // Update latest reading from the response
        final dynamic readingData = latestWithPrediction['reading'];
        if (readingData != null) {
          _latest = SensorReading.fromJson(readingData as Map<String, dynamic>);
        }

        // Update prediction from the response
        final dynamic predictionData = latestWithPrediction['prediction'];
        if (predictionData != null) {
          _latestPrediction = EosmStressPrediction.fromJson(
            predictionData as Map<String, dynamic>,
          );
          debugPrint('SensorProvider: Prediction updated - ${_latestPrediction?.stressLabel}');
        } else {
          _latestPrediction = null;
          debugPrint('SensorProvider: No prediction in response');
        }

        // Update energy optimization from the response
        final dynamic energyData = latestWithPrediction['energy_optimization'];
        if (energyData != null) {
          _latestEnergyOptimization = EosmEnergyOptimization.fromJson(
            energyData as Map<String, dynamic>,
          );
        } else {
          _latestEnergyOptimization = null;
        }
      }

      // Always fetch history for trends (regardless of latest-with-prediction result)
      final List<SensorReading> history =
          await _api.fetchHistory(limit: historyLimit, token: _token);
      if (history.isNotEmpty) {
        _readings = history;
        // Update _latest if we got it from latest-with-prediction, otherwise use first from history
        if (_latest == null) {
          _latest = history.first;
        } else {
          // Ensure latest is at the front of the list if it's not already there
          _readings.remove(_latest);
          _readings.insert(0, _latest!);
        }
      } else {
        if (_latest != null) {
          _readings = <SensorReading>[_latest!];
        } else {
          _latest = null;
          _readings = <SensorReading>[];
          _errorMessage = 'No sensor readings available yet.';
        }
      }

      // Initialize default selection to 'ALL'
      _selectedDeviceId ??= 'ALL';
    } catch (err) {
      debugPrint('SensorProvider.refresh error: $err');
      _errorMessage = 'Unable to load sensor data. Please try again.';
      _latestPrediction = null;
      _latestEnergyOptimization = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<List<SensorReading>> fetchHistoryForDateRange({
    DateTime? startDate,
    DateTime? endDate,
    String? deviceId,
    int limit = 1000,
  }) async {
    try {
      // Convert Sri Lanka dates to UTC date ranges for backend filtering
      // Sri Lanka is UTC+5:30
      // Dec 1 00:00:00 SL = Nov 30 18:30:00 UTC
      // Dec 1 23:59:59 SL = Dec 1 18:29:59 UTC
      // So for Dec 1 SL, query backend with Nov 30 to Dec 2 (UTC dates) to ensure we capture all data
      DateTime? utcStartDate;
      DateTime? utcEndDate;
      
      if (startDate != null) {
        // Start of selected day in Sri Lanka = previous day 18:30 UTC
        // To be safe, use previous day (backend will use 00:00 UTC of that day)
        utcStartDate = DateTime(startDate.year, startDate.month, startDate.day).subtract(const Duration(days: 1));
      }
      
      if (endDate != null) {
        // endDate is stored as next day (exclusive) in Sri Lanka time
        // If user selected Dec 1, endDate is Dec 2
        // We want to include up to Dec 1 23:59:59 SL = Dec 1 18:29:59 UTC
        // So use endDate - 1 day, which gives us Dec 1
        // Backend will interpret "2025-12-01" as Dec 1 23:59:59 UTC, which is perfect
        final DateTime actualEndDate = endDate.subtract(const Duration(days: 1));
        utcEndDate = DateTime(actualEndDate.year, actualEndDate.month, actualEndDate.day);
      }

      final int fetchLimit = limit.clamp(1, 2000);
      final List<SensorReading> history = await _api.fetchHistory(
        limit: fetchLimit,
        startDate: utcStartDate,
        endDate: utcEndDate,
        token: _token,
      );

      // Client-side filtering by date in Sri Lanka timezone
      List<SensorReading> filtered = history;
      
      if (startDate != null || endDate != null) {
        filtered = filtered.where((SensorReading r) {
          // Backend sends IST time directly, so use displayTime as-is
          final DateTime slTime = r.displayTime;
          // Extract just the date part (year, month, day) in Sri Lanka time
          final int slYear = slTime.year;
          final int slMonth = slTime.month;
          final int slDay = slTime.day;
          
          if (startDate != null && endDate != null) {
            // Both dates provided - endDate is stored as next day (exclusive)
            final int startYear = startDate.year;
            final int startMonth = startDate.month;
            final int startDay = startDate.day;
            
            final int endYear = endDate.year;
            final int endMonth = endDate.month;
            final int endDay = endDate.day;
            
            // Check if reading date is >= startDate and < endDate (in Sri Lanka time)
            final bool afterStart = slYear > startYear ||
                (slYear == startYear && slMonth > startMonth) ||
                (slYear == startYear && slMonth == startMonth && slDay >= startDay);
            
            final bool beforeEnd = slYear < endYear ||
                (slYear == endYear && slMonth < endMonth) ||
                (slYear == endYear && slMonth == endMonth && slDay < endDay);
            
            return afterStart && beforeEnd;
          } else if (startDate != null) {
            final int startYear = startDate.year;
            final int startMonth = startDate.month;
            final int startDay = startDate.day;
            
            return slYear > startYear ||
                (slYear == startYear && slMonth > startMonth) ||
                (slYear == startYear && slMonth == startMonth && slDay >= startDay);
          } else if (endDate != null) {
            // endDate is stored as next day (exclusive)
            final int endYear = endDate.year;
            final int endMonth = endDate.month;
            final int endDay = endDate.day;
            
            return slYear < endYear ||
                (slYear == endYear && slMonth < endMonth) ||
                (slYear == endYear && slMonth == endMonth && slDay < endDay);
          }
          return true;
        }).toList();
      }

      // Filter by device serial
      if (deviceId != null && deviceId != 'ALL') {
        filtered = filtered.where((SensorReading r) => r.deviceId == deviceId).toList();
      }
      
      // Sort by timestamp descending (newest first)
      filtered.sort((a, b) => b.displayTime.compareTo(a.displayTime));
      
      // Limit results
      return filtered.take(limit).toList();
    } catch (err) {
      debugPrint('SensorProvider.fetchHistoryForDateRange error: $err');
      return <SensorReading>[];
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
// End of EOSM
