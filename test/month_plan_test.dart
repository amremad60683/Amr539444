import 'package:flutter_test/flutter_test.dart';
import 'package:masrofy/models/installment.dart';
import 'package:masrofy/services/date_utils.dart';
import 'package:masrofy/services/month_plan.dart';

void main() {
  final now = DateTime(2026, 11, 10, 15);

  MonthPlan plan({
    double balance = 3000,
    double salary = 0,
    DateTime? nextSalary,
    double safety = 0,
    Map<DateTime, double> spent = const {},
    List<Installment> inst = const [],
  }) =>
      MonthPlan.build(
        now: now,
        balance: balance,
        salary: salary,
        salaryDay: 25,
        nextSalary: nextSalary,
        safetyBalance: safety,
        spentByDay: spent.map((k, v) => MapEntry(dayKey(k), v)),
        installmentsPaidBetween: (a, b) => 0,
        installments: inst,
      );

  test('calendar month cycle without salary', () {
    final p = plan(spent: {DateTime(2026, 11, 1): 200, DateTime(2026, 11, 10): 100, DateTime(2026, 10, 30): 999});
    expect(p.cycleStart, DateTime(2026, 11, 1));
    expect(p.cycleEnd, DateTime(2026, 12, 1));
    expect(p.spent, 300);
    expect(p.daysElapsed, 10);
    expect(p.daysAfterToday, 20); // Nov 11..30
    expect(p.averageDaily, 30);
  });

  test('salary cycle runs payday to payday', () {
    final p = plan(salary: 8000, nextSalary: DateTime(2026, 11, 25));
    expect(p.salaryBased, true);
    expect(p.cycleStart, DateTime(2026, 10, 25));
    expect(p.cycleEnd, DateTime(2026, 11, 25));
    expect(p.daysAfterToday, 14); // Nov 11..24
  });

  test('projection subtracts installments due and spending per day', () {
    final i = Installment(
        id: 'i', name: 'Phone', amount: 500, dueDay: 20, total: 6, remaining: 3, nextDue: DateTime(2026, 11, 20));
    final p = plan(balance: 3000, inst: [i]);
    expect(p.installmentsDue, 500);
    expect(p.free, 2500);
    expect(p.projectedAt(100), 2500 - 100 * 20);
  });

  test('safe daily keeps the safety balance', () {
    final p = plan(balance: 3000, safety: 1000);
    expect(p.safeDaily, (3000 - 1000) / 20);
    final broke = plan(balance: 800, safety: 1000);
    expect(broke.safeDaily, 0);
  });

  test('average counts from the first tracked day', () {
    final p = MonthPlan.build(
      now: now,
      balance: 3000,
      salary: 0,
      salaryDay: 1,
      nextSalary: null,
      safetyBalance: 0,
      spentByDay: {dayKey(DateTime(2026, 11, 9)): 200, dayKey(DateTime(2026, 11, 10)): 100},
      installmentsPaidBetween: (a, b) => 0,
      installments: const [],
      trackingStart: DateTime(2026, 11, 9),
    );
    expect(p.daysElapsed, 2);
    expect(p.averageDaily, 150);
  });
}
