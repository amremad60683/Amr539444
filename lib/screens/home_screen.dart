import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/assistant.dart';
import '../services/budget_engine.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/bank_sheet.dart';
import '../widgets/common.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/outing_sheet.dart';
import '../widgets/today_meter.dart';
import '../widgets/txn_row.dart';
import 'assistant_screen.dart';

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
    final recent = app.txns.take(4).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        color: tk.accent,
        backgroundColor: tk.surface,
        onRefresh: app.refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _QuickActions(),
                  SectionHeader(s.t('upcomingPayments'), action: s.t('viewAll'), onAction: () => onNavigate(2)),
                  const _Upcoming(),
                  SectionHeader(s.t('week')),
                  Panel(child: WeekBars(days: app.lastDays(7), limit: app.settings.maxDaily, s: s)),
                  SectionHeader(s.t('recent'), action: recent.isEmpty ? null : s.t('viewAll'), onAction: () => onNavigate(1)),
                  if (recent.isEmpty)
                    EmptyBlock(text: s.t('noTxnsHint'), icon: CupertinoIcons.pencil)
                  else
                    Group(indent: 72, children: [for (final t in recent) TxnRow(t)]),
                  SectionHeader(
                    s.t('insights'),
                    action: s.t('assistant'),
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AssistantScreen()),
                    ),
                  ),
                  Group(indent: 68, children: [
                    for (final i in insights.take(3))
                      Line(icon: i.icon, iconColor: _levelColor(tk, i.level), title: i.text),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _levelColor(Tokens tk, InsightLevel l) => switch (l) {
      InsightLevel.danger => tk.danger,
      InsightLevel.warning => tk.warn,
      InsightLevel.good => tk.good,
      InsightLevel.info => tk.dark ? tk.ink2 : tk.primaryEnd,
    };

/// Navy header: greeting, today's answer, the meter and the three figures.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final t = app.today;
    final top = MediaQuery.of(context).padding.top;
    final hour = DateTime.now().hour;
    final heroStatus = Tokens.onHero(t.status);
    final statusText = switch (t.status) {
      BudgetStatus.safe => s.t('statusSafe'),
      BudgetStatus.warning => s.t('statusWarning'),
      BudgetStatus.over => s.t('statusOver'),
    };
    final lasts = app.balanceDays();
    final sync = app.settings.lastBankSync;
    final boneOnHero = Colors.white.withValues(alpha: 0.14);

    Widget circleButton(IconData icon, String label, VoidCallback onTap) => Semantics(
          button: true,
          label: label,
          child: Material(
            color: Colors.white.withValues(alpha: 0.12),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 44, height: 44, child: Icon(icon, color: Colors.white, size: 20)),
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        gradient: tk.hero,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: app.settings.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hour < 12 ? s.t('goodMorning') : s.t('goodEvening'),
                        style: AppType.label.copyWith(color: tk.onPrimary2)),
                    Text(app.settings.name, style: AppType.title.copyWith(color: Colors.white)),
                  ],
                ),
              ),
              circleButton(CupertinoIcons.chat_bubble_2, s.t('assistant'), () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AssistantScreen()));
              }),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text(s.t('leftToday'), style: AppType.body.copyWith(color: tk.onPrimary2))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: heroStatus, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(statusText, style: AppType.meta.copyWith(color: heroStatus, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(
            height: 56,
            child: Reveal(
              bone: Bone(width: 160, height: 42, radius: 10, color: boneOnHero),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                    text: s.num0(t.remaining),
                    style: AppType.lead.copyWith(color: t.status == BudgetStatus.over ? heroStatus : Colors.white),
                  ),
                  TextSpan(text: '  ${s.currency}', style: AppType.body.copyWith(color: tk.onPrimary2)),
                ])),
              ),
            ),
          ),
          SizedBox(
            height: 20,
            child: Reveal(
              bone: Bone(width: 130, height: 12, color: boneOnHero),
              child: Text(
                s.t('spentOf', {'spent': s.money(t.spent), 'allow': s.money(t.allowance)}),
                style: AppType.label.copyWith(color: tk.onPrimary2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TodayMeter(day: t, s: s, onHero: true),
          if (t.isOuting) ...[
            const SizedBox(height: 8),
            Note(icon: CupertinoIcons.star, text: s.t('outingToday', {'x': s.money(t.allowance)}), color: Colors.white),
          ],
          if (t.deducted > 0) ...[
            const SizedBox(height: 8),
            Note(
              icon: CupertinoIcons.arrow_counterclockwise,
              text: s.t('deductedToday', {'x': s.money(t.deducted)}),
              color: Tokens.heroWarn,
            ),
          ],
          if (t.debtOut > 0) ...[
            const SizedBox(height: 8),
            Note(
              icon: CupertinoIcons.exclamationmark_triangle,
              text: s.t('carryTomorrow', {'x': s.money(t.debtOut)}),
              color: Tokens.heroDanger,
            ),
          ],
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                for (final (i, f) in [
                  (s.t('balance'), s.money(app.settings.balance)),
                  (s.t('monthSpent'), s.money(app.monthPlan.spent)),
                  (s.t('lasts'), lasts == null ? '—' : s.t('daysN', {'d': lasts})),
                ].indexed)
                  Expanded(
                    child: Container(
                      height: 72,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: i == 0
                          ? null
                          : BoxDecoration(
                              border: BorderDirectional(start: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
                            ),
                      child: Figure(
                        label: f.$1,
                        value: f.$2,
                        labelColor: tk.onPrimary2,
                        color: Colors.white,
                        boneColor: boneOnHero,
                        boneWidth: 64,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (sync != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(CupertinoIcons.checkmark_seal, size: 14, color: tk.onPrimary2),
                const SizedBox(width: 6),
                Text(
                  s.t('syncedAgo', {
                    't': sameDay(sync, DateTime.now()) ? s.time(sync) : s.shortDate(sync),
                  }),
                  style: AppType.meta.copyWith(color: tk.onPrimary2),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Four shortcuts in white tiles.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final s = app.s;
    final tk = context.tk;

    Widget tile(IconData icon, Color color, String label, VoidCallback onTap) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Panel(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              onTap: onTap,
              child: Column(
                children: [
                  IconTile(icon: icon, color: color, size: 46),
                  const SizedBox(height: 8),
                  Text(label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.meta.copyWith(color: tk.ink, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        );

    return Row(
      children: [
        tile(CupertinoIcons.minus_circle, tk.accent, s.t('qExpense'), () => showAddExpense(context)),
        tile(CupertinoIcons.chat_bubble_text, const Color(0xFF3B82F6), s.t('quickBank'), () => showBankPaste(context)),
        tile(CupertinoIcons.star, const Color(0xFFEC4899), s.t('outingDay'), () => showOutingSheet(context)),
        tile(CupertinoIcons.plus_circle, tk.good, s.t('qMoney'), () async {
          final v = await askAmount(context, s, title: s.t('addMoney'));
          if (v != null) await app.addMoney(v, '');
        }),
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
          leading: IconTile(icon: CupertinoIcons.calendar, color: tk.accent),
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
          leading: IconTile(icon: CupertinoIcons.money_pound_circle, color: tk.good),
          title: s.t('payday'),
          subtitle: when(pay),
          trailing: Text('+${s.money(app.settings.salary)}', style: AppType.bodyStrong.copyWith(color: tk.good)),
        ),
      ));
    }
    final outings = app.upcomingOutings;
    if (outings.isNotEmpty) {
      final o = outings.first;
      rows.add((
        o.key,
        Line(
          leading: const IconTile(icon: CupertinoIcons.star, color: Color(0xFFEC4899)),
          title: s.t('outingDay'),
          subtitle: when(o.key),
          trailing: Text(s.money(o.value), style: AppType.bodyStrong.copyWith(color: tk.ink)),
          onTap: () => showOutingSheet(context, initialDate: o.key),
        ),
      ));
    }
    rows.sort((a, b) => a.$1.compareTo(b.$1));

    if (rows.isEmpty) return EmptyBlock(text: s.t('nothingUpcoming'));
    return Group(indent: 72, children: [for (final r in rows) r.$2]);
  }
}
