// File: smartrose_frontend/lib/services/inm_service.dart

// Purpose: Fetch INM sensor readings from common backend API

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';

class INMService {
  /// Fetch all sensor readings
  /// Returns a map with 'success', 'data', and 'error' keys
  Future<Map<String, dynamic>> fetchSensorReadings() async {
    try {
      // Add timestamp to prevent caching and always get fresh data
      final String baseUrl = '${getApiBaseUrl()}/inm/sensor-data';
      final String urlWithCacheBust = '$baseUrl?_t=${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('🔄 Fetching sensor data from: $urlWithCacheBust');
      
      final response = await http.get(
        Uri.parse(urlWithCacheBust),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        
        List<Map<String, dynamic>> readings = [];
        
        // Handle different response formats
        if (decoded is List) {
          // Direct array: [...]
          readings = decoded.map((item) => item as Map<String, dynamic>).toList();
        } else if (decoded is Map<String, dynamic>) {
          // Object with data property: {"data": [...], ...}
          // Try common property names for the array
          final dynamic data = decoded['data'] ?? 
                               decoded['readings'] ?? 
                               decoded['results'] ?? 
                               decoded['items'] ??
                               decoded['sensor_data'];
          
          if (data is List) {
            readings = data.map((item) => item as Map<String, dynamic>).toList();
          } else {
            // If the object itself contains sensor data (single reading)
            readings = [decoded];
          }
          
          debugPrint('📋 Response is an object, extracted ${readings.length} readings');
        }
        
        debugPrint('✅ Successfully fetched ${readings.length} readings');
        return {
          'success': true,
          'data': readings,
          'error': null,
        };
      } else {
        debugPrint('❌ Error fetching sensor readings: ${response.statusCode}');
        return {
          'success': false,
          'data': <Map<String, dynamic>>[],
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('❌ Exception fetching sensor readings: $e');
      return {
        'success': false,
        'data': <Map<String, dynamic>>[],
        'error': e.toString(),
      };
    }
  }
}
