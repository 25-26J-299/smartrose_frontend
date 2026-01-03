// File: lib/features/inm/models/inm_action_history.dart
// Purpose: Model for INM recommendation action history

class InmActionHistory {
  final String id;
  final DateTime timestamp;
  final String ecAction;
  final String phAction;
  final String npkRecommendation;
  final String? growthStage;
  final String actionTaken; // 'applied' or 'ignored'
  final String? recommendationText; // Full recommendation text

  InmActionHistory({
    required this.id,
    required this.timestamp,
    required this.ecAction,
    required this.phAction,
    required this.npkRecommendation,
    this.growthStage,
    required this.actionTaken,
    this.recommendationText,
  });

  factory InmActionHistory.fromJson(Map<String, dynamic> json) {
    return InmActionHistory(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      timestamp: _parseTimestamp(json['timestamp'] ?? json['created_at']),
      ecAction: json['ec_action']?.toString() ?? 'No EC action available',
      phAction: json['ph_action']?.toString() ?? 'No pH action available',
      npkRecommendation: json['npk_recommendation']?.toString() ?? 'No NPK recommendation available',
      growthStage: json['growth_stage']?.toString(),
      actionTaken: json['action_taken']?.toString() ?? 'unknown',
      recommendationText: json['recommendation_text']?.toString(),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    
    if (value is DateTime) return value;
    
    String timestampStr = value.toString().trim();
    if (timestampStr.isEmpty) return DateTime.now();
    
    // Remove 'Z' suffix if present
    if (timestampStr.endsWith('Z')) {
      timestampStr = timestampStr.substring(0, timestampStr.length - 1);
    }
    
    final parsedTime = DateTime.tryParse(timestampStr);
    return parsedTime ?? DateTime.now();
  }

  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final year = timestamp.year;
    return '$day/$month/$year $hour:$minute';
  }

  String get actionLabel {
    switch (actionTaken.toLowerCase()) {
      case 'applied':
        return 'Applied';
      case 'ignored':
        return 'Ignored';
      default:
        return 'Unknown';
    }
  }
}

