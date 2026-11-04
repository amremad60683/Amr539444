import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:masrofy/main.dart';
import 'package:masrofy/models/txn.dart';
import 'package:masrofy/services/budget_engine.dart';
import 'package:masrofy/services/notification_service.dart';
import 'package:masrofy/services/storage_service.dart';
import 'package:masrofy/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> makeApp([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  await initializeDateFormatting();
  final storage = StorageService();
  await storage.init();
  // Not initialised -> all notification calls are no-ops in tests.
  final app = AppState(storage, NotificationService());
  await app.load();
  return app;
}

Widget wrap(AppState app) => ChangeNotifierProvider.value(
      value: app,
      child: MasrofyApp(boot: (_) async {}, minSplash: Duration.zero),
    );

void main() {
  testWidgets('splash, onboarding, then home reveals values', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final app = await makeApp();
    await tester.pumpWidget(wrap(app));
    await tester.pumpAndSettle();

    expect(find.text('يلا نبدأ'), findsOneWidget);
    // Feminine wording switches the Arabic copy.
    await tester.tap(find.text('مؤنث'));
    await tester.pumpAndSettle();
    expect(find.text('معاكي كام في البنك دلوقتي؟'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'سارة');
    await tester.enterText(fields.at(1), '5000');
    await tester.ensureVisible(find.text('يلا نبدأ'));
    await tester.tap(find.text('يلا نبدأ'));
    await tester.pumpAndSettle();

    expect(find.text('أهلاً سارة'), findsOneWidget);
    expect(find.text('باقي ليكي النهارده'), findsOneWidget);
    expect(find.text('5,000 ج.م'), findsWidgets);
    expect(app.today.allowance, 250);
  });

  test('state: overspending warns and reduces tomorrow, installments auto-pay', () async {
    final app = await makeApp();
    await app.completeOnboarding(name: 'Amr', balance: 5000, minDaily: 150, maxDaily: 250, lang: 'en');

    final r1 = await app.addExpense(amount: 160, date: DateTime.now(), category: 'beauty');
    expect(r1.crossedTarget, true);
    expect(r1.after.status, BudgetStatus.warning);

    final r2 = await app.addExpense(amount: 140, date: DateTime.now());
    expect(r2.crossedLimit, true);
    expect(app.today.debtOut, 50);
    expect(app.tomorrow.allowance, 200);
    expect(app.settings.balance, 4700);

    // Installment due today is paid automatically and excluded from daily spending.
    await app.addInstallment(name: 'Phone', amount: 1000, dueDay: DateTime.now().day, total: 12, remaining: 5);
    expect(app.installments.single.remaining, 4);
    expect(app.settings.balance, 3700);
    expect(app.today.spent, 300);

    // Deleting the installment payment restores balance and count.
    final paid = app.txns.firstWhere((t) => t.type == TxnType.installment);
    await app.deleteTxn(paid);
    expect(app.installments.single.remaining, 5);
    expect(app.settings.balance, 4700);

    // Spending by category.
    final now = DateTime.now();
    final cats = app.spentByCategory(DateTime(now.year, now.month, 1), now);
    expect(cats.first.key.id, 'beauty');
    expect(cats.first.value, 160);
  });

  test('salary is added automatically on payday, not on setup day', () async {
    final app = await makeApp();
    final now = DateTime.now();
    await app.completeOnboarding(
        name: 'A', balance: 1000, minDaily: 100, maxDaily: 200, lang: 'en', salary: 8000, salaryDay: now.day);
    // Set up today: today's salary is assumed to be in the entered balance.
    expect(app.settings.balance, 1000);
    expect(app.settings.nextSalary!.isAfter(now), true);

    // Pretend the payday arrived.
    app.settings.nextSalary = DateTime(now.year, now.month, now.day);
    expect(await app.processSalary(), true);
    expect(app.settings.balance, 9000);
    expect(app.txns.first.type, TxnType.salary);
    expect(app.settings.nextSalary!.isAfter(now), true);
    // Running again the same day adds nothing.
    expect(await app.processSalary(), false);
  });

  test('custom categories can be added and deleted', () async {
    final app = await makeApp();
    await app.completeOnboarding(name: 'A', balance: 1000, minDaily: 100, maxDaily: 200, lang: 'ar');
    await app.addCategory('جيم', 'sportscourt');
    final c = app.settings.customCategories.single;
    await app.addExpense(amount: 50, date: DateTime.now(), category: c.id);
    expect(app.categoryById(c.id).label(true), 'جيم');
    await app.deleteCategory(c);
    expect(app.txns.single.category, 'other');
  });
}
