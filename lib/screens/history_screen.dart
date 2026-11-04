import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/txn.dart';
import '../services/budget_engine.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Every entry grouped by day, with this week / this month at the top.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final now = DateTime.now();
    final week = app.spentBetween(DateTime(now.year, now.month, now.day - 6), now);
    final month = app.spentBetween(DateTime(now.year, now.month, 1), now);
    final avg = app.averageDaily(30);

    // Group by day (txns are sorted newest first).
    final groups = <String, List<Txn>>{};
    for (final t in app.txns) {
      groups.putIfAbsent(dayKey(t.date), () => []).add(t);
    }
    final keys = groups.keys.toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageTitle(s.t('history')),
                  const SizedBox(height: 12),
                  FigureStrip(figures: [
                    Figure(label: s.t('thisWeek'), value: s.money(week)),
                    Figure(label: s.t('thisMonth'), value: s.money(month)),
                    Figure(
                      label: s.t('dailyAvg'),
                      value: avg == null ? '—' : s.money(avg.roundToDouble()),
                      color: avg == null ? tk.ink3 : null,
                    ),
                  ]),
                ],
              ),
            ),
          ),
          if (keys.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(child: EmptyBlock(text: '${s.t('noTxns')}. ${s.t('noTxnsHint')}')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverList.builder(
                itemCount: keys.length,
                itemBuilder: (context, i) => _DayGroup(day: parseDayKey(keys[i]), txns: groups[keys[i]]!),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({required this.day, required this.txns});
  final DateTime day;
  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final b = app.budgetFor(day);
    final now = DateTime.now();
    final label = sameDay(day, now)
        ? s.t('today')
        : sameDay(day, DateTime(now.year, now.month, now.day - 1))
            ? s.t('yesterday')
            : s.date(day);
    final hasExpenses = txns.any((t) => t.type == TxnType.expense);
    final dayColor = b.status == BudgetStatus.over ? tk.danger : tk.ink3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Row(
            children: [
              Expanded(child: Text(label, style: AppType.bodyStrong.copyWith(color: tk.ink))),
              if (b.isOuting) ...[
                Icon(CupertinoIcons.star, size: 14, color: tk.ink3),
                const SizedBox(width: 6),
              ],
              if (hasExpenses)
                Text(
                  '${s.num0(b.spent)} / ${s.num0(b.allowance)}',
                  style: AppType.label.copyWith(
                    color: dayColor,
                    fontWeight: b.status == BudgetStatus.over ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
        Group(children: [for (final t in txns) _TxnTile(t)]),
      ],
    );
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile(this.t);
  final Txn t;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final s = app.s;
    final tk = context.tk;
    final cat = app.categoryById(t.category);
    final (IconData icon, String title, String subtitle) = switch (t.type) {
      TxnType.expense => (
          cat.icon,
          t.note.isEmpty ? cat.label(app.isAr) : t.note,
          t.note.isEmpty ? s.time(t.date) : '${cat.label(app.isAr)} · ${s.time(t.date)}',
        ),
      TxnType.installment => (CupertinoIcons.calendar, app.installmentName(t), s.t('type_installment')),
      TxnType.deposit => (CupertinoIcons.plus_circle, t.note.isEmpty ? s.t('type_deposit') : t.note, s.t('type_deposit')),
      TxnType.salary => (CupertinoIcons.money_pound_circle, s.t('type_salary'), s.time(t.date)),
    };
    final income = t.isIncome;

    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: tk.danger,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(CupertinoIcons.trash, color: tk.bg),
      ),
      confirmDismiss: (_) => confirm(context, s, s.t('deleteTxn'), ok: s.t('delete'), danger: true),
      onDismissed: (_) => app.deleteTxn(t),
      child: Line(
        icon: icon,
        iconColor: income ? tk.accent : tk.ink2,
        title: title,
        subtitle: subtitle,
        trailing: Text(
          '${income ? '+' : '-'}${s.money(t.amount)}',
          style: AppType.bodyStrong.copyWith(color: income ? tk.accent : tk.ink),
        ),
        onLongPress: () async {
          if (await confirm(context, s, s.t('deleteTxn'), ok: s.t('delete'), danger: true)) {
            await app.deleteTxn(t);
          }
        },
      ),
    );
  }
}
