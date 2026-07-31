import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/meal_plan_week.dart';
import '../providers/lists_providers.dart';

/// Weekly meal planner — one Firestore doc per ISO week holding a flat
/// `day_slot -> dish` map, edited by tapping any cell in a 7×3 grid.
class MealPlannerScreen extends ConsumerWidget {
  const MealPlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekId = isoWeekId(DateTime.now());
    final weekAsync = ref.watch(mealPlanWeekProvider(weekId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Meal planner · $weekId'),
      ),
      body: weekAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
        ),
        data: (week) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
            itemCount: mealPlanDayKeys.length,
            itemBuilder: (context, dayIndex) {
              final day = mealPlanDayKeys[dayIndex];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mealPlanDayLabels[dayIndex],
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(mealPlanSlotKeys.length, (slotIndex) {
                        final slot = mealPlanSlotKeys[slotIndex];
                        final dish = week.mealFor(day, slot);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _editMeal(
                              context,
                              ref,
                              weekId: weekId,
                              day: day,
                              slot: slot,
                              current: dish,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 82,
                                    child: Text(
                                      mealPlanSlotLabels[slotIndex],
                                      style: TextStyle(
                                          color: scheme.onSurfaceVariant),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      dish.isEmpty ? 'Tap to plan…' : dish,
                                      style: TextStyle(
                                        color: dish.isEmpty
                                            ? scheme.outline
                                            : scheme.onSurface,
                                        fontStyle: dish.isEmpty
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.edit_outlined,
                                      size: 16, color: scheme.outline),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editMeal(
    BuildContext context,
    WidgetRef ref, {
    required String weekId,
    required String day,
    required String slot,
    required String current,
  }) async {
    final ctrl = TextEditingController(text: current);
    final dayLabel =
        mealPlanDayLabels[mealPlanDayKeys.indexOf(day)];
    final slotLabel =
        mealPlanSlotLabels[mealPlanSlotKeys.indexOf(slot)];
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$dayLabel · $slotLabel'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Aloo paratha'),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          if (current.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Clear'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await ref.read(mealPlanRepositoryProvider).setMeal(
          weekId: weekId,
          day: day,
          slot: slot,
          dish: result,
        );
  }
}
