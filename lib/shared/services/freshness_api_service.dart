import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../models/prediction_model.dart';
import '../models/reading_model.dart';

/// API service for freshness monitoring endpoints.
class FreshnessApiService {
  FreshnessApiService({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? getApiBaseUrl(),
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: <String, dynamic>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // Disable caching to always get fresh data
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      ),
    );
  }

  late final Dio _dio;

  /// Fetches the latest sensor readings for a specific device from the database.
  ///
  /// This retrieves the most recent sensor reading sorted by timestamp descending
  /// (latest update first) from the database.
  ///
  /// [deviceId] - The device identifier to retrieve readings for.
  /// Returns [ReadingModel] containing the most recent sensor data.
  /// Throws [DioException] if the request fails.
  Future<ReadingModel> getLatestReadings(String deviceId) async {
    try {
      // URL encode the device ID to handle special characters and spaces
      final encodedDeviceId = Uri.encodeComponent(deviceId);
      final Response<Map<String, dynamic>> response = await _dio
          .get<Map<String, dynamic>>('/fm/latest/$encodedDeviceId');

      if (response.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Response data is null',
        );
      }

      return ReadingModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetches the latest sensor reading with ML model prediction in a single call.
  ///
  /// This retrieves the most recent sensor reading from the database (sorted by
  /// timestamp descending) and generates a freshness prediction using the ML model
  /// (or heuristic fallback if model is not available).
  ///
  /// [deviceId] - The device identifier to retrieve readings for.
  /// [forceRefresh] - If true, adds a timestamp query parameter to bypass cache.
  /// Returns a map containing both the reading and prediction.
  /// Throws [DioException] if the request fails.
  Future<Map<String, dynamic>> getLatestWithPrediction(
    String deviceId, {
    bool forceRefresh = true,
  }) async {
    try {
      // URL encode the device ID to handle special characters and spaces
      final encodedDeviceId = Uri.encodeComponent(deviceId);

      // Add timestamp query parameter to force fresh data (bypass cache)
      final queryParams = forceRefresh
          ? '?t=${DateTime.now().millisecondsSinceEpoch}'
          : '';

      final Response<Map<String, dynamic>> response = await _dio
          .get<Map<String, dynamic>>(
            '/fm/latest-with-prediction/$encodedDeviceId$queryParams',
            options: Options(
              // Explicitly disable caching
              extra: <String, dynamic>{'disableCache': true},
              // Force fresh request
              validateStatus: (status) => status! < 500,
            ),
          );

      if (response.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Response data is null',
        );
      }

      return response.data!;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetches the freshness prediction based on sensor reading data using the ML model.
  ///
  /// Uses the FM ML model to generate predictions. Falls back to heuristic if
  /// the model is not available.
  ///
  /// [reading] - The sensor reading data to use for prediction.
  /// Returns [PredictionModel] containing freshness score, vase life hours,
  /// and alerts.
  /// Throws [DioException] if the request fails.
  Future<PredictionModel> getFreshnessPrediction(ReadingModel reading) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio
          .post<Map<String, dynamic>>('/fm/predict', data: reading.toJson());

      if (response.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Response data is null',
        );
      }

      return PredictionModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  DioException _handleError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return DioException(
        requestOptions: error.requestOptions,
        error: 'Connection timeout. Please check your internet connection.',
        type: error.type,
      );
    } else if (error.type == DioExceptionType.badResponse) {
      final int? statusCode = error.response?.statusCode;
      String message;
      if (statusCode == 404) {
        message =
            error.response?.data?['detail'] as String? ??
            error.response?.data?['message'] as String? ??
            'Device not found. Please check the device ID or ensure data exists for this device.';
      } else {
        message =
            error.response?.data?['detail'] as String? ??
            error.response?.data?['message'] as String? ??
            'Server error (${statusCode ?? 'unknown'})';
      }
      return DioException(
        requestOptions: error.requestOptions,
        response: error.response,
        error: message,
        type: error.type,
      );
    } else if (error.type == DioExceptionType.cancel) {
      return DioException(
        requestOptions: error.requestOptions,
        error: 'Request was cancelled',
        type: error.type,
      );
    } else if (error.type == DioExceptionType.unknown) {
      final String errorMessage = error.error?.toString() ?? '';
      if (errorMessage.contains('Failed host lookup') ||
          errorMessage.contains('ERR_NAME_NOT_RESOLVED') ||
          errorMessage.contains('Connection refused')) {
        return DioException(
          requestOptions: error.requestOptions,
          error:
              'Cannot connect to backend server. Please ensure the backend is running on http://localhost:8000',
          type: error.type,
        );
      }
      return DioException(
        requestOptions: error.requestOptions,
        error: 'Network error. Please check your connection.',
        type: error.type,
      );
    } else {
      return error;
    }
  }

  /// Uploads a sensor reading to the backend.
  ///
  /// [reading] - The sensor reading data to upload.
  /// Returns the inserted document ID.
  /// Throws [DioException] if the request fails.
  Future<String> uploadSensorReading(ReadingModel reading) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio
          .post<Map<String, dynamic>>('/fm/upload', data: reading.toJson());

      if (response.data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Response data is null',
        );
      }

      return response.data!['id'] as String? ?? '';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Creates sample data for a device for testing purposes.
  ///
  /// [deviceId] - The device identifier to create sample data for.
  /// Returns the created sensor reading.
  /// Throws [DioException] if the request fails.
  Future<ReadingModel> createSampleData(String deviceId) async {
    final sampleReading = ReadingModel(
      deviceId: deviceId,
      timestamp: DateTime.now().toUtc(),
      temperature: 20.5,
      humidity: 65.0,
      gasValue: 45.0,
      waterLevel: 75,
    );

    await uploadSensorReading(sampleReading);
    return sampleReading;
  }

  /// Disposes the Dio instance and cancels any pending requests.
  void dispose() {
    _dio.close(force: true);
  }
}
