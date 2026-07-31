import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/presentation/providers/family_providers.dart';
import '../../data/lists_repository.dart';
import '../../data/meal_plan_repository.dart';
import '../../domain/meal_plan_week.dart';
import '../../domain/shared_list.dart';
import '../../domain/shared_list_item.dart';

final listsRepositoryProvider = Provider<ListsRepository>((ref) {
  final scope = ref.watch(familyScopeProvider);
  return ListsRepository(scope: scope);
});

final mealPlanRepositoryProvider = Provider<MealPlanRepository>((ref) {
  final scope = ref.watch(familyScopeProvider);
  return MealPlanRepository(scope: scope);
});

final sharedListsStreamProvider =
    StreamProvider.autoDispose<List<SharedList>>((ref) {
  return ref.watch(listsRepositoryProvider).watchLists();
});

final sharedListProvider =
    StreamProvider.autoDispose.family<SharedList?, String>((ref, listId) {
  return ref.watch(listsRepositoryProvider).watchList(listId);
});

final sharedListItemsProvider = StreamProvider.autoDispose
    .family<List<SharedListItem>, String>((ref, listId) {
  return ref.watch(listsRepositoryProvider).watchItems(listId);
});

/// Defaults to the current ISO week — pass a different weekId to browse
/// other weeks later if that's ever added.
final mealPlanWeekProvider =
    StreamProvider.autoDispose.family<MealPlanWeek, String>((ref, weekId) {
  return ref.watch(mealPlanRepositoryProvider).watchWeek(weekId);
});
