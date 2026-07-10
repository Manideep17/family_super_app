import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/domain/entities/family_member.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../providers/tasks_providers.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _points = TextEditingController(text: '10');
  String? _assigneeEmail;
  DateTime _dueAt = DateTime.now().add(const Duration(days: 3));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _points.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dueAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_assigneeEmail == null) return;
    final pts = int.tryParse(_points.text.trim()) ?? 0;
    setState(() => _saving = true);
    try {
      await ref.read(tasksRepositoryProvider).createTask(
            title: _title.text,
            description: _description.text,
            assigneeEmail: _assigneeEmail!,
            dueAt: _dueAt,
            rewardPoints: pts,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members =
        ref.watch(familyMembersProvider).valueOrNull ?? const <FamilyMember>[];
    final assigneeChoices = members;
    if (_assigneeEmail == null && assigneeChoices.isNotEmpty) {
      _assigneeEmail = assigneeChoices.first.email.toLowerCase();
    }

    if (assigneeChoices.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assign task')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Add at least one member before assigning tasks.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign task'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Any member can assign a task to another member. The assignee completes the task and the assigner approves it.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _assigneeEmail != null &&
                      assigneeChoices
                          .any((m) => m.email.toLowerCase() == _assigneeEmail)
                  ? _assigneeEmail
                  : assigneeChoices.first.email.toLowerCase(),
              decoration: const InputDecoration(labelText: 'Assign to'),
              items: assigneeChoices
                  .map(
                    (m) => DropdownMenuItem(
                      value: m.email.toLowerCase(),
                      child: Text('${m.displayName} (${m.email})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _assigneeEmail = v),
              validator: (v) => v == null ? 'Pick a member' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                labelText: 'Description',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Add details' : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due'),
              subtitle: Text(_dueAt.toLocal().toString().split('.').first),
              trailing: IconButton(
                icon: const Icon(Icons.edit_calendar_rounded),
                onPressed: _pickDue,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _points,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reward points',
                hintText: '10',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter points';
                if (int.tryParse(v.trim()) == null) return 'Whole number';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
