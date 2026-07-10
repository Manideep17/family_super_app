import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/presentation/providers/family_providers.dart';
import '../../data/predictions_repository_impl.dart';
import '../../domain/entities/family_prediction.dart';
import '../../domain/repositories/predictions_repository.dart';

final predictionsRepositoryProvider = Provider<PredictionsRepository>((ref) {
  final scope = ref.watch(familyScopeProvider);
  final me = ref.watch(currentMemberProvider).valueOrNull;
  return PredictionsRepositoryImpl(
    scope: scope,
    memberDisplayName: me?.displayName,
  );
});

final predictionsStreamProvider = StreamProvider<List<FamilyPrediction>>((ref) {
  return ref.watch(predictionsRepositoryProvider).watchPredictions();
});
