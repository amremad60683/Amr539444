// Renders screenshots of the main screens into docs/screenshots.
// Run: flutter test tool/screenshots_test.dart --update-goldens
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:masrofy/main.dart';
import 'package:masrofy/services/bank_sms.dart';
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

Future<AppState> seeded(String lang, {String gender = 'm', String theme = 'light', bool pin = false}) async {
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
  await app.applyBank(parseBankSms(lang == 'ar'
      ? 'تم خصم 95 جنيه لدى اوبر. الرصيد المتاح 4,380 جنيه'
      : 'Purchase of EGP 95.00 at UBER EGYPT. Available balance EGP 4,380.00'));
  if (pin) await app.setPin('1234');
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

  Widget appOf(AppState app, {Duration splash = Duration.zero}) => ChangeNotifierProvider.value(
        value: app,
        child: MasrofyApp(boot: (_) async {}, minSplash: splash, listenLinks: false),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
  }

  Future<AppState> fresh() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final app = AppState(storage, NotificationService());
    await app.load();
    return app;
  }

  testWidgets('opening sequence', (tester) async {
    phone(tester);
    late AppState app;
    await tester.runAsync(() async => app = await seeded('ar'));
    await tester.pumpWidget(appOf(app, splash: const Duration(milliseconds: 1100)));
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await shot(tester, 'a01_splash');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 450));
    await shot(tester, 'a02_skeleton');
    await settle(tester);
    await shot(tester, 'a03_home');
  });

  testWidgets('sign up and login', (tester) async {
    phone(tester);
    late AppState app;
    await tester.runAsync(() async => app = await fresh());
    await tester.pumpWidget(appOf(app));
    await tester.pumpAndSettle();
    await shot(tester, 'b01_welcome');
    await tester.tap(find.text('اعمل حسابي'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'عمرو');
    await tester.enterText(fields.at(1), '9200');
    await tester.pumpAndSettle();
    await shot(tester, 'b02_step_you');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(2), '9000');
    await tester.pumpAndSettle();
    await shot(tester, 'b03_step_budget');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('2').last);
    await tester.pumpAndSettle();
    await shot(tester, 'b04_step_pin');

    // Login screen for a user with a PIN.
    late AppState app2;
    await tester.runAsync(() async => app2 = await seeded('ar', pin: true));
    app2.unlocked = false;
    await tester.pumpWidget(appOf(app2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4').last);
    await tester.tap(find.text('7').last);
    await tester.pumpAndSettle();
    await shot(tester, 'b05_login');
  });

  for (final (lang, gender, theme) in [('ar', 'm', 'light'), ('en', 'm', 'light'), ('ar', 'f', 'dark')]) {
    testWidgets('screens $lang $gender $theme', (tester) async {
      phone(tester);
      final p = 'c_${lang}_$theme${gender == 'f' ? '_f' : ''}';
      late AppState app;
      await tester.runAsync(() async => app = await seeded(lang, gender: gender, theme: theme));
      await tester.pumpWidget(appOf(app));
      await settle(tester);
      await shot(tester, '${p}_1_home');

      final labels = lang == 'ar' ? ['السجل', 'الشهر', 'حسابي'] : ['History', 'Month', 'Profile'];
      final names = ['2_transactions', '3_month', '4_profile'];
      for (var i = 0; i < labels.length; i++) {
        await tester.tap(find.text(labels[i]).last);
        await settle(tester);
        await shot(tester, '${p}_${names[i]}');
      }
      if (theme == 'dark') return;

      // Profile scrolled to the settings.
      await tester.drag(find.byType(ListView).last, const Offset(0, -900));
      await tester.pumpAndSettle();
      await shot(tester, '${p}_5_profile_settings');

      // Bank guide.
      await tester.drag(find.byType(ListView).last, const Offset(0, 900));
      await tester.pumpAndSettle();
      await tester.tap(find.text(lang == 'ar' ? 'شغّل القراية التلقائية' : 'Set up automatic reading'));
      await tester.pumpAndSettle();
      await shot(tester, '${p}_6_bank_guide');
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pumpAndSettle();

      // Home: assistant.
      await tester.tap(find.text(lang == 'ar' ? 'النهارده' : 'Today').last);
      await settle(tester);
      await tester.tap(find.byIcon(CupertinoIcons.chat_bubble_2).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ActionChip).at(1));
      await tester.pumpAndSettle();
      await shot(tester, '${p}_7_assistant');
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pumpAndSettle();

      // Bank message sheet.
      await app.receiveBankText(lang == 'ar'
          ? 'تم خصم مبلغ 1,250.00 جنيه من بطاقتك المنتهية ب 4321 لدى كارفور المعادي. الرصيد المتاح 3,130.00 جنيه'
          : 'Your card ending with 4321 was used for EGP 1,250.00 at CARREFOUR MAADI. Available balance EGP 3,130.00');
      await tester.pumpAndSettle();
      await shot(tester, '${p}_8_bank_sheet');
      await tester.tap(find.text(lang == 'ar' ? 'تجاهل' : 'Ignore'));
      await tester.pumpAndSettle();

      // Add expense (centre button).
      await tester.tap(find.bySemanticsLabel(lang == 'ar' ? 'سجل مصروف' : 'Add expense').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '200');
      await tester.pumpAndSettle();
      await shot(tester, '${p}_9_add_expense');
    });
  }
}
