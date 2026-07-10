import '../entities/calendar_event.dart';

abstract class CalendarRepository {
  Stream<List<CalendarEvent>> watchEvents({int limit});

  Stream<CalendarEvent?> watchEvent(String eventId);

  Future<String> createEvent({
    required String title,
    required String description,
    required DateTime startAt,
    DateTime? endAt,
    required bool allDay,
    required String eventType,
    required List<String> participantEmails,
  });

  Future<void> deleteEvent(String eventId);
}
