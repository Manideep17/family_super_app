import 'package:equatable/equatable.dart';

/// `predictions/{id}` — family “future” bets; reveal when you say it happened.
class FamilyPrediction extends Equatable {
  const FamilyPrediction({
    required this.id,
    required this.text,
    required this.predictorUid,
    required this.predictorName,
    required this.createdAt,
    required this.revealed,
    this.outcomeNote,
  });

  final String id;
  final String text;
  final String predictorUid;
  final String predictorName;
  final DateTime createdAt;
  final bool revealed;
  final String? outcomeNote;

  @override
  List<Object?> get props =>
      [id, text, predictorUid, predictorName, createdAt, revealed, outcomeNote];
}
