import 'package:equatable/equatable.dart';

class OwnerContributorRow extends Equatable {
  const OwnerContributorRow({
    required this.displayName,
    required this.familyLabel,
    required this.points,
    required this.storiesCreated,
    required this.gamesWon,
  });

  final String displayName;
  final String familyLabel;
  final int points;
  final int storiesCreated;
  final int gamesWon;

  @override
  List<Object?> get props =>
      [displayName, familyLabel, points, storiesCreated, gamesWon];
}

class OwnerAnalyticsSnapshot extends Equatable {
  const OwnerAnalyticsSnapshot({
    required this.scopeLabel,
    required this.familyCount,
    required this.totalMembers,
    required this.storyCount,
    required this.taskCount,
    required this.eventCount,
    required this.vaultCount,
    required this.predictionCount,
    required this.gamesCount,
    required this.taskStatusCounts,
    required this.moodCounts,
    required this.topContributors,
    required this.recentActivityLines,
  });

  final String scopeLabel;
  final int familyCount;
  final int totalMembers;
  final int storyCount;
  final int taskCount;
  final int eventCount;
  final int vaultCount;
  final int predictionCount;
  final int gamesCount;
  final Map<String, int> taskStatusCounts;
  final Map<String, int> moodCounts;
  final List<OwnerContributorRow> topContributors;
  final List<String> recentActivityLines;

  @override
  List<Object?> get props => [
        scopeLabel,
        familyCount,
        totalMembers,
        storyCount,
        taskCount,
        eventCount,
        vaultCount,
        predictionCount,
        gamesCount,
        taskStatusCounts,
        moodCounts,
        topContributors,
        recentActivityLines,
      ];
}
