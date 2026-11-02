import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/installment.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class InstallmentsScreen extends StatelessWidget {
  const InstallmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final list = [...app.installments]..sort((a, b) {
        if (a.isFinished != b.isFinished) return a.isFinished ? 1 : -1;
        return a.nextDue.compareTo(b.nextDue);
      });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(s.t('installments'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addInst',
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => const _AddInstallmentSheet(),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(s.t('addInstallment')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          Row(
            children: [
              Expanded(child: _Summary(label: s.t('totalMonthly'), value: s.money(app.monthlyInstallments))),
              const SizedBox(width: 12),
              Expanded(child: _Summary(label: s.t('totalRemaining'), value: s.money(app.remainingInstallments))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(s.t('instAutoNote'), style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Icon(Icons.event_available_rounded, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 8),
                  Text(s.t('noInstallments')),
                ],
              ),
            ),
          for (final i in list) ...[
            _InstallmentCard(i),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
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
    final scheme = Theme.of(context).colorScheme;
    final days = dateOnly(i.nextDue).difference(dateOnly(DateTime.now())).inDays;
    final soon = !i.isFinished && days <= 3;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: (i.isFinished ? AppColors.safe : scheme.primary).withValues(alpha: 0.12),
                child: Icon(i.isFinished ? Icons.check_rounded : Icons.event_repeat_rounded,
                    color: i.isFinished ? AppColors.safe : scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('${s.money(i.amount)} • ${s.t('dayLabel', {'d': i.dueDay})}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'pay') {
                    await app.payInstallment(i);
                  } else if (v == 'delete') {
                    if (await confirm(context, s, s.t('deleteInst'), ok: s.t('delete'), danger: true)) {
                      await app.deleteInstallment(i);
                    }
                  }
                },
                itemBuilder: (_) => [
                  if (!i.isFinished) PopupMenuItem(value: 'pay', child: Text(s.t('payNow'))),
                  PopupMenuItem(value: 'delete', child: Text(s.t('delete'))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: i.total == 0 ? 1 : i.paid / i.total,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              color: i.isFinished ? AppColors.safe : scheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(i.isFinished ? s.t('finished') : s.t('instLeft', {'n': i.remaining, 't': i.total}),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (!i.isFinished)
                Pill(s.t('instDue', {'date': s.shortDate(i.nextDue)}),
                    color: soon ? AppColors.warning : scheme.primary, icon: Icons.schedule_rounded),
            ],
          ),
          if (!i.isFinished) ...[
            const SizedBox(height: 4),
            Text(s.t('instRemainingAmount', {'x': s.money(i.remainingAmount)}),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _AddInstallmentSheet extends StatefulWidget {
  const _AddInstallmentSheet();

  @override
  State<_AddInstallmentSheet> createState() => _AddInstallmentSheetState();
}

class _AddInstallmentSheetState extends State<_AddInstallmentSheet> {
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
              Text(s.t('addInstallment'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: s.t('instName')),
                validator: (v) => (v == null || v.trim().isEmpty) ? s.t('required') : null,
              ),
              const SizedBox(height: 12),
              AmountField(
                controller: _amount,
                label: s.t('instAmount'),
                suffix: s.currency,
                validator: positiveValidator(s),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _dueDay,
                decoration: InputDecoration(labelText: s.t('instDueDay')),
                items: [
                  for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d')),
                ],
                onChanged: (v) => setState(() => _dueDay = v ?? _dueDay),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AmountField(
                      controller: _total,
                      label: s.t('instTotal'),
                      integer: true,
                      validator: intValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AmountField(
                      controller: _remaining,
                      label: s.t('instRemaining'),
                      integer: true,
                      validator: intValidator,
                    ),
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
