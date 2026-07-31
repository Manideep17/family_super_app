import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/shared_list.dart';
import '../providers/lists_providers.dart';
import 'meal_planner_screen.dart';
import 'shared_list_detail_screen.dart';

/// Family shared lists — grocery, to-do, packing, whatever the family wants
/// to track together — plus the entry point to the weekly meal planner.
class SharedListsHomeScreen extends ConsumerWidget {
  const SharedListsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final listsAsync = ref.watch(sharedListsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lists & meals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New list'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.tertiaryContainer,
                child: Icon(Icons.restaurant_menu_rounded,
                    color: scheme.onTertiaryContainer),
              ),
              title: const Text('Meal planner'),
              subtitle: const Text('Plan breakfast, lunch, and dinner for the week'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MealPlannerScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('Shared lists', style: Theme.of(context).textTheme.titleMedium),
          ),
          listsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('$e'),
            ),
            data: (lists) {
              if (lists.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.checklist_rounded,
                            size: 48, color: scheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          'No shared lists yet — tap "New list" for groceries, a packing list, or anything else the family needs to track together.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: lists.map((l) => _ListTile(list: l)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  static Future<void> _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameCtrl = TextEditingController();
    var kind = SharedListKind.grocery;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New shared list'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'List name'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<SharedListKind>(
                segments: const [
                  ButtonSegment(
                    value: SharedListKind.grocery,
                    label: Text('Grocery'),
                    icon: Icon(Icons.local_grocery_store_outlined),
                  ),
                  ButtonSegment(
                    value: SharedListKind.todo,
                    label: Text('To-do'),
                    icon: Icon(Icons.checklist_outlined),
                  ),
                  ButtonSegment(
                    value: SharedListKind.other,
                    label: Text('Other'),
                    icon: Icon(Icons.list_alt_outlined),
                  ),
                ],
                selected: {kind},
                onSelectionChanged: (s) => setState(() => kind = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await ref
                      .read(listsRepositoryProvider)
                      .createList(name: name, kind: kind);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({required this.list});

  final SharedList list;

  IconData get _icon {
    switch (list.kind) {
      case SharedListKind.grocery:
        return Icons.local_grocery_store_outlined;
      case SharedListKind.todo:
        return Icons.checklist_outlined;
      case SharedListKind.other:
        return Icons.list_alt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_icon),
        title: Text(list.name),
        subtitle: Text(list.kind.label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SharedListDetailScreen(listId: list.id),
          ),
        ),
      ),
    );
  }
}
