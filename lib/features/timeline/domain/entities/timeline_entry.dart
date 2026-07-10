import 'package:equatable/equatable.dart';

enum TimelineKind { story, calendarEvent }

/// Unified row for the memory feed (diary + calendar).
class TimelineEntry extends Equatable {
  const TimelineEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.at,
    required this.authorOrCreatorName,
    required this.involvedEmails,
    this.storyId,
    this.eventId,
    this.thumbUrl,
    this.mood,
    this.taggedEmails = const [],
    this.eventType,
  });

  final TimelineKind kind;
  final String id;
  final String title;
  final String subtitle;
  final DateTime at;
  final String authorOrCreatorName;

  /// Lowercased emails for “involves this person” filter (author, tagged, participants).
  final List<String> involvedEmails;

  final String? storyId;
  final String? eventId;
  final String? thumbUrl;
  final String? mood;
  final List<String> taggedEmails;
  final String? eventType;

  bool involvesPerson(String emailLower) {
    final e = emailLower.trim().toLowerCase();
    return involvedEmails.any((x) => x == e);
  }

  bool isOnThisDay(DateTime reference) {
    return at.month == reference.month && at.day == reference.day;
  }

  @override
  List<Object?> get props => [
        kind,
        id,
        title,
        subtitle,
        at,
        authorOrCreatorName,
        involvedEmails,
        storyId,
        eventId,
        thumbUrl,
        mood,
        taggedEmails,
        eventType,
      ];
}
