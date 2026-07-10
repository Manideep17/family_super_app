import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/moderation_reports_repository.dart';
import '../../domain/entities/moderation_report_entry.dart';
import 'family_providers.dart';

final moderationReportsRepositoryProvider =
    Provider<ModerationReportsRepository>((ref) {
  return ModerationReportsRepository();
});

final familyModerationReportsStreamProvider =
    StreamProvider.autoDispose<List<ModerationReportEntry>>((ref) {
  final fid = ref.watch(currentFamilyIdProvider).valueOrNull;
  if (fid == null || fid.isEmpty) {
    return Stream<List<ModerationReportEntry>>.value([]);
  }
  return ref
      .watch(moderationReportsRepositoryProvider)
      .watchReportsForFamily(fid);
});
