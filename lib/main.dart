import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppState(StorageService(), NotificationService());
  runApp(ChangeNotifierProvider.value(value: app, child: const MasrofyApp()));
}

/// Loads everything the app needs. Runs while the splash is on screen.
Future<void> bootstrap(AppState app) async {
  await initializeDateFormatting();
  await app.storage.init();
  await app.notifications.init();
  await app.load();
}

class MasrofyApp extends StatelessWidget {
  const MasrofyApp({super.key, this.boot = bootstrap, this.minSplash = const Duration(milliseconds: 1100)});

  final Future<void> Function(AppState) boot;
  final Duration minSplash;

  @override
  Widget build(BuildContext context) {
    final lang = context.select<AppState, String>((a) => a.settings.lang);
    final mode = context.select<AppState, String>((a) => a.settings.themeMode);
    return MaterialApp(
      title: lang == 'ar' ? 'مصروفي' : 'Masrofy',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeModeFrom(mode),
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: child!,
        );
      },
      home: Root(boot: boot, minSplash: minSplash),
    );
  }
}

/// Splash while loading, then onboarding, lock or the app.
class Root extends StatefulWidget {
  const Root({super.key, required this.boot, required this.minSplash});
  final Future<void> Function(AppState) boot;
  final Duration minSplash;

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> with WidgetsBindingObserver {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    final app = context.read<AppState>();
    // The splash stays at least [minSplash] so its mark animation can finish,
    // and as long as loading takes.
    await Future.wait([
      if (!app.ready) widget.boot(app),
      Future<void>.delayed(widget.minSplash),
    ]);
    if (mounted) setState(() => _splashDone = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final app = context.read<AppState>();
    if (!app.ready) return;
    if (state == AppLifecycleState.resumed) {
      app.refresh();
    } else if (state == AppLifecycleState.paused && app.settings.pinHash != null) {
      app.unlocked = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final Widget page;
    if (!_splashDone || !app.ready) {
      page = const SplashScreen(key: ValueKey('splash'));
    } else if (!app.settings.onboarded) {
      page = const OnboardingScreen(key: ValueKey('onboarding'));
    } else if (!app.unlocked) {
      page = const LockScreen(key: ValueKey('lock'));
    } else {
      page = const HomeShell(key: ValueKey('home'));
    }
    return AnimatedSwitcher(
      duration: Duration(milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 420),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: page,
    );
  }
}
