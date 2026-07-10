import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../providers/calendar_providers.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(calendarEventProvider(eventId));
    final auth = ref.watch(authRepositoryProvider);
    final me = auth.currentUserEmail?.toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (ev) {
          if (ev == null) return const Center(child: Text('Event not found.'));
          final fmt = DateFormat.yMMMEd().add_jm();
          final canDelete = me != null && me == ev.creatorEmail;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(ev.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Chip(label: Text(ev.eventType)),
              const SizedBox(height: 16),
              Text('When', style: Theme.of(context).textTheme.titleSmall),
              Text(ev.allDay ? fmt.format(ev.startAt).split(',').first : fmt.format(ev.startAt)),
              if (ev.endAt != null) Text('Ends: ${fmt.format(ev.endAt!)}'),
              const SizedBox(height: 16),
              Text('Who', style: Theme.of(context).textTheme.titleSmall),
              Text('Created by ${ev.creatorName}'),
              Wrap(
                spacing: 6,
                children: ev.participantEmails
                    .map((e) => Chip(label: Text(e), visualDensity: VisualDensity.compact))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Text('Details', style: Theme.of(context).textTheme.titleSmall),
              Text(ev.description),
              if (canDelete) ...[
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete event?'),
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
                    if (ok == true && context.mounted) {
                      try {
                        await ref.read(calendarRepositoryProvider).deleteEvent(eventId);
                        if (context.mounted) Navigator.of(context).pop();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete event'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
