import '../entities/family_prediction.dart';

abstract class PredictionsRepository {
  Stream<List<FamilyPrediction>> watchPredictions({int limit});

  Future<String> createPrediction(String text);

  /// Marks prediction as revealed (author only enforced in app).
  Future<void> revealPrediction(String id, {String? outcomeNote});
}
