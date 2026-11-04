import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../services/budget_engine.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

Future<void> showAddExpense(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddExpenseSheet(),
    );

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _cat = 'food';
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
    final when = sameDay(_date, DateTime.now()) ? DateTime.now() : DateTime(_date.year, _date.month, _date.day, 12);
    final p = app.preview(amount, when);

    // Warn BEFORE saving if this crosses the day's allowance.
    if (p.after.status == BudgetStatus.over) {
      final a = p.after;
      final body = [
        if (a.isOuting) s.t('outingWarnBody', {'allow': s.money(a.allowance)}),
        s.t('overWarnBody', {'allow': s.money(a.allowance), 'total': s.money(a.spent), 'over': s.money(a.overBy)}),
      ].join('\n\n');
      final ok = await confirm(context, s, body, title: s.t('overWarnTitle'), ok: s.t('spendAnyway'), danger: true);
      if (!ok || !mounted) return;
    }

    final outcome = await app.addExpense(amount: amount, date: when, note: _note.text.trim(), category: _cat);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    final a = outcome.after;
    String? msg;
    if (a.status == BudgetStatus.over) {
      msg = s.t('carryTomorrow', {'x': s.money(a.debtOut)});
    } else if (outcome.crossedTarget) {
      msg = s.t('targetReachedBody', {'spent': s.money(a.spent), 'left': s.money(a.remaining)});
    }
    if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _newCategory() async {
    final app = context.read<AppState>();
    final r = await showCategoryEditor(context);
    if (r == null) return;
    await app.addCategory(r.$1, r.$2);
    setState(() => _cat = app.settings.customCategories.last.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final day = app.budgetFor(_date);
    final typed = parseAmount(_amount.text) ?? 0;
    final after = day.spent + typed;
    final status = day.statusFor(after);
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final isOther = !sameDay(_date, now) && !sameDay(_date, yesterday);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.t('addExpense'), style: AppType.title.copyWith(color: tk.ink)),
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
              Row(
                children: [
                  Icon(
                    status == BudgetStatus.over
                        ? CupertinoIcons.exclamationmark_triangle_fill
                        : status == BudgetStatus.warning
                            ? CupertinoIcons.info_circle
                            : CupertinoIcons.checkmark_circle,
                    size: 16,
                    color: tk.forStatus(status),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${s.t('afterAdd', {'x': '${s.money(after)} / ${s.money(day.allowance)}'})}'
                      '${day.isOuting ? ' · ${s.t('outingDay')}' : ''}',
                      style: AppType.label.copyWith(color: tk.forStatus(status), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(s.t('category'), style: AppType.label.copyWith(color: tk.ink3)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in app.allCategories)
                    _CatChip(
                      cat: c,
                      label: c.label(app.isAr),
                      selected: _cat == c.id,
                      onTap: () => setState(() => _cat = c.id),
                    ),
                  ActionChip(
                    avatar: Icon(CupertinoIcons.plus, size: 16, color: tk.ink2),
                    label: Text(s.t('addCategory'), style: AppType.label.copyWith(color: tk.ink2)),
                    onPressed: _newCategory,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(s.t('date'), style: AppType.label.copyWith(color: tk.ink3)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 0, label: Text(s.t('today'))),
                  ButtonSegment(value: 1, label: Text(s.t('yesterday'))),
                  ButtonSegment(value: 2, label: Text(isOther ? s.shortDate(_date) : s.t('pickDate'))),
                ],
                selected: {sameDay(_date, now) ? 0 : (sameDay(_date, yesterday) ? 1 : 2)},
                onSelectionChanged: (v) async {
                  if (v.first == 0) return setState(() => _date = now);
                  if (v.first == 1) return setState(() => _date = yesterday);
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(now.year - 1),
                    lastDate: now,
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                decoration: InputDecoration(labelText: s.t('note'), hintText: s.t('notePh')),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _save, child: Text(s.t('save'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({required this.cat, required this.label, required this.selected, required this.onTap});
  final CategoryDef cat;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return ChoiceChip(
      avatar: Icon(cat.icon, size: 16, color: selected ? tk.bg : tk.ink2),
      label: Text(label, style: AppType.label.copyWith(color: selected ? tk.bg : tk.ink)),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

/// Name + icon editor for a custom category. Returns (name, iconKey).
Future<(String, String)?> showCategoryEditor(BuildContext context) {
  return showModalBottomSheet<(String, String)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _CategoryEditor(),
  );
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor();

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _icon = 'tag';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>().s;
    final tk = context.tk;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.t('addCategory'), style: AppType.title.copyWith(color: tk.ink)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: s.t('categoryName')),
              validator: (v) => (v == null || v.trim().isEmpty) ? s.t('required') : null,
            ),
            const SizedBox(height: 16),
            Text(s.t('categoryIcon'), style: AppType.label.copyWith(color: tk.ink3)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in categoryIcons.entries)
                  Semantics(
                    button: true,
                    selected: _icon == e.key,
                    label: e.key,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _icon = e.key),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _icon == e.key ? tk.ink : tk.raised,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(e.value, size: 20, color: _icon == e.key ? tk.bg : tk.ink2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) Navigator.pop(context, (_name.text.trim(), _icon));
              },
              child: Text(s.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}
