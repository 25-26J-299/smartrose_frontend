import 'package:flutter/material.dart';

enum StressLevel { optimal, warning, critical }

class StressStatus {
  const StressStatus({required this.level, required this.color, this.label});

  final StressLevel level;
  final Color color;
  final String? label;
}

class SensorReading {
  SensorReading({
    required this.basestationId,
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    this.greenhouseId,
    this.id,
    this.receivedAt,
    this.uvRaw,
    this.uvVoltage,
    this.soilRaw,
    this.soilVoltage,
    this.mqRaw,
    this.mqVoltage,
  });

  final String? id;
  final String basestationId;
  final String? greenhouseId;
  final DateTime timestamp; // localized to Sri Lanka (UTC+5:30)
  final DateTime? receivedAt; // localized to Sri Lanka (UTC+5:30)
  final double temperature;
  final double humidity;
  final int? uvRaw;
  final double? uvVoltage;
  final int? soilRaw;
  final double? soilVoltage;
  final int? mqRaw;
  final double? mqVoltage;

  DateTime get displayTime => receivedAt ?? timestamp;

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is int) {
        // seconds epoch
        return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true)
            .add(const Duration(hours: 5, minutes: 30));
      }
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
            .add(const Duration(hours: 5, minutes: 30));
      }
      if (value is String && value.isNotEmpty) {
        final DateTime? parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return parsed.toUtc().add(const Duration(hours: 5, minutes: 30));
        }
      }
      return null;
    }

    double? _toDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int? _toInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    final DateTime ts =
        _parseDate(json['timestamp']) ?? DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

    return SensorReading(
      id: (json['id'] ?? json['_id'])?.toString(),
      basestationId: (json['basestationId'] ??
              json['basestation_id'] ??
              json['baseStationId'] ??
              json['sensor_id'] ??
              json['sensorId'] ??
              json['sensorID'] ??
              '')
          .toString(),
      greenhouseId: (json['greenhouseId'] ??
              json['greenhouse_id'] ??
              json['greenhouseID'] ??
              json['greenhouseid'])
          ?.toString(),
      timestamp: ts,
      receivedAt: _parseDate(json['received_at'] ?? json['receivedAt']),
      temperature: _toDouble(json['temperature']) ?? 0,
      humidity: _toDouble(json['humidity']) ?? 0,
      uvRaw: _toInt(json['uv_raw'] ?? json['uvRaw']),
      uvVoltage: _toDouble(json['uv_voltage'] ?? json['uvVoltage']),
      soilRaw: _toInt(json['soil_raw'] ?? json['soilRaw']),
      soilVoltage: _toDouble(json['soil_voltage'] ?? json['soilVoltage']),
      mqRaw: _toInt(json['mq_raw'] ?? json['mqRaw']),
      mqVoltage: _toDouble(json['mq_voltage'] ?? json['mqVoltage']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'basestationId': basestationId,
        if (greenhouseId != null) 'greenhouseId': greenhouseId,
        'timestamp': timestamp.toIso8601String(),
        if (receivedAt != null) 'received_at': receivedAt!.toIso8601String(),
        'temperature': temperature,
        'humidity': humidity,
        if (uvRaw != null) 'uv_raw': uvRaw,
        if (uvVoltage != null) 'uv_voltage': uvVoltage,
        if (soilRaw != null) 'soil_raw': soilRaw,
        if (soilVoltage != null) 'soil_voltage': soilVoltage,
        if (mqRaw != null) 'mq_raw': mqRaw,
        if (mqVoltage != null) 'mq_voltage': mqVoltage,
      };

  // Simple rule-based statuses (not ML)
  StressStatus get temperatureStatus {
    if (temperature < 18 || temperature > 28) {
      return StressStatus(level: StressLevel.critical, color: const Color(0xFFF44336), label: 'Critical');
    }
    if (temperature > 24 && temperature <= 28) {
      return StressStatus(level: StressLevel.warning, color: const Color(0xFFFFC107), label: 'Warning');
    }
    return StressStatus(level: StressLevel.optimal, color: const Color(0xFF4CAF50), label: 'Optimal');
  }

  StressStatus get humidityStatus {
    if (humidity < 50 || humidity > 85) {
      return StressStatus(level: StressLevel.critical, color: const Color(0xFFF44336), label: 'Critical');
    }
    if (humidity > 75 && humidity <= 85) {
      return StressStatus(level: StressLevel.warning, color: const Color(0xFFFFC107), label: 'Warning');
    }
    return StressStatus(level: StressLevel.optimal, color: const Color(0xFF4CAF50), label: 'Optimal');
  }

  StressStatus get soilStatus {
    if (soilVoltage == null) {
      return const StressStatus(level: StressLevel.warning, color: Color(0xFFFFC107), label: 'No data');
    }
    final double v = soilVoltage!;
    if (v < 2.0 || v > 3.1) {
      return const StressStatus(level: StressLevel.critical, color: Color(0xFFF44336), label: 'Critical');
    }
    if ((v >= 2.0 && v < 2.4) || (v > 2.9 && v <= 3.1)) {
      return const StressStatus(level: StressLevel.warning, color: Color(0xFFFFC107), label: 'Warning');
    }
    return const StressStatus(level: StressLevel.optimal, color: Color(0xFF4CAF50), label: 'Optimal');
  }

  StressStatus get uvStatus {
    if (uvVoltage == null) {
      return const StressStatus(level: StressLevel.optimal, color: Color(0xFF4CAF50), label: 'N/A');
    }
    final double v = uvVoltage!;
    if (v > 1.0) {
      return const StressStatus(level: StressLevel.critical, color: Color(0xFFF44336), label: 'Critical');
    }
    if (v > 0.5) {
      return const StressStatus(level: StressLevel.warning, color: Color(0xFFFFC107), label: 'Warning');
    }
    return const StressStatus(level: StressLevel.optimal, color: Color(0xFF4CAF50), label: 'Optimal');
  }

  StressStatus get gasStatus {
    if (mqVoltage == null) {
      return const StressStatus(level: StressLevel.warning, color: Color(0xFFFFC107), label: 'No data');
    }
    final double v = mqVoltage!;
    if (v > 1.0) {
      return const StressStatus(level: StressLevel.critical, color: Color(0xFFF44336), label: 'Critical');
    }
    if (v >= 0.5) {
      return const StressStatus(level: StressLevel.warning, color: Color(0xFFFFC107), label: 'Warning');
    }
    return const StressStatus(level: StressLevel.optimal, color: const Color(0xFF4CAF50), label: 'Good');
  }
}


