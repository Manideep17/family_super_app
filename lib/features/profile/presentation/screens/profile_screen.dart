import 'dart:io' show File;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_flags.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/data/auth_repository_impl.dart' show FamilyAuthException;
import '../../../billing/presentation/providers/billing_providers.dart';
import '../../../billing/presentation/screens/paywall_screen.dart';
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
          if (AppFlags.billingEnabled)
            ListTile(
              leading: Icon(
                Icons.workspace_premium_rounded,
                color: ref.watch(isPremiumProvider) ? scheme.primary : null,
              ),
              title: Text(
                ref.watch(isPremiumProvider) ? 'FAM Premium' : 'Go Premium',
              ),
              subtitle: Text(
                ref.watch(isPremiumProvider)
                    ? 'Your family has Premium — thank you!'
                    : 'AI digest, more vault storage, and more',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
              ),
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
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Danger zone',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: scheme.error, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Deletes your account sign-in, your personal profile, and — if '
            "you're the only member of your family — the whole family's "
            'data. If others are still in your family, content you shared '
            'with them (tasks, diary entries, chat messages) stays with the '
            'family, same as leaving a group chat. This cannot be undone.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () => _confirmAndDeleteAccount(context, ref),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete my account'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your sign-in and profile. Type '
              'DELETE to confirm.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'DELETE'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    final typedConfirm = confirmCtrl.text.trim();
    confirmCtrl.dispose();
    if (confirmed != true || typedConfirm != 'DELETE') return;
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      // Router redirects to the login screen automatically once
      // authStateChanges emits null — nothing further to navigate here.
    } on FamilyAuthException catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close spinner
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete account: $e')));
      }
      return;
    }
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // close spinner
    }
  }
}
