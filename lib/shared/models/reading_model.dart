/// Model representing sensor reading data for freshness monitoring.
/// Matches backend FMSensorInput structure.
class ReadingModel {
  const ReadingModel({
    required this.deviceId,
    required this.timestamp,
    required this.airTemperature,
    required this.waterTemperature,
    required this.humidity,
    required this.gasValue,
    required this.waterLevel,
    this.id,
  });

  final String? id; // MongoDB _id, may be null for new readings
  final String deviceId;
  final DateTime timestamp;
  final double airTemperature;
  final double waterTemperature;
  final double humidity;
  final double gasValue;
  final int waterLevel;

  factory ReadingModel.fromJson(Map<String, dynamic> json) {
    DateTime parseTimestamp(dynamic timestampValue) {
      if (timestampValue is String) {
        final parsed = DateTime.parse(timestampValue);
        // If the string doesn't have timezone info, assume it's UTC
        // (backend typically sends UTC timestamps)
        if (!timestampValue.endsWith('Z') &&
            !timestampValue.contains('+') &&
            !timestampValue.contains('-', 10)) {
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
        return parsed;
      } else if (timestampValue is num) {
        // Unix timestamp in seconds, convert to milliseconds and parse as UTC
        return DateTime.fromMillisecondsSinceEpoch(
          (timestampValue.toInt() * 1000),
          isUtc: true,
        );
      }
      throw FormatException('Invalid timestamp format: $timestampValue');
    }

    // Handle backward compatibility: support both old 'temperature' and new 'air_temperature' fields
    // Also handle missing water_temperature with default value
    final airTemp =
        (json['air_temperature'] as num?)?.toDouble() ??
        (json['temperature'] as num?)?.toDouble() ??
        20.0;
    final waterTemp =
        (json['water_temperature'] as num?)?.toDouble() ?? airTemp;

    return ReadingModel(
      id: json['_id'] as String?,
      deviceId: json['device_id'] as String,
      timestamp: parseTimestamp(json['timestamp']),
      airTemperature: airTemp,
      waterTemperature: waterTemp,
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
      'air_temperature': airTemperature,
      'water_temperature': waterTemperature,
      'humidity': humidity,
      'gas_value': gasValue,
      'water_level': waterLevel,
    };
  }
}
