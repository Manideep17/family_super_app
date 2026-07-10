import '../entities/timeline_entry.dart';

abstract class TimelineRepository {
  Stream<List<TimelineEntry>> watchTimeline({
    int storyLimit = 120,
    int eventLimit = 200,
  });
}
