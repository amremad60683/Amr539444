import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/txn.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// All recorded entries grouped by day, with weekly/monthly totals.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final now = DateTime.now();
    final week = app.spentBetween(DateTime(now.year, now.month, now.day - 6), now);
    final month = app.spentBetween(DateTime(now.year, now.month, 1), now);
    final avg = app.averageDaily(30) ?? 0;

    // Group by day (txns are sorted newest first).
    final groups = <String, List<Txn>>{};
    for (final t in app.txns) {
      groups.putIfAbsent(dayKey(t.date), () => []).add(t);
    }

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(title: Text(s.t('history')), floating: true),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(child: _Stat(label: s.t('thisWeek'), value: s.money(week))),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(label: s.t('thisMonth'), value: s.money(month))),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(label: s.t('dailyAvg'), value: s.money(avg))),
                ],
              ),
            ),
          ),
          if (groups.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                    const SizedBox(height: 8),
                    Text(s.t('noTxns')),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList.builder(
                itemCount: groups.length,
                itemBuilder: (context, i) {
                  final key = groups.keys.elementAt(i);
                  return _DayGroup(day: parseDayKey(key), txns: groups[key]!);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
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
    final b = app.budgetFor(day);
    final now = DateTime.now();
    final label = sameDay(day, now)
        ? s.t('today')
        : sameDay(day, DateTime(now.year, now.month, now.day - 1))
            ? s.t('yesterday')
            : s.date(day);
    final hasExpenses = txns.any((t) => t.type == TxnType.expense);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
              if (b.isOuting) ...[
                Icon(Icons.celebration_rounded, size: 16, color: Theme.of(context).colorScheme.tertiary),
                const SizedBox(width: 6),
              ],
              if (hasExpenses)
                Pill('${s.num0(b.spent)} / ${s.num0(b.allowance)}', color: AppColors.forStatus(b.status)),
            ],
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final t in txns) _TxnTile(t),
            ],
          ),
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, title) = switch (t.type) {
      TxnType.expense => (t.category.icon, scheme.primary, t.note.isEmpty ? categoryLabel(s, t.category) : t.note),
      TxnType.installment => (Icons.event_repeat_rounded, AppColors.warning, app.installmentName(t)),
      TxnType.deposit => (Icons.savings_rounded, AppColors.safe, t.note.isEmpty ? s.t('type_deposit') : t.note),
    };
    final subtitle = t.type == TxnType.expense
        ? '${categoryLabel(s, t.category)} • ${s.time(t.date)}'
        : s.t('type_${t.type.name}');
    final sign = t.type == TxnType.deposit ? '+' : '-';

    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.error,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_rounded, color: scheme.onError),
      ),
      confirmDismiss: (_) => confirm(context, s, s.t('deleteTxn'), ok: s.t('delete'), danger: true),
      onDismissed: (_) => app.deleteTxn(t),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle),
        trailing: Text(
          '$sign${s.money(t.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: t.type == TxnType.deposit ? AppColors.safe : null,
          ),
        ),
      ),
    );
  }
}
