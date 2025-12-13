class SensorReading {
  SensorReading({
    required this.sensorId,
    required this.timestamp,
    required this.temperature,
    required this.humidity,
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
  final String sensorId;
  final DateTime timestamp;
  final DateTime? receivedAt;
  final double temperature;
  final double humidity;
  final int? uvRaw;
  final double? uvVoltage;
  final int? soilRaw;
  final double? soilVoltage;
  final int? mqRaw;
  final double? mqVoltage;

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
      if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
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

    return SensorReading(
      id: (json['id'] ?? json['_id'])?.toString(),
      sensorId: (json['sensor_id'] ?? json['sensorId'] ?? json['sensorID'] ?? '').toString(),
      timestamp: parseDate(json['timestamp']) ?? DateTime.now().toUtc(),
      receivedAt: parseDate(json['received_at'] ?? json['receivedAt']),
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
        'sensor_id': sensorId,
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
}
