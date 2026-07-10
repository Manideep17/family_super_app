import '../entities/family_task.dart';

abstract class TasksRepository {
  /// Tasks where the current user is assigner or assignee (`participantEmails`).
  Stream<List<FamilyTask>> watchTasksInvolvingMe();

  Stream<FamilyTask?> watchTask(String taskId);

  Future<String> createTask({
    required String title,
    required String description,
    required String assigneeEmail,
    required DateTime dueAt,
    required int rewardPoints,
  });

  /// Assignee marks done and requests approval from the assigner.
  Future<void> submitTask(String taskId, {String? note});

  /// Only the assigner can approve.
  Future<void> approveTask(String taskId);

  /// Only the assigner can reject.
  Future<void> rejectTask(String taskId, {String? reason});
}
