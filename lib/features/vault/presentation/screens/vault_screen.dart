import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_flags.dart';
import '../../../../core/media/text_extraction_service.dart';
import '../../../family/domain/entities/family_member.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../domain/entities/vault_item.dart';
import '../providers/vault_providers.dart';

class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vaultItemsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Media vault')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 56,
                      color: scheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No shared photos yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppFlags.storageEnabled
                          ? 'Add a family photo — everyone in your family can see it here. '
                              'Great for recipes, IDs, and trip pics.'
                          : 'Vault uploads are off in this build (storage not configured). '
                              'Your host can enable Firebase Storage for uploads.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(vaultItemsProvider);
              await ref.read(vaultItemsProvider.future);
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final it = items[i];
                return _VaultTile(item: it);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: AppFlags.storageEnabled ? () => _onAddPhoto(context, ref) : null,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text(AppFlags.storageEnabled ? 'Add photo' : 'Storage off'),
      ),
    );
  }

  static Future<void> _onAddPhoto(BuildContext context, WidgetRef ref) async {
    if (!AppFlags.storageEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage is disabled in no-cost mode.')),
      );
      return;
    }
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploads are supported on iOS/Android in this build.'),
        ),
      );
      return;
    }
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (x == null || !context.mounted) return;

    // On-device OCR (free, no network) — scan before showing the details
    // dialog so any detected text/dates can be surfaced right away.
    var ocr = TextExtractionResult.empty;
    if (TextExtractionService.isSupported) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Scanning photo…'),
                ],
              ),
            ),
          ),
        ),
      );
      ocr = await TextExtractionService.instance.extractFrom(File(x.path));
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!context.mounted) return;

    final titleCtrl = TextEditingController(text: 'Photo');
    final eventCtrl = TextEditingController();
    final tags = <String>{};
    final members =
        ref.read(familyMembersProvider).valueOrNull ?? const <FamilyMember>[];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              title: const Text('Photo details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: eventCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Event label (optional)',
                        hintText: 'Birthday 2026',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (ocr.text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.document_scanner_outlined,
                              size: 16, color: Theme.of(ctx).colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Text detected — saved so you can search for it later',
                            style: Theme.of(ctx).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          ocr.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text('Tag people', style: Theme.of(ctx).textTheme.labelLarge),
                    Wrap(
                      spacing: 6,
                    children: members.map((m) {
                        final e = m.email.toLowerCase();
                        final on = tags.contains(e);
                        return FilterChip(
                          label: Text(m.displayName),
                          selected: on,
                          onSelected: (v) {
                            setSt(() {
                              if (v) {
                                tags.add(e);
                              } else {
                                tags.remove(e);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Upload'),
                ),
              ],
            );
          },
        );
      },
    );
    final titleText = titleCtrl.text;
    final eventText = eventCtrl.text.trim();
    final personTags = tags.toList();
    titleCtrl.dispose();
    eventCtrl.dispose();
    if (ok != true || !context.mounted) return;

    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Uploading…'),
                ],
              ),
            ),
          ),
        ),
      );
      await ref.read(vaultRepositoryProvider).uploadPhoto(
            file: File(x.path),
            title: titleText,
            personTags: personTags,
            eventTag: eventText.isEmpty ? null : eventText,
            extractedText: ocr.text,
          );
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ref.invalidate(vaultItemsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploaded')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }
}

class _VaultTile extends ConsumerWidget {
  const _VaultTile({required this.item});

  final VaultItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(item.title)),
                body: Column(
                  children: [
                    Expanded(
                      child: InteractiveViewer(
                        child: Center(
                          child: item.isImage
                              ? Image.network(item.downloadUrl)
                              : Text(item.downloadUrl),
                        ),
                      ),
                    ),
                    if (item.extractedText.isNotEmpty)
                      SafeArea(
                        top: false,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          color: Theme.of(context).colorScheme.surfaceContainerHigh,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Detected text',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(item.extractedText),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        onLongPress: () async {
          final action = await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Delete'),
                    onTap: () => Navigator.pop(ctx, 'delete'),
                  ),
                ],
              ),
            ),
          );
          if (action == 'delete' && context.mounted) {
            try {
              await ref.read(vaultRepositoryProvider).deleteItem(item.id);
              ref.invalidate(vaultItemsProvider);
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$e')),
              );
            }
          }
        },
        child: GridTile(
          footer: GridTileBar(
            backgroundColor: Colors.black54,
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: item.eventTag != null ? Text(item.eventTag!) : null,
            trailing: item.extractedText.isNotEmpty
                ? const Tooltip(
                    message: 'Text detected in this photo',
                    child: Icon(
                      Icons.document_scanner_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  )
                : null,
          ),
          child: item.isImage
              ? Image.network(
                  item.downloadUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                )
              : const Icon(Icons.insert_drive_file),
        ),
      ),
    );
  }
}
