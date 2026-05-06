import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../shared/services/api_service.dart';
import '../models/edas_models.dart';

/// API Service for EDAS (Early Disease Alert System)
/// Fetches sensor data and ML predictions from backend
class EdasApiService {
  EdasApiService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  void _addScopeQueries(
    Map<String, String> query, {
    String? greenhouseId,
    String? deviceId,
  }) {
    if (greenhouseId != null &&
        greenhouseId.isNotEmpty &&
        greenhouseId != 'ALL') {
      query['greenhouseId'] = greenhouseId;
    }
    if (deviceId != null &&
        deviceId.isNotEmpty &&
        deviceId != 'ALL') {
      query['device_id'] = deviceId;
    }
  }

  Map<String, dynamic>? _unwrapData(Map<String, dynamic>? body) {
    if (body == null) return null;
    final dynamic inner = body['data'];
    if (inner is Map<String, dynamic>) {
      return inner;
    }
    return body;
  }

  /// Fetch latest sensor readings with optional filtering (JWT required server-side).
  Future<List<EdasSensorReading>> fetchLatestReadings({
    required String token,
    int limit = 20,
    String? greenhouseId,
    String? deviceId,
  }) async {
    try {
      final Map<String, String> query = <String, String>{
        'limit': '$limit',
      };
      _addScopeQueries(query, greenhouseId: greenhouseId, deviceId: deviceId);

      final http.Response response = await _apiService.get(
        '/edas-data/',
        query: query,
        token: token,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic>? body = _apiService.decodeJson(response);
        final dynamic data = body?['data'] ?? body;
        final List<dynamic> items = _extractItems(data);

        if (items.isNotEmpty) {
          return items
              .map(
                (dynamic item) => EdasSensorReading.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList();
        }
      }
    } catch (err) {
      debugPrint('EdasApiService.fetchLatestReadings failed: $err');
    }

    return <EdasSensorReading>[];
  }

  /// Fetch sensor reading history with date range filtering
  Future<List<EdasSensorReading>> fetchHistory({
    required String token,
    int limit = 100,
    String? greenhouseId,
    String? deviceId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String? formatDate(DateTime? date) {
      if (date == null) return null;
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    final Map<String, String> query = <String, String>{
      'limit': '$limit',
      if (startDate != null) 'startDate': formatDate(startDate)!,
      if (endDate != null) 'endDate': formatDate(endDate)!,
    };
    _addScopeQueries(query, greenhouseId: greenhouseId, deviceId: deviceId);

    final Uri uri = _apiService.uri('/edas-data/', query: query);

    try {
      final http.Response response = await _apiService.getUri(uri, token: token);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic>? body = _apiService.decodeJson(response);
        final dynamic data = body?['data'] ?? body;
        final List<dynamic> items = _extractItems(data);
        return items
            .map((dynamic e) =>
                EdasSensorReading.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (err) {
      debugPrint('EdasApiService.fetchHistory error: $err');
    }
    return <EdasSensorReading>[];
  }

  /// Fetch the latest sensor data record from MongoDB
  Future<EdasSensorReading?> fetchLatestSensorData({
    required String token,
    String? greenhouseId,
    String? deviceId,
  }) async {
    try {
      final Map<String, String> query = <String, String>{};
      _addScopeQueries(query, greenhouseId: greenhouseId, deviceId: deviceId);

      final Uri latestUri =
          _apiService.uri('/edas-data/latest-sensor-data', query: query);
      final http.Response latestResponse =
          await _apiService.getUri(latestUri, token: token);

      if (latestResponse.statusCode >= 200 &&
          latestResponse.statusCode < 300) {
        final Map<String, dynamic>? body =
            _apiService.decodeJson(latestResponse);
        if (body != null) {
          final Map<String, dynamic>? data = _unwrapData(body);
          if (data != null) {
            return EdasSensorReading.fromJson(data);
          }
        }
      }

      final List<EdasSensorReading> readings = await fetchLatestReadings(
        token: token,
        limit: 1,
        greenhouseId: greenhouseId,
        deviceId: deviceId,
      );

      if (readings.isNotEmpty) {
        return readings.first;
      }
    } catch (err) {
      debugPrint('EdasApiService.fetchLatestSensorData error: $err');
    }
    return null;
  }

  /// Fetch latest sensor reading with its ML disease prediction
  Future<Map<String, dynamic>?> fetchLatestWithPrediction({
    required String token,
    String? greenhouseId,
    String? deviceId,
  }) async {
    final Map<String, String> query = <String, String>{};
    _addScopeQueries(query, greenhouseId: greenhouseId, deviceId: deviceId);

    final Uri uri =
        _apiService.uri('/edas-data/latest-with-prediction', query: query);

    try {
      final http.Response response = await _apiService.getUri(uri, token: token);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic>? body = _apiService.decodeJson(response);
        final Map<String, dynamic>? inner = _unwrapData(body);
        if (inner == null) {
          return null;
        }
        return <String, dynamic>{
          ...inner,
          'reading': inner['reading'] ?? inner['sensor_data'],
          'prediction': inner['prediction'],
        };
      }
    } catch (err) {
      debugPrint('EdasApiService.fetchLatestWithPrediction error: $err');
    }
    return null;
  }

  List<dynamic> _extractItems(dynamic data) {
    if (data is List<dynamic>) return data;
    if (data is Map<String, dynamic>) {
      final dynamic items =
          data['items'] ?? data['results'] ?? data['readings'] ?? data['data'];
      if (items is List<dynamic>) return items;
    }
    return <dynamic>[];
  }
}
