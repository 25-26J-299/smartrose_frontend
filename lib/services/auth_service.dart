import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../models/user.dart';

/// Simple container for auth responses.
class AuthResult {
  AuthResult({required this.user, required this.token});

  final User user;
  final String token;
}

class AuthService {
  AuthService({
    http.Client? client,
    FlutterSecureStorage? storage,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage(),
       _baseUrl = baseUrl ?? getApiBaseUrl();

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String _baseUrl;
  static const String _tokenKey = 'smartrose_access_token';

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  /// Register with full_name, email, phone, password, roles (list), and location.
  /// Returns AuthResult only if backend returns token (legacy); otherwise returns null
  /// and caller should show "pending approval" message.
  Future<AuthResult?> register(
    String fullName,
    String email,
    String phone,
    String password,
    List<String> roles, {
    required String locationName,
    required String locationType,
    required String locationAddress,
  }) async {
    final http.Response response = await _client.post(
      _uri('/auth/register'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'roles': roles,
        'location': <String, dynamic>{
          'name': locationName,
          'type': locationType,
          'address': locationAddress,
        },
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      final User user = User.fromJson(body['user'] as Map<String, dynamic>);
      final String? token = body['access_token'] as String?;
      if (token != null && token.isNotEmpty) {
        await persistToken(token);
        return AuthResult(user: user, token: token);
      }
      // New flow: no token, user must be approved
      return null;
    }
    final Map<String, dynamic>? err =
        jsonDecode(response.body) as Map<String, dynamic>?;
    throw Exception(err?['detail'] ?? 'Registration failed');
  }

  Future<AuthResult?> login(String email, String password) async {
    try {
      final http.Response response = await _client
          .post(
            _uri('/auth/login'),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'email': email,
              'password': password,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Login request timed out');
            },
          );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> body =
            jsonDecode(response.body) as Map<String, dynamic>;
        final User user = User.fromJson(body['user'] as Map<String, dynamic>);
        final String token = body['access_token'] as String;
        await persistToken(token);
        return AuthResult(user: user, token: token);
      }

      if (response.statusCode == 403) {
        final Map<String, dynamic>? err =
            jsonDecode(response.body) as Map<String, dynamic>?;
        throw Exception(err?['detail'] ?? 'Account pending approval');
      }

      debugPrint('Login failed with status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      return null;
    } catch (e, stackTrace) {
      debugPrint('Login error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Base URL: $_baseUrl');
      rethrow;
    }
  }

  Future<User?> fetchProfile(String token) async {
    try {
      final http.Response response = await _client
          .get(
            _uri('/auth/me'),
            headers: <String, String>{'Authorization': 'Bearer $token'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Fetch profile request timed out');
            },
          );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> body =
            jsonDecode(response.body) as Map<String, dynamic>;
        return User.fromJson(body['user'] as Map<String, dynamic>);
      }
      debugPrint('Fetch profile failed with status: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Fetch profile error: $e');
      return null;
    }
  }

  Future<AuthResult?> updateRoles(List<String> roles, String token) async {
    final http.Response response = await _client.patch(
      _uri('/auth/update-roles'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{'roles': roles}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      final User user = User.fromJson(body['user'] as Map<String, dynamic>);
      final String newToken = body['access_token'] as String;
      await persistToken(newToken);
      return AuthResult(user: user, token: newToken);
    }
    return null;
  }

  /// Fetch the logged-in user's locations (greenhouses & flower shops).
  Future<List<Map<String, dynamic>>> fetchMyLocations(String token) async {
    try {
      final http.Response response = await _client
          .get(
            _uri('/auth/my-locations'),
            headers: <String, String>{'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> body =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> raw =
            body['locations'] as List<dynamic>? ?? <dynamic>[];
        return raw.cast<Map<String, dynamic>>();
      }
      return <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint('fetchMyLocations error: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// Fetch the logged-in user's assigned devices.
  ///
  /// Pass [deviceType] to filter by type (e.g. 'INM', 'EOSM', 'EDAS', 'FM').
  /// Pass [locationId] to filter by a specific greenhouse / flower shop.
  /// Returns a list of device maps from the backend.
  Future<List<Map<String, dynamic>>> fetchMyDevices(
    String token, {
    String? deviceType,
    String? locationId,
  }) async {
    final List<String> params = <String>[];
    if (deviceType != null) {
      params.add('device_type=${Uri.encodeComponent(deviceType)}');
    }
    if (locationId != null) {
      params.add('location_id=${Uri.encodeComponent(locationId)}');
    }
    var path = '/auth/my-devices';
    if (params.isNotEmpty) {
      path += '?${params.join('&')}';
    }
    try {
      final http.Response response = await _client
          .get(
            _uri(path),
            headers: <String, String>{'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> body =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> raw =
            body['devices'] as List<dynamic>? ?? <dynamic>[];
        return raw.cast<Map<String, dynamic>>();
      }
      debugPrint('fetchMyDevices failed: ${response.statusCode}');
      return <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint('fetchMyDevices error: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<String?> loadToken() => _storage.read(key: _tokenKey);

  Future<void> persistToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
