/// Represents a user-owned location (greenhouse or flower shop).
class LocationModel {
  const LocationModel({
    required this.id,
    required this.name,
    required this.type,
    this.address,
  });

  final String id;
  final String name;

  /// 'greenhouse' or 'flower_shop'
  final String type;

  final String? address;

  bool get isGreenhouse => type.toLowerCase() == 'greenhouse';
  bool get isFlowerShop => type.toLowerCase() == 'flower_shop';

  /// Human-readable label for the type
  String get typeLabel => isGreenhouse ? 'Greenhouse' : 'Flower Shop';

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Unknown',
      type: json['type'] as String? ?? 'greenhouse',
      address: json['address'] as String?,
    );
  }
}
