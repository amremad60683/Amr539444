import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/txn.dart';
import '../services/budget_engine.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

Future<void> showAddExpense(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const AddExpenseSheet(),
  );
}

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _form = GlobalKey<FormState>();
  ExpenseCategory _cat = ExpenseCategory.food;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final app = context.read<AppState>();
    final s = app.s;
    final amount = parseAmount(_amount.text)!;
    final when = sameDay(_date, DateTime.now())
        ? DateTime.now()
        : DateTime(_date.year, _date.month, _date.day, 12);
    final p = app.preview(amount, when);

    // Warn BEFORE spending if this crosses the day's allowance.
    if (p.after.status == BudgetStatus.over) {
      final a = p.after;
      final body = a.isOuting
          ? '${s.t('outingWarnBody', {'allow': s.money(a.allowance)})}\n\n'
              '${s.t('overWarnBody', {'allow': s.money(a.allowance), 'total': s.money(a.spent), 'over': s.money(a.overBy)})}'
          : s.t('overWarnBody', {
              'allow': s.money(a.allowance),
              'total': s.money(a.spent),
              'over': s.money(a.overBy),
            });
      final ok = await confirm(context, s, body,
          title: s.t('overWarnTitle'), ok: s.t('spendAnyway'), danger: true);
      if (!ok || !mounted) return;
    }

    final outcome = await app.addExpense(
      amount: amount,
      date: when,
      note: _note.text.trim(),
      category: _cat,
    );
    if (!mounted) return;
    Navigator.pop(context);

    final a = outcome.after;
    String? msg;
    Color? color;
    if (outcome.crossedLimit || a.status == BudgetStatus.over) {
      msg = s.t('carryTomorrow', {'x': s.money(a.debtOut)});
      color = AppColors.danger;
    } else if (outcome.crossedTarget) {
      msg = s.t('targetReachedBody', {'spent': s.money(a.spent), 'left': s.money(a.remaining)});
      color = AppColors.warning;
    }
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final day = app.budgetFor(_date);
    final typed = parseAmount(_amount.text) ?? 0;
    final after = day.spent + typed;
    final status = day.statusFor(after);
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.t('addExpense'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              AmountField(
                controller: _amount,
                label: s.t('amount'),
                autofocus: true,
                big: true,
                suffix: s.currency,
                validator: positiveValidator(s),
              ),
              const SizedBox(height: 10),
              // Live preview of where the day will stand.
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.forStatus(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      status == BudgetStatus.over
                          ? Icons.warning_amber_rounded
                          : status == BudgetStatus.warning
                              ? Icons.info_outline_rounded
                              : Icons.check_circle_outline_rounded,
                      color: AppColors.forStatus(status),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${s.money(after)} / ${s.money(day.allowance)}'
                        '${day.isOuting ? '  •  ${s.t('outingDay')}' : ''}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.forStatus(status)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(s.t('category'), style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in ExpenseCategory.values)
                    ChoiceChip(
                      avatar: Icon(c.icon, size: 18),
                      label: Text(categoryLabel(s, c)),
                      selected: _cat == c,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _cat = c),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(s.t('date'), style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(s.t('today')),
                    selected: sameDay(_date, now),
                    onSelected: (_) => setState(() => _date = now),
                  ),
                  ChoiceChip(
                    label: Text(s.t('yesterday')),
                    selected: sameDay(_date, yesterday),
                    onSelected: (_) => setState(() => _date = yesterday),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: Text(sameDay(_date, now) || sameDay(_date, yesterday) ? s.t('date') : s.shortDate(_date)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(now.year - 1),
                        lastDate: now,
                      );
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(controller: _note, decoration: InputDecoration(labelText: s.t('note'))),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(s.t('save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
