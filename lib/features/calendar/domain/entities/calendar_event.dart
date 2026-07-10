import 'package:equatable/equatable.dart';

/// `calendar_events/{id}` — shared family calendar.
class CalendarEvent extends Equatable {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startAt,
    this.endAt,
    required this.allDay,
    required this.eventType,
    required this.creatorUid,
    required this.creatorName,
    required this.creatorEmail,
    required this.participantEmails,
  });

  final String id;
  final String title;
  final String description;
  final DateTime startAt;
  final DateTime? endAt;
  final bool allDay;
  final String eventType;
  final String creatorUid;
  final String creatorName;
  final String creatorEmail;
  final List<String> participantEmails;

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        startAt,
        endAt,
        allDay,
        eventType,
        creatorUid,
        creatorName,
        creatorEmail,
        participantEmails,
      ];
}
