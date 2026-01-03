// File: lib/features/inm/services/inm_api_service.dart
// Purpose: API service for fetching INM sensor readings from backend

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/inm_sensor_reading.dart';
import '../models/inm_status.dart';
import '../models/inm_action_history.dart';

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
        debugPrint('✅ INM: Status fetched - EC: ${status.currentEc}, Predicted: ${status.predictedEc24h}, Growth Stage: ${status.growthStage}');
        return status;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ INM: Exception fetching status: $e');
      rethrow;
    }
  }

  /// Fetches the current growth stage from backend
  Future<String> fetchGrowthStage() async {
    final String url = '$_baseUrl/growth-stage?_t=${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      debugPrint('🔄 INM: Fetching growth stage from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      debugPrint('📡 INM: Growth stage response: ${response.statusCode}');
      debugPrint('📦 INM: Growth stage response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        
        String growthStage;
        if (decoded is Map<String, dynamic>) {
          // Handle wrapped response format: {"status": "ok", "data": {"current_growth_stage": "..."}}
          if (decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>) {
            final data = decoded['data'] as Map<String, dynamic>;
            growthStage = data['current_growth_stage']?.toString() ?? 
                         data['growth_stage']?.toString() ?? 
                         'vegetative';
          } else {
            // Handle direct format: {"growth_stage": "..."}
            growthStage = decoded['growth_stage']?.toString() ?? 
                         decoded['current_growth_stage']?.toString() ?? 
                         'vegetative';
          }
        } else {
          growthStage = 'vegetative';
        }
        
        debugPrint('✅ INM: Growth stage fetched: $growthStage');
        return growthStage;
      } else if (response.statusCode == 404 || response.statusCode == 405) {
        // Endpoint not found or method not allowed - default to vegetative
        debugPrint('⚠️ INM: Growth stage endpoint not available (${response.statusCode}), defaulting to vegetative');
        return 'vegetative';
      } else {
        // Default to vegetative if no stage is set
        debugPrint('⚠️ INM: No growth stage set (${response.statusCode}), defaulting to vegetative');
        return 'vegetative';
      }
    } catch (e) {
      debugPrint('❌ INM: Exception fetching growth stage: $e');
      // Default to vegetative on error
      return 'vegetative';
    }
  }

  /// Saves the growth stage to backend
  Future<bool> saveGrowthStage(String growthStage) async {
    final String url = '$_baseUrl/growth-stage';
    
    try {
      debugPrint('🔄 INM: Saving growth stage: $growthStage');
      
      final requestBody = jsonEncode({
        'growth_stage': growthStage,
      });
      debugPrint('📤 INM: Request body: $requestBody');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      );

      debugPrint('📡 INM: Save growth stage response: ${response.statusCode}');
      debugPrint('📦 INM: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ INM: Growth stage saved successfully');
        return true;
      } else {
        debugPrint('❌ INM: Failed to save growth stage: ${response.statusCode}');
        debugPrint('❌ INM: Error details: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ INM: Exception saving growth stage: $e');
      return false;
    }
  }

  /// Saves farmer action (applied/ignored) to backend
  Future<bool> saveAction(InmStatus status, String actionType) async {
    final String url = '$_baseUrl/action';
    
    try {
      debugPrint('🔄 INM: Saving action: $actionType');
      
      // Combine all recommendations into a single text as backend expects
      final recommendationText = '''
EC Action: ${status.ecAction}

pH Action: ${status.phAction}

NPK Recommendation: ${status.npkRecommendation}
'''.trim();
      
      final requestBody = jsonEncode({
        'action_taken': actionType,
        'recommendation_text': recommendationText,
        'ec_action': status.ecAction,
        'ph_action': status.phAction,
        'npk_recommendation': status.npkRecommendation,
        'growth_stage': status.growthStage?.toLowerCase(),
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('📤 INM: Request body: $requestBody');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      );

      debugPrint('📡 INM: Save action response: ${response.statusCode}');
      debugPrint('📦 INM: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ INM: Action saved successfully');
        return true;
      } else {
        debugPrint('❌ INM: Failed to save action: ${response.statusCode}');
        debugPrint('❌ INM: Error details: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ INM: Exception saving action: $e');
      return false;
    }
  }

  /// Fetches action history from backend
  Future<List<InmActionHistory>> fetchActionHistory() async {
    final String url = '$_baseUrl/action-history?_t=${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      debugPrint('🔄 INM: Fetching action history from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      debugPrint('📡 INM: Action history response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> dataList = [];

        // Handle different response formats
        if (decoded is List) {
          dataList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          dataList = decoded['data'] ?? 
                     decoded['actions'] ?? 
                     decoded['history'] ?? 
                     [decoded];
        }

        debugPrint('📊 INM: Received ${dataList.length} action records from backend');

        // Parse action history
        final actions = dataList
            .map((json) => InmActionHistory.fromJson(json as Map<String, dynamic>))
            .toList();

        // Sort by timestamp descending (newest first)
        actions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        debugPrint('✅ INM: Total ${actions.length} action history ready');
        return actions;
      } else if (response.statusCode == 404) {
        // No actions found yet
        debugPrint('⚠️ INM: No action history found');
        return [];
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ INM: Exception fetching action history: $e');
      // Return empty list on error instead of throwing
      return [];
    }
  }
}

