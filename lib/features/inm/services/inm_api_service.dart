// File: lib/features/inm/services/inm_api_service.dart
// Purpose: API service for fetching INM sensor readings from backend

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/inm_sensor_reading.dart';

class InmApiService {
  // Base URL for the backend API
  static const String _baseUrl = 'http://localhost:8000/api/v1/inm';

  /// Fetches all sensor readings from the backend
  /// Returns a list of [InmSensorReading] sorted by timestamp (newest first)
  Future<List<InmSensorReading>> fetchAllReadings() async {
    final String url = '$_baseUrl/sensor-data';
    
    try {
      debugPrint('🔄 INM: Fetching sensor data from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint('📡 INM: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> dataList = [];

        // Handle different response formats
        if (decoded is List) {
          dataList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          dataList = decoded['data'] ?? 
                     decoded['readings'] ?? 
                     decoded['results'] ?? 
                     decoded['items'] ??
                     decoded['sensor_data'] ?? 
                     [decoded];
        }

        // Parse readings
        final readings = dataList
            .map((json) => InmSensorReading.fromJson(json as Map<String, dynamic>))
            .toList();

        // Sort by timestamp descending (newest first)
        readings.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        debugPrint('✅ INM: Successfully fetched ${readings.length} readings');
        return readings;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ INM: Exception fetching sensor readings: $e');
      rethrow;
    }
  }

  /// Gets only the latest (most recent) sensor reading
  Future<InmSensorReading?> fetchLatestReading() async {
    final readings = await fetchAllReadings();
    return readings.isNotEmpty ? readings.first : null;
  }
}

