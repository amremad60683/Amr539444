import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/assistant.dart';
import '../services/budget_engine.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/outing_sheet.dart';
import '../widgets/today_meter.dart';

/// Answers one question first: how much can I still spend today?
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final insights = Assistant(app).insights();
    final now = DateTime.now();
    final plan = app.monthPlan;
    final lasts = app.balanceDays();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: tk.ink,
        backgroundColor: tk.surface,
        onRefresh: app.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _Header(name: app.settings.name, date: s.date(now)),
            const SizedBox(height: 24),
            const _TodayBlock(),
            const SizedBox(height: 24),
            FigureStrip(figures: [
              Figure(
                label: s.t('balance'),
                value: s.money(app.settings.balance),
                boneWidth: 84,
              ),
              Figure(label: s.t('monthSpent'), value: s.money(plan.spent)),
              Figure(
                label: s.t('lasts'),
                value: lasts == null ? '—' : s.t('daysN', {'d': lasts}),
                color: lasts == null ? tk.ink3 : null,
                boneWidth: 56,
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(
              children: [
                _SmallAction(
                  icon: CupertinoIcons.pencil,
                  label: s.t('editBalance'),
                  onTap: () async {
                    final v = await askAmount(context, s,
                        title: s.t('setBalance'),
                        helper: s.t('setBalanceHelp'),
                        initial: app.settings.balance,
                        allowZero: true);
                    if (v != null) await app.setBalance(v);
                  },
                ),
                _SmallAction(
                  icon: CupertinoIcons.plus,
                  label: s.t('addMoney'),
                  onTap: () async {
                    final v = await askAmount(context, s, title: s.t('addMoney'));
                    if (v != null) await app.addMoney(v, '');
                  },
                ),
              ],
            ),
            SectionHeader(s.t('week')),
            Panel(child: WeekBars(days: app.lastDays(7), limit: app.settings.maxDaily, s: s)),
            SectionHeader(s.t('upcoming')),
            const _Upcoming(),
            SectionHeader(s.t('insights'), action: s.t('assistant'), onAction: () => onNavigate(3)),
            Group(children: [
              for (final i in insights.take(3))
                Line(
                  icon: i.icon,
                  iconColor: _levelColor(tk, i.level),
                  title: i.text,
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

Color _levelColor(Tokens tk, InsightLevel l) => switch (l) {
      InsightLevel.danger => tk.danger,
      InsightLevel.warning => tk.warn,
      InsightLevel.good => tk.accent,
      InsightLevel.info => tk.ink2,
    };

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.date});
  final String name;
  final String date;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final tk = context.tk;
    return Row(
      children: [
        BrandMark(size: 36, isAr: app.isAr),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(app.s.t('hello', {'name': name}), style: AppType.title.copyWith(color: tk.ink)),
              Text(date, style: AppType.label.copyWith(color: tk.ink3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: tk.ink2, padding: const EdgeInsets.symmetric(horizontal: 10)),
      icon: Icon(icon, size: 16),
      label: Text(label, style: AppType.label.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

/// The answer: what is left today, the meter, and why.
class _TodayBlock extends StatelessWidget {
  const _TodayBlock();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final t = app.today;
    final statusColor = tk.forStatus(t.status);
    final statusText = switch (t.status) {
      BudgetStatus.safe => s.t('statusSafe'),
      BudgetStatus.warning => s.t('statusWarning'),
      BudgetStatus.over => s.t('statusOver'),
    };
    final leadColor = t.status == BudgetStatus.safe ? tk.ink : statusColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (t.isOuting) ...[
          Note(
            icon: CupertinoIcons.star,
            text: s.t('outingToday', {'x': s.money(t.allowance)}),
            color: tk.ink2,
          ),
          const SizedBox(height: 10),
        ],
        Text(s.t('leftToday'), style: AppType.body.copyWith(color: tk.ink2)),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: Reveal(
                bone: const Bone(width: 150, height: 40, radius: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: s.num0(t.remaining), style: AppType.lead.copyWith(color: leadColor)),
                      TextSpan(text: '  ${s.currency}', style: AppType.body.copyWith(color: tk.ink3)),
                    ]),
                  ),
                ),
              ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: tk.tintFor(t.status), borderRadius: BorderRadius.circular(99)),
              child: Text(statusText, style: AppType.meta.copyWith(color: statusColor, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        SizedBox(
          height: 20,
          child: Reveal(
            bone: const Bone(width: 120, height: 12),
            child: Text(
              s.t('spentOf', {'spent': s.money(t.spent), 'allow': s.money(t.allowance)}),
              style: AppType.label.copyWith(color: tk.ink3),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TodayMeter(day: t, s: s),
        if (t.deducted > 0) ...[
          const SizedBox(height: 10),
          Note(
            icon: CupertinoIcons.arrow_counterclockwise,
            text: s.t('deductedToday', {'x': s.money(t.deducted)}),
            color: tk.warn,
          ),
        ],
        if (t.debtOut > 0) ...[
          const SizedBox(height: 8),
          Note(
            icon: CupertinoIcons.exclamationmark_triangle,
            text: s.t('carryTomorrow', {'x': s.money(t.debtOut)}),
            color: tk.danger,
          ),
        ],
      ],
    );
  }
}

/// Installment, payday and outing, soonest first.
class _Upcoming extends StatelessWidget {
  const _Upcoming();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final today = dateOnly(DateTime.now());

    String when(DateTime d) {
      final n = dateOnly(d).difference(today).inDays;
      if (n == 0) return s.t('todayWord');
      if (n == 1) return s.t('tomorrowWord');
      return '${s.shortDate(d)} · ${s.t('inDays', {'d': n})}';
    }

    final rows = <(DateTime, Widget)>[];
    final inst = app.nextInstallment;
    if (inst != null) {
      rows.add((
        inst.nextDue,
        Line(
          icon: CupertinoIcons.calendar,
          title: inst.name,
          subtitle: when(inst.nextDue),
          trailing: Text('-${s.money(inst.amount)}', style: AppType.bodyStrong.copyWith(color: tk.ink)),
        ),
      ));
    }
    final pay = app.settings.nextSalary;
    if (app.settings.hasSalary && pay != null) {
      rows.add((
        pay,
        Line(
          icon: CupertinoIcons.money_pound_circle,
          title: s.t('payday'),
          subtitle: when(pay),
          trailing: Text('+${s.money(app.settings.salary)}', style: AppType.bodyStrong.copyWith(color: tk.accent)),
        ),
      ));
    }
    final outings = app.upcomingOutings;
    if (outings.isNotEmpty) {
      final o = outings.first;
      rows.add((
        o.key,
        Line(
          icon: CupertinoIcons.star,
          title: s.t('outingDay'),
          subtitle: when(o.key),
          trailing: Text(s.money(o.value), style: AppType.bodyStrong.copyWith(color: tk.ink)),
          onTap: () => showOutingSheet(context, initialDate: o.key),
        ),
      ));
    }
    rows.sort((a, b) => a.$1.compareTo(b.$1));

    return Group(children: [
      if (rows.isEmpty) Line(title: s.t('nothingUpcoming'), titleColor: tk.ink3),
      ...rows.map((r) => r.$2),
      if (outings.isEmpty)
        Line(
          icon: CupertinoIcons.plus,
          title: s.t('planOuting'),
          titleColor: tk.ink2,
          onTap: () => showOutingSheet(context),
        ),
    ]);
  }
}
