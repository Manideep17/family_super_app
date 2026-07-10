import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_flags.dart';
import '../../../family/domain/entities/family_member.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../diary_moods.dart';
import '../providers/diary_providers.dart';

/// Create a diary entry: text, mood, tagged family, and inline photos
/// uploaded straight from gallery/camera to configured media backend.
class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({super.key, this.initialTitle});

  /// Pre-fills the title — used by the festival/tradition prompt on Home so
  /// "Add a tradition for Diwali" doesn't start from a blank page.
  final String? initialTitle;

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  late final _title = TextEditingController(text: widget.initialTitle ?? '');
  final _body = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  String _mood = DiaryMoods.options.first.$1;
  final Set<String> _tagged = {};
  final List<File> _pendingPhotos = [];
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _addPhoto({required ImageSource source}) async {
    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2400,
      );
      if (x == null) return;
      setState(() => _pendingPhotos.add(File(x.path)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  Future<void> _addPhotoFlow() async {
    if (!AppFlags.storageEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Photo uploads are disabled in this build configuration.'),
          ),
        );
      }
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _addPhoto(source: source);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(diaryRepositoryProvider);
      final urls = <String>[];
      for (final f in _pendingPhotos) {
        final url = await repo.uploadStoryImage(f);
        urls.add(url);
      }
      await repo.createStory(
        title: _title.text,
        body: _body.text,
        mood: _mood,
        taggedEmails: _tagged.toList(),
        imageUrls: urls,
        videoUrls: const [],
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final members =
        ref.watch(familyMembersProvider).valueOrNull ?? const <FamilyMember>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('New memory'),
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
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Give this moment a name',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Add a title' : null,
            ),
            const SizedBox(height: 18),
            Text('Mood', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DiaryMoods.options.map((o) {
                final selected = _mood == o.$1;
                return FilterChip(
                  label: Text('${o.$3} ${o.$2}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _mood = o.$1),
                  showCheckmark: false,
                  selectedColor: scheme.primaryContainer,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Tag family', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: members.map((m) {
                final email = m.email.toLowerCase();
                final on = _tagged.contains(email);
                return FilterChip(
                  label: Text(m.displayName),
                  selected: on,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _tagged.add(email);
                      } else {
                        _tagged.remove(email);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _body,
              minLines: 5,
              maxLines: 12,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                labelText: 'Story',
                hintText: 'What happened? How did it feel?',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Write something' : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Photos',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving || !AppFlags.storageEnabled
                      ? null
                      : _addPhotoFlow,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_pendingPhotos.isEmpty)
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    AppFlags.storageEnabled
                        ? 'Add photos straight from your phone — they upload when you tap Save.'
                        : 'Photo uploads are off in this build. Text memories still work.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingPhotos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) {
                    final f = _pendingPhotos[i];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            f,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(
                                () => _pendingPhotos.removeAt(i),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
