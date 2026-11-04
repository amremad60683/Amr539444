// Renders screenshots of the main screens into docs/screenshots.
// Run: flutter test tool/screenshots_test.dart --update-goldens
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:masrofy/main.dart';
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
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  Future<void> load(String family, String path) async {
    final l = FontLoader(family)..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
    await l.load();
  }

  await load('MaterialIcons', '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  final pub = Platform.environment['PUB_CACHE'] ?? '${Platform.environment['HOME']}/.pub-cache';
  final cupertino = Directory('$pub/hosted/pub.dev')
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.contains('cupertino_icons-'))
      .first;
  await load('packages/cupertino_icons/CupertinoIcons', '${cupertino.path}/assets/CupertinoIcons.ttf');
}

Future<AppState> seeded(String lang, {String gender = 'm', String theme = 'dark'}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  final app = AppState(storage, NotificationService());
  await app.load();
  final now = DateTime.now();
  await app.completeOnboarding(
    name: lang == 'ar' ? (gender == 'f' ? 'سارة' : 'عمرو') : 'Amr',
    balance: 9200,
    minDaily: 150,
    maxDaily: 250,
    lang: lang,
    gender: gender,
    salary: 9000,
    salaryDay: DateTime(now.year, now.month, now.day + 12).day,
  );
  app.settings.startDate = DateTime(now.year, now.month, now.day - 10);
  await app.setThemeMode(theme);
  await app.setSafetyBalance(2000);
  final spend = [
    (180.0, 'food'), (120.0, 'transport'), (310.0, 'beauty'), (140.0, 'food'),
    (200.0, 'clothes'), (90.0, 'mobile'), (230.0, 'fun'),
  ];
  for (var i = 0; i < spend.length; i++) {
    final d = DateTime(now.year, now.month, now.day - (7 - i), 13);
    await app.addExpense(amount: spend[i].$1, date: d, category: spend[i].$2);
  }
  await app.addExpense(amount: 85, date: DateTime(now.year, now.month, now.day, 9), category: 'food');
  await app.addExpense(amount: 40, date: DateTime(now.year, now.month, now.day, 10), category: 'transport');
  final due = DateTime(now.year, now.month, now.day + 3);
  await app.addInstallment(
      name: lang == 'ar' ? 'الموبايل' : 'Phone', amount: 1200, dueDay: due.day, total: 12, remaining: 7);
  await app.addInstallment(
      name: lang == 'ar' ? 'اللابتوب' : 'Laptop', amount: 2000, dueDay: 25, total: 10, remaining: 4);
  await app.setOuting(DateTime(now.year, now.month, now.day + 2), 600);
  return app;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadFonts();
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> shot(WidgetTester tester, String name) =>
      expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/screenshots/$name.png'));

  testWidgets('opening sequence', (tester) async {
    phone(tester);
    late AppState app;
    await tester.runAsync(() async => app = await seeded('ar'));
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: app,
      child: MasrofyApp(boot: (_) async {}, minSplash: const Duration(milliseconds: 1100)),
    ));
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await shot(tester, 'flow_1_splash');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50)); // splash done -> crossfade
    }
    await tester.pump(const Duration(milliseconds: 450));
    await shot(tester, 'flow_2_skeleton');
    await tester.pump(const Duration(milliseconds: 300)); // reveal starts
    await tester.pump(const Duration(milliseconds: 250));
    await shot(tester, 'flow_3_revealing');
    await tester.pumpAndSettle();
    await shot(tester, 'flow_4_ready');
  });

  for (final (lang, gender, theme) in [('ar', 'm', 'dark'), ('en', 'm', 'dark'), ('ar', 'f', 'light')]) {
    testWidgets('screens $lang $gender $theme', (tester) async {
      phone(tester);
      final p = '${lang}_$theme${gender == 'f' ? '_f' : ''}';
      late AppState app;
      await tester.runAsync(() async => app = await seeded(lang, gender: gender, theme: theme));
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: app,
        child: MasrofyApp(boot: (_) async {}, minSplash: Duration.zero),
      ));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      await shot(tester, '${p}_1_home');
      if (theme == 'light') return;

      final labels = lang == 'ar'
          ? ['السجل', 'الشهر', 'المساعد', 'حسابي']
          : ['History', 'Month', 'Assistant', 'Profile'];
      final names = ['2_history', '3_month', '4_assistant', '5_profile'];
      for (var i = 0; i < labels.length; i++) {
        await tester.tap(find.text(labels[i]).last);
        await tester.pumpAndSettle();
        if (i == 2) {
          await tester.tap(find.byType(ActionChip).at(1));
          await tester.pumpAndSettle();
        }
        await shot(tester, '${p}_${names[i]}');
      }

      // Add-expense sheet with an amount that crosses the limit.
      await tester.tap(find.text(lang == 'ar' ? 'النهارده' : 'Today').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '200');
      await tester.pumpAndSettle();
      await shot(tester, '${p}_6_add_expense');
    });
  }

  testWidgets('onboarding feminine', (tester) async {
    phone(tester);
    late AppState app;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      app = AppState(storage, NotificationService());
      await app.load();
    });
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: app,
      child: MasrofyApp(boot: (_) async {}, minSplash: Duration.zero),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مؤنث'));
    await tester.pumpAndSettle();
    await shot(tester, 'ar_dark_f_0_onboarding');
  });
}
