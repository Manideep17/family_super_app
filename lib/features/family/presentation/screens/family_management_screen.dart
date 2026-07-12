import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/invite_link_hosts.dart';
import '../../../../core/moderation/local_hide_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/family_member.dart';
import '../providers/family_providers.dart';
import '../providers/local_hide_providers.dart';
import 'family_reports_inbox_screen.dart';

/// "My family" screen — accessible from the drawer. Shows everyone, the
/// invite code (with copy), and a leave button.
class FamilyManagementScreen extends ConsumerWidget {
  const FamilyManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final familyAsync = ref.watch(currentFamilyProvider);
    final membersAsync = ref.watch(familyMembersProvider);
    final myUid = ref.watch(currentUidProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My family')),
      body: familyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (family) {
          if (family == null) {
            return const Center(child: Text('No family found.'));
          }
          final ownerUid = family.ownerUid.isNotEmpty
              ? family.ownerUid
              : family.createdBy;
          final isOwner = myUid != null && ownerUid == myUid;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family.name,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${family.memberCount} members',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.key_rounded,
                                color: scheme.onPrimaryContainer),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invite code',
                                    style: TextStyle(
                                      color: scheme.onPrimaryContainer,
                                    ),
                                  ),
                                  Text(
                                    family.joinCode,
                                    style: const TextStyle(
                                      letterSpacing: 4,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy',
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: family.joinCode),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Code copied'),
                                    ),
                                  );
                                }
                              },
                              icon: Icon(Icons.copy_rounded,
                                  color: scheme.onPrimaryContainer),
                            ),
                            IconButton(
                              tooltip: 'Copy app link',
                              onPressed: () async {
                                final link =
                                    'famsuperapp://join/${family.joinCode}';
                                await Clipboard.setData(ClipboardData(text: link));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('App link copied'),
                                    ),
                                  );
                                }
                              },
                              icon: Icon(Icons.link_rounded,
                                  color: scheme.onPrimaryContainer),
                            ),
                            IconButton(
                              tooltip: 'Copy HTTPS link',
                              onPressed: () async {
                                final link = InviteLinkHosts.httpsJoinUrl(
                                  family.joinCode,
                                );
                                await Clipboard.setData(ClipboardData(text: link));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'HTTPS link copied (${InviteLinkHosts.displayHost})',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: Icon(Icons.public_rounded,
                                  color: scheme.onPrimaryContainer),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          Icon(Icons.restore_rounded, color: scheme.primary),
                      title: const Text('Show hidden content again'),
                      subtitle: const Text(
                        'Clears chat and diary hides on this phone only.',
                      ),
                      onTap: () async {
                        await LocalHideStore.clearAllChatHides(family.id);
                        await LocalHideStore.clearAllDiaryHides(family.id);
                        ref.invalidate(hiddenChatMessageIdsProvider);
                        ref.invalidate(hiddenDiaryStoryIdsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Restored hidden chat and diary on this device.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    if (isOwner)
                      ListTile(
                        leading:
                            Icon(Icons.inbox_outlined, color: scheme.primary),
                        title: const Text('Reports inbox'),
                        subtitle: const Text(
                          'Chat & diary flags from members (read-only)',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const FamilyReportsInboxScreen(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Home announcement',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(Icons.campaign_outlined, color: scheme.primary),
                  title: Text(
                    family.pinnedAnnouncement.isEmpty
                        ? (isOwner
                            ? 'None set — tap to add a short note for the home tab'
                            : 'No announcement — only the family owner can set this.')
                        : family.pinnedAnnouncement,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    isOwner
                        ? 'Everyone sees this on the home dashboard'
                        : 'Set by the family owner; shown on the home dashboard',
                  ),
                  trailing: isOwner
                      ? const Icon(Icons.edit_outlined)
                      : Icon(Icons.lock_outline_rounded, color: scheme.outline),
                  onTap: isOwner
                      ? () async {
                    final ctrl =
                        TextEditingController(text: family.pinnedAnnouncement);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Home announcement'),
                        content: TextField(
                          controller: ctrl,
                          maxLines: 3,
                          maxLength: 200,
                          decoration: const InputDecoration(
                            hintText:
                                'Movie night at 7 · Grandma visiting Saturday',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.sentences,
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
                    if (ok != true) {
                      ctrl.dispose();
                      return;
                    }
                    try {
                      await ref
                          .read(familyRepositoryProvider)
                          .updatePinnedAnnouncement(
                            familyId: family.id,
                            text: ctrl.text,
                          );
                      ctrl.dispose();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Announcement updated')),
                        );
                      }
                    } catch (e) {
                      ctrl.dispose();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  }
                      : null,
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: 8),
                Card(
                  child: SwitchListTile(
                    secondary: Icon(
                      Icons.notifications_active_outlined,
                      color: scheme.primary,
                    ),
                    title: const Text('Daily digest reminder'),
                    subtitle: const Text(
                      'Optional morning push to open FAM. Deploy Cloud Functions for delivery.',
                    ),
                    value: family.dailyDigestOptIn,
                    onChanged: (v) async {
                      try {
                        await ref
                            .read(familyRepositoryProvider)
                            .updateDailyDigestOptIn(
                              familyId: family.id,
                              enabled: v,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                v
                                    ? 'Digest reminders on'
                                    : 'Digest reminders off',
                              ),
                            ),
                          );
                        }
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
              ],
              const SizedBox(height: 16),
              Text(
                'Members',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('$e'),
                data: (members) {
                  return Column(
                    children: [
                      ...members.map(
                        (m) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppTheme.colorForMember(m.email),
                              backgroundImage: m.avatarUrl != null &&
                                      m.avatarUrl!.isNotEmpty
                                  ? NetworkImage(m.avatarUrl!)
                                  : null,
                              child:
                                  m.avatarUrl == null || m.avatarUrl!.isEmpty
                                      ? Text(
                                          m.initial,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                            ),
                            title: Row(
                              children: [
                                Text(m.displayName),
                                if (m.uid == myUid) ...[
                                  const SizedBox(width: 6),
                                  const Chip(
                                    label: Text('you'),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    labelStyle: TextStyle(fontSize: 11),
                                  ),
                                ],
                                if (m.uid == ownerUid) ...[
                                  const SizedBox(width: 6),
                                  const Chip(
                                    label: Text('Owner'),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    labelStyle: TextStyle(fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(m.email),
                            trailing: const Chip(
                              label: Text('Member'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ),
                      if (isOwner && members.length > 1) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final others = members
                                .where((m) => m.uid != myUid)
                                .toList();
                            if (others.isEmpty) return;
                            FamilyMember? selected;
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => StatefulBuilder(
                                builder: (ctx, setSt) {
                                  return AlertDialog(
                                    title: const Text('Transfer ownership'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const Text(
                                            'Pick the new owner. You will stay a member.',
                                          ),
                                          const SizedBox(height: 12),
                                          RadioGroup<String>(
                                            groupValue: selected?.uid,
                                            onChanged: (v) {
                                              if (v == null) return;
                                              setSt(() {
                                                selected = others.firstWhere(
                                                  (x) => x.uid == v,
                                                );
                                              });
                                            },
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                ...others.map(
                                                  (m) =>
                                                      RadioListTile<String>(
                                                    title:
                                                        Text(m.displayName),
                                                    subtitle: Text(m.email),
                                                    value: m.uid,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(
                                          ctx,
                                          selected != null,
                                        ),
                                        child: const Text('Transfer'),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                            if (ok != true || selected == null) return;
                            try {
                              await ref
                                  .read(familyRepositoryProvider)
                                  .transferOwnership(
                                    familyId: family.id,
                                    newOwnerUid: selected!.uid,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ownership transferred'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('Transfer ownership'),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Leave family?'),
                      content: const Text(
                        'You can rejoin with the same invite code later, but '
                        'your stats and tasks remain in this '
                        'family.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Leave'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  try {
                    await ref
                        .read(familyRepositoryProvider)
                        .leaveFamily(family.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Leave family'),
              ),
            ],
          );
        },
      ),
    );
  }
}
