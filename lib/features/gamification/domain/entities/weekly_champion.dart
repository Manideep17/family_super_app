import 'package:equatable/equatable.dart';

/// `gamification/weekly_champion` — client-synced from leaderboard (week bucket).
class WeeklyChampion extends Equatable {
  const WeeklyChampion({
    required this.weekId,
    this.uid,
    this.name,
    this.points = 0,
  });

  final String weekId;
  final String? uid;
  final String? name;
  final int points;

  @override
  List<Object?> get props => [weekId, uid, name, points];
}
