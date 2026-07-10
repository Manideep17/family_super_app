/// Static Indian festival/occasion suggestions — the "fun & family-specific"
/// layer that generic organizer apps (Cozi, FamilyWall) don't have.
///
/// This is a client-only, best-effort list — not authoritative. Fixed
/// national holidays (Republic Day, Independence Day, Gandhi Jayanti,
/// Christmas) are solid. Solar festivals (Makar Sankranti/Pongal) are
/// solid. Lunar-calendar festivals (Holi, Diwali, Navratri, Raksha Bandhan,
/// Onam, Ram Navami) shift year to year and are approximate here — and
/// Islamic festivals (Eid al-Fitr, Eid al-Adha) depend on moon sighting, so
/// treat those dates as "roughly this week," not exact. Families should
/// confirm locally-important dates themselves; this is a nudge to
/// celebrate together, not a religious calendar of record.
///
/// Dates below are for 2026 only. Re-verify and extend for 2027+ rather
/// than assuming a fixed offset — most of these move every year.
class IndianFestival {
  const IndianFestival({
    required this.name,
    required this.date,
    required this.emoji,
    this.approximate = false,
  });

  final String name;
  final DateTime date;
  final String emoji;

  /// True for lunar/moon-sighting-dependent festivals — surfaced in the UI
  /// as "around this date" instead of a confident exact day.
  final bool approximate;
}

abstract final class IndianFestivals {
  static final List<IndianFestival> year2026 = [
    IndianFestival(name: 'Makar Sankranti', date: DateTime(2026, 1, 14), emoji: '🪁'),
    IndianFestival(name: 'Pongal', date: DateTime(2026, 1, 14), emoji: '🌾'),
    IndianFestival(name: 'Republic Day', date: DateTime(2026, 1, 26), emoji: '🇮🇳'),
    IndianFestival(name: 'Holi', date: DateTime(2026, 3, 4), emoji: '🎨', approximate: true),
    IndianFestival(name: 'Ram Navami', date: DateTime(2026, 3, 27), emoji: '🙏', approximate: true),
    IndianFestival(name: 'Eid al-Fitr', date: DateTime(2026, 3, 30), emoji: '🌙', approximate: true),
    IndianFestival(name: 'Eid al-Adha', date: DateTime(2026, 5, 27), emoji: '🌙', approximate: true),
    IndianFestival(name: 'Raksha Bandhan', date: DateTime(2026, 8, 18), emoji: '🧵', approximate: true),
    IndianFestival(name: 'Independence Day', date: DateTime(2026, 8, 15), emoji: '🇮🇳'),
    IndianFestival(name: 'Onam', date: DateTime(2026, 8, 26), emoji: '🌼', approximate: true),
    IndianFestival(name: 'Navratri begins', date: DateTime(2026, 10, 11), emoji: '💃', approximate: true),
    IndianFestival(name: 'Dussehra / Vijayadashami', date: DateTime(2026, 10, 20), emoji: '🏹', approximate: true),
    IndianFestival(name: 'Diwali', date: DateTime(2026, 11, 8), emoji: '🪔', approximate: true),
    IndianFestival(name: 'Guru Nanak Jayanti', date: DateTime(2026, 11, 24), emoji: '🪯', approximate: true),
    IndianFestival(name: 'Christmas', date: DateTime(2026, 12, 25), emoji: '🎄'),
  ]..sort((a, b) => a.date.compareTo(b.date));

  /// Next festival within [withinDays] of [from] (default: today).
  static IndianFestival? next({DateTime? from, int withinDays = 21}) {
    final now = from ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final f in year2026) {
      final days = f.date.difference(today).inDays;
      if (days >= 0 && days <= withinDays) return f;
    }
    return null;
  }

  static int daysUntil(IndianFestival f, {DateTime? from}) {
    final now = from ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return f.date.difference(today).inDays;
  }
}
