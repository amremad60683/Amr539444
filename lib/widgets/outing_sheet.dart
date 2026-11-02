import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/date_utils.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Plan an outing day with its own (bigger) budget.
Future<void> showOutingSheet(BuildContext context, {DateTime? initialDate}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _OutingSheet(initialDate: initialDate ?? DateTime.now()),
  );
}

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
            Row(children: [
              const Icon(Icons.celebration_rounded),
              const SizedBox(width: 8),
              Text(s.t('planOuting'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Text(s.t('outingHelp'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_rounded),
              title: Text(s.t('outingDate')),
              subtitle: Text(s.date(_date)),
              trailing: const Icon(Icons.edit_calendar_rounded),
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
            const SizedBox(height: 8),
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
            if (exists) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await app.removeOuting(dayKey(_date));
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(s.t('removeOuting')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
