import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/common.dart';
import 'assistant_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'month_screen.dart';
import 'profile_screen.dart';

/// Bottom tab bar with the five sections. Owns the first-load reveal: the
/// layout shows at once with bones in place of values, then values land.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _revealed = ValueNotifier(false);

  void go(int i) => setState(() => _index = i);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (reduceMotion(context)) {
        _revealed.value = true;
      } else {
        Future.delayed(const Duration(milliseconds: 550), () {
          if (mounted) _revealed.value = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _revealed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    final pages = [
      HomeScreen(onNavigate: go),
      const HistoryScreen(),
      const MonthScreen(),
      const AssistantScreen(),
      const ProfileScreen(),
    ];
    return RevealScope(
      revealed: _revealed,
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        floatingActionButton: _index <= 1
            ? FloatingActionButton.extended(
                onPressed: () => showAddExpense(context),
                icon: const Icon(CupertinoIcons.plus, size: 20),
                label: Text(s.t('addExpense')),
              )
            : null,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: go,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                  icon: const Icon(CupertinoIcons.house),
                  selectedIcon: const Icon(CupertinoIcons.house_fill),
                  label: s.t('home')),
              NavigationDestination(
                  icon: const Icon(CupertinoIcons.list_bullet), label: s.t('history')),
              NavigationDestination(
                  icon: const Icon(CupertinoIcons.calendar),
                  selectedIcon: const Icon(CupertinoIcons.calendar_today),
                  label: s.t('month')),
              NavigationDestination(
                  icon: const Icon(CupertinoIcons.bubble_left),
                  selectedIcon: const Icon(CupertinoIcons.bubble_left_fill),
                  label: s.t('assistant')),
              NavigationDestination(
                  icon: const Icon(CupertinoIcons.person),
                  selectedIcon: const Icon(CupertinoIcons.person_fill),
                  label: s.t('profile')),
            ],
          ),
        ),
      ),
    );
  }
}
