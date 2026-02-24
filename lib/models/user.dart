class User {
  const User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    this.status,
    this.createdAt,
    this.lastLogin,
    this.isActive = true,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final String? status;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final bool isActive;

  /// Legacy: name for backward compatibility
  String get name => fullName;

  /// Legacy: roles as list for backward compatibility
  List<String> get roles => [role];

  factory User.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];
    final lastLoginRaw = json['last_login'];
    return User(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      fullName: json['full_name'] as String? ?? json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? (json['roles'] as List<dynamic>?)?[0]?.toString() ?? 'farmer',
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
    'status': status,
    'created_at': createdAt?.toIso8601String(),
    'last_login': lastLogin?.toIso8601String(),
    'is_active': isActive,
  };
}
