import 'package:json_annotation/json_annotation.dart';

part 'project_model.g.dart';

@JsonSerializable()
class Project {
  final String id;
  final String name;
  final String description;
  final String color; // Hex color
  final String? commessaId;
  final bool isBillable;
  final double? hourlyCost;
  final double? hourlyRate;
  final double? estimatedHours;
  final double? estimatedBudget;
  final String? ownerUserId;
  final String? createdByUserId;
  final bool isActive;
  final DateTime createdAt;
  final List<String> assignedUserIds;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    this.commessaId,
    this.isBillable = false,
    this.hourlyCost,
    this.hourlyRate,
    this.estimatedHours,
    this.estimatedBudget,
    this.ownerUserId,
    this.createdByUserId,
    this.isActive = true,
    required this.createdAt,
    this.assignedUserIds = const [],
  });

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);
  Map<String, dynamic> toJson() => _$ProjectToJson(this);

  Project copyWith({
    String? id,
    String? name,
    String? description,
    String? color,
    String? commessaId,
    bool? isBillable,
    double? hourlyCost,
    double? hourlyRate,
    double? estimatedHours,
    double? estimatedBudget,
    String? ownerUserId,
    String? createdByUserId,
    bool? isActive,
    DateTime? createdAt,
    List<String>? assignedUserIds,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      commessaId: commessaId ?? this.commessaId,
      isBillable: isBillable ?? this.isBillable,
      hourlyCost: hourlyCost ?? this.hourlyCost,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      estimatedBudget: estimatedBudget ?? this.estimatedBudget,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      assignedUserIds: assignedUserIds ?? this.assignedUserIds,
    );
  }
}
