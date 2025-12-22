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
      timestamp: _parseTimestamp(json['timestamp']),
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

  /// Parse timestamp - backend stores UTC, convert to Sri Lanka Time (UTC+5:30)
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    
    final String timestampStr = value.toString();
    if (timestampStr.isEmpty) return null;
    
    // Parse timestamp - treat as UTC if no timezone specified
    DateTime? utcTime;
    
    if (timestampStr.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(timestampStr)) {
      // Already has timezone info
      utcTime = DateTime.tryParse(timestampStr)?.toUtc();
    } else {
      // No timezone - backend stores UTC without 'Z', parse as UTC
      utcTime = DateTime.tryParse('${timestampStr}Z');
    }
    
    if (utcTime == null) return null;
    
    // Convert UTC to Sri Lanka Time (UTC+5:30)
    final sriLankaTime = utcTime.add(const Duration(hours: 5, minutes: 30));
    
    // Return as local DateTime with Sri Lanka time values
    return DateTime(
      sriLankaTime.year,
      sriLankaTime.month,
      sriLankaTime.day,
      sriLankaTime.hour,
      sriLankaTime.minute,
      sriLankaTime.second,
      sriLankaTime.millisecond,
      sriLankaTime.microsecond,
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
    
    // timestamp is already converted to local time
    final Duration diff = DateTime.now().difference(timestamp!);
    
    if (diff.inSeconds < 0) {
      return 'Just now';
    } else if (diff.inSeconds < 60) {
      return '${diff.inSeconds} seconds ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
  }

  /// Returns formatted local time string (timestamp already converted to local)
  String get formattedTime {
    if (timestamp == null) return 'No timestamp';
    
    final hour = timestamp!.hour.toString().padLeft(2, '0');
    final minute = timestamp!.minute.toString().padLeft(2, '0');
    final second = timestamp!.second.toString().padLeft(2, '0');
    final day = timestamp!.day.toString().padLeft(2, '0');
    final month = timestamp!.month.toString().padLeft(2, '0');
    final year = timestamp!.year;
    return '$day/$month/$year $hour:$minute:$second';
  }
}

