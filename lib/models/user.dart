class User {
  const User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.roles,
    this.status,
    this.createdAt,
    this.lastLogin,
    this.isActive = true,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;

  /// All roles the user holds (e.g. ["farmer"], ["florist"], ["farmer","florist"])
  final List<String> roles;

  /// Primary role (first in list, or 'farmer' as fallback)
  String get role => roles.isNotEmpty ? roles.first : 'farmer';

  /// Legacy alias
  String get name => fullName;

  final String? status;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final bool isActive;

  factory User.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];
    final lastLoginRaw = json['last_login'];

    // Parse roles list from backend; fall back to single role field
    final List<String> rolesList = () {
      final raw = json['roles'];
      if (raw is List && raw.isNotEmpty) {
        return raw.map((e) => e.toString()).toList();
      }
      final singleRole = json['role'] as String?;
      if (singleRole != null && singleRole.isNotEmpty) {
        return [singleRole];
      }
      return ['farmer'];
    }();

    return User(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      fullName: json['full_name'] as String? ?? json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      roles: rolesList,
      status: json['status'] as String?,
      createdAt: createdAtRaw != null ? DateTime.tryParse(createdAtRaw.toString()) : null,
      lastLogin: lastLoginRaw != null ? DateTime.tryParse(lastLoginRaw.toString()) : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    '_id': id,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'role': role,
    'roles': roles,
    'status': status,
    'created_at': createdAt?.toIso8601String(),
    'last_login': lastLogin?.toIso8601String(),
    'is_active': isActive,
  };
}
