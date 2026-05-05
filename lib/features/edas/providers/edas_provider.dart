import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/edas_models.dart';
import '../services/edas_api_service.dart';

/// Provider for EDAS (Early Disease Alert System) state management
class EdasProvider extends ChangeNotifier {
  EdasProvider({EdasApiService? api})
      : _api = api ?? EdasApiService();

  final EdasApiService _api;

  List<EdasSensorReading> _readings = <EdasSensorReading>[];
  EdasSensorReading? _latest;
  EdasDiseasePrediction? _latestPrediction;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;

  List<EdasSensorReading> get readings => _readings;
  EdasSensorReading? get latest => _latest;
  EdasDiseasePrediction? get latestPrediction => _latestPrediction;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Latest reading - always returns overall latest
  EdasSensorReading? get latestForSelected {
    if (_readings.isEmpty) return null;
    return _latest ?? _readings.first;
  }

  /// History - returns capped list for UI
  List<EdasSensorReading> get readingsForSelected {
    if (_readings.isEmpty) return <EdasSensorReading>[];
    return _readings.take(50).toList();
  }

  double? get averagePlantTemperature {
    final List<EdasSensorReading> source = readingsForSelected;
    if (source.isEmpty) return null;
    final double sum = source.fold<double>(
      0,
      (double acc, EdasSensorReading reading) =>
          acc + reading.plantTemperature,
    );
    return sum / source.length;
  }

  double? get averageAirTemperature {
    final List<EdasSensorReading> source = readingsForSelected;
    if (source.isEmpty) return null;
    final double sum = source.fold<double>(
      0,
      (double acc, EdasSensorReading reading) => acc + reading.airTemperature,
    );
    return sum / source.length;
  }

  double? get averageHumidity {
    final List<EdasSensorReading> source = readingsForSelected;
    if (source.isEmpty) return null;
    final double sum = source.fold<double>(
      0,
      (double acc, EdasSensorReading reading) => acc + reading.humidity,
    );
    return sum / source.length;
  }

  double? get averageTemperatureDifference {
    final List<EdasSensorReading> source = readingsForSelected;
    if (source.isEmpty) return null;
    final double sum = source.fold<double>(
      0,
      (double acc, EdasSensorReading reading) =>
          acc + reading.temperatureDifference,
    );
    return sum / source.length;
  }

