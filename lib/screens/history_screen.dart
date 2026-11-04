import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/txn.dart';
import '../services/budget_engine.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/txn_row.dart';

/// Every entry grouped by day, filterable, with week / month at the top.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _filter = 0;

  bool _keep(Txn t) => switch (_filter) {
        1 => t.type == TxnType.expense,
        2 => t.isIncome,
        3 => t.type == TxnType.installment,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final now = DateTime.now();
    final week = app.spentBetween(DateTime(now.year, now.month, now.day - 6), now);
    final month = app.spentBetween(DateTime(now.year, now.month, 1), now);
    final avg = app.averageDaily(30);

    final groups = <String, List<Txn>>{};
    for (final t in app.txns.where(_keep)) {
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
                  PageTitle(s.t('transactions')),
                  const SizedBox(height: 10),
                  FigureStrip(figures: [
                    Figure(label: s.t('thisWeek'), value: s.money(week)),
                    Figure(label: s.t('thisMonth'), value: s.money(month)),
                    Figure(
                      label: s.t('dailyAvg'),
                      value: avg == null ? '—' : s.money(avg.roundToDouble()),
                      color: avg == null ? tk.ink3 : null,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  PillTabs(
                    labels: [s.t('all'), s.t('expenses'), s.t('income'), s.t('installments')],
                    index: _filter,
                    onChanged: (i) => setState(() => _filter = i),
                  ),
                ],
              ),
            ),
          ),
          if (keys.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: EmptyBlock(text: '${s.t('noTxns')}. ${s.t('noTxnsHint')}', icon: CupertinoIcons.list_bullet),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
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
    final over = b.status == BudgetStatus.over;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
          child: Row(
            children: [
              Expanded(child: Text(label, style: AppType.bodyStrong.copyWith(color: tk.ink))),
              if (b.isOuting) ...[
                const Icon(CupertinoIcons.star, size: 14, color: Color(0xFFEC4899)),
                const SizedBox(width: 6),
              ],
              if (hasExpenses)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: over ? tk.dangerTint : tk.raised,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${s.num0(b.spent)} / ${s.num0(b.allowance)}',
                    style: AppType.meta.copyWith(color: over ? tk.danger : tk.ink2, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
        ),
        Group(indent: 72, children: [for (final t in txns) TxnRow(t)]),
      ],
    );
  }
}
