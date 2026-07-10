import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/presentation/providers/family_providers.dart';
import '../../data/timeline_repository_impl.dart';
import '../../domain/entities/timeline_entry.dart';
import '../../domain/repositories/timeline_repository.dart';

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  final scope = ref.watch(familyScopeProvider);
  return TimelineRepositoryImpl(scope: scope);
});

final timelineStreamProvider = StreamProvider<List<TimelineEntry>>((ref) {
  return ref.watch(timelineRepositoryProvider).watchTimeline();
});
