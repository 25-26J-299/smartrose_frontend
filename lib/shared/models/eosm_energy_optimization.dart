/// Model for EOSM Energy Optimization (EODE) response from backend.
/// Matches backend energy_optimization structure from latest-with-prediction.

class EosmEnergyOptimization {
  const EosmEnergyOptimization({
    required this.fanLevel,
    required this.acLevel,
    required this.waterPump,
    required this.uvLightIntensity,
    required this.energyMode,
    required this.estimatedEnergySaving,
    required this.reasoning,
  });

  final String fanLevel; // OFF | LOW | MEDIUM | HIGH
  final String acLevel;
  final String waterPump; // OFF | LOW | HIGH
  final String uvLightIntensity; // OFF | LOW | MEDIUM | HIGH
  final String energyMode; // MAX_SAVING | OPTIMIZED | PROTECT
  final String estimatedEnergySaving; // e.g. "25%"
  final String reasoning;

  factory EosmEnergyOptimization.fromJson(Map<String, dynamic> json) {
    return EosmEnergyOptimization(
      fanLevel: (json['fan_level'] as String?) ?? 'LOW',
      acLevel: (json['ac_level'] as String?) ?? 'OFF',
      waterPump: (json['water_pump'] as String?) ?? 'OFF',
      uvLightIntensity: (json['uv_light_intensity'] as String?) ?? 'OFF',
      energyMode: (json['energy_mode'] as String?) ?? 'OPTIMIZED',
      estimatedEnergySaving: (json['estimated_energy_saving'] as String?) ?? '—',
      reasoning: (json['reasoning'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fan_level': fanLevel,
      'ac_level': acLevel,
      'water_pump': waterPump,
      'uv_light_intensity': uvLightIntensity,
      'energy_mode': energyMode,
      'estimated_energy_saving': estimatedEnergySaving,
      'reasoning': reasoning,
    };
  }
}
