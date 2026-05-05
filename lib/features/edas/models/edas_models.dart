import 'package:flutter/material.dart';

/// EDAS Sensor Reading Model
/// Contains plant temperature, air temperature, humidity, and temperature difference
class EdasSensorReading {
  EdasSensorReading({
    required this.basestationId,
    required this.timestamp,
    required this.plantTemperature,
    required this.airTemperature,
    required this.humidity,
    this.greenhouseId,
    this.id,
    this.receivedAt,
  });

  final String? id;
  final String basestationId;
  final String? greenhouseId;
  final DateTime timestamp; // UTC timestamp
  final DateTime? receivedAt; // UTC timestamp
  final double plantTemperature; // Plant temperature in °C
  final double airTemperature; // Air temperature in °C
  final double humidity; // Humidity in %

  /// Calculate temperature difference (plant temp - air temp)
  double get temperatureDifference => plantTemperature - airTemperature;

  /// Convert UTC timestamp to Sri Lanka time (UTC+05:30)
  static DateTime _toSriLankaTime(DateTime utcTime) {
    // Sri Lanka is UTC+05:30 (Asia/Colombo)
    return utcTime.add(const Duration(hours: 5, minutes: 30));
  }

  /// Get display time in Sri Lanka timezone
  /// Backend sends UTC timestamps, convert to Sri Lanka time for display
  DateTime get displayTime {
    final DateTime utcTime = receivedAt ?? timestamp;
    return _toSriLankaTime(utcTime);
  }

  factory EdasSensorReading.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is int) {
        // Backend sends UTC timestamps as epoch seconds
        return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
      }
      if (value is num) {
        // Backend sends UTC timestamps as epoch milliseconds
        return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
      }
      if (value is String && value.isNotEmpty) {
        final DateTime? parsed = DateTime.tryParse(value);
        if (parsed != null) {
          // Backend sends UTC timestamps as ISO strings
          // If parsed datetime doesn't have timezone info, assume it's UTC
          if (parsed.isUtc) {
            return parsed;
          } else {
            // If no timezone info, treat as UTC
            return DateTime.utc(
              parsed.year,
              parsed.month,
              parsed.day,
              parsed.hour,
              parsed.minute,
              parsed.second,
              parsed.millisecond,
              parsed.microsecond,
            );
          }
        }
      }
      return null;
    }

    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    final DateTime ts =
        parseDate(json['timestamp']) ?? DateTime.now().toUtc();

    return EdasSensorReading(
      id: (json['id'] ?? json['_id'])?.toString(),
      basestationId: (json['basestationId'] ??
              json['basestation_id'] ??
              json['baseStationId'] ??
              json['device_id'] ??
              json['deviceId'] ??
              json['sensor_id'] ??
              json['sensorId'] ??
              json['sensorID'] ??
              '')
          .toString(),
      greenhouseId: (json['greenhouseId'] ??
              json['greenhouse_id'] ??
              json['greenhouseID'] ??
              json['greenhouseid'] ??
              json['location_id'] ??
              json['locationId'])
          ?.toString(),
      timestamp: ts,
      receivedAt: parseDate(json['received_at'] ?? json['receivedAt']),
      plantTemperature: toDouble(json['plant_temperature'] ??
              json['plantTemperature'] ??
              json['plant_temp']) ??
          0,
      airTemperature: toDouble(json['air_temperature'] ??
              json['airTemperature'] ??
              json['air_temp']) ??
          0,
      humidity: toDouble(json['humidity']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'basestationId': basestationId,
        if (greenhouseId != null) 'greenhouseId': greenhouseId,
        'timestamp': timestamp.toIso8601String(),
        if (receivedAt != null) 'received_at': receivedAt!.toIso8601String(),
        'plant_temperature': plantTemperature,
        'air_temperature': airTemperature,
        'humidity': humidity,
      };
}

/// EDAS Disease Prediction Model
/// Contains ML predictions for early disease detection and risk level
class EdasDiseasePrediction {
  const EdasDiseasePrediction({
    required this.riskLevel,
    required this.riskProbabilities,
    this.diseaseType,
    this.confidence,
    this.timestamp,
    this.recommendations,
  });

  final String riskLevel; // "HIGH", "MEDIUM", "LOW", or specific disease name
  final Map<String, double> riskProbabilities; // Probabilities for each risk level/disease
  final String? diseaseType; // Specific disease type if detected
  final double? confidence; // Overall confidence score
  final DateTime? timestamp; // Prediction timestamp
  final List<String>? recommendations; // ML-generated recommendations

  factory EdasDiseasePrediction.fromJson(Map<String, dynamic> json) {
    DateTime? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
      }
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
      }
      if (value is String && value.isNotEmpty) {
        final DateTime? parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return parsed.toUtc();
        }
      }
      return null;
    }

    Map<String, double> parseProbabilities(dynamic value) {
      if (value == null) return <String, double>{};
      if (value is Map) {
        return value.map<String, double>(
          (dynamic key, dynamic val) => MapEntry(
            key.toString(),
            (val as num?)?.toDouble() ?? 0.0,
          ),
        );
      }
      return <String, double>{};
    }

    List<String>? parseRecommendations(dynamic value) {
      if (value == null) return null;
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return null;
    }

    return EdasDiseasePrediction(
      riskLevel: (json['disease_risk_level'] ??
              json['risk_level'] ??
              json['riskLevel'] ??
              'LOW')
          .toString(),
      riskProbabilities: parseProbabilities(
          json['risk_probabilities'] ?? json['riskProbabilities']),
      diseaseType: json['disease_type'] ?? json['diseaseType'],
      confidence: (json['confidence'] as num?)?.toDouble(),
      timestamp: parseTimestamp(json['timestamp']),
      recommendations: parseRecommendations(json['recommendations']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'risk_level': riskLevel,
      'risk_probabilities': riskProbabilities,
      if (diseaseType != null) 'disease_type': diseaseType,
      if (confidence != null) 'confidence': confidence,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      if (recommendations != null) 'recommendations': recommendations,
    };
  }

  /// Get risk level color for UI
  Color get riskColor {
    final String level = riskLevel.toUpperCase();
    if (level.contains('HIGH') || level.contains('CRITICAL')) {
      return const Color(0xFFF44336); // Red
    }
    if (level.contains('MEDIUM') || level.contains('WARNING')) {
      return const Color(0xFFFFC107); // Amber
    }
    if (level.contains('LOW') || level.contains('OPTIMAL')) {
      return const Color(0xFF4CAF50); // Green
    }
    // Default to amber for unknown
    return const Color(0xFFFFC107);
  }

  /// Get highest probability value
  double get highestProbability {
    if (riskProbabilities.isEmpty) return confidence ?? 0.0;
    return riskProbabilities.values.reduce((a, b) => a > b ? a : b);
  }

  /// Get formatted risk level for display
  String get displayRiskLevel {
    final String level = riskLevel.toUpperCase();
    if (level.contains('HIGH') || level.contains('CRITICAL')) {
      return 'HIGH RISK';
    }
    if (level.contains('MEDIUM') || level.contains('WARNING')) {
      return 'MEDIUM RISK';
    }
    if (level.contains('LOW') || level.contains('OPTIMAL')) {
      return 'LOW RISK';
    }
    return level;
  }
}

