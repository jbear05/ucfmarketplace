class User {
  final String id;
  final String name;
  final String email;
  final bool isVerifiedStudent;
  final bool isAdmin;
  final List<String> favorites;
  final String avatarKey;
  final double ratingAvg;
  final int ratingCount;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.isVerifiedStudent = false,
    this.isAdmin = false,
    this.favorites = const [],
    this.avatarKey = 'student_male',
    this.ratingAvg = 0,
    this.ratingCount = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id:                json['_id'] ?? json['id'] ?? '',
    name:              json['name'] ?? '',
    email:             json['email'] ?? '',
    isVerifiedStudent: json['isVerifiedStudent'] ?? false,
    isAdmin:           json['isAdmin'] ?? json['role'] == 'admin',
    favorites:         (json['favorites'] as List? ?? []).map((f) {
      if (f is String) return f;
      if (f is Map) return (f['_id'] ?? f['id'] ?? '').toString();
      return f.toString();
    }).where((id) => id.isNotEmpty).toList(),
    avatarKey:         json['avatarKey'] ?? 'student_male',
    ratingAvg:         (json['ratingAvg'] ?? 0).toDouble(),
    ratingCount:       json['ratingCount'] ?? 0,
  );

  User copyWith({
    String? id, String? name, String? email,
    bool? isVerifiedStudent, bool? isAdmin,
    List<String>? favorites, String? avatarKey,
    double? ratingAvg, int? ratingCount,
  }) => User(
    id:                id ?? this.id,
    name:              name ?? this.name,
    email:             email ?? this.email,
    isVerifiedStudent: isVerifiedStudent ?? this.isVerifiedStudent,
    isAdmin:           isAdmin ?? this.isAdmin,
    favorites:         favorites ?? this.favorites,
    avatarKey:         avatarKey ?? this.avatarKey,
    ratingAvg:         ratingAvg ?? this.ratingAvg,
    ratingCount:       ratingCount ?? this.ratingCount,
  );
}
