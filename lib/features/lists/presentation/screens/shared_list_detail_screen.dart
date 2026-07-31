import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/shared_list_item.dart';
import '../providers/lists_providers.dart';

class SharedListDetailScreen extends ConsumerWidget {
  const SharedListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(sharedListProvider(listId));
    final itemsAsync = ref.watch(sharedListItemsProvider(listId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(listAsync.valueOrNull?.name ?? 'List'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              final repo = ref.read(listsRepositoryProvider);
              if (v == 'clear') {
                await repo.clearChecked(listId);
              } else if (v == 'archive') {
                await repo.setArchived(listId, true);
                if (context.mounted) Navigator.of(context).pop();
              } else if (v == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete this list?'),
                    content: const Text('This removes it for the whole family.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await repo.deleteList(listId);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear checked items')),
              PopupMenuItem(value: 'archive', child: Text('Archive list')),
              PopupMenuItem(value: 'delete', child: Text('Delete list')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemSheet(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.playlist_add_check_rounded,
                        size: 56, color: scheme.outline),
                    const SizedBox(height: 16),
                    const Text('Nothing on this list yet — add the first item.'),
                  ],
                ),
              ),
            );
          }
          final unchecked = items.where((i) => !i.checked).toList();
          final checked = items.where((i) => i.checked).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            children: [
              ...unchecked.map((i) => _ItemTile(listId: listId, item: i)),
              if (checked.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    '${checked.length} checked off',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                ...checked.map((i) => _ItemTile(listId: listId, item: i)),
              ],
            ],
          );
        },
      ),
    );
  }

  static Future<void> _showAddItemSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ctrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Add an item…'),
                onSubmitted: (v) async {
                  Navigator.pop(ctx);
                  await ref.read(listsRepositoryProvider).addItem(listId, v);
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: () async {
                final v = ctrl.text;
                Navigator.pop(ctx);
                await ref.read(listsRepositoryProvider).addItem(listId, v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.listId, required this.item});

  final String listId;
  final SharedListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Icon(Icons.delete_outline_rounded),
      ),
      onDismissed: (_) {
        ref.read(listsRepositoryProvider).deleteItem(listId, item.id);
      },
      child: CheckboxListTile(
        value: item.checked,
        onChanged: (v) {
          ref
              .read(listsRepositoryProvider)
              .setChecked(listId, item.id, v ?? false);
        },
        title: Text(
          item.text,
          style: item.checked
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}
