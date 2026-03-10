import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';
import '../../core/config/app_config.dart';

/// Fetches in-app notifications from the backend (MongoDB).
class NotificationsApiService {
  NotificationsApiService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  /// GET /notifications/ — use trailing slash to avoid 307 redirect (FastAPI).
  Future<List<Map<String, dynamic>>> fetchNotifications({
    String? token,
    String? type,
    int limit = 100,
  }) async {
    final Map<String, String> query = <String, String>{
      'limit': '$limit',
      if (type != null && type.isNotEmpty) 'type': type,
    };
    final Uri uri = _apiService.uri('/notifications/', query: query);
    try {
      final http.Response response =
          await _apiService.getUri(uri, token: token);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic>? body = _apiService.decodeJson(response);
        final dynamic data = body?['data'];
        if (data is Map<String, dynamic>) {
          final dynamic list = data['notifications'];
          if (list is List<dynamic>) {
            return list
                .map((e) => e as Map<String, dynamic>)
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('NotificationsApiService.fetchNotifications error: $e');
    }
    return <Map<String, dynamic>>[];
  }

  /// DELETE /notifications/clear — delete all notifications for the user.
  /// Returns true if the request succeeded.
  Future<bool> clearAll({String? token}) async {
    try {
      final http.Response response =
          await _apiService.delete('/notifications/clear', token: token);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('NotificationsApiService.clearAll error: $e');
      return false;
    }
  }

  /// PATCH /notifications/read-all — mark all notifications as read.
  /// Returns true if the request succeeded.
  Future<bool> markAllRead({String? token}) async {
    try {
      final http.Response response =
          await _apiService.patch('/notifications/read-all', token: token);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('NotificationsApiService.markAllRead error: $e');
      return false;
    }
  }
}
