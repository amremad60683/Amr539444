import 'package:flutter_test/flutter_test.dart';
import 'package:masrofy/models/installment.dart';
import 'package:masrofy/services/budget_engine.dart';
import 'package:masrofy/services/date_utils.dart';

void main() {
  final d1 = DateTime(2026, 11, 1);
  final d2 = DateTime(2026, 11, 2);
  final d3 = DateTime(2026, 11, 3);
  final d4 = DateTime(2026, 11, 4);

  BudgetEngine engine(Map<DateTime, double> spent, [Map<DateTime, double> outings = const {}]) =>
      BudgetEngine(
        minDaily: 150,
        maxDaily: 250,
        startDate: d1,
        spentByDay: spent.map((k, v) => MapEntry(dayKey(k), v)),
        outingBudgets: outings.map((k, v) => MapEntry(dayKey(k), v)),
      );

  test('normal day: allowance is the max, status by thresholds', () {
    final e = engine({d1: 100});
    final b = e.forDay(d1);
    expect(b.allowance, 250);
    expect(b.target, 150);
    expect(b.status, BudgetStatus.safe);
    expect(b.statusFor(160), BudgetStatus.warning);
    expect(b.statusFor(251), BudgetStatus.over);
  });

  test('overspending is deducted from the next day', () {
    final e = engine({d1: 300});
    expect(e.forDay(d1).debtOut, 50);
    final b2 = e.forDay(d2);
    expect(b2.allowance, 200);
    expect(b2.deducted, 50);
  });

  test('allowance never drops below the minimum; rest carries on', () {
    // 250 over -> day2 can only deduct 100 (250-150), remaining 150 carries.
    final e = engine({d1: 500, d2: 150});
    final b2 = e.forDay(d2);
    expect(b2.allowance, 150);
    expect(b2.debtOut, 150); // 250 + 150 - 250
    final b3 = e.forDay(d3);
    expect(b3.allowance, 150);
    final b4 = engine({d1: 500, d2: 150, d3: 150}).forDay(d4);
    expect(b4.allowance, 200); // 50 still carried
  });

  test('spending less than the max pays the carried amount down', () {
    final e = engine({d1: 300, d2: 100});
    expect(e.forDay(d3).allowance, 250);
  });

  test('outing day uses its own budget', () {
    final e = engine({d2: 600}, {d2: 500});
    final b2 = e.forDay(d2);
    expect(b2.isOuting, true);
    expect(b2.allowance, 500);
    expect(b2.overBy, 100);
    expect(e.forDay(d3).allowance, 150);
  });

  test('range matches forDay', () {
    final e = engine({d1: 400, d2: 100, d3: 260});
    final r = e.range(d4, 4);
    for (final b in r) {
      expect(b.allowance, e.forDay(b.day).allowance);
    }
  });

  test('installment due dates clamp to month length', () {
    expect(dueDateIn(2026, 2, 31), DateTime(2026, 2, 28));
    expect(dueDateIn(2026, 13, 5), DateTime(2027, 1, 5));
    expect(Installment.firstDueFrom(DateTime(2026, 11, 10), 5), DateTime(2026, 12, 5));
    expect(Installment.firstDueFrom(DateTime(2026, 11, 10), 10), DateTime(2026, 11, 10));
    final i = Installment(
        id: 'x', name: 'n', amount: 100, dueDay: 31, total: 3, remaining: 3, nextDue: DateTime(2026, 1, 31));
    i.advance();
    expect(i.nextDue, DateTime(2026, 2, 28));
    i.advance();
    expect(i.nextDue, DateTime(2026, 3, 31));
  });
}
