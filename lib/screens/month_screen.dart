import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/installment.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The cycle until payday (or month end): salary, what's left at the end,
/// the safety balance, where the money went and the installments.
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
    final avg = p.averageDaily;

    Widget projection(String label, double perDay) {
      final end = p.projectedAt(perDay);
      final risky = end < st.safetyBalance || end < 0;
      return Line(
        title: label,
        trailing: Reveal(
          bone: const Bone(width: 70, height: 16),
          child: Text(
            s.money(end),
            style: AppType.bodyStrong.copyWith(color: risky ? tk.danger : tk.ink),
          ),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          PageTitle(s.t('monthTitle'), subtitle: subtitle),
          const SizedBox(height: 12),
          FigureStrip(figures: [
            Figure(label: s.t('spentCycle'), value: s.money(p.spent)),
            Figure(label: s.t('instCycle'), value: s.money(p.installmentsPaid + p.installmentsDue)),
            Figure(label: s.t('daysLeft'), value: s.t('daysN', {'d': p.daysLeft}), boneWidth: 48),
          ]),

          // ---------------------------------------------------- end of cycle
          SectionHeader(p.salaryBased ? s.t('endSalary') : s.t('endMonth')),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(s.t('fromTomorrow'), style: AppType.label.copyWith(color: tk.ink3)),
                ),
                projection(s.t('atTarget', {'x': s.num0(st.minDaily)}), st.minDaily),
                const Divider(indent: 16, endIndent: 16),
                if (avg > 0) ...[
                  projection(s.t('atAvg', {'x': s.num0(avg.roundToDouble())}), avg.roundToDouble()),
                  const Divider(indent: 16, endIndent: 16),
                ],
                projection(s.t('atMax', {'x': s.num0(st.maxDaily)}), st.maxDaily),
                Divider(color: tk.line),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: st.safetyBalance > 0 && p.free <= st.safetyBalance
                      ? Note(
                          icon: CupertinoIcons.exclamationmark_triangle,
                          text: s.t('safeDailyZero', {'safe': s.money(st.safetyBalance)}),
                          color: tk.danger,
                        )
                      : Text(
                          s.t('safeDaily', {
                            'safe': s.money(st.safetyBalance),
                            'x': s.money(p.safeDaily.floorToDouble()),
                          }),
                          style: AppType.body.copyWith(color: tk.ink),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Group(children: [
            Line(
              icon: CupertinoIcons.lock,
              title: s.t('safety'),
              subtitle: s.t('safetyHelp'),
              trailing: Text(
                st.safetyBalance > 0 ? s.money(st.safetyBalance) : s.t('safetyNone'),
                style: AppType.body.copyWith(color: st.safetyBalance > 0 ? tk.ink : tk.ink3),
              ),
              chevron: true,
              onTap: () async {
                final v = await askAmount(context, s,
                    title: s.t('safety'), helper: s.t('safetyHelp'), initial: st.safetyBalance, allowZero: true);
                if (v != null) await app.setSafetyBalance(v);
              },
            ),
          ]),

          // ---------------------------------------------------- salary
          SectionHeader(s.t('salaryTitle')),
          if (!st.hasSalary)
            EmptyBlock(
              text: s.t('salaryNone'),
              action: s.t('addSalary'),
              onAction: () => showSalarySheet(context),
            )
          else
            Group(children: [
              Line(
                icon: CupertinoIcons.money_pound_circle,
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
            Group(children: [
              for (final e in cats.take(8))
                _CategoryRow(
                  icon: e.key.icon,
                  label: e.key.label(app.isAr),
                  amount: s.money(e.value),
                  share: catTotal == 0 ? 0 : e.value / catTotal,
                ),
            ]),

          // ---------------------------------------------------- installments
          SectionHeader(s.t('installments'), action: s.t('addInstallment'), onAction: () => showInstallmentSheet(context)),
          const _Installments(),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.icon, required this.label, required this.amount, required this.share});
  final IconData icon;
  final String label;
  final String amount;
  final double share;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: tk.ink2),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppType.body.copyWith(color: tk.ink))),
              Text('${(share * 100).round()}%', style: AppType.label.copyWith(color: tk.ink3)),
              const SizedBox(width: 12),
              Text(amount, style: AppType.bodyStrong.copyWith(color: tk.ink)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(children: [
                Container(color: tk.raised),
                FractionallySizedBox(
                  widthFactor: max(0.02, share),
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(color: tk.accent),
                ),
              ]),
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
        const SizedBox(height: 8),
        Group(children: [for (final i in list) _InstallmentRow(i)]),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(s.t('instAutoNote'), style: AppType.meta.copyWith(color: tk.ink3)),
        ),
      ],
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow(this.i);
  final Installment i;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final s = app.s;
    final tk = context.tk;
    final days = dateOnly(i.nextDue).difference(dateOnly(DateTime.now())).inDays;
    final soon = !i.isFinished && days <= 3;

    return InkWell(
      onLongPress: () => _menu(context),
      onTap: () => _menu(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(i.name, style: AppType.bodyStrong.copyWith(color: tk.ink)),
                ),
                Text(s.money(i.amount), style: AppType.bodyStrong.copyWith(color: tk.ink)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    i.isFinished ? s.t('finished') : s.t('instLeft', {'n': i.remaining, 't': i.total}),
                    style: AppType.label.copyWith(color: i.isFinished ? tk.accent : tk.ink3),
                  ),
                ),
                if (!i.isFinished)
                  Text(
                    s.t('instDue', {'date': s.shortDate(i.nextDue)}),
                    style: AppType.label.copyWith(
                      color: soon ? tk.warn : tk.ink3,
                      fontWeight: soon ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: i.total == 0 ? 1 : i.paid / i.total,
                minHeight: 4,
                backgroundColor: tk.raised,
                color: i.isFinished ? tk.accent : tk.ink2,
              ),
            ),
          ],
        ),
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
                  Line(icon: CupertinoIcons.checkmark_circle, title: s.t('payNow'), onTap: () => Navigator.pop(ctx, 'pay')),
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
