import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/domain/entities/family_member.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../data/vault_repository_impl.dart';
import '../../domain/entities/vault_item.dart';
import '../../domain/repositories/vault_repository.dart';

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  final scope = ref.watch(familyScopeProvider);
  final me = ref.watch(currentMemberProvider).valueOrNull;
  final members =
      ref.watch(familyMembersProvider).valueOrNull ?? const <FamilyMember>[];
  return VaultRepositoryImpl(
    scope: scope,
    familyMemberEmails: members.map((m) => m.email).toSet(),
    memberDisplayName: me?.displayName,
  );
});

final vaultItemsProvider = StreamProvider<List<VaultItem>>((ref) {
  return ref.watch(vaultRepositoryProvider).watchItems();
});
