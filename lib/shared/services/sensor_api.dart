import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/sensor_reading.dart';
import 'api_service.dart';

class SensorApi {
  SensorApi({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<SensorReading?> fetchLatest({String? deviceId}) async {
    final List<SensorReading> list = await fetchHistory(limit: 1, deviceId: deviceId);
    return list.isNotEmpty ? list.first : null;
  }

  Future<List<SensorReading>> fetchHistory({
    int limit = 100,
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
      if (deviceId != null) 'deviceId': deviceId,
      if (startDate != null) 'startDate': formatDate(startDate)!,
      if (endDate != null) 'endDate': formatDate(endDate)!,
    };
    // Start of EOSM
    final Uri uri = _apiService.uri('/eosm-data/', query: query);
    
    try {
      final http.Response response = await _apiService.getUri(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic>? body = _apiService.decodeJson(response);
        final dynamic data = body?['data'];
        final List<dynamic> items = _extractItems(data);
        return items
            .map((dynamic e) => SensorReading.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (err) {
      debugPrint('SensorApi.fetchHistory error: $err');
    }
    return <SensorReading>[];
  }

  /// Fetch latest sensor reading with its ML prediction
  Future<Map<String, dynamic>?> fetchLatestWithPrediction({
    String? deviceId,
  }) async {
    // Start of EOSM
    final Map<String, String> query = <String, String>{};
    if (deviceId != null) query['deviceId'] = deviceId;

    final Uri uri = _apiService.uri('/eosm-data/latest-with-prediction', query: query);

    try {
      final http.Response response = await _apiService.getUri(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic>? body = _apiService.decodeJson(response);
        final dynamic data = body?['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
    } catch (err) {
      debugPrint('SensorApi.fetchLatestWithPrediction error: $err');
    }
    return null;
    // End of EOSM
  }

  List<dynamic> _extractItems(dynamic data) {
    if (data is List<dynamic>) return data;
    if (data is Map<String, dynamic>) {
      final dynamic items = data['items'] ?? data['results'] ?? data['readings'];
      if (items is List<dynamic>) return items;
    }
    return <dynamic>[];
  }
}
// End of EOSM


