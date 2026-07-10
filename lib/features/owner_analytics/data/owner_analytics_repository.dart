import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/owner_analytics_snapshot.dart';

final ownerAnalyticsRepositoryProvider = Provider<OwnerAnalyticsRepository>((ref) {
  return OwnerAnalyticsRepository(FirebaseFirestore.instance);
});

class OwnerAnalyticsRepository {
  OwnerAnalyticsRepository(this._db);

  final FirebaseFirestore _db;

  static const int _familyConcurrency = 6;

  Future<OwnerAnalyticsSnapshot> loadAppWideAggregates() async {
    final famSnap = await _db.collection('families').get();
    if (famSnap.docs.isEmpty) {
      return const OwnerAnalyticsSnapshot(
        scopeLabel: 'No families in project',
        familyCount: 0,
        totalMembers: 0,
        storyCount: 0,
        taskCount: 0,
        eventCount: 0,
        vaultCount: 0,
        predictionCount: 0,
        gamesCount: 0,
        taskStatusCounts: {},
        moodCounts: {},
        topContributors: [],
        recentActivityLines: [],
      );
    }

    final docs = famSnap.docs;
    final perFamily = <_FamilyMetrics>[];

    for (var i = 0; i < docs.length; i += _familyConcurrency) {
      final chunk = docs.sublist(
        i,
        i + _familyConcurrency > docs.length ? docs.length : i + _familyConcurrency,
      );
      final part = await Future.wait(chunk.map(_collectFamily));
      perFamily.addAll(part);
    }

    final taskStatus = <String, int>{};
    final moods = <String, int>{};
    var members = 0;
    var stories = 0;
    var tasks = 0;
    var events = 0;
    var vault = 0;
    var predictions = 0;
    var games = 0;
    final contributors = <OwnerContributorRow>[];
    final recent = <_RecentLine>[];

    for (final m in perFamily) {
      members += m.memberCount;
      stories += m.storyCount;
      tasks += m.taskCount;
      events += m.eventCount;
      vault += m.vaultCount;
      predictions += m.predictionCount;
      games += m.gamesCount;
      for (final e in m.taskStatus.entries) {
        taskStatus[e.key] = (taskStatus[e.key] ?? 0) + e.value;
      }
      for (final e in m.moods.entries) {
        moods[e.key] = (moods[e.key] ?? 0) + e.value;
      }
      contributors.addAll(m.contributorRows);
      recent.addAll(m.recentLines);
    }

    contributors.sort((a, b) => b.points.compareTo(a.points));
    final top = contributors.take(10).toList();

    recent.sort((a, b) => b.sortMillis.compareTo(a.sortMillis));
    final recentLines = recent.take(14).map((r) => r.text).toList();

    return OwnerAnalyticsSnapshot(
      scopeLabel: 'All families (${docs.length})',
      familyCount: docs.length,
      totalMembers: members,
      storyCount: stories,
      taskCount: tasks,
      eventCount: events,
      vaultCount: vault,
      predictionCount: predictions,
      gamesCount: games,
      taskStatusCounts: taskStatus,
      moodCounts: moods,
      topContributors: top,
      recentActivityLines: recentLines,
    );
  }

