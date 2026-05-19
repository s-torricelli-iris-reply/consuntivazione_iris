import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

enum UserRole { admin, manager, teamLead, employee }

enum DeveloperType { android, ios, fullStack, backend, frontend, designer, qa }

@JsonSerializable()
class User {
  static const Object _unset = Object();

  final String id;
  final String email;
  final String name;
  final String surname;
  final UserRole role;
  final DeveloperType? developerType;
  final String? managerId;
  final String? teamLeadId;
  final bool canCreateProjects;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.surname,
    required this.role,
    this.developerType,
    this.managerId,
    this.teamLeadId,
    this.canCreateProjects = false,
    this.isActive = true,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? surname,
    UserRole? role,
    Object? developerType = _unset,
    Object? managerId = _unset,
    Object? teamLeadId = _unset,
    bool? canCreateProjects,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      role: role ?? this.role,
      developerType: identical(developerType, _unset)
          ? this.developerType
          : developerType as DeveloperType?,
      managerId: identical(managerId, _unset)
          ? this.managerId
          : managerId as String?,
      teamLeadId: identical(teamLeadId, _unset)
          ? this.teamLeadId
          : teamLeadId as String?,
      canCreateProjects: canCreateProjects ?? this.canCreateProjects,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get fullName => '$name $surname';
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.teamLead:
        return 'Team Lead';
      case UserRole.employee:
        return 'Developer';
    }
  }

  bool get canManageProjects {
    return this == UserRole.admin ||
        this == UserRole.manager ||
        this == UserRole.teamLead;
  }

  bool get canViewTeamDashboard {
    return canManageProjects;
  }
}

extension DeveloperTypeExtension on DeveloperType {
  String get displayName {
    switch (this) {
      case DeveloperType.android:
        return 'Android';
      case DeveloperType.ios:
        return 'iOS';
      case DeveloperType.fullStack:
        return 'Full Stack';
      case DeveloperType.backend:
        return 'Backend';
      case DeveloperType.frontend:
        return 'Frontend';
      case DeveloperType.designer:
        return 'Designer';
      case DeveloperType.qa:
        return 'QA';
    }
  }
}
