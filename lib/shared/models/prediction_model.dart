/// Model representing freshness prediction data.
/// Matches backend FMPredictionResponse structure.
class PredictionModel {
  const PredictionModel({
    required this.freshnessScore,
    required this.vaseLifeHours,
    required this.alerts,
  });

  final double freshnessScore; // 0.0 to 100.0
  final double vaseLifeHours; // Predicted vase life in hours
  final List<String> alerts; // Alert messages for detected issues

  factory PredictionModel.fromJson(Map<String, dynamic> json) {
    return PredictionModel(
      freshnessScore: (json['freshness_score'] as num).toDouble(),
      vaseLifeHours: (json['vase_life_hours'] as num).toDouble(),
      alerts: json['alerts'] != null
          ? List<String>.from(json['alerts'] as List)
          : <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'freshness_score': freshnessScore,
      'vase_life_hours': vaseLifeHours,
      'alerts': alerts,
    };
  }
}
