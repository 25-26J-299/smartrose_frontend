import 'package:flutter/material.dart';

/// Model representing EOSM stress prediction data.
/// Matches backend EOSMStressPredictionResponse structure.

// Start of EOSM

class EosmStressPrediction {
  const EosmStressPrediction({
    required this.stressLabel,
    required this.stressProbabilities,
    this.timestamp,
  });

  final String stressLabel; // "HIGH", "MEDIUM", or "LOW"
  final Map<String, double> stressProbabilities; // Probabilities for each label
  final DateTime? timestamp; // Prediction timestamp

  factory EosmStressPrediction.fromJson(Map<String, dynamic> json) {
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

    // Parse probabilities map
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

    return EosmStressPrediction(
      stressLabel: (json['stress_label'] as String?) ?? 'LOW',
      stressProbabilities: parseProbabilities(json['stress_probabilities']),
      timestamp: parseTimestamp(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stress_label': stressLabel,
      'stress_probabilities': stressProbabilities,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
    };
  }

  /// Get stress level color for UI
  Color get stressColor {
    switch (stressLabel.toUpperCase()) {
      case 'HIGH':
        return const Color(0xFFF44336); // Red
      case 'MEDIUM':
        return const Color(0xFFFFC107); // Amber
      case 'LOW':
      default:
        return const Color(0xFF4CAF50); // Green
    }
  }

  /// Get highest probability value
  double get highestProbability {
    if (stressProbabilities.isEmpty) return 0.0;
    return stressProbabilities.values.reduce((a, b) => a > b ? a : b);
  }
}

// End of EOSM

