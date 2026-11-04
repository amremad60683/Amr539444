import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/installment.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The cycle until payday (or month end): what's left at the end, the safe
/// daily spend, salary, where the money went and the installments.
class MonthScreen extends StatelessWidget {
  const MonthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final st = app.settings;
    final p = app.monthPlan;
    final lastDay = DateTime(p.cycleEnd.year, p.cycleEnd.month, p.cycleEnd.day - 1);
    final subtitle = p.salaryBased
        ? s.t('cycleSalary', {'from': s.dayMonth(p.cycleStart), 'to': s.dayMonth(p.cycleEnd)})
        : s.t('cycleMonth', {'from': s.dayMonth(p.cycleStart), 'to': s.dayMonth(lastDay)});
    final cats = app.spentByCategory(p.cycleStart, DateTime.now());
    final catTotal = cats.fold(0.0, (a, e) => a + e.value);
    final avg = p.averageDaily.roundToDouble();
    final pace = avg > 0 ? avg : st.minDaily;
    final end = p.projectedAt(pace);
    final belowSafety = st.safetyBalance > 0 && end < st.safetyBalance;

    Widget scenario(String label, double perDay) {
      final v = p.projectedAt(perDay);
      final risky = v < st.safetyBalance || v < 0;
      return Line(
        title: label,
        trailing: Reveal(
          bone: const Bone(width: 70, height: 16),
          child: Text(s.money(v), style: AppType.bodyStrong.copyWith(color: risky ? tk.danger : tk.ink)),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
        children: [
          PageTitle(s.t('monthTitle'), subtitle: subtitle),
          const SizedBox(height: 10),

          // ---------------------------------------------------- hero: end of cycle
          HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.salaryBased ? s.t('endSalary') : s.t('endMonth'),
                    style: AppType.body.copyWith(color: tk.onPrimary2)),
                SizedBox(
                  height: 54,
                  child: Reveal(
                    bone: Bone(width: 150, height: 40, radius: 10, color: Colors.white.withValues(alpha: 0.14)),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                          text: s.num0(end),
                          style: AppType.lead.copyWith(color: belowSafety ? Tokens.heroDanger : Colors.white, fontSize: 40),
                        ),
                        TextSpan(text: '  ${s.currency}', style: AppType.body.copyWith(color: tk.onPrimary2)),
                      ])),
                    ),
                  ),
                ),
                Text('${s.t('atYourPace')} · ${s.money(pace)}',
                    style: AppType.label.copyWith(color: tk.onPrimary2)),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      for (final (i, f) in [
                        (s.t('spentCycle'), s.money(p.spent)),
                        (s.t('instCycle'), s.money(p.installmentsPaid + p.installmentsDue)),
                        (s.t('daysLeft'), s.t('daysN', {'d': p.daysLeft})),
                      ].indexed)
                        Expanded(
                          child: Container(
                            height: 72,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: i == 0
                                ? null
                                : BoxDecoration(
                                    border: BorderDirectional(
                                        start: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
                                  ),
                            child: Figure(
                              label: f.$1,
                              value: f.$2,
                              labelColor: tk.onPrimary2,
                              color: Colors.white,
                              boneColor: Colors.white.withValues(alpha: 0.14),
                              boneWidth: 60,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---------------------------------------------------- safe per day
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconTile(icon: CupertinoIcons.lock_shield, color: belowSafety ? tk.danger : tk.good),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.t('perDaySafe'), style: AppType.label.copyWith(color: tk.ink3)),
                          Text(s.money(p.safeDaily.floorToDouble()),
                              style: AppType.figure.copyWith(color: belowSafety ? tk.danger : tk.ink)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final v = await askAmount(context, s,
                            title: s.t('safety'), helper: s.t('safetyHelp'), initial: st.safetyBalance, allowZero: true);
                        if (v != null) await app.setSafetyBalance(v);
                      },
                      child: Text(s.t('edit')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  st.safetyBalance > 0 && p.free <= st.safetyBalance
                      ? s.t('safeDailyZero', {'safe': s.money(st.safetyBalance)})
                      : s.t('safeDaily', {'safe': s.money(st.safetyBalance), 'x': s.money(p.safeDaily.floorToDouble())}),
                  style: AppType.label.copyWith(color: tk.ink2),
                ),
                const SizedBox(height: 12),
                // How far the balance is above the safety balance.
                _Bar(
                  value: st.safetyBalance <= 0 ? 1 : (st.safetyBalance / max(1, p.free)).clamp(0, 1).toDouble(),
                  color: belowSafety ? tk.danger : tk.accent,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text('${s.t('safety')} ${st.safetyBalance > 0 ? s.money(st.safetyBalance) : s.t('safetyNone')}',
                          style: AppType.meta.copyWith(color: tk.ink3)),
                    ),
                    Text(s.money(p.free), style: AppType.meta.copyWith(color: tk.ink3)),
                  ],
                ),
              ],
            ),
          ),

          // ---------------------------------------------------- scenarios
          SectionHeader(s.t('fromTomorrow')),
          Group(children: [
            scenario(s.t('atTarget', {'x': s.num0(st.minDaily)}), st.minDaily),
            if (avg > 0) scenario(s.t('atAvg', {'x': s.num0(avg)}), avg),
            scenario(s.t('atMax', {'x': s.num0(st.maxDaily)}), st.maxDaily),
          ]),

          // ---------------------------------------------------- salary
          SectionHeader(s.t('salaryTitle')),
          if (!st.hasSalary)
            EmptyBlock(
              icon: CupertinoIcons.money_pound_circle,
              text: s.t('salaryNone'),
              action: s.t('addSalary'),
              onAction: () => showSalarySheet(context),
            )
          else
            Group(children: [
              Line(
                leading: IconTile(icon: CupertinoIcons.money_pound_circle, color: tk.good),
                title: s.t('salaryLine', {'x': s.money(st.salary), 'd': st.salaryDay}),
                subtitle: st.nextSalary == null ? null : s.t('nextPayday', {'date': s.dayMonth(st.nextSalary!)}),
                chevron: true,
                onTap: () => showSalarySheet(context),
              ),
            ]),

          // ---------------------------------------------------- categories
          SectionHeader(s.t('byCategory')),
          if (cats.isEmpty)
            EmptyBlock(text: s.t('noSpending'))
          else
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                for (final e in cats.take(8))
                  _CategoryRow(
                    icon: e.key.icon,
                    color: e.key.color,
                    label: e.key.label(app.isAr),
                    amount: s.money(e.value),
                    share: catTotal == 0 ? 0 : e.value / catTotal,
                  ),
              ]),
            ),

          // ---------------------------------------------------- installments
          SectionHeader(s.t('installments'), action: s.t('addInstallment'), onAction: () => showInstallmentSheet(context)),
          const _Installments(),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Stack(children: [
          Container(color: tk.raised),
          FractionallySizedBox(
            widthFactor: max(0.02, value),
            alignment: AlignmentDirectional.centerStart,
            child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          ),
        ]),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.amount,
    required this.share,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String amount;
  final double share;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          IconTile(icon: icon, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label, style: AppType.bodyStrong.copyWith(color: tk.ink))),
                    Text(amount, style: AppType.bodyStrong.copyWith(color: tk.ink)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _Bar(value: share, color: color)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 36,
                      child: Text('${(share * 100).round()}%',
                          textAlign: TextAlign.end, style: AppType.meta.copyWith(color: tk.ink3)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Installments extends StatelessWidget {
  const _Installments();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final list = [...app.installments]..sort((a, b) {
        if (a.isFinished != b.isFinished) return a.isFinished ? 1 : -1;
        return a.nextDue.compareTo(b.nextDue);
      });

    if (list.isEmpty) {
      return EmptyBlock(
        icon: CupertinoIcons.calendar,
        text: '${s.t('noInstallments')}. ${s.t('instAutoNote')}',
        action: s.t('addInstallment'),
        onAction: () => showInstallmentSheet(context),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FigureStrip(figures: [
          Figure(label: s.t('totalMonthly'), value: s.money(app.monthlyInstallments)),
          Figure(label: s.t('totalRemaining'), value: s.money(app.remainingInstallments)),
        ]),
        for (final i in list) ...[const SizedBox(height: 10), _InstallmentCard(i)],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(s.t('instAutoNote'), style: AppType.meta.copyWith(color: tk.ink3)),
        ),
      ],
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  const _InstallmentCard(this.i);
  final Installment i;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final s = app.s;
    final tk = context.tk;
    final days = dateOnly(i.nextDue).difference(dateOnly(DateTime.now())).inDays;
    final soon = !i.isFinished && days <= 3;

    return Panel(
      onTap: () => _menu(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: i.isFinished ? CupertinoIcons.checkmark_alt : CupertinoIcons.calendar,
                color: i.isFinished ? tk.good : tk.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.name, style: AppType.bodyStrong.copyWith(color: tk.ink)),
                    Text(
                      i.isFinished ? s.t('finished') : s.t('instDue', {'date': s.shortDate(i.nextDue)}),
                      style: AppType.label.copyWith(
                        color: i.isFinished ? tk.good : (soon ? tk.warn : tk.ink3),
                        fontWeight: soon ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(s.money(i.amount), style: AppType.figure.copyWith(color: tk.ink, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 14),
          _Bar(value: i.total == 0 ? 1 : i.paid / i.total, color: i.isFinished ? tk.good : tk.accent),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(s.t('instLeft', {'n': i.remaining, 't': i.total}),
                    style: AppType.meta.copyWith(color: tk.ink3)),
              ),
              if (!i.isFinished)
                Text(s.t('instRemainingAmount', {'x': s.money(i.remainingAmount)}),
                    style: AppType.meta.copyWith(color: tk.ink3)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _menu(BuildContext context) async {
    final app = context.read<AppState>();
    final s = app.s;
    final tk = context.tk;
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(i.name, style: AppType.title.copyWith(color: tk.ink)),
              ),
              Group(children: [
                if (!i.isFinished)
                  Line(
                    icon: CupertinoIcons.checkmark_circle,
                    iconColor: tk.good,
                    title: s.t('payNow'),
                    onTap: () => Navigator.pop(ctx, 'pay'),
                  ),
                Line(
                  icon: CupertinoIcons.trash,
                  iconColor: tk.danger,
                  title: s.t('delete'),
                  titleColor: tk.danger,
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    if (v == 'pay') {
      await app.payInstallment(i);
    } else if (v == 'delete') {
      if (await confirm(context, s, s.t('deleteInst'), ok: s.t('delete'), danger: true)) {
        await app.deleteInstallment(i);
      }
    }
  }
}

// ------------------------------------------------------------------ sheets

Future<void> showInstallmentSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _InstallmentSheet(),
    );

class _InstallmentSheet extends StatefulWidget {
  const _InstallmentSheet();

  @override
  State<_InstallmentSheet> createState() => _InstallmentSheetState();
}

class _InstallmentSheetState extends State<_InstallmentSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _total = TextEditingController();
  final _remaining = TextEditingController();
  int _dueDay = DateTime.now().day;

  @override
  void dispose() {
    for (final c in [_name, _amount, _total, _remaining]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final s = app.s;
    final tk = context.tk;
    String? intValidator(String? v) {
      final n = int.tryParse(v ?? '');
      return (n == null || n <= 0) ? s.t('required') : null;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.t('addInstallment'), style: AppType.title.copyWith(color: tk.ink)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: s.t('instName'), hintText: s.t('instNamePh')),
                validator: (v) => (v == null || v.trim().isEmpty) ? s.t('required') : null,
              ),
              const SizedBox(height: 12),
              AmountField(controller: _amount, label: s.t('instAmount'), suffix: s.currency, validator: positiveValidator(s)),
              const SizedBox(height: 12),
              DayPicker(label: s.t('instDueDay'), value: _dueDay, onChanged: (d) => setState(() => _dueDay = d)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: AmountField(controller: _total, label: s.t('instTotal'), integer: true, validator: intValidator)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AmountField(controller: _remaining, label: s.t('instRemaining'), integer: true, validator: intValidator),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  await app.addInstallment(
                    name: _name.text.trim(),
                    amount: parseAmount(_amount.text)!,
                    dueDay: _dueDay,
                    total: int.parse(_total.text),
                    remaining: int.parse(_remaining.text),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(s.t('save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showSalarySheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _SalarySheet(),
    );

class _SalarySheet extends StatefulWidget {
  const _SalarySheet();

  @override
  State<_SalarySheet> createState() => _SalarySheetState();
}

class _SalarySheetState extends State<_SalarySheet> {
  final _form = GlobalKey<FormState>();
  late final AppState app = context.read<AppState>();
  late final _amount = TextEditingController(
      text: app.settings.hasSalary ? app.s.num0(app.settings.salary).replaceAll(',', '') : '');
  late int _day = app.settings.salaryDay;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = app.s;
    final tk = context.tk;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(app.settings.hasSalary ? s.t('editSalary') : s.t('addSalary'), style: AppType.title.copyWith(color: tk.ink)),
            const SizedBox(height: 4),
            Text(s.t('salaryHelp'), style: AppType.label.copyWith(color: tk.ink3)),
            const SizedBox(height: 16),
            AmountField(
              controller: _amount,
              label: s.t('salaryAmount'),
              suffix: s.currency,
              autofocus: !app.settings.hasSalary,
              big: true,
              validator: positiveValidator(s),
            ),
            const SizedBox(height: 12),
            DayPicker(label: s.t('salaryDay'), value: _day, onChanged: (d) => setState(() => _day = d)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                await app.setSalary(parseAmount(_amount.text)!, _day);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(s.t('save')),
            ),
            if (app.settings.hasSalary)
              TextButton(
                onPressed: () async {
                  await app.setSalary(0, _day);
                  if (context.mounted) Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: tk.danger),
                child: Text(s.t('removeSalary')),
              ),
          ],
        ),
      ),
    );
  }
}

/// Day-of-month picker (1–31) as a field that opens a wheel.
class DayPicker extends StatelessWidget {
  const DayPicker({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        var picked = value;
        await showModalBottomSheet<void>(
          context: context,
          builder: (ctx) => SizedBox(
            height: 260,
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(initialItem: value - 1),
              onSelectedItemChanged: (i) => picked = i + 1,
              children: [
                for (var d = 1; d <= 31; d++)
                  Center(child: Text('$d', style: AppType.title.copyWith(color: tk.ink))),
              ],
            ),
          ),
        );
        onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text('$value', style: AppType.body.copyWith(fontSize: 17, color: tk.ink)),
      ),
    );
  }
}
