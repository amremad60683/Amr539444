import 'dart:math';

import '../models/installment.dart';
import 'date_utils.dart';

/// The money picture for the current cycle: from the last payday to the next
/// one when a salary is set, otherwise the calendar month.
class MonthPlan {
  MonthPlan({
    required this.today,
    required this.cycleStart,
    required this.cycleEnd,
    required this.balance,
    required this.spent,
    required this.installmentsPaid,
    required this.installmentsDue,
    required this.safetyBalance,
    required this.salaryBased,
    DateTime? trackingStart,
  }) : trackingStart = trackingStart ?? cycleStart;

  /// First day the user tracked spending. Averages start from here when it
  /// is inside the cycle, so a new user's average isn't diluted.
  final DateTime trackingStart;

  final DateTime today;

  /// First day of the cycle (inclusive).
  final DateTime cycleStart;

  /// Day the cycle ends (exclusive): next payday or the 1st of next month.
  final DateTime cycleEnd;

  final double balance;

  /// Daily expenses since [cycleStart].
  final double spent;

  /// Installments already paid in this cycle.
  final double installmentsPaid;

  /// Installments still due before [cycleEnd].
  final double installmentsDue;

  final double safetyBalance;

  /// True when the cycle runs payday to payday.
  final bool salaryBased;

  /// Days elapsed in the cycle (since tracking began), today included.
  int get daysElapsed {
    final from = trackingStart.isAfter(cycleStart) ? trackingStart : cycleStart;
    return max(1, today.difference(from).inDays + 1);
  }

  /// Days after today until the cycle ends.
  int get daysAfterToday => max(0, cycleEnd.difference(today).inDays - 1);

  /// Days left including today.
  int get daysLeft => daysAfterToday + 1;

  /// Average daily spending so far in this cycle.
  double get averageDaily => spent / daysElapsed;

  /// Money free to spend: balance minus installments still due.
  double get free => balance - installmentsDue;

  /// Balance left when the cycle ends if spending [perDay] from tomorrow on.
  double projectedAt(double perDay) => (free - perDay * daysAfterToday).roundToDouble();

  /// Highest daily spend (from tomorrow) that still ends at the safety balance.
  double get safeDaily {
    if (daysAfterToday == 0) return max(0, free - safetyBalance);
    return max(0, (free - safetyBalance) / daysAfterToday);
  }

  static MonthPlan build({
    required DateTime now,
    required double balance,
    required double salary,
    required int salaryDay,
    required DateTime? nextSalary,
    required double safetyBalance,
    required Map<String, double> spentByDay,
    required double Function(DateTime from, DateTime to) installmentsPaidBetween,
    required List<Installment> installments,
    DateTime? trackingStart,
  }) {
    final today = dateOnly(now);
    DateTime start;
    DateTime end;
    final salaryBased = salary > 0 && nextSalary != null;
    if (salaryBased) {
      end = dateOnly(nextSalary);
      start = dueDateIn(end.year, end.month - 1, salaryDay);
      if (start.isAfter(today)) start = DateTime(today.year, today.month, 1);
    } else {
      start = DateTime(today.year, today.month, 1);
      end = DateTime(today.year, today.month + 1, 1);
    }

    double spent = 0;
    spentByDay.forEach((k, v) {
      final d = parseDayKey(k);
      if (!d.isBefore(start) && !d.isAfter(today)) spent += v;
    });

    double due = 0;
    for (final i in installments) {
      var d = i.nextDue;
      var left = i.remaining;
      while (left > 0 && d.isBefore(end)) {
        due += i.amount;
        left--;
        d = dueDateIn(d.year, d.month + 1, i.dueDay);
      }
    }

    return MonthPlan(
      today: today,
      cycleStart: start,
      cycleEnd: end,
      balance: balance,
      spent: spent,
      installmentsPaid: installmentsPaidBetween(start, today),
      installmentsDue: due,
      safetyBalance: safetyBalance,
      salaryBased: salaryBased,
      trackingStart: trackingStart == null ? null : dateOnly(trackingStart),
    );
  }
}
