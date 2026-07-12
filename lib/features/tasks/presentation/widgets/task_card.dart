import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/family_task.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.myEmail,
    required this.onTap,
  });

  final FamilyTask task;
  final String myEmail;
  final VoidCallback onTap;

  static final _dueFmt = DateFormat.MMMd().add_jm();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final assigneeMe = task.isAssignee(myEmail);
    final subtitle = assigneeMe
        ? 'From ${task.assignerName}'
        : 'To ${task.assigneeName}';

    final statusColor = switch (task.status) {
      TaskStatus.pending => scheme.tertiary,
      TaskStatus.submitted => scheme.primary,
      TaskStatus.approved => Colors.green.shade600,
      TaskStatus.rejected => scheme.error,
    };

    final overdue =
        task.dueAt.isBefore(DateTime.now()) && task.status == TaskStatus.pending;

    // Signature color of whoever the task is "about" (the assignee) — same
    // helper used for their Home avatar, so the color reads consistently
    // across the app.
    final memberAccent = AppTheme.colorForMember(
      task.assigneeEmail.isNotEmpty ? task.assigneeEmail : task.assigneeName,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: memberAccent.withValues(alpha: 0.45), width: 1.4),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        task.status.name,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      backgroundColor: statusColor.withValues(alpha: 0.22),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: memberAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(subtitle, style: textTheme.bodySmall?.copyWith(color: scheme.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 18,
                      color: overdue ? scheme.error : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Due ${_dueFmt.format(task.dueAt)}',
                      style: textTheme.labelMedium?.copyWith(
                        color: overdue ? scheme.error : scheme.onSurfaceVariant,
                        fontWeight: overdue ? FontWeight.w600 : null,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.stars_rounded, size: 18, color: scheme.secondary),
                    const SizedBox(width: 4),
                    Text(
                      '${task.rewardPoints} pts',
                      style: textTheme.labelMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
