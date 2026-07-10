import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../domain/entities/family_task.dart';
import '../providers/tasks_providers.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _note = TextEditingController();
  final _rejectReason = TextEditingController();
  bool _busy = false;
  /// Shown once after this assigner approves, to optionally post thanks in family chat.
  bool _offerThanksAfterApprove = false;

  @override
  void dispose() {
    _note.dispose();
    _rejectReason.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authRepositoryProvider);
    final email = auth.currentUserEmail?.toLowerCase() ?? '';
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat.yMMMEd().add_jm();

    return Scaffold(
      appBar: AppBar(title: const Text('Task')),
      body: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (task) {
          if (task == null) {
            return const Center(child: Text('Task not found.'));
          }
          final assigneeMe = task.isAssignee(email);
          final assignerMe = task.isAssigner(email);

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                children: [
                  Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(task.status.name)),
                      Chip(
                        avatar: Icon(Icons.stars_rounded, size: 18, color: scheme.secondary),
                        label: Text('${task.rewardPoints} pts'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MetaRow(icon: Icons.person_outline, text: 'From ${task.assignerName}'),
                  _MetaRow(icon: Icons.assignment_ind_outlined, text: 'To ${task.assigneeName}'),
                  _MetaRow(
                    icon: Icons.event_rounded,
                    text: 'Due ${dateFmt.format(task.dueAt)}',
                  ),
                  const SizedBox(height: 20),
                  Text('Description', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SelectableText(
                    task.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
                  ),
                  if (task.submittedNote != null && task.submittedNote!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Assignee note', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(task.submittedNote!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  if (task.rejectedReason != null && task.rejectedReason!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Rejection reason', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(
                      task.rejectedReason!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.error),
                    ),
                  ],
                  if (assigneeMe && task.status == TaskStatus.pending) ...[
                    const SizedBox(height: 24),
                    Text('Note for assigner (optional)', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _note,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'What did you complete?',
                      ),
                    ),
                  ],
                ],
              ),
              if (_busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x33000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Material(
                  elevation: 12,
                  color: scheme.surface,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (assigneeMe && task.status == TaskStatus.pending)
                            FilledButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                        await ref.read(tasksRepositoryProvider).submitTask(
                                              widget.taskId,
                                              note: _note.text,
                                            );
                                        if (context.mounted) Navigator.of(context).pop();
                                      }),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Mark done & request approval'),
                            ),
                          if (assignerMe && task.status == TaskStatus.submitted) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _run(() async {
                                              await ref
                                                  .read(tasksRepositoryProvider)
                                                  .approveTask(widget.taskId);
                                              if (context.mounted) {
                                                setState(() {
                                                  _offerThanksAfterApprove = true;
                                                });
                                              }
                                            }),
                                    icon: const Icon(Icons.thumb_up_alt_outlined),
                                    label: const Text('Approve'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () async {
                                            final reason = await showDialog<String>(
                                              context: context,
                                              builder: (ctx) {
                                                return AlertDialog(
                                                  title: const Text('Reject task'),
                                                  content: TextField(
                                                    controller: _rejectReason,
                                                    decoration: const InputDecoration(
                                                      hintText: 'Reason (optional)',
                                                    ),
                                                    maxLines: 3,
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    FilledButton(
                                                      onPressed: () => Navigator.pop(
                                                        ctx,
                                                        _rejectReason.text,
                                                      ),
                                                      child: const Text('Reject'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                            if (reason == null || !mounted) return;
                                            await _run(() async {
                                              await ref.read(tasksRepositoryProvider).rejectTask(
                                                    widget.taskId,
                                                    reason: reason.isEmpty ? null : reason,
                                                  );
                                              if (context.mounted) Navigator.of(context).pop();
                                            });
                                          },
                                    icon: const Icon(Icons.thumb_down_alt_outlined),
                                    label: const Text('Reject'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (task.status == TaskStatus.approved) ...[
                            Text(
                              'Approved — great work!',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: scheme.primary,
                                  ),
                            ),
                            if (assignerMe && _offerThanksAfterApprove) ...[
                              const SizedBox(height: 12),
                              FilledButton.tonalIcon(
                                onPressed: _busy
                                    ? null
                                    : () => _run(() async {
                                          final msg =
                                              '🙏 Thanks, ${task.assigneeName}! Great job on “${task.title}”.';
                                          await ref
                                              .read(chatRepositoryProvider)
                                              .sendTextMessage(msg);
                                          if (!context.mounted) return;
                                          setState(() {
                                            _offerThanksAfterApprove = false;
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Thanks shared in family chat.'),
                                            ),
                                          );
                                          if (context.mounted) {
                                            Navigator.of(context).pop();
                                          }
                                        }),
                                icon: const Icon(Icons.favorite_outline_rounded),
                                label: const Text('Say thanks in family chat'),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () {
                                        setState(() {
                                          _offerThanksAfterApprove = false;
                                        });
                                        Navigator.of(context).pop();
                                      },
                                child: const Text('Skip'),
                              ),
                            ],
                          ],
                          if (task.status == TaskStatus.rejected)
                            Text(
                              'Rejected',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: scheme.error,
                                  ),
                            ),
                          if (task.status == TaskStatus.submitted && assigneeMe)
                            Text(
                              'Waiting for ${task.assignerName} to approve.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
