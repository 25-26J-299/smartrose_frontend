/// Utility class for role-based filtering
class RoleFilter {
  /// Check if user has farmer role
  static bool isFarmer(List<String> roles) {
    return roles.contains('farmer');
  }

  /// Check if user has florist role
  static bool isFlorist(List<String> roles) {
    return roles.contains('florist');
  }

  /// Check if user has both roles
  static bool hasBothRoles(List<String> roles) {
    return isFarmer(roles) && isFlorist(roles);
  }

  /// Check if component should be shown based on roles
  /// 
  /// Component types:
  /// - 'freshness' (FM) - Florist only
  /// - 'inm' (INM) - Farmer only
  /// - 'disease' - Farmer only
  /// - 'environment' (EOSF/EDAS) - Farmer only
  static bool shouldShowComponent(String componentType, List<String> roles) {
    final bool isFarmerRole = isFarmer(roles);
    final bool isFloristRole = isFlorist(roles);

    // If user has both roles, show everything
    if (hasBothRoles(roles)) {
      return true;
    }

    // Florist only: show freshness
    if (componentType == 'freshness') {
      return isFloristRole;
    }

    // Farmer only: show INM, disease, environment
    if (componentType == 'inm' ||
        componentType == 'disease' ||
        componentType == 'environment') {
      return isFarmerRole;
    }

    // Default: don't show if role doesn't match
    return false;
  }

  /// Get filtered components for dashboard
  static List<T> filterComponents<T>({
    required List<T> allComponents,
    required List<String> roles,
    required String Function(T) getComponentType,
  }) {
    if (hasBothRoles(roles)) {
      return allComponents;
    }

    return allComponents.where((component) {
      final componentType = getComponentType(component);
      return shouldShowComponent(componentType, roles);
    }).toList();
  }
}

