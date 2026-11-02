// Small date helpers. All budget logic works on whole days.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dayKey(DateTime d) {
  final x = dateOnly(d);
  return '${x.year.toString().padLeft(4, '0')}-'
      '${x.month.toString().padLeft(2, '0')}-'
      '${x.day.toString().padLeft(2, '0')}';
}

DateTime parseDayKey(String k) => DateTime.parse(k);

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Due date in [year]/[month] for [dueDay], clamped to the month length
/// (e.g. day 31 in February becomes the 28th/29th). Month overflow is
/// normalised (month 13 -> January next year).
DateTime dueDateIn(int year, int month, int dueDay) {
  final first = DateTime(year, month, 1);
  final day = dueDay.clamp(1, daysInMonth(first.year, first.month));
  return DateTime(first.year, first.month, day);
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
