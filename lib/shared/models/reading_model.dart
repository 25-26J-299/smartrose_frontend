/// Model representing sensor reading data for freshness monitoring.
/// Matches backend FMSensorInput structure.
class ReadingModel {
  const ReadingModel({
    required this.deviceId,
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    required this.gasValue,
    required this.waterLevel,
    this.id,
  });

  final String? id; // MongoDB _id, may be null for new readings
  final String deviceId;
  final DateTime timestamp;
  final double temperature;
  final double humidity;
  final double gasValue;
  final int waterLevel;

  factory ReadingModel.fromJson(Map<String, dynamic> json) {
    return ReadingModel(
      id: json['_id'] as String?,
      deviceId: json['device_id'] as String,
      timestamp: json['timestamp'] is String
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.fromMillisecondsSinceEpoch(
              (json['timestamp'] as num).toInt() * 1000,
              isUtc: true,
            ),
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      gasValue: (json['gas_value'] as num).toDouble(),
      waterLevel: (json['water_level'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) '_id': id,
      'device_id': deviceId,
      'timestamp': timestamp.toIso8601String(),
      'temperature': temperature,
      'humidity': humidity,
      'gas_value': gasValue,
      'water_level': waterLevel,
    };
  }
}
