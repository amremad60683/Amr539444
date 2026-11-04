import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Plan an outing day with its own (bigger) budget.
Future<void> showOutingSheet(BuildContext context, {DateTime? initialDate}) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _OutingSheet(initialDate: initialDate ?? DateTime.now()),
    );

class _OutingSheet extends StatefulWidget {
  const _OutingSheet({required this.initialDate});
  final DateTime initialDate;

  @override
  State<_OutingSheet> createState() => _OutingSheetState();
}

class _OutingSheetState extends State<_OutingSheet> {
  late DateTime _date = dateOnly(widget.initialDate);
  final _budget = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final existing = app.outings[dayKey(_date)];
    _budget.text = (existing ?? app.settings.maxDaily * 2).toStringAsFixed(0);
  }

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final exists = app.outings.containsKey(dayKey(_date));
    final now = DateTime.now();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.t('planOuting'), style: AppType.title.copyWith(color: tk.ink)),
            const SizedBox(height: 4),
            Text(s.t('outingHelp'), style: AppType.label.copyWith(color: tk.ink3)),
            const SizedBox(height: 16),
            Group(children: [
              Line(
                icon: CupertinoIcons.calendar,
                title: s.t('outingDate'),
                trailing: Text(s.date(_date), style: AppType.body.copyWith(color: tk.ink2)),
                chevron: true,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: DateTime(now.year + 1, now.month, now.day),
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
            ]),
            const SizedBox(height: 12),
            AmountField(
              controller: _budget,
              label: s.t('outingBudget'),
              suffix: s.currency,
              validator: positiveValidator(s),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                await app.setOuting(_date, parseAmount(_budget.text)!);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(s.t('save')),
            ),
            if (exists)
              TextButton(
                onPressed: () async {
                  await app.removeOuting(dayKey(_date));
                  if (context.mounted) Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: tk.danger),
                child: Text(s.t('removeOuting')),
              ),
          ],
        ),
      ),
    );
  }
}
