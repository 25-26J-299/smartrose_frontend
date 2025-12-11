import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/sensor_reading.dart';
import 'api_service.dart';

class SensorApi {
  SensorApi({ApiService? apiService, this.defaultSensorId = 'gateway_01'})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;
  final String defaultSensorId;

  Future<SensorReading?> fetchLatest({String? sensorId}) async {
    final String id = sensorId ?? defaultSensorId;
    final Uri uri = _apiService.uri('/sensor-data/latest', query: <String, String>{
      'sensorId': id,
    });
    try {
      final http.Response response = await _apiService.getUri(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic>? body = _apiService.decodeJson(response);
        final dynamic data = body?['data'] ?? body?['reading'] ?? body;
        if (data is Map<String, dynamic>) {
          return SensorReading.fromJson(data);
        }
      }
    } catch (err) {
      debugPrint('SensorApi.fetchLatest error: $err');
    }
    return null;
  }

  Future<List<SensorReading>> fetchHistory({int limit = 100, String? sensorId}) async {
    final String id = sensorId ?? defaultSensorId;
    final Uri uri = _apiService.uri('/sensor-data', query: <String, String>{
      'limit': '$limit',
      'sensorId': id,
    });
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

