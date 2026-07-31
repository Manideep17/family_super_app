import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/domain/entities/family_member.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../data/calendar_repository_impl.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/repositories/calendar_repository.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final scope = ref.watch(familyScopeProvider);
  final me = ref.watch(currentMemberProvider).valueOrNull;
  final members =
      ref.watch(familyMembersProvider).valueOrNull ?? const <FamilyMember>[];
  return CalendarRepositoryImpl(
    scope: scope,
    familyMemberEmails: members.map((m) => m.email).toSet(),
    memberDisplayName: me?.displayName,
  );
});

final calendarEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  return ref.watch(calendarRepositoryProvider).watchEvents();
});

final calendarEventProvider =
    StreamProvider.autoDispose.family<CalendarEvent?, String>((ref, id) {
  return ref.watch(calendarRepositoryProvider).watchEvent(id);
});
