class RolePermission {
  final String roleName;
  final List<String> permissionIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RolePermission({
    required this.roleName,
    required this.permissionIds,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'roleName': roleName,
      'permissionIds': permissionIds,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory RolePermission.fromJson(Map<String, dynamic> json) {
    return RolePermission(
      roleName: json['roleName'] as String,
      permissionIds: (json['permissionIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  RolePermission copyWith({
    String? roleName,
    List<String>? permissionIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RolePermission(
      roleName: roleName ?? this.roleName,
      permissionIds: permissionIds ?? this.permissionIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

