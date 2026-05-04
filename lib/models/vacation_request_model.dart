enum VacationRequestStatus { pending, approved, rejected }

class VacationRequest {
  final String id;
  final String requesterUserId;
  final String approverUserId;
  final DateTime startDate;
  final DateTime endDate;
  final int workingDays;
  final String motivation;
  final VacationRequestStatus status;
  final String? reviewerUserId;
  final String? reviewerNote;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;

  const VacationRequest({
    required this.id,
    required this.requesterUserId,
    required this.approverUserId,
    required this.startDate,
    required this.endDate,
    required this.workingDays,
    required this.motivation,
    this.status = VacationRequestStatus.pending,
    this.reviewerUserId,
    this.reviewerNote,
    required this.createdAt,
    this.updatedAt,
    this.reviewedAt,
  });

  factory VacationRequest.fromJson(Map<String, dynamic> json) {
    return VacationRequest(
      id: json['id'].toString(),
      requesterUserId: json['requesterUserId'].toString(),
      approverUserId: json['approverUserId'].toString(),
      startDate: DateTime.parse(json['startDate'].toString()),
      endDate: DateTime.parse(json['endDate'].toString()),
      workingDays: (json['workingDays'] as num?)?.toInt() ?? 0,
      motivation: (json['motivation'] ?? '').toString(),
      status: _statusFromJson(json['status']),
      reviewerUserId: json['reviewerUserId']?.toString(),
      reviewerNote: json['reviewerNote']?.toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'].toString()),
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.parse(json['reviewedAt'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'requesterUserId': requesterUserId,
    'approverUserId': approverUserId,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'workingDays': workingDays,
    'motivation': motivation,
    'status': status.name,
    'reviewerUserId': reviewerUserId,
    'reviewerNote': reviewerNote,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'reviewedAt': reviewedAt?.toIso8601String(),
  };

  VacationRequest copyWith({
    String? id,
    String? requesterUserId,
    String? approverUserId,
    DateTime? startDate,
    DateTime? endDate,
    int? workingDays,
    String? motivation,
    VacationRequestStatus? status,
    String? reviewerUserId,
    String? reviewerNote,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reviewedAt,
  }) {
    return VacationRequest(
      id: id ?? this.id,
      requesterUserId: requesterUserId ?? this.requesterUserId,
      approverUserId: approverUserId ?? this.approverUserId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      workingDays: workingDays ?? this.workingDays,
      motivation: motivation ?? this.motivation,
      status: status ?? this.status,
      reviewerUserId: reviewerUserId ?? this.reviewerUserId,
      reviewerNote: reviewerNote ?? this.reviewerNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  static VacationRequestStatus _statusFromJson(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    return VacationRequestStatus.values.firstWhere(
      (status) => status.name.toLowerCase() == value,
      orElse: () => VacationRequestStatus.pending,
    );
  }
}

extension VacationRequestStatusExtension on VacationRequestStatus {
  String get displayName {
    switch (this) {
      case VacationRequestStatus.pending:
        return 'In lavorazione';
      case VacationRequestStatus.approved:
        return 'Accettata';
      case VacationRequestStatus.rejected:
        return 'Respinta';
    }
  }
}
