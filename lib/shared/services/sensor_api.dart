import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/sensor_reading.dart';
import 'api_service.dart';

class SensorApi {
  SensorApi({ApiService? apiService, this.defaultBasestationId = 'basestation_01'})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;
  final String defaultBasestationId;

  Future<SensorReading?> fetchLatest({String? sensorId}) async {
    // No latest endpoint; use list with limit=1 (already sorted newest-first server-side).
    final List<SensorReading> list = await fetchHistory(
      limit: 1,
      sensorId: sensorId,
    );
    return list.isNotEmpty ? list.first : null;
  }

  Future<List<SensorReading>> fetchHistory({
    int limit = 100,
    String? sensorId,
  }) async {
    final Map<String, String> query = <String, String>{
      'limit': '$limit',
      if (sensorId != null) 'basestationId': sensorId,
    };
    // Start of EOSM
    final Uri uri = _apiService.uri('/eosm-data/', query: query);
    // End of EOSM
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


