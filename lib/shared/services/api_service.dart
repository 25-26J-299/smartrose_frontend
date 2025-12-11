import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Lightweight HTTP helper so feature services can share base URL logic.
class ApiService {
  ApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'SMARTROSE_API_BASE',
              defaultValue: kIsWeb
                  ? 'http://localhost:8000/api/v1'
                  : 'http://10.0.2.2:8000/api/v1',
            );

  final http.Client _client;
  final String _baseUrl;

  Uri uri(String path, {Map<String, String>? query}) {
    final Uri uri = Uri.parse('$_baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<http.Response> getUri(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    final Map<String, String> resolvedHeaders = <String, String>{
      'Content-Type': 'application/json',
      ...?headers,
    };
    return _client.get(uri, headers: resolvedHeaders);
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) {
    return getUri(uri(path, query: query), headers: headers);
  }

  Map<String, dynamic>? decodeJson(http.Response response) {
    if (response.body.isEmpty) return null;
    final dynamic body = jsonDecode(response.body);
    return body is Map<String, dynamic> ? body : null;
  }
}
