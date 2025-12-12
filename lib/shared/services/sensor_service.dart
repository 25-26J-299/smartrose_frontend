import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/sensor_data.dart';
import 'api_service.dart';

// Start of EOSM
class SensorService {
  SensorService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<List<SensorReading>> fetchLatestReadings({int limit = 20}) async {
    try {
      // Start of EOSM
      final http.Response response = await _apiService.get(
        '/eosm-data/',
        query: <String, String>{'limit': '$limit'},
      );
      // End of EOSM

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic>? body = _apiService.decodeJson(response);
        final dynamic data = body?['data'];
        final List<dynamic> items = _extractItems(data);

        if (items.isNotEmpty) {
          return items
              .map(
                (dynamic item) => SensorReading.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList();
        }
      }
    } catch (err) {
      debugPrint('SensorService.fetchLatestReadings failed: $err');
    }

    return _demoReadings();
  }

  List<dynamic> _extractItems(dynamic data) {
    if (data is List<dynamic>) return data;
    if (data is Map<String, dynamic>) {
      final dynamic items = data['items'] ?? data['results'] ?? data['readings'];
      if (items is List<dynamic>) return items;
    }
    return <dynamic>[];
  }

  List<SensorReading> _demoReadings() {
    final DateTime now = DateTime.now().toUtc();
    return <SensorReading>[
      SensorReading(
        id: 'demo-1',
        sensorId: 'gateway-001',
        timestamp: now.subtract(const Duration(minutes: 1)),
        receivedAt: now,
        temperature: 23.6,
        humidity: 58.0,
        uvRaw: 112,
        uvVoltage: 0.94,
        soilRaw: 481,
        soilVoltage: 2.3,
        mqRaw: 52,
        mqVoltage: 0.41,
      ),
      SensorReading(
        id: 'demo-2',
        sensorId: 'gateway-001',
        timestamp: now.subtract(const Duration(minutes: 6)),
        receivedAt: now.subtract(const Duration(minutes: 5)),
        temperature: 23.1,
        humidity: 59.0,
        uvRaw: 118,
        uvVoltage: 0.98,
        soilRaw: 489,
        soilVoltage: 2.35,
        mqRaw: 49,
        mqVoltage: 0.39,
      ),
      SensorReading(
        id: 'demo-3',
        sensorId: 'gateway-001',
        timestamp: now.subtract(const Duration(minutes: 12)),
        receivedAt: now.subtract(const Duration(minutes: 11)),
        temperature: 22.8,
        humidity: 60.0,
        uvRaw: 121,
        uvVoltage: 1.01,
        soilRaw: 497,
        soilVoltage: 2.38,
        mqRaw: 47,
        mqVoltage: 0.37,
      ),
    ];
  }
}
// End of EOSM
