import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/bank_sheet.dart';
import '../widgets/common.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'month_screen.dart';
import 'profile_screen.dart';

/// Four tabs around a centre "add" button. Owns the first-load reveal and
/// shows bank messages that arrive from the iPhone Shortcut.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _revealed = ValueNotifier(false);
  bool _bankSheetOpen = false;

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

  void _handleBank(AppState app) {
    if (app.pendingBank != null && !_bankSheetOpen) {
      _bankSheetOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showBankSheet(context, message: app.pendingBank);
        _bankSheetOpen = false;
        app.dismissBank();
      });
    }
    final auto = app.lastAutoBank;
    if (auto != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final s = app.s;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(auto.hasTransaction
              ? s.t('bankAdded', {'x': s.money(auto.amount!)})
              : s.t('bankBalanceOnly')),
        ));
        app.lastAutoBank = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    _handleBank(app);
    final pages = [
      HomeScreen(onNavigate: go),
      const HistoryScreen(),
      const MonthScreen(),
      const ProfileScreen(),
    ];
    return RevealScope(
      revealed: _revealed,
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: _NavBar(index: _index, onTap: go, onAdd: () => showAddExpense(context)),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap, required this.onAdd});
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final bottom = MediaQuery.of(context).padding.bottom;

    Widget item(int i, IconData icon, IconData active, String label) {
      final on = index == i;
      final c = on ? (tk.dark ? tk.ink : tk.primary) : tk.ink3;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          label: label,
          child: InkResponse(
            onTap: () => onTap(i),
            radius: 32,
            child: SizedBox(
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(on ? active : icon, color: c, size: 24),
                  const SizedBox(height: 3),
                  Text(label,
                      style: AppType.meta.copyWith(color: c, fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom - 8 : 6, top: 6),
      decoration: BoxDecoration(
        color: tk.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(R.hero)),
        boxShadow: [BoxShadow(color: tk.dark ? Colors.black54 : tk.shadow, blurRadius: 24, offset: const Offset(0, -6))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          item(0, CupertinoIcons.house, CupertinoIcons.house_fill, s.t('home')),
          item(1, CupertinoIcons.list_bullet, CupertinoIcons.list_bullet, s.t('history')),
          SizedBox(
            width: 76,
            height: 64,
            child: Center(
              child: Semantics(
                button: true,
                label: s.t('addExpense'),
                child: Material(
                  color: tk.accent,
                  shape: const CircleBorder(),
                  elevation: 0,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onAdd,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: tk.accent.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Icon(CupertinoIcons.plus, color: tk.onAccent, size: 28),
                    ),
                  ),
                ),
              ),
            ),
          ),
          item(2, CupertinoIcons.chart_bar, CupertinoIcons.chart_bar_fill, s.t('month')),
          item(3, CupertinoIcons.person, CupertinoIcons.person_fill, s.t('profile')),
        ],
      ),
    );
  }
}
