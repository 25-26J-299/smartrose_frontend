// File: lib/features/inm/models/inm_status.dart
// Purpose: Model class for INM status response from Random Forest ML model

class InmStatus {
  final double currentEc;
  final double predictedEc24h;
  final String ecStatus;
  final String ecAction;
  final String phAction;
  final String npkRecommendation;

  InmStatus({
    required this.currentEc,
    required this.predictedEc24h,
    required this.ecStatus,
    required this.ecAction,
    required this.phAction,
    required this.npkRecommendation,
  });

  factory InmStatus.fromJson(Map<String, dynamic> json) {
    return InmStatus(
      currentEc: _parseDouble(json['current_ec'] ?? json['currentEc']),
      predictedEc24h: _parseDouble(json['predicted_ec_24h'] ?? json['predictedEc24h']),
      ecStatus: json['ec_status']?.toString() ?? 'unknown',
      ecAction: json['ec_action']?.toString() ?? 'No EC action available',
      phAction: json['ph_action']?.toString() ?? 'No pH action available',
      npkRecommendation: json['npk_recommendation']?.toString() ?? 'No NPK recommendation available',
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Returns the EC status type for color coding
  EcStatusType get statusType {
    switch (ecStatus.toLowerCase()) {
      case 'optimal':
        return EcStatusType.optimal;
      case 'low':
        return EcStatusType.low;
      case 'high':
        return EcStatusType.high;
      case 'critical_low':
        return EcStatusType.criticalLow;
      case 'critical_high':
        return EcStatusType.criticalHigh;
      default:
        return EcStatusType.unknown;
    }
  }

  /// Returns human-readable status label
  String get statusLabel {
    switch (statusType) {
      case EcStatusType.optimal:
        return 'Optimal';
      case EcStatusType.low:
        return 'Low';
      case EcStatusType.high:
        return 'High';
      case EcStatusType.criticalLow:
        return 'Critical Low';
      case EcStatusType.criticalHigh:
        return 'Critical High';
      case EcStatusType.unknown:
        return 'Unknown';
    }
  }

  /// Calculate EC change percentage
  double get ecChangePercent {
    if (currentEc == 0) return 0;
    return ((predictedEc24h - currentEc) / currentEc) * 100;
  }

  /// Check if EC is trending up or down
  bool get isEcIncreasing => predictedEc24h > currentEc;
}

enum EcStatusType {
  optimal,      // Green
  low,          // Orange
  high,         // Orange
  criticalLow,  // Red
  criticalHigh, // Red
  unknown,      // Grey
}
