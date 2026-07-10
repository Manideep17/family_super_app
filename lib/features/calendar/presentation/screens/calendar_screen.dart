import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../domain/entities/calendar_event.dart';
import '../providers/calendar_providers.dart';
import '../widgets/create_event_sheet.dart';
import 'event_detail_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  Map<DateTime, List<CalendarEvent>> _groupByDay(List<CalendarEvent> events) {
    final map = <DateTime, List<CalendarEvent>>{};
    for (final e in events) {
      final k = DateTime.utc(e.startAt.year, e.startAt.month, e.startAt.day);
      map.putIfAbsent(k, () => []).add(e);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.startAt.compareTo(b.startAt));
    }
    return map;
  }

  List<CalendarEvent> _eventsForDay(
    Map<DateTime, List<CalendarEvent>> map,
    DateTime day,
  ) {
    final k = DateTime.utc(day.year, day.month, day.day);
    return map[k] ?? const [];
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(calendarEventsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Family calendar')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (events) {
          final map = _groupByDay(events);
          final dayEvents = _eventsForDay(map, _selected);

          return Column(
            children: [
              Card(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                clipBehavior: Clip.antiAlias,
                child: TableCalendar<CalendarEvent>(
                  firstDay: DateTime.utc(2022, 1, 1),
                  lastDay: DateTime.utc(2035, 12, 31),
                  focusedDay: _focused,
                  selectedDayPredicate: (d) => isSameDay(_selected, d),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selected = selected;
                      _focused = focused;
                    });
                  },
                  onPageChanged: (focused) => setState(() => _focused = focused),
                  eventLoader: (d) => _eventsForDay(map, d),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    markersMaxCount: 3,
                    selectedDecoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      border: Border.all(color: scheme.primary, width: 2),
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: dayEvents.isEmpty
                    ? Center(
                        child: Text(
                          'No events on this day.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: dayEvents.length,
                        itemBuilder: (context, i) {
                          final e = dayEvents[i];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(e.eventType[0].toUpperCase()),
                            ),
                            title: Text(e.title),
                            subtitle: Text(e.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => EventDetailScreen(eventId: e.id),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await showCreateEventSheet(context);
          if (ok == true && mounted) {
            ref.invalidate(calendarEventsProvider);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add event'),
      ),
    );
  }
}