  /// [tick] is invoked immediately and on each [interval]; return a [Future] that loads data.
  Future<void> startAutoRefresh({
    Duration interval = const Duration(seconds: 15),
    required Future<void> Function() tick,
  }) async {
    await tick();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) {
      unawaited(tick());
    });
  }

  Future<void> refresh({
    bool force = false,
    int historyLimit = 120,
    required String? token,
    String? greenhouseId,
  }) async {
    if (_isLoading && !force) return;

    if (token == null || token.isEmpty) {
      _errorMessage = 'Please sign in to view disease detection data.';
      _latest = null;
      _readings = <EdasSensorReading>[];
      _latestPrediction = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    if (!force) notifyListeners();

    try {
      final EdasSensorReading? latestSensorData =
          await _api.fetchLatestSensorData(
        token: token,
        greenhouseId: greenhouseId,
      );

      if (latestSensorData != null) {
        _latest = latestSensorData;
        debugPrint(
            'EdasProvider: Latest sensor data updated - Plant: ${_latest!.plantTemperature}°C, Air: ${_latest!.airTemperature}°C, Humidity: ${_latest!.humidity}%');
      }

      final Map<String, dynamic>? latestWithPrediction =
          await _api.fetchLatestWithPrediction(
        token: token,
        greenhouseId: greenhouseId,
      );

      if (latestWithPrediction != null) {
        final dynamic predictionData = latestWithPrediction['prediction'];
        if (predictionData != null) {
          _latestPrediction = EdasDiseasePrediction.fromJson(
              predictionData as Map<String, dynamic>);
          debugPrint(
              'EdasProvider: Prediction updated - ${_latestPrediction?.riskLevel}');
        } else {
          _latestPrediction = null;
          debugPrint('EdasProvider: No prediction in response');
        }

        final dynamic readingData = latestWithPrediction['reading'];
        if (readingData != null) {
          final EdasSensorReading readingFromPrediction =
              EdasSensorReading.fromJson(
                  readingData as Map<String, dynamic>);
          if (_latest == null ||
              readingFromPrediction.timestamp.isAfter(_latest!.timestamp)) {
            _latest = readingFromPrediction;
            debugPrint(
                'EdasProvider: Updated to newer reading from prediction endpoint');
          }
        }
      }

      final List<EdasSensorReading> history = await _api.fetchHistory(
        token: token,
        greenhouseId: greenhouseId,
        limit: historyLimit,
      );
      if (history.isNotEmpty) {
        final List<EdasSensorReading> newReadings =
            List<EdasSensorReading>.from(history);
        if (_latest != null) {
          newReadings.removeWhere((EdasSensorReading r) =>
              r.id == _latest!.id && r.timestamp == _latest!.timestamp);
          newReadings.insert(0, _latest!);
          _readings = newReadings;
        } else {
          _latest = newReadings.first;
          _readings = newReadings;
        }
      } else {
        if (_latest != null) {
          _readings = <EdasSensorReading>[_latest!];
        } else {
          _latest = null;
          _readings = <EdasSensorReading>[];
          _errorMessage = 'No sensor readings available yet.';
        }
      }
    } catch (err) {
      debugPrint('EdasProvider.refresh error: $err');
      _errorMessage = 'Unable to load sensor data. Please try again.';
      _latestPrediction = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<EdasSensorReading>> fetchHistoryForDateRange({
    required String? token,
    DateTime? startDate,
    DateTime? endDate,
    String? greenhouseId,
    int limit = 1000,
  }) async {
    if (token == null || token.isEmpty) {
      return <EdasSensorReading>[];
    }
    try {
      DateTime? utcStartDate;
      DateTime? utcEndDate;

      if (startDate != null) {
        utcStartDate = DateTime(startDate.year, startDate.month, startDate.day)
            .subtract(const Duration(days: 1));
      }

      if (endDate != null) {
        final DateTime actualEndDate =
            endDate.subtract(const Duration(days: 1));
        utcEndDate = DateTime(
            actualEndDate.year, actualEndDate.month, actualEndDate.day);
      }

      final int fetchLimit = limit.clamp(1, 2000);
      final List<EdasSensorReading> history = await _api.fetchHistory(
        token: token,
        greenhouseId: greenhouseId == 'ALL' ? null : greenhouseId,
        limit: fetchLimit,
        startDate: utcStartDate,
        endDate: utcEndDate,
      );

      List<EdasSensorReading> filtered = history;

      if (startDate != null || endDate != null) {
        filtered = filtered.where((EdasSensorReading r) {
          final DateTime slTime = r.displayTime;
          final int slYear = slTime.year;
          final int slMonth = slTime.month;
          final int slDay = slTime.day;

          if (startDate != null && endDate != null) {
            final int startYear = startDate.year;
            final int startMonth = startDate.month;
            final int startDay = startDate.day;

            final int endYear = endDate.year;
            final int endMonth = endDate.month;
            final int endDay = endDate.day;

            final bool afterStart = slYear > startYear ||
                (slYear == startYear && slMonth > startMonth) ||
                (slYear == startYear &&
                    slMonth == startMonth &&
                    slDay >= startDay);

            final bool beforeEnd = slYear < endYear ||
                (slYear == endYear && slMonth < endMonth) ||
                (slYear == endYear &&
                    slMonth == endMonth &&
                    slDay < endDay);

            return afterStart && beforeEnd;
          } else if (startDate != null) {
            final int startYear = startDate.year;
            final int startMonth = startDate.month;
            final int startDay = startDate.day;

            return slYear > startYear ||
                (slYear == startYear && slMonth > startMonth) ||
                (slYear == startYear &&
                    slMonth == startMonth &&
                    slDay >= startDay);
          } else if (endDate != null) {
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

      if (greenhouseId != null && greenhouseId != 'ALL') {
        filtered = filtered
            .where((EdasSensorReading r) => r.greenhouseId == greenhouseId)
            .toList();
      }

      filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return filtered.take(limit).toList();
    } catch (err) {
      debugPrint('EdasProvider.fetchHistoryForDateRange error: $err');
      return <EdasSensorReading>[];
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
