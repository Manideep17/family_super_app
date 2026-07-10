import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import '../../family/data/family_scope.dart';
import '../domain/entities/timeline_entry.dart';
import '../domain/repositories/timeline_repository.dart';

class TimelineRepositoryImpl implements TimelineRepository {
  TimelineRepositoryImpl({required FamilyScope scope}) : _scope = scope;

  final FamilyScope _scope;

  CollectionReference<Map<String, dynamic>> get _stories =>
      _scope.stories;
  CollectionReference<Map<String, dynamic>> get _events =>
      _scope.calendarEvents;

  TimelineEntry _fromStory(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final ts = d['createdAt'];
    DateTime at;
    if (ts is Timestamp) {
      at = ts.toDate();
    } else {
      at = DateTime.fromMillisecondsSinceEpoch(0);
    }
    final tagged = (d['taggedEmails'] as List<dynamic>?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        const <String>[];
    final authorEmail = (d['authorEmail'] as String? ?? '').toLowerCase();
    final involved = <String>{...tagged, if (authorEmail.isNotEmpty) authorEmail}.toList();
    final images = d['imageUrls'] as List<dynamic>?;
    final thumb = images != null && images.isNotEmpty ? images.first.toString() : null;
    return TimelineEntry(
      kind: TimelineKind.story,
      id: 'story_${doc.id}',
      storyId: doc.id,
      title: d['title'] as String? ?? 'Memory',
      subtitle: (d['body'] as String? ?? '').length > 120
          ? '${(d['body'] as String).substring(0, 120)}…'
          : (d['body'] as String? ?? ''),
      at: at,
      authorOrCreatorName: d['authorName'] as String? ?? '',
      involvedEmails: involved,
      thumbUrl: thumb,
      mood: d['mood'] as String?,
      taggedEmails: tagged,
    );
  }

  TimelineEntry _fromEvent(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final ts = d['startAt'];
    DateTime at;
    if (ts is Timestamp) {
      at = ts.toDate();
    } else {
      at = DateTime.fromMillisecondsSinceEpoch(0);
    }
    final parts = (d['participantEmails'] as List<dynamic>?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        const <String>[];
    final creator = (d['creatorEmail'] as String? ?? '').toLowerCase();
    final involved = <String>{...parts, if (creator.isNotEmpty) creator}.toList();
    return TimelineEntry(
      kind: TimelineKind.calendarEvent,
      id: 'event_${doc.id}',
      eventId: doc.id,
      title: d['title'] as String? ?? 'Event',
      subtitle: d['description'] as String? ?? '',
      at: at,
      authorOrCreatorName: d['creatorName'] as String? ?? '',
      involvedEmails: involved,
      eventType: d['eventType'] as String? ?? 'other',
    );
  }

  @override
  Stream<List<TimelineEntry>> watchTimeline({
    int storyLimit = 120,
    int eventLimit = 200,
  }) {
    final stories$ = _stories
        .orderBy('createdAt', descending: true)
        .limit(storyLimit)
        .snapshots()
        .map((s) => s.docs.map(_fromStory).toList());

    final events$ = _events
        .orderBy('startAt', descending: true)
        .limit(eventLimit)
        .snapshots()
        .map((s) => s.docs.map(_fromEvent).toList());

    return Rx.combineLatest2<List<TimelineEntry>, List<TimelineEntry>, List<TimelineEntry>>(
      stories$,
      events$,
      (stories, events) {
        final merged = [...stories, ...events]
          ..sort((a, b) => b.at.compareTo(a.at));
        return merged;
      },
    );
  }
}
