// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['id'] as String,
  email: json['email'] as String,
  name: json['name'] as String,
  surname: json['surname'] as String,
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  developerType: $enumDecodeNullable(
    _$DeveloperTypeEnumMap,
    json['developerType'],
  ),
  managerId: json['managerId'] as String?,
  teamLeadId: json['teamLeadId'] as String?,
  canCreateProjects: json['canCreateProjects'] as bool? ?? false,
  isActive: json['isActive'] as bool? ?? true,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'name': instance.name,
  'surname': instance.surname,
  'role': _$UserRoleEnumMap[instance.role]!,
  'developerType': _$DeveloperTypeEnumMap[instance.developerType],
  'managerId': instance.managerId,
  'teamLeadId': instance.teamLeadId,
  'canCreateProjects': instance.canCreateProjects,
  'isActive': instance.isActive,
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$UserRoleEnumMap = {
  UserRole.admin: 'admin',
  UserRole.manager: 'manager',
  UserRole.teamLead: 'teamLead',
  UserRole.employee: 'employee',
};

const _$DeveloperTypeEnumMap = {
  DeveloperType.android: 'android',
  DeveloperType.ios: 'ios',
  DeveloperType.fullStack: 'fullStack',
  DeveloperType.backend: 'backend',
  DeveloperType.frontend: 'frontend',
  DeveloperType.designer: 'designer',
  DeveloperType.qa: 'qa',
};
