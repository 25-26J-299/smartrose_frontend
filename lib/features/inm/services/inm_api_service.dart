// File: lib/features/inm/services/inm_api_service.dart
// Purpose: API service for the INM module.
//
// Multi-user / multi-greenhouse update:
// Every method now requires a [token] (JWT Bearer) and [deviceId].
// The token is used for authentication; the deviceId scopes all queries
// to the specific INM device owned by the logged-in user.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/inm_sensor_reading.dart';
import '../models/inm_status.dart';
import '../models/inm_action_history.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/services/weather_api_service.dart';

class InmApiService {
  static String get _baseUrl => '${getApiBaseUrl()}/inm';

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      };

  String _ts() => DateTime.now().millisecondsSinceEpoch.toString();

  // ---------------------------------------------------------------------------
  // Sensor readings
  // ---------------------------------------------------------------------------

  /// Fetches all sensor readings for [deviceId], newest first.
  Future<List<InmSensorReading>> fetchAllReadings(
    String deviceId,
    String token,
  ) async {
    final url =
        '$_baseUrl/sensor-data?device_id=${Uri.encodeComponent(deviceId)}&_t=${_ts()}';
    try {
      debugPrint('🔄 INM: Fetching sensor data → $url');
      final response = await http.get(Uri.parse(url), headers: _headers(token));
      debugPrint('📡 INM: sensor-data status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> dataList = [];
        if (decoded is List) {
          dataList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          dataList = decoded['data'] ?? decoded['readings'] ?? [];
        }

        final readings = dataList
            .map((j) => InmSensorReading.fromJson(j as Map<String, dynamic>))
            .toList();

        readings.sort((a, b) {
          if (a.timestamp == null && b.timestamp == null) return 0;
          if (a.timestamp == null) return 1;
          if (b.timestamp == null) return -1;
          return b.timestamp!.compareTo(a.timestamp!);
        });

        debugPrint('✅ INM: ${readings.length} readings ready');
        return readings;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ INM: fetchAllReadings error: $e');
      rethrow;
    }
  }

  /// Gets only the most recent sensor reading for [deviceId].
  Future<InmSensorReading?> fetchLatestReading(
      String deviceId, String token) async {
    final readings = await fetchAllReadings(deviceId, token);
    return readings.isNotEmpty ? readings.first : null;
  }

  // ---------------------------------------------------------------------------
  // Status (EC prediction + recommendations)
  // ---------------------------------------------------------------------------

  /// Fetches the current INM status for [deviceId].
  Future<InmStatus> fetchStatus(String deviceId, String token) async {
    final url =
        '$_baseUrl/status?device_id=${Uri.encodeComponent(deviceId)}&_t=${_ts()}';
    try {
      debugPrint('🔄 INM: Fetching status → $url');
      final response = await http.get(Uri.parse(url), headers: _headers(token));
      debugPrint('📡 INM: status response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        Map<String, dynamic> statusData;
        if (decoded is Map<String, dynamic>) {
          statusData = decoded['data'] ?? decoded;
        } else {
          throw Exception('Invalid response format');
        }
        final status = InmStatus.fromJson(statusData);
        debugPrint(
            '✅ INM: Status — EC: ${status.currentEc}, Predicted: ${status.predictedEc24h}');
        return status;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ INM: fetchStatus error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Growth stage
  // ---------------------------------------------------------------------------

  /// Fetches the current growth stage for [deviceId].
  Future<String> fetchGrowthStage(String deviceId, String token) async {
    final url =
        '$_baseUrl/growth-stage?device_id=${Uri.encodeComponent(deviceId)}&_t=${_ts()}';
    try {
      debugPrint('🔄 INM: Fetching growth stage → $url');
      final response = await http.get(Uri.parse(url), headers: _headers(token));
      debugPrint('📡 INM: growth-stage response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is Map) {
            final data = decoded['data'] as Map<String, dynamic>;
            return data['current_growth_stage']?.toString() ?? 'vegetative';
          }
          return decoded['current_growth_stage']?.toString() ??
              decoded['growth_stage']?.toString() ??
              'vegetative';
        }
        return 'vegetative';
      } else if (response.statusCode == 404 || response.statusCode == 405) {
        return 'vegetative';
      } else {
        return 'vegetative';
      }
    } catch (e) {
      debugPrint('❌ INM: fetchGrowthStage error: $e');
      return 'vegetative';
    }
  }

  /// Saves [growthStage] for [deviceId] to the backend.
  Future<bool> saveGrowthStage(
    String deviceId,
    String token,
    String growthStage,
  ) async {
    final url = '$_baseUrl/growth-stage';
    try {
      debugPrint('🔄 INM: Saving growth stage "$growthStage" for $deviceId');
      final body = jsonEncode({
        'growth_stage': growthStage,
        'device_id': deviceId,
      });
      final response = await http.post(
        Uri.parse(url),
        headers: _headers(token),
        body: body,
      );
      debugPrint('📡 INM: save growth-stage response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('❌ INM: saveGrowthStage error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Actions (farmer feedback)
  // ---------------------------------------------------------------------------

  /// Saves a farmer action (applied/ignored) for [deviceId].
  ///
  /// Pass the current [weather] snapshot so the backend records the
  /// environmental context at the moment the farmer made the decision.
  /// This allows the history view and analytics to show why an application
  /// was skipped (weather-driven vs. manual skip).
  Future<bool> saveAction(
    String deviceId,
    String token,
    InmStatus status,
    String actionType, {
    WeatherModel? weather,
  }) async {
    final url = '$_baseUrl/action';
    try {
      debugPrint('🔄 INM: Saving action "$actionType" for device $deviceId');

      final recommendationText =
          'EC Action: ${status.ecAction}\n\npH Action: ${status.phAction}\n\nNPK Recommendation: ${status.npkRecommendation}'
              .trim();

      // Compute the advisory level to record alongside the raw weather values
      String? advisoryLabel;
      if (weather != null) {
        final condition = weather.condition.toLowerCase();
        final isRaining = condition.contains('rain') ||
            condition.contains('drizzle') ||
            condition.contains('thunder') ||
            weather.precipitation > 2.0;
        if (isRaining) {
          advisoryLabel = 'postpone';
        } else if (weather.humidity > 85 || weather.temperature > 33) {
          advisoryLabel = 'caution';
        } else {
          advisoryLabel = 'good';
        }
      }

      final body = jsonEncode({
        'device_id': deviceId,
        'action_taken': actionType,
        'recommendation_text': recommendationText,
        // Store separate fields so history view can show structured rows
        'ec_action': status.ecAction,
        'ph_action': status.phAction,
        'npk_recommendation': status.npkRecommendation,
        if (status.growthStage != null) 'growth_stage': status.growthStage,
        // Weather context – only included when available
        if (weather != null) ...{
          'weather_condition': weather.condition,
          'weather_temperature_c': weather.temperature,
          'weather_humidity_pct': weather.humidity,
          'weather_precipitation_mm': weather.precipitation,
          'weather_advisory': advisoryLabel,
        },
      });

      final response = await http.post(
        Uri.parse(url),
        headers: _headers(token),
        body: body,
      );
      debugPrint('📡 INM: save action response: ${response.statusCode}');
      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('❌ INM: action error body: ${response.body}');
      }
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('❌ INM: saveAction error: $e');
      return false;
    }
  }

  /// Fetches action history for [deviceId].
  Future<List<InmActionHistory>> fetchActionHistory(
    String deviceId,
    String token,
  ) async {
    final url =
        '$_baseUrl/action-history?device_id=${Uri.encodeComponent(deviceId)}&_t=${_ts()}';
    try {
      debugPrint('🔄 INM: Fetching action history → $url');
      final response = await http.get(Uri.parse(url), headers: _headers(token));
      debugPrint('📡 INM: action-history response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> dataList = [];
        if (decoded is List) {
          dataList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          dataList = decoded['data'] ?? decoded['actions'] ?? decoded['history'] ?? [];
        }

        final actions = dataList
            .map((j) => InmActionHistory.fromJson(j as Map<String, dynamic>))
            .toList();
        actions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        debugPrint('✅ INM: ${actions.length} action records ready');
        return actions;
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ INM: fetchActionHistory error: $e');
      return [];
    }
  }
}
