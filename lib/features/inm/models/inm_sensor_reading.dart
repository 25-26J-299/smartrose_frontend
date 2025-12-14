// File: lib/features/inm/models/inm_sensor_reading.dart
// Purpose: Model class for INM sensor reading data

class InmSensorReading {
  final String id;
  final String deviceId;
  final DateTime? timestamp;
  final double soilMoisture;
  final double soilTemp;
  final double airTemp;
  final double airHum;
  final double ec;
  final double ph;
  final double nitrogen;
  final double phosphorus;
  final double potassium;

  InmSensorReading({
    required this.id,
    required this.deviceId,
    this.timestamp,
    required this.soilMoisture,
    required this.soilTemp,
    required this.airTemp,
    required this.airHum,
    required this.ec,
    required this.ph,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
  });

  factory InmSensorReading.fromJson(Map<String, dynamic> json) {
    return InmSensorReading(
      id: json['_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? 'unknown',
      timestamp: DateTime.tryParse(json['timestamp'] ?? ''),
      soilMoisture: _parseDouble(json['soil_moisture']),
      soilTemp: _parseDouble(json['soil_temp']),
      airTemp: _parseDouble(json['air_temp']),
      airHum: _parseDouble(json['air_hum']),
      ec: _parseDouble(json['ec']),
      ph: _parseDouble(json['ph']),
      nitrogen: _parseDouble(json['N']),
      phosphorus: _parseDouble(json['P']),
      potassium: _parseDouble(json['K']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Returns a human-readable "X minutes ago" string
  String get timeAgo {
    if (timestamp == null) return 'Unknown time';
    
    final Duration diff = DateTime.now().difference(timestamp!.toLocal());
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} seconds ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
  }

  /// Returns formatted local time string
  String get formattedTime {
    if (timestamp == null) return 'No timestamp';
    
    final local = timestamp!.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return '$day/$month/$year $hour:$minute';
  }
}

