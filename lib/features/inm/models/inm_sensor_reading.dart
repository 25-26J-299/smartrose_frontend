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
      soilTemp: _parseDouble(json['soil_temp'] ?? json['soil_temperature']),
      airTemp: _parseDouble(json['air_temp']),
      airHum: _parseDouble(json['air_hum']),
      ec: _parseDouble(json['ec']),
      ph: _parseDouble(json['ph']),
      nitrogen: _parseDouble(json['N']),
      phosphorus: _parseDouble(json['P']),
      potassium: _parseDouble(json['K']),
    );
  }

  /// Parse timestamp - backend already stores Sri Lanka Time
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    
    String timestampStr = value.toString().trim();
    if (timestampStr.isEmpty) return null;
    
    // Fix malformed timestamps like "2025-12-28T10:0:14Z" -> "2025-12-28T10:00:14Z"
    timestampStr = _normalizeTimestamp(timestampStr);
    
    // Remove 'Z' suffix if present - backend stores Sri Lanka time, not UTC
    if (timestampStr.endsWith('Z')) {
      timestampStr = timestampStr.substring(0, timestampStr.length - 1);
    }
    
    // Parse as local time (backend already stores Sri Lanka time)
    final parsedTime = DateTime.tryParse(timestampStr);
    if (parsedTime == null) return null;
    
    // Return as local DateTime with Sri Lanka time values (no conversion needed)
    return DateTime(
      parsedTime.year,
      parsedTime.month,
      parsedTime.day,
      parsedTime.hour,
      parsedTime.minute,
      parsedTime.second,
      parsedTime.millisecond,
      parsedTime.microsecond,
    );
  }

  /// Normalize malformed timestamps (e.g., "10:0:14" -> "10:00:14")
  static String _normalizeTimestamp(String ts) {
    // Match time parts and pad with zeros if needed
    // Pattern: T followed by H:M:S where H, M, S might be single digits
    final timeMatch = RegExp(r'T(\d{1,2}):(\d{1,2}):(\d{1,2})').firstMatch(ts);
    if (timeMatch != null) {
      final hour = timeMatch.group(1)!.padLeft(2, '0');
      final minute = timeMatch.group(2)!.padLeft(2, '0');
      final second = timeMatch.group(3)!.padLeft(2, '0');
      ts = ts.replaceFirst(
        timeMatch.group(0)!,
        'T$hour:$minute:$second',
      );
    }
    return ts;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Get current time in Sri Lanka (UTC+5:30)
  static DateTime get _sriLankaNow {
    final utcNow = DateTime.now().toUtc();
    final sriLankaTime = utcNow.add(const Duration(hours: 5, minutes: 30));
    return DateTime(
      sriLankaTime.year,
      sriLankaTime.month,
      sriLankaTime.day,
      sriLankaTime.hour,
      sriLankaTime.minute,
      sriLankaTime.second,
      sriLankaTime.millisecond,
    );
  }

  /// Returns a human-readable "X minutes ago" string (based on Sri Lanka time)
  String get timeAgo {
    if (timestamp == null) return 'Unknown time';
    
    // Compare with current Sri Lanka time
    final Duration diff = _sriLankaNow.difference(timestamp!);
    
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

  /// Returns formatted Sri Lanka time string
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

  /// Returns formatted Sri Lanka time string with timezone indicator
  String get formattedTimeWithZone {
    if (timestamp == null) return 'No timestamp';
    
    final hour = timestamp!.hour.toString().padLeft(2, '0');
    final minute = timestamp!.minute.toString().padLeft(2, '0');
    final day = timestamp!.day.toString().padLeft(2, '0');
    final month = timestamp!.month.toString().padLeft(2, '0');
    final year = timestamp!.year;
    return '$day/$month/$year $hour:$minute (SLT)';
  }
}

