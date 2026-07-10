import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/presentation/providers/family_providers.dart';
import '../providers/tasks_providers.dart';
import '../widgets/task_card.dart';
import 'create_task_screen.dart';
import 'task_detail_screen.dart';

enum _TaskScope { forMe, byMe }

/// Tasks assigned to you vs tasks you assigned.
class TasksHomeScreen extends ConsumerStatefulWidget {
  const TasksHomeScreen({super.key});

  @override
  ConsumerState<TasksHomeScreen> createState() => _TasksHomeScreenState();
}

class _TasksHomeScreenState extends ConsumerState<TasksHomeScreen> {
  _TaskScope _scope = _TaskScope.forMe;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myTasksStreamProvider);
    final me = ref.watch(currentMemberProvider).valueOrNull;
    final email = me?.email.toLowerCase() ?? '';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: ColoredBox(
        color: Color.lerp(
            scheme.surfaceContainerLowest, scheme.secondaryContainer, 0.05)!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<_TaskScope>(
                segments: const [
                  ButtonSegment(
                    value: _TaskScope.forMe,
                    label: Text('For me'),
                    icon: Icon(Icons.inbox_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: _TaskScope.byMe,
                    label: Text('By me'),
                    icon: Icon(Icons.outgoing_mail, size: 18),
                  ),
                ],
                selected: {_scope},
                onSelectionChanged: (s) => setState(() => _scope = s.first),
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load tasks.\n$e',
                        textAlign: TextAlign.center),
                  ),
                ),
                data: (tasks) {
                  final filtered = tasks.where((t) {
                    if (_scope == _TaskScope.forMe) {
                      return t.isAssignee(email);
                    }
                    return t.isAssigner(email);
                  }).toList();

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(myTasksStreamProvider);
                      await ref.read(myTasksStreamProvider.future);
                    },
                    child: filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(32),
                            children: [
                              const SizedBox(height: 40),
                              Icon(Icons.task_alt_rounded,
                                  size: 56, color: scheme.outline),
                              const SizedBox(height: 16),
                              Text(
                                _scope == _TaskScope.forMe
                                    ? 'No tasks for you yet'
                                    : 'You have not assigned any tasks',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _scope == _TaskScope.forMe
                                    ? 'When someone assigns you a task, it will show up here. Pull down to refresh.'
                                    : 'Tap the + button to assign a chore, reminder, or surprise for someone in your family.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(top: 4, bottom: 100),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final t = filtered[i];
                              return TaskCard(
                                task: t,
                                myEmail: email,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          TaskDetailScreen(taskId: t.id),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              fullscreenDialog: true,
              builder: (_) => const CreateTaskScreen(),
            ),
          );
          if (created == true && mounted) {
            ref.invalidate(myTasksStreamProvider);
          }
        },
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Assign task'),
      ),
    );
  }
}
