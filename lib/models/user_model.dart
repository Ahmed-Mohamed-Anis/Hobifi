class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String? phone;
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? username;
  final String? bio;
  final List<String> interests;
  final String? city;
  final bool businessOnboarded;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.phone,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.username,
    this.bio,
    this.interests = const [],
    this.city,
    this.businessOnboarded = false,
  });

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    email: (json['email'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    avatarUrl: json['avatar_url'] as String?,
    phone: json['phone'] as String?,
    role: UserRole.values.firstWhere((e) => e.name == json['role'], orElse: () => UserRole.user),
    createdAt: _parseDate(json['created_at']),
    updatedAt: _parseDate(json['updated_at']),
    username: json['username'] as String?,
    bio: json['bio'] as String?,
    interests: (json['interests'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    city: json['city'] as String?,
    businessOnboarded: (json['business_onboarded'] as bool?) ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'avatar_url': avatarUrl,
    'phone': phone,
    'role': role.name,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'username': username,
    if (bio != null) 'bio': bio,
    'interests': interests,
    if (city != null) 'city': city,
    'business_onboarded': businessOnboarded,
  };

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? phone,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? username,
    String? bio,
    List<String>? interests,
    String? city,
    bool? businessOnboarded,
  }) => UserModel(
    id: id ?? this.id,
    email: email ?? this.email,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    username: username ?? this.username,
    bio: bio ?? this.bio,
    interests: interests ?? this.interests,
    city: city ?? this.city,
    businessOnboarded: businessOnboarded ?? this.businessOnboarded,
  );
}

enum UserRole {
  user,
  business
}
