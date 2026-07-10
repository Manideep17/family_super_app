/// Monday-based week bucket `yyyy-Www` (0–52 from Jan 1). Good enough for “family champion”.
String familyWeekId(DateTime d) {
  final start = DateTime(d.year, 1, 1);
  final days = DateTime(d.year, d.month, d.day).difference(start).inDays;
  final w = days ~/ 7;
  return '${d.year}-W$w';
}
