import 'package:flutter/material.dart';

// Start of EOSM

enum StressLevel { optimal, warning, critical }

class StressStatus {
  const StressStatus({required this.level, required this.color, this.label});

  final StressLevel level;
  final Color color;
  final String? label;
}

// End of EOSM

class SensorReading {
  SensorReading({
    required this.basestationId,
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    this.deviceId,
    this.locationId,
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
  /// Base station serial (e.g. SR-BS-20251003), sourced from base_station_serial.
  final String basestationId;
  /// Human-readable device serial (e.g. SR-EOSM-20250310).
  final String? deviceId;
  /// Location ObjectId from the backend.
  final String? locationId;
  final DateTime timestamp; // UTC timestamp
  final DateTime? receivedAt; // UTC timestamp
  final double temperature;
  final double humidity;
  final int? uvRaw;
  final double? uvVoltage;
  final int? soilRaw;
  final double? soilVoltage;
  final int? mqRaw;
  final double? mqVoltage;

  DateTime get displayTime => receivedAt ?? timestamp;

  /// Returns the best human-readable device/location label for display.
  String get displayDeviceLabel => deviceId ?? basestationId;

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
      }
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
      }
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    // reading_time_slst is stored as an ISO string with +05:30 offset,
    // e.g. "2026-03-10T14:39:43+05:30". DateTime.tryParse converts this to UTC
    // (09:09:43Z), so we add the +05:30 offset back to recover the local wall
    // clock time for display.
    DateTime? parseSLST(dynamic value) {
      if (value is! String || value.isEmpty) return null;
      final DateTime? parsed = DateTime.tryParse(value);
      if (parsed == null) return null;
      // If the string carries an explicit offset, parsed is UTC. Shift it to
      // the SLST wall-clock value so the UI shows 14:39 not 09:09.
      if (value.contains('+') || value.endsWith('Z')) {
        return parsed.toUtc().add(const Duration(hours: 5, minutes: 30));
      }
      return parsed;
    }

    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int? toInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    final DateTime ts =
        parseDate(json['timestamp']) ?? DateTime.now().toUtc();

    // Prefer reading_time_slst (Sri Lanka time set by backend) for display.
    // Fall back to received_at, then raw timestamp.
    final DateTime? slstTime = parseSLST(json['reading_time_slst']);
    final DateTime? receivedAtTime = parseDate(json['received_at'] ?? json['receivedAt']);
    final DateTime? displayTs = slstTime ?? receivedAtTime;

    return SensorReading(
      id: (json['id'] ?? json['_id'])?.toString(),
      basestationId: (json['base_station_serial'] ??
              json['basestationId'] ??
              json['basestation_id'] ??
              json['baseStationId'] ??
              json['sensor_id'] ??
              json['sensorId'] ??
              json['sensorID'] ??
              '')
          .toString(),
      deviceId: (json['deviceId'] ?? json['device_id'])?.toString(),
      locationId: (json['location_id'] ?? json['locationId'])?.toString(),
      timestamp: ts,
      receivedAt: displayTs,
      temperature: toDouble(json['temperature']) ?? 0,
      humidity: toDouble(json['humidity']) ?? 0,
      uvRaw: toInt(json['uv_raw'] ?? json['uvRaw']),
      uvVoltage: toDouble(json['uv_voltage'] ?? json['uvVoltage']),
      soilRaw: toInt(json['soil_raw'] ?? json['soilRaw']),
      soilVoltage: toDouble(json['soil_voltage'] ?? json['soilVoltage']),
      mqRaw: toInt(json['mq_raw'] ?? json['mqRaw']),
      mqVoltage: toDouble(json['mq_voltage'] ?? json['mqVoltage']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'basestationId': basestationId,
        if (deviceId != null) 'device_id': deviceId,
        if (locationId != null) 'location_id': locationId,
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
    return const StressStatus(level: StressLevel.optimal, color: Color(0xFF4CAF50), label: 'Good');
  }
}