  Future<_FamilyMetrics> _collectFamily(QueryDocumentSnapshot<Map<String, dynamic>> fd) async {
    final fid = fd.id;
    final name = ((fd.data()['name'] as String?) ?? '').trim();
    final familyLabel = name.isNotEmpty ? name : fid;

    final base = _db.collection('families').doc(fid);

    final membersSnap = await base.collection('members').get();
    final storiesSnap = await base.collection('stories').get();
    final tasksSnap = await base.collection('tasks').get();
    final eventsSnap = await base.collection('calendar_events').get();
    final vaultSnap = await base.collection('vault_items').get();
    final predSnap = await base.collection('predictions').get();
    final futurePredSnap = await base.collection('future_predictions').get();
    final reelsSnap = await base.collection('reels').get();
    final creativeSnap = await base.collection('creative_submissions').get();
    final timeTravelSnap = await base.collection('time_travel_entries').get();

    final taskStatus = <String, int>{};
    for (final d in tasksSnap.docs) {
      final status = (d.data()['status'] as String?) ?? 'pending';
      taskStatus[status] = (taskStatus[status] ?? 0) + 1;
    }

    final moodMap = <String, int>{};
    for (final d in storiesSnap.docs) {
      final mood = (d.data()['mood'] as String?) ?? 'unknown';
      moodMap[mood] = (moodMap[mood] ?? 0) + 1;
    }

    final statsSnap = await base
        .collection('member_stats')
        .orderBy('points', descending: true)
        .limit(10)
        .get();

    final contributorRows = <OwnerContributorRow>[];
    for (final d in statsSnap.docs) {
      final s = d.data();
      contributorRows.add(
        OwnerContributorRow(
          displayName: (s['displayName'] as String?)?.trim().isNotEmpty == true
              ? s['displayName'] as String
              : (s['email'] as String?) ?? d.id,
          familyLabel: familyLabel,
          points: (s['points'] as num?)?.toInt() ?? 0,
          storiesCreated: (s['storiesCreated'] as num?)?.toInt() ?? 0,
          gamesWon: (s['gamesWon'] as num?)?.toInt() ?? 0,
        ),
      );
    }

    final recentStories = await base
        .collection('stories')
        .orderBy('createdAt', descending: true)
        .limit(6)
        .get();
    final recentTasks = await base
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .limit(4)
        .get();

    final recentLines = <_RecentLine>[];
    for (final d in recentStories.docs) {
      final x = d.data();
      final ts = x['createdAt'];
      recentLines.add(
        _RecentLine(
          sortMillis: _tsMillis(ts),
          text:
              '[$familyLabel] Story: ${(x['title'] as String?)?.trim().isNotEmpty == true ? x['title'] : 'Untitled'} by ${(x['authorName'] as String?) ?? 'Unknown'}',
        ),
      );
    }
    for (final d in recentTasks.docs) {
      final x = d.data();
      final ts = x['createdAt'];
      recentLines.add(
        _RecentLine(
          sortMillis: _tsMillis(ts),
          text:
              '[$familyLabel] Task: ${(x['title'] as String?)?.trim().isNotEmpty == true ? x['title'] : 'Untitled'} (${(x['status'] as String?) ?? 'pending'})',
        ),
      );
    }

    return _FamilyMetrics(
      memberCount: membersSnap.size,
      storyCount: storiesSnap.size,
      taskCount: tasksSnap.size,
      eventCount: eventsSnap.size,
      vaultCount: vaultSnap.size,
      predictionCount: predSnap.size + futurePredSnap.size,
      gamesCount: reelsSnap.size + creativeSnap.size + timeTravelSnap.size,
      taskStatus: taskStatus,
      moods: moodMap,
      contributorRows: contributorRows,
      recentLines: recentLines,
    );
  }

  static int _tsMillis(Object? ts) {
    if (ts is Timestamp) return ts.millisecondsSinceEpoch;
    return 0;
  }
}

class _FamilyMetrics {
  _FamilyMetrics({
    required this.memberCount,
    required this.storyCount,
    required this.taskCount,
    required this.eventCount,
    required this.vaultCount,
    required this.predictionCount,
    required this.gamesCount,
    required this.taskStatus,
    required this.moods,
    required this.contributorRows,
    required this.recentLines,
  });

  final int memberCount;
  final int storyCount;
  final int taskCount;
  final int eventCount;
  final int vaultCount;
  final int predictionCount;
  final int gamesCount;
  final Map<String, int> taskStatus;
  final Map<String, int> moods;
  final List<OwnerContributorRow> contributorRows;
  final List<_RecentLine> recentLines;
}

class _RecentLine {
  _RecentLine({required this.sortMillis, required this.text});

  final int sortMillis;
  final String text;
}
