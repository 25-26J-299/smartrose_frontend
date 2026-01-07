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

  /// Fetch latest sensor readings with optional filtering
  Future<List<EdasSensorReading>> fetchLatestReadings({
    int limit = 20,
    String? greenhouseId,
  }) async {
    try {
      final Map<String, String> query = <String, String>{
        'limit': '$limit',
        if (greenhouseId != null && greenhouseId != 'ALL')
          'greenhouseId': greenhouseId,
      };

      final http.Response response = await _apiService.get(
        '/edas-data/',
        query: query,
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
    int limit = 100,
    String? greenhouseId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String? formatDate(DateTime? date) {
      if (date == null) return null;
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    final Map<String, String> query = <String, String>{
      'limit': '$limit',
      if (greenhouseId != null && greenhouseId != 'ALL')
        'greenhouseId': greenhouseId,
      if (startDate != null) 'startDate': formatDate(startDate)!,
      if (endDate != null) 'endDate': formatDate(endDate)!,
    };

    final Uri uri = _apiService.uri('/edas-data/', query: query);

    try {
      final http.Response response = await _apiService.getUri(uri);
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
  /// This ensures we always get the most recent record for the summary cards
  Future<EdasSensorReading?> fetchLatestSensorData({
    String? greenhouseId,
  }) async {
    try {
      final Map<String, String> query = <String, String>{};
      if (greenhouseId != null && greenhouseId != 'ALL') {
        query['greenhouseId'] = greenhouseId;
      }

      // Try the dedicated latest-sensor-data endpoint first
      final Uri latestUri = _apiService.uri('/edas-data/latest-sensor-data', query: query);
      final http.Response latestResponse = await _apiService.getUri(latestUri);
      
      if (latestResponse.statusCode >= 200 && latestResponse.statusCode < 300) {
        final Map<String, dynamic>? body = _apiService.decodeJson(latestResponse);
        if (body != null) {
          final dynamic data = body['data'] ?? body['reading'] ?? body;
          if (data is Map<String, dynamic>) {
            return EdasSensorReading.fromJson(data);
          } else if (data is List && data.isNotEmpty) {
            return EdasSensorReading.fromJson(data[0] as Map<String, dynamic>);
          }
        }
      }
      
      // Fallback: fetch with limit=1 to get the latest
      final List<EdasSensorReading> readings = await fetchLatestReadings(
        limit: 1,
        greenhouseId: greenhouseId,
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
    String? greenhouseId,
  }) async {
    final Map<String, String> query = <String, String>{};
    if (greenhouseId != null && greenhouseId != 'ALL') {
      query['greenhouseId'] = greenhouseId;
    }

    final Uri uri =
        _apiService.uri('/edas-data/latest-with-prediction', query: query);

    try {
      final http.Response response = await _apiService.getUri(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic>? body = _apiService.decodeJson(response);
        return body;
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

