import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/assistant.dart';
import '../services/budget_engine.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/budget_ring.dart';
import '../widgets/common.dart';
import '../widgets/outing_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final insights = Assistant(app).insights();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: app.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            _Header(name: app.settings.name, date: s.date(DateTime.now())),
            const SizedBox(height: 16),
            const _BalanceCard(),
            const SizedBox(height: 12),
            const _TodayCard(),
            SectionTitle(
              s.t('insights'),
              trailing: TextButton(onPressed: () => onNavigate(3), child: Text(s.t('assistant'))),
            ),
            for (final i in insights.take(3)) ...[
              _InsightTile(i),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: _OutingCard()),
                const SizedBox(width: 12),
                Expanded(child: _NextInstallmentCard(onTap: () => onNavigate(2))),
              ],
            ),
            SectionTitle(s.t('last7days')),
            const _WeekChart(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.date});
  final String name;
  final String date;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>().s;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('hello', {'name': name}),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          Text(date, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final days = app.balanceDays();
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.seed.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(s.t('balance'), style: text.titleSmall?.copyWith(color: Colors.white70)),
              const Spacer(),
              IconButton(
                tooltip: s.t('editBalance'),
                style: IconButton.styleFrom(backgroundColor: Colors.white24),
                color: Colors.white,
                icon: const Icon(Icons.edit_rounded, size: 18),
                onPressed: () async {
                  final v = await askAmount(context, s,
                      title: s.t('setBalance'), initial: app.settings.balance, allowZero: true);
                  if (v != null) await app.setBalance(v);
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: s.t('addMoney'),
                style: IconButton.styleFrom(backgroundColor: Colors.white24),
                color: Colors.white,
                icon: const Icon(Icons.add_rounded, size: 18),
                onPressed: () async {
                  final v = await askAmount(context, s, title: s.t('addMoney'));
                  if (v != null) await app.addMoney(v, '');
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              s.money(app.settings.balance),
              style: text.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          if (days != null) ...[
            const SizedBox(height: 6),
            Text(s.t('balanceLasts', {'d': days}), style: text.bodyMedium?.copyWith(color: Colors.white)),
          ],
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final t = app.today;
    final color = AppColors.forStatus(t.status);
    final text = Theme.of(context).textTheme;
    final statusText = switch (t.status) {
      BudgetStatus.safe => s.t('statusSafe'),
      BudgetStatus.warning => s.t('statusWarning'),
      BudgetStatus.over => s.t('statusOver'),
    };

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          if (t.isOuting) ...[
            Pill(s.t('outingToday'), color: Theme.of(context).colorScheme.tertiary, icon: Icons.celebration_rounded),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              BudgetRing(
                progress: t.progress,
                targetFraction: t.allowance == 0 ? 0 : t.target / t.allowance,
                color: color,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.t('todayLeft'), style: text.labelSmall),
                    FittedBox(
                      child: Text(
                        s.num0(t.remaining),
                        style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: color),
                      ),
                    ),
                    Text(s.currency, style: text.labelSmall),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Pill(statusText, color: color),
                    const SizedBox(height: 12),
                    _kv(context, s.t('spentToday'), s.money(t.spent)),
                    _kv(context, s.t('todayAllowance'), s.money(t.allowance)),
                    _kv(context, s.t('target'), s.money(t.target)),
                  ],
                ),
              ),
            ],
          ),
          if (t.deducted > 0) ...[
            const SizedBox(height: 12),
            _note(context, Icons.trending_down_rounded, AppColors.warning,
                s.t('deductedToday', {'x': s.money(t.deducted)})),
          ],
          if (t.debtOut > 0) ...[
            const SizedBox(height: 8),
            _note(context, Icons.warning_amber_rounded, AppColors.danger,
                s.t('carryTomorrow', {'x': s.money(t.debtOut)})),
          ],
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _note(BuildContext context, IconData icon, Color color, String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _InsightTile extends StatelessWidget {
  const _InsightTile(this.insight);
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final color = insightColor(context, insight.level);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(insight.icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(insight.text)),
        ],
      ),
    );
  }
}

Color insightColor(BuildContext context, InsightLevel l) => switch (l) {
      InsightLevel.good => AppColors.safe,
      InsightLevel.warning => AppColors.warning,
      InsightLevel.danger => AppColors.danger,
      InsightLevel.info => Theme.of(context).colorScheme.primary,
    };

class _OutingCard extends StatelessWidget {
  const _OutingCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final upcoming = app.upcomingOutings;
    final next = upcoming.isEmpty ? null : upcoming.first;
    final tertiary = Theme.of(context).colorScheme.tertiary;
    return AppCard(
      onTap: () => showOutingSheet(context, initialDate: next?.key),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.celebration_rounded, color: tertiary),
          const SizedBox(height: 8),
          Text(s.t('outingDay'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (next == null)
            Text(s.t('planOuting'), style: TextStyle(color: tertiary, fontWeight: FontWeight.w600))
          else ...[
            Text(sameDay(next.key, DateTime.now()) ? s.t('today') : s.shortDate(next.key),
                style: Theme.of(context).textTheme.bodySmall),
            Text(s.money(next.value), style: TextStyle(color: tertiary, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}

class _NextInstallmentCard extends StatelessWidget {
  const _NextInstallmentCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final next = app.nextInstallment;
    final primary = Theme.of(context).colorScheme.primary;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_repeat_rounded, color: primary),
          const SizedBox(height: 8),
          Text(s.t('nextInstallment'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (next == null)
            Text(s.t('noInstallments'), style: Theme.of(context).textTheme.bodySmall)
          else ...[
            Text('${next.name} • ${s.shortDate(next.nextDue)}',
                style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(s.money(next.amount), style: TextStyle(color: primary, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}

/// Bar chart of the last 7 days with the daily max line.
class _WeekChart extends StatelessWidget {
  const _WeekChart();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final days = app.lastDays(7);
    final maxVal = [
      app.settings.maxDaily,
      ...days.map((d) => d.spent),
      ...days.map((d) => d.allowance),
    ].reduce((a, b) => a > b ? a : b);
    const h = 120.0;
    final limitY = app.settings.maxDaily / maxVal * h;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        children: [
          SizedBox(
            height: h + 20,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: limitY + 20,
                  child: Container(height: 1.5, color: AppColors.danger.withValues(alpha: 0.5)),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final d in days)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Tooltip(
                              message: s.money(d.spent),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                height: (d.spent / maxVal * h).clamp(3, h),
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: d.spent == 0 ? scheme.surfaceContainerHighest : AppColors.forStatus(d.status),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 16,
                              child: Text(
                                s.weekday(d.day),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontWeight: sameDay(d.day, DateTime.now()) ? FontWeight.w800 : null,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 14, height: 2, color: AppColors.danger),
              const SizedBox(width: 6),
              Text('${s.t('dailyMax')}: ${s.money(app.settings.maxDaily)}',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}
