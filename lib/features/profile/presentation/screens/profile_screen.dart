import 'dart:io' show File;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_flags.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../../gamification/domain/title_catalog.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';
import '../providers/user_profile_providers.dart';

/// Avatar + basics synced to `users/{uid}`.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentMemberProvider).valueOrNull;
    final async = ref.watch(myUserProfileProvider);
    final statsAsync = ref.watch(myMemberStatsProvider);
    final scheme = Theme.of(context).colorScheme;

    Future<void> pickAvatar() async {
      if (!AppFlags.storageEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar upload is disabled in this build.'),
          ),
        );
        return;
      }
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Avatar upload is available on mobile for now.')),
        );
        return;
      }
      final x = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 1200);
      if (x == null || !context.mounted) return;
      final path = x.path;
      if (path.isEmpty) return;
      try {
        await ref
            .read(userProfileRepositoryProvider)
            .uploadAvatarFile(File(path));
        ref.invalidate(myUserProfileProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile photo updated')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: async.when(
              loading: () => const CircleAvatar(
                  radius: 48, child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (p) {
                final url =
                    p?.avatarUrl ?? FirebaseAuth.instance.currentUser?.photoURL;
                final name = me?.displayName.trim();
                final initial = (name != null && name.isNotEmpty)
                    ? name[0].toUpperCase()
                    : '?';
                final hasImage = url != null && url.isNotEmpty;
                return Column(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundImage: hasImage ? NetworkImage(url) : null,
                      onBackgroundImageError: hasImage ? (_, __) {} : null,
                      child: !hasImage
                          ? Text(initial, style: const TextStyle(fontSize: 40))
                          : null,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: AppFlags.storageEnabled ? pickAvatar : null,
                      icon: const Icon(Icons.photo_camera_front_outlined),
                      label: const Text(
                        AppFlags.storageEnabled ? 'Change photo' : 'Upload off',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Name'),
            subtitle: Text(me?.displayName ?? '—'),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(me?.email ?? '—'),
          ),
          const ListTile(
            leading: Icon(Icons.groups_outlined),
            title: Text('Family status'),
            subtitle: Text('Member'),
          ),
          statsAsync.when(
            loading: () => const ListTile(
              leading: Icon(Icons.stars_outlined),
              title: Text('FAM coins'),
              subtitle: Text('…'),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) {
              final coins = stats?.famCoins ?? 0;
              final titleVal = stats?.displayTitle ?? '';
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.stars_outlined),
                    title: const Text('FAM coins'),
                    subtitle: Text(
                      '$coins — earned from tasks, diary, and games.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Family title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.military_tech_outlined),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: titleVal.isEmpty ? '' : titleVal,
                          items: TitleCatalog.choices
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(TitleCatalog.labelFor(c)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) async {
                            if (v == null) return;
                            try {
                              await ref
                                  .read(gamificationRepositoryProvider)
                                  .updateMyDisplayTitle(
                                      v.isEmpty ? null : v);
                              ref.invalidate(myMemberStatsProvider);
                              ref.invalidate(leaderboardProvider);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () async {
              final nameCtrl =
                  TextEditingController(text: me?.displayName ?? '');
              final greetCtrl = TextEditingController(text: me?.greeting ?? '');
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Edit profile'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: greetCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Custom greeting',
                          hintText: 'Hey rockstar',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              final newName = nameCtrl.text;
              final newGreeting = greetCtrl.text;
              nameCtrl.dispose();
              greetCtrl.dispose();
              if (ok != true) return;
              try {
                await ref.read(userProfileRepositoryProvider).updateMyProfile(
                      displayName: newName,
                      greeting: newGreeting,
                    );
                ref.invalidate(currentMemberProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit name & greeting'),
          ),
          const SizedBox(height: 12),
          Text(
            AppFlags.storageEnabled
                ? 'Your greeting appears on your dashboard hero card. Photos upload to the configured media service for this build.'
                : 'Your greeting appears on your dashboard hero card. Photo upload is currently disabled in this build.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
