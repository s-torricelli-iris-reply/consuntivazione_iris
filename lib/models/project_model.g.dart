// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Project _$ProjectFromJson(Map<String, dynamic> json) => Project(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  color: json['color'] as String,
  commessaId: json['commessaId'] as String?,
  isBillable: json['isBillable'] as bool? ?? false,
  hourlyCost: (json['hourlyCost'] as num?)?.toDouble(),
  hourlyRate: (json['hourlyRate'] as num?)?.toDouble(),
  estimatedHours: (json['estimatedHours'] as num?)?.toDouble(),
  estimatedBudget: (json['estimatedBudget'] as num?)?.toDouble(),
  ownerUserId: json['ownerUserId'] as String?,
  createdByUserId: json['createdByUserId'] as String?,
  isActive: json['isActive'] as bool? ?? true,
  createdAt: DateTime.parse(json['createdAt'] as String),
  assignedUserIds:
      (json['assignedUserIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$ProjectToJson(Project instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'color': instance.color,
  'commessaId': instance.commessaId,
  'isBillable': instance.isBillable,
  'hourlyCost': instance.hourlyCost,
  'hourlyRate': instance.hourlyRate,
  'estimatedHours': instance.estimatedHours,
  'estimatedBudget': instance.estimatedBudget,
  'ownerUserId': instance.ownerUserId,
  'createdByUserId': instance.createdByUserId,
  'isActive': instance.isActive,
  'createdAt': instance.createdAt.toIso8601String(),
  'assignedUserIds': instance.assignedUserIds,
};
