// File: lib/features/inm/services/inm_api_service.dart
// Purpose: API service for fetching INM sensor readings from backend

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/inm_sensor_reading.dart';
import '../models/inm_status.dart';

class InmApiService {
  // Base URL for the backend API
  static const String _baseUrl = 'http://localhost:8000/api/v1/inm';

  /// Fetches all sensor readings from the backend
  /// Returns a list of [InmSensorReading] sorted by timestamp (newest first)
  Future<List<InmSensorReading>> fetchAllReadings() async {
    // Fetch all data - add cache-busting timestamp
    final String url = '$_baseUrl/sensor-data?_t=${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      debugPrint('🔄 INM: Fetching sensor data from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
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

        debugPrint('📊 INM: Received ${dataList.length} records from backend');

        // Debug: Print first and last raw timestamps
        if (dataList.isNotEmpty) {
          final firstItem = dataList.first as Map<String, dynamic>;
          final lastItem = dataList.last as Map<String, dynamic>;
          debugPrint('🕐 INM: First record timestamp: "${firstItem['timestamp']}"');
          debugPrint('🕐 INM: Last record timestamp: "${lastItem['timestamp']}"');
        }

        // Parse readings
        final readings = dataList
            .map((json) => InmSensorReading.fromJson(json as Map<String, dynamic>))
            .toList();

        // Sort by timestamp descending (newest first), null timestamps go to end
        readings.sort((a, b) {
          if (a.timestamp == null && b.timestamp == null) return 0;
          if (a.timestamp == null) return 1;
          if (b.timestamp == null) return -1;
          return b.timestamp!.compareTo(a.timestamp!);
        });

        // Debug: Print newest and oldest after sorting
        if (readings.isNotEmpty) {
          debugPrint('✅ INM: After sorting - Newest: ${readings.first.formattedTime}');
          debugPrint('✅ INM: After sorting - Oldest: ${readings.last.formattedTime}');
        }

        debugPrint('✅ INM: Total ${readings.length} readings ready');
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

  /// Fetches the current INM status with EC values and recommendation
  Future<InmStatus> fetchStatus() async {
    final String url = '$_baseUrl/status?_t=${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      debugPrint('🔄 INM: Fetching status from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      debugPrint('📡 INM: Status response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        
        // Handle wrapped response format
        Map<String, dynamic> statusData;
        if (decoded is Map<String, dynamic>) {
          statusData = decoded['data'] ?? decoded;
        } else {
          throw Exception('Invalid response format');
        }
        
        final status = InmStatus.fromJson(statusData);
        debugPrint('✅ INM: Status fetched - EC: ${status.currentEc}, Predicted: ${status.predictedEc24h}');
        return status;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ INM: Exception fetching status: $e');
      rethrow;
    }
  }
}

