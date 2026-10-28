enum UserRole {
  agencyManager,
  agencyAgent;

  String get label {
    switch (this) {
      case UserRole.agencyManager:
        return 'Responsable d\'agence';
      case UserRole.agencyAgent:
        return 'Agent de guichet';
    }
  }
}

class Agency {
  final String id;
  final String name;
  final String code;
  final String phone;
  final String cityHeadquarters;
  final DateTime createdAt;

  const Agency({
    required this.id,
    required this.name,
    required this.code,
    required this.phone,
    required this.cityHeadquarters,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'phone': phone,
      'city_headquarters': cityHeadquarters,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Agency.fromMap(Map<String, dynamic> map) {
    return Agency(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      code: map['code'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      cityHeadquarters: map['city_headquarters'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Agency copyWith({
    String? name,
    String? code,
    String? phone,
    String? cityHeadquarters,
  }) {
    return Agency(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      phone: phone ?? this.phone,
      cityHeadquarters: cityHeadquarters ?? this.cityHeadquarters,
      createdAt: createdAt,
    );
  }
}

class AgencyMember {
  final String id;
  final String agencyId;
  final String userId;
  final String fullName;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  String get roleLabel => role.label;

  const AgencyMember({
    required this.id,
    required this.agencyId,
    required this.userId,
    required this.fullName,
    required this.role,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'agency_id': agencyId,
      'user_id': userId,
      'full_name': fullName,
      'role': role.name,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AgencyMember.fromMap(Map<String, dynamic> map) {
    UserRole parsedRole;
    try {
      parsedRole = UserRole.values.byName(map['role'] as String? ?? 'agencyAgent');
    } catch (_) {
      parsedRole = UserRole.agencyAgent;
    }

    return AgencyMember(
      id: map['id'] as String? ?? '',
      agencyId: map['agency_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      role: parsedRole,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
