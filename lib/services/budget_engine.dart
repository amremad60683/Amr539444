import 'dart:math';

import 'date_utils.dart';

/// Where the day's spending stands compared to the limits.
enum BudgetStatus {
  /// Below the daily target (minimum).
  safe,

  /// Between the target and the day's allowance.
  warning,

  /// Above the day's allowance.
  over,
}

/// Budget picture for one day.
class DayBudget {
  DayBudget({
    required this.day,
    required this.base,
    required this.debtIn,
    required this.allowance,
    required this.target,
    required this.spent,
    required this.isOuting,
  });

  final DateTime day;

  /// Normal limit for the day: the daily max, or the outing budget.
  final double base;

  /// Overspending carried in from previous days.
  final double debtIn;

  /// What may actually be spent today after deducting carried overspending.
  final double allowance;

  /// The soft target (daily minimum), never above [allowance].
  final double target;

  final double spent;
  final bool isOuting;

  /// How much was deducted from today because of previous overspending.
  double get deducted => base - allowance;

  double get remaining => allowance - spent;

  /// Overspending that will be carried to the next day.
  double get debtOut => max(0, debtIn + spent - base);

  /// Amount over today's allowance (0 if within).
  double get overBy => max(0, spent - allowance);

  BudgetStatus get status => statusFor(spent);

  BudgetStatus statusFor(double amount) {
    if (amount > allowance) return BudgetStatus.over;
    if (amount >= target) return BudgetStatus.warning;
    return BudgetStatus.safe;
  }

  /// Progress 0..1+ of spending relative to the allowance.
  double get progress => allowance <= 0 ? 1 : spent / allowance;
}

/// Pure budgeting rules (no Flutter, easy to test).
///
/// Rules:
/// * Each day has a base limit = [maxDaily] (or the outing budget on an
///   outing day).
/// * Overspending above the base is carried forward as "debt".
/// * Allowance = base - debt, but never below [minDaily] so the user can
///   still live; whatever is not recovered keeps carrying to later days.
/// * Spending less than the base pays the debt down.
///
/// Equivalent recurrence: debt[d+1] = max(0, debt[d] + spent[d] - base[d]).
class BudgetEngine {
  BudgetEngine({
    required this.minDaily,
    required this.maxDaily,
    required this.startDate,
    required this.spentByDay,
    required this.outingBudgets,
  });

  final double minDaily;
  final double maxDaily;
  final DateTime startDate;

  /// dayKey -> total daily expenses.
  final Map<String, double> spentByDay;

  /// dayKey -> budget for an outing day.
  final Map<String, double> outingBudgets;

  double baseFor(DateTime day) => outingBudgets[dayKey(day)] ?? maxDaily;

  DayBudget _make(DateTime day, double debtIn) {
    final key = dayKey(day);
    final base = baseFor(day);
    final floor = min(minDaily, base);
    final allowance = max(floor, base - debtIn);
    return DayBudget(
      day: day,
      base: base,
      debtIn: debtIn,
      allowance: allowance,
      target: min(minDaily, allowance),
      spent: spentByDay[key] ?? 0,
      isOuting: outingBudgets.containsKey(key),
    );
  }

  /// Budget for [day], walking forward from [startDate] to accumulate debt.
  DayBudget forDay(DateTime day) {
    final target = dateOnly(day);
    var cursor = dateOnly(startDate);
    // Start from the earliest day that has spending, if before startDate.
    for (final k in spentByDay.keys) {
      final d = parseDayKey(k);
      if (d.isBefore(cursor)) cursor = d;
    }
    if (target.isBefore(cursor)) return _make(target, 0);

    double debt = 0;
    while (cursor.isBefore(target)) {
      final b = _make(cursor, debt);
      debt = b.debtOut;
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return _make(target, debt);
  }

  /// Budgets for the [count] days ending at [end] (oldest first).
  List<DayBudget> range(DateTime end, int count) {
    final first = DateTime(end.year, end.month, end.day - (count - 1));
    var b = forDay(first);
    final out = <DayBudget>[b];
    var cursor = first;
    for (var i = 1; i < count; i++) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
      b = _make(cursor, b.debtOut);
      out.add(b);
    }
    return out;
  }
}
