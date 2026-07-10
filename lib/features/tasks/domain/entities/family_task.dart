import 'package:equatable/equatable.dart';

enum TaskStatus {
  pending,
  submitted,
  approved,
  rejected;

  static TaskStatus parse(String? raw) {
    switch (raw) {
      case 'submitted':
        return TaskStatus.submitted;
      case 'approved':
        return TaskStatus.approved;
      case 'rejected':
        return TaskStatus.rejected;
      default:
        return TaskStatus.pending;
    }
  }

  String get wireName => name;
}

/// `tasks/{id}` — anyone in the family can assign; assigner approves after submit.
class FamilyTask extends Equatable {
  const FamilyTask({
    required this.id,
    required this.title,
    required this.description,
    required this.assignerUid,
    required this.assignerEmail,
    required this.assignerName,
    required this.assigneeEmail,
    required this.assigneeName,
    required this.dueAt,
    required this.rewardPoints,
    required this.status,
    required this.createdAt,
    this.submittedNote,
    this.rejectedReason,
    this.assigneeUid = '',
  });

  final String id;
  final String title;
  final String description;
  final String assignerUid;
  final String assignerEmail;
  final String assignerName;
  final String assigneeEmail;
  final String assigneeName;
  /// Set when assignee submits (used for reward points on approve).
  final String assigneeUid;
  final DateTime dueAt;
  final int rewardPoints;
  final TaskStatus status;
  final DateTime createdAt;
  final String? submittedNote;
  final String? rejectedReason;

  bool isAssignee(String myEmail) =>
      assigneeEmail.toLowerCase() == myEmail.toLowerCase();

  bool isAssigner(String myEmail) =>
      assignerEmail.toLowerCase() == myEmail.toLowerCase();

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        assignerUid,
        assignerEmail,
        assignerName,
        assigneeEmail,
        assigneeName,
        dueAt,
        rewardPoints,
        status,
        createdAt,
        submittedNote,
        rejectedReason,
        assigneeUid,
      ];
}
