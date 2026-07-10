import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/owner_analytics_repository.dart';
import '../../domain/owner_analytics_snapshot.dart';

final ownerAnalyticsSnapshotProvider =
    FutureProvider.autoDispose<OwnerAnalyticsSnapshot>((ref) async {
  final repo = ref.watch(ownerAnalyticsRepositoryProvider);
  return repo.loadAppWideAggregates();
});
