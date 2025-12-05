class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final List<String> roles;
  final DateTime? createdAt;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      roles: (json['roles'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic role) => role.toString())
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String? ?? '')
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        '_id': id,
        'name': name,
        'email': email,
        'roles': roles,
        'created_at': createdAt?.toIso8601String(),
      };
}

