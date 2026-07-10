import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/domain/entities/family_member.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../data/tasks_repository_impl.dart';
import '../../domain/entities/family_task.dart';
import '../../domain/repositories/tasks_repository.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final scope = ref.watch(familyScopeProvider);
  final me = ref.watch(currentMemberProvider).valueOrNull;
  final roster =
      ref.watch(familyMembersProvider).valueOrNull ?? const <FamilyMember>[];
  return TasksRepositoryImpl(
    scope: scope,
    roster: roster,
    memberDisplayName: me?.displayName,
  );
});

final myTasksStreamProvider = StreamProvider<List<FamilyTask>>((ref) {
  return ref.watch(tasksRepositoryProvider).watchTasksInvolvingMe();
});

final taskDetailProvider =
    StreamProvider.family<FamilyTask?, String>((ref, id) {
  return ref.watch(tasksRepositoryProvider).watchTask(id);
});
