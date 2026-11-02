// Renders screenshots of the main screens into docs/screenshots.
// Run: flutter test tool/screenshots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:masrofy/main.dart';
import 'package:masrofy/models/txn.dart';
import 'package:masrofy/services/notification_service.dart';
import 'package:masrofy/services/storage_service.dart';
import 'package:masrofy/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadFonts() async {
  final cairo = FontLoader('Cairo');
  for (final f in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    cairo.addFont(Future.value(ByteData.sublistView(File('assets/fonts/Cairo-$f.ttf').readAsBytesSync())));
  }
  await cairo.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(
        File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

Future<AppState> seeded(String lang) async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  final app = AppState(storage, NotificationService());
  await app.load();
  await app.completeOnboarding(name: lang == 'ar' ? 'عمرو' : 'Amr', balance: 8500, minDaily: 150, maxDaily: 250, lang: lang);
  final now = DateTime.now();
  app.settings.startDate = DateTime(now.year, now.month, now.day - 8);
  final spend = [180.0, 120.0, 310.0, 140.0, 200.0, 90.0, 230.0];
  final cats = ExpenseCategory.values;
  for (var i = 0; i < spend.length; i++) {
    final d = DateTime(now.year, now.month, now.day - (7 - i), 13);
    await app.addExpense(amount: spend[i], date: d, category: cats[i % cats.length], note: '');
  }
  await app.addExpense(amount: 85, date: DateTime(now.year, now.month, now.day, 9), category: ExpenseCategory.food);
  await app.addExpense(amount: 40, date: DateTime(now.year, now.month, now.day, 10), category: ExpenseCategory.transport);
  final due = DateTime(now.year, now.month, now.day + 3);
  await app.addInstallment(name: lang == 'ar' ? 'الموبايل' : 'Phone', amount: 1200, dueDay: due.day, total: 12, remaining: 7);
  await app.addInstallment(name: lang == 'ar' ? 'اللابتوب' : 'Laptop', amount: 2000, dueDay: 25, total: 10, remaining: 4);
  await app.setOuting(DateTime(now.year, now.month, now.day + 2), 600);
  return app;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadFonts();
  });

  for (final lang in ['ar', 'en']) {
    testWidgets('screens $lang', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late AppState app;
      await tester.runAsync(() async => app = await seeded(lang));
      await tester.pumpWidget(ChangeNotifierProvider.value(value: app, child: const MasrofyApp()));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/screenshots/${lang}_1_home.png'));

      final labels = lang == 'ar'
          ? ['السجل', 'الأقساط', 'المساعد', 'حسابي']
          : ['History', 'Installments', 'Assistant', 'Profile'];
      final names = ['2_history', '3_installments', '4_assistant', '5_profile'];
      for (var i = 0; i < labels.length; i++) {
        await tester.tap(find.text(labels[i]).last);
        await tester.pumpAndSettle();
        if (i == 2) {
          await tester.tap(find.byType(ActionChip).first);
          await tester.pumpAndSettle();
        }
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/screenshots/${lang}_${names[i]}.png'));
      }

      // Add-expense sheet with an amount that crosses the limit.
      await tester.tap(find.text(labels[0]).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '200');
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/screenshots/${lang}_6_add_expense.png'));
    });
  }
}
