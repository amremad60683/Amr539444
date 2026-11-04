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
      child: MasrofyApp(boot: (_) async {}, minSplash: Duration.zero, listenLinks: false),
    );

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> signUp(WidgetTester tester, {bool female = false}) async {
  await tester.tap(find.text('اعمل حسابي'));
  await tester.pumpAndSettle();
  if (female) {
    await tester.tap(find.text('مؤنث'));
    await tester.pumpAndSettle();
    expect(find.text('معاكي كام في البنك دلوقتي؟'), findsOneWidget);
  }
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), female ? 'سارة' : 'عمرو');
  await tester.enterText(fields.at(1), '5000');
  await tester.tap(find.text('التالي'));
  await tester.pumpAndSettle();
  expect(find.text('ميزانيتك'), findsOneWidget);
  await tester.tap(find.text('التالي'));
  await tester.pumpAndSettle();
}

Future<void> settle(WidgetTester tester) async {
  // The first-load reveal starts on a timer after the home's first frame.
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pumpAndSettle();
}

Future<void> typePin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d).last);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sign up (feminine), skip PIN, home reveals values', (tester) async {
    phone(tester);
    final app = await makeApp();
    await tester.pumpWidget(wrap(app));
    await tester.pumpAndSettle();
    expect(find.text('فلوسك كل يوم تحت السيطرة'), findsOneWidget);

    await signUp(tester, female: true);
    await tester.tap(find.text('بعدين'));
    await settle(tester);

    expect(find.text('سارة'), findsWidgets);
    expect(find.text('باقي ليكي النهارده'), findsOneWidget);
    expect(find.text('5,000 ج.م'), findsWidgets);
    expect(app.settings.pinHash, isNull);
  });

  testWidgets('sign up with a PIN, then log in', (tester) async {
    phone(tester);
    final app = await makeApp();
    await tester.pumpWidget(wrap(app));
    await tester.pumpAndSettle();
    await signUp(tester);
    await typePin(tester, '1234');
    expect(find.text('اكتب الرقم السري تاني'), findsOneWidget);
    await typePin(tester, '1234');
    expect(app.settings.pinHash, isNotNull);
    expect(find.text('باقي لك النهارده'), findsOneWidget);

    app.lock();
    await tester.pumpAndSettle();
    expect(find.text('أهلاً تاني يا عمرو'), findsOneWidget);
    await typePin(tester, '9999');
    expect(find.text('الرقم السري غلط، جرب تاني.'), findsOneWidget);
    await typePin(tester, '1234');
    expect(find.text('باقي لك النهارده'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('a bank link opens the confirmation sheet and adds the expense', (tester) async {
    phone(tester);
    final app = await makeApp();
    await app.completeOnboarding(name: 'Amr', balance: 5000, minDaily: 150, maxDaily: 250, lang: 'ar');
    await tester.pumpWidget(wrap(app));
    await settle(tester);

    await app.receiveBankText('تم خصم 120 جنيه لدى كارفور. الرصيد المتاح 4,500 جنيه');
    await tester.pumpAndSettle();
    expect(find.text('سجّله'), findsOneWidget);
    expect(find.text('رصيدك في البنك 4,500 ج.م'), findsOneWidget);
    await tester.tap(find.text('سجّله'));
    await tester.pumpAndSettle();

    expect(app.today.spent, 120);
    expect(app.txns.first.category, 'food');
    expect(app.settings.balance, 4500); // synced from the bank
    expect(app.settings.lastBankSync, isNotNull);

    // The same message again is flagged, not added twice.
    await app.receiveBankText('تم خصم 120 جنيه لدى كارفور. الرصيد المتاح 4,500 جنيه');
    await tester.pumpAndSettle();
    expect(find.text('الرسالة دي اتسجلت قبل كده.'), findsOneWidget);
  });

  test('auto-add bank messages', () async {
    final app = await makeApp();
    await app.completeOnboarding(name: 'Amr', balance: 5000, minDaily: 150, maxDaily: 250, lang: 'en');
    await app.setBankOptions(autoAdd: true);
    await app.receiveBankText('Your account was credited with EGP 9,000.00 salary. Avail Bal: EGP 14,000.00');
    expect(app.pendingBank, isNull);
    expect(app.lastAutoBank, isNotNull);
    expect(app.txns.first.type, TxnType.deposit);
    expect(app.settings.balance, 14000);
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

    await app.addInstallment(name: 'Phone', amount: 1000, dueDay: DateTime.now().day, total: 12, remaining: 5);
    expect(app.installments.single.remaining, 4);
    expect(app.settings.balance, 3700);
    expect(app.today.spent, 300);

    final paid = app.txns.firstWhere((t) => t.type == TxnType.installment);
    await app.deleteTxn(paid);
    expect(app.installments.single.remaining, 5);
    expect(app.settings.balance, 4700);

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
    expect(app.settings.balance, 1000);
    expect(app.settings.nextSalary!.isAfter(now), true);
    app.settings.nextSalary = DateTime(now.year, now.month, now.day);
    expect(await app.processSalary(), true);
    expect(app.settings.balance, 9000);
    expect(app.txns.first.type, TxnType.salary);
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
