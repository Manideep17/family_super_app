import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/domain/entities/family_member.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../providers/calendar_providers.dart';

const _eventTypes = [
  ('birthday', 'Birthday'),
  ('trip', 'Trip'),
  ('reminder', 'Reminder'),
  ('other', 'Other'),
];

Future<bool?> showCreateEventSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _CreateEventBody(),
  );
}

class _CreateEventBody extends ConsumerStatefulWidget {
  const _CreateEventBody();

  @override
  ConsumerState<_CreateEventBody> createState() => _CreateEventBodyState();
}

class _CreateEventBodyState extends ConsumerState<_CreateEventBody> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _type = 'other';
  bool _allDay = false;
  DateTime _start = DateTime.now().add(const Duration(hours: 1));
  final Set<String> _participants = {};
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (d == null || !mounted) return;
    if (_allDay) {
      setState(() => _start = DateTime(d.year, d.month, d.day));
      return;
    }
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (t == null || !mounted) return;
    setState(() {
      _start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(calendarRepositoryProvider).createEvent(
            title: _title.text,
            description: _description.text,
            startAt: _start,
            endAt: null,
            allDay: _allDay,
            eventType: _type,
            participantEmails: _participants.toList(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final members =
        ref.watch(familyMembersProvider).valueOrNull ?? const <FamilyMember>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('New event', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  labelText: 'Description',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _eventTypes
                    .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'other'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('All day'),
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Starts'),
                subtitle: Text(_start.toLocal().toString().split('.').first),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_calendar_outlined),
                  onPressed: _pickStart,
                ),
              ),
              Text('Participants', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: members.map((m) {
                  final email = m.email.toLowerCase();
                  final on = _participants.contains(email);
                  return FilterChip(
                    label: Text(m.displayName),
                    selected: on,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _participants.add(email);
                        } else {
                          _participants.remove(email);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save event'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
