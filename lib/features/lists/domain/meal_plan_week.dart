import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// The 7 days, Monday-first, matching [MealPlanWeek.dayKeys].
const List<String> mealPlanDayKeys = [
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
];

const List<String> mealPlanDayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> mealPlanSlotKeys = ['breakfast', 'lunch', 'dinner'];

const List<String> mealPlanSlotLabels = ['Breakfast', 'Lunch', 'Dinner'];

/// ISO-8601 week id (`2026-W31`) — same algorithm as `weekId()` in
/// `functions/src/weekly.ts`, so the app and the weekly-champion Cloud
/// Function agree on which week "now" belongs to.
String isoWeekId(DateTime d) {
  final utc = DateTime.utc(d.year, d.month, d.day);
  // ISO: Monday=1 .. Sunday=7; shift to the Thursday of this week.
  final dayNr = (utc.weekday + 6) % 7;
  final thursday = utc.add(Duration(days: 3 - dayNr));
  final firstThursdayBase = DateTime.utc(thursday.year, 1, 4);
  final firstThursdayDayNr = (firstThursdayBase.weekday + 6) % 7;
  final firstThursday =
      firstThursdayBase.add(Duration(days: 3 - firstThursdayDayNr));
  final week =
      1 + (thursday.difference(firstThursday).inDays / 7).round();
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

/// `families/{fid}/meal_plans/{weekId}` — one doc per week. `meals` is a
/// flat `"<day>_<slot>" -> dish name` map (e.g. `mon_breakfast`) so the whole
/// week is a single realtime doc instead of 21 separate ones.
class MealPlanWeek extends Equatable {
  const MealPlanWeek({
    required this.weekId,
    required this.meals,
    this.updatedBy = '',
    this.updatedAt,
  });

  final String weekId;
  final Map<String, String> meals;
  final String updatedBy;
  final DateTime? updatedAt;

  static String keyFor(String day, String slot) => '${day}_$slot';

  String mealFor(String day, String slot) => meals[keyFor(day, slot)] ?? '';

  static MealPlanWeek empty(String weekId) =>
      MealPlanWeek(weekId: weekId, meals: const {});

  static MealPlanWeek fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final rawMeals = d['meals'];
    final meals = <String, String>{};
    if (rawMeals is Map) {
      for (final entry in rawMeals.entries) {
        final v = entry.value;
        if (v is String && v.trim().isNotEmpty) {
          meals[entry.key.toString()] = v;
        }
      }
    }
    final ts = d['updatedAt'];
    return MealPlanWeek(
      weekId: doc.id,
      meals: meals,
      updatedBy: d['updatedBy'] as String? ?? '',
      updatedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  @override
  List<Object?> get props => [weekId, meals, updatedBy, updatedAt];
}
