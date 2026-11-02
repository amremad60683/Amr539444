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

Future<AppState> makeApp() async {
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting();
  final storage = StorageService();
  await storage.init();
  // Not initialised -> all notification calls are no-ops in tests.
  final app = AppState(storage, NotificationService());
  await app.load();
  return app;
}

Widget wrap(AppState app) => ChangeNotifierProvider.value(value: app, child: const MasrofyApp());

void main() {
  testWidgets('onboarding then home shows balance and allowance', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final app = await makeApp();
    await tester.pumpWidget(wrap(app));
    await tester.pumpAndSettle();

    expect(find.text('يلا نبدأ'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'عمرو');
    await tester.enterText(fields.at(1), '5000');
    await tester.tap(find.text('يلا نبدأ'));
    await tester.pumpAndSettle();

    expect(find.text('أهلاً عمرو'), findsOneWidget);
    expect(find.text('5,000 ج.م'), findsWidgets);
    expect(app.today.allowance, 250);
  });

  test('state: overspending warns and reduces tomorrow, installments auto-pay', () async {
    final app = await makeApp();
    await app.completeOnboarding(name: 'Amr', balance: 5000, minDaily: 150, maxDaily: 250, lang: 'en');

    final r1 = await app.addExpense(amount: 160, date: DateTime.now(), category: ExpenseCategory.food);
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
  });
}
