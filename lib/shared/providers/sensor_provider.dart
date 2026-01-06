import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sensor_reading.dart';
import '../models/eosm_stress_prediction.dart';
import '../services/sensor_api.dart';

// Start of EOSM
class SensorProvider extends ChangeNotifier {
  SensorProvider({SensorApi? api, this.basestationId = 'basestation_01'})
      : _api = api ?? SensorApi(defaultBasestationId: basestationId);

  final SensorApi _api;
  final String basestationId;

  List<SensorReading> _readings = <SensorReading>[]; // all readings (all greenhouses)
  SensorReading? _latest;
  EosmStressPrediction? _latestPrediction;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;
  String? _selectedGreenhouseId; // null = not set; 'ALL' = aggregate

  List<SensorReading> get readings => _readings;
  SensorReading? get latest => _latest;
  EosmStressPrediction? get latestPrediction => _latestPrediction;
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
    // Refresh data for the newly selected greenhouse
    unawaited(refresh(force: true));
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
      // Fetch latest sensor data and prediction together
      // This ensures we always get the absolute latest reading from the database
      final String? ghId = _selectedGreenhouseId == 'ALL' ? null : _selectedGreenhouseId;
      final Map<String, dynamic>? latestWithPrediction = await _api.fetchLatestWithPrediction(
        basestationId: null, // Let backend find the latest regardless of basestation
        greenhouseId: ghId,
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
      }

      // Always fetch history for trends (regardless of latest-with-prediction result)
      final List<SensorReading> history =
          await _api.fetchHistory(sensorId: null, limit: historyLimit);
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

      // Initialize default selection to 'ALL' as requested
      _selectedGreenhouseId ??= 'ALL';
    } catch (err) {
      debugPrint('SensorProvider.refresh error: $err');
      _errorMessage = 'Unable to load sensor data. Please try again.';
      _latestPrediction = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<List<SensorReading>> fetchHistoryForDateRange({
    DateTime? startDate,
    DateTime? endDate,
    String? greenhouseId,
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

      // Backend has a maximum limit of 2000, so cap at that
      final int fetchLimit = limit.clamp(1, 2000);
      final List<SensorReading> history = await _api.fetchHistory(
        sensorId: null,
        limit: fetchLimit,
        startDate: utcStartDate,
        endDate: utcEndDate,
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

      // Filter by greenhouse
      if (greenhouseId != null && greenhouseId != 'ALL') {
        filtered = filtered.where((SensorReading r) => r.greenhouseId == greenhouseId).toList();
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
