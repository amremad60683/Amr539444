import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../services/bank_sms.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Confirmation sheet for a bank message (from the Shortcut link).
Future<void> showBankSheet(BuildContext context, {BankMessage? message}) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BankSheet(message: message),
    );

/// Paste a bank message (prefilled from the clipboard when it holds text).
Future<void> showBankPaste(BuildContext context) async {
  String? clip;
  try {
    clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  } catch (_) {}
  if (!context.mounted) return;
  final m = (clip != null && parseBankSms(clip).isUseful) ? parseBankSms(clip) : null;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BankSheet(message: m, initialText: m == null ? clip : null),
  );
}

class BankSheet extends StatefulWidget {
  const BankSheet({super.key, this.message, this.initialText});
  final BankMessage? message;
  final String? initialText;

  @override
  State<BankSheet> createState() => _BankSheetState();
}

class _BankSheetState extends State<BankSheet> {
  late BankMessage? _m = widget.message;
  late final _text = TextEditingController(text: widget.initialText ?? widget.message?.raw ?? '');
  late final _amount = TextEditingController(
      text: widget.message?.amount == null ? '' : _plain(widget.message!.amount!));
  late String _cat = widget.message?.category ?? 'other';
  bool _editing = false;

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _text.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _read() {
    final m = parseBankSms(_text.text);
    setState(() {
      _m = m;
      _editing = false;
      _amount.text = m.amount == null ? '' : _plain(m.amount!);
      _cat = m.category;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final m = _m;
    final showInput = m == null || !m.isUseful || _editing;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconTile(icon: CupertinoIcons.building_2_fill, color: Color(0xFF3B82F6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('bankTitle'), style: AppType.title.copyWith(color: tk.ink)),
                      Text(s.t('bankSub'), style: AppType.meta.copyWith(color: tk.ink3)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (showInput) ...[
              if (m != null && !m.isUseful) ...[
                Note(icon: CupertinoIcons.info_circle, text: s.t('bankNotUnderstood'), color: tk.warn),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _text,
                minLines: 3,
                maxLines: 6,
                autofocus: m == null,
                decoration: InputDecoration(hintText: s.t('bankPasteHint')),
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: _read, child: Text(s.t('bankRead'))),
            ] else ...[
              _Preview(
                m: m,
                amount: _amount,
                category: _cat,
                onCategory: (c) => setState(() => _cat = c),
                onEditText: () => setState(() => _editing = true),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  final edited = parseAmount(_amount.text);
                  final msg = BankMessage(
                    raw: m.raw,
                    kind: m.kind,
                    amount: edited ?? m.amount,
                    balance: m.balance,
                    merchant: m.merchant,
                    cardLast4: m.cardLast4,
                    category: _cat,
                  );
                  final messenger = ScaffoldMessenger.of(context);
                  await app.applyBank(msg, category: _cat);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  messenger.showSnackBar(SnackBar(
                    content: Text(msg.hasTransaction
                        ? s.t('bankAdded', {'x': s.money(msg.amount!)})
                        : s.t('bankBalanceOnly')),
                  ));
                },
                child: Text(m.hasTransaction ? s.t('bankAdd') : s.t('save')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: tk.ink2),
                child: Text(s.t('bankIgnore')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.m,
    required this.amount,
    required this.category,
    required this.onCategory,
    required this.onEditText,
  });

  final BankMessage m;
  final TextEditingController amount;
  final String category;
  final ValueChanged<String> onCategory;
  final VoidCallback onEditText;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final debit = m.kind == BankKind.debit;
    final seen = app.bankSeenBefore(m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The message itself, quoted, so the user sees what was read.
        Panel(
          color: tk.raised,
          padding: const EdgeInsets.all(14),
          onTap: onEditText,
          child: Text(m.raw, maxLines: 4, overflow: TextOverflow.ellipsis, style: AppType.label.copyWith(color: tk.ink2)),
        ),
        const SizedBox(height: 14),
        if (seen) ...[
          Note(icon: CupertinoIcons.exclamationmark_triangle, text: s.t('bankDuplicate'), color: tk.warn),
          const SizedBox(height: 12),
        ],
        if (m.hasTransaction) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: debit ? tk.dangerTint : tk.goodTint,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  debit ? s.t('bankDebit') : s.t('bankCredit'),
                  style: AppType.meta.copyWith(color: debit ? tk.danger : tk.good, fontWeight: FontWeight.w800),
                ),
              ),
              if (m.merchant != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(m.merchant!,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.bodyStrong.copyWith(color: tk.ink)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          AmountField(controller: amount, label: s.t('amount'), suffix: s.currency, big: true),
          if (debit) ...[
            const SizedBox(height: 14),
            Text(s.t('category'), style: AppType.label.copyWith(color: tk.ink3)),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in app.allCategories)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        avatar: Icon(c.icon, size: 16, color: category == c.id ? Colors.white : c.color),
                        label: Text(c.label(app.isAr),
                            style: AppType.label.copyWith(color: category == c.id ? Colors.white : tk.ink)),
                        selected: category == c.id,
                        onSelected: (_) => onCategory(c.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
        if (m.balance != null) ...[
          const SizedBox(height: 14),
          Group(children: [
            Line(
              leading: const IconTile(icon: CupertinoIcons.creditcard, color: Color(0xFF3B82F6), size: 38),
              title: s.t('bankBalanceLine', {'x': s.money(m.balance!)}),
              subtitle: app.settings.bankSyncBalance ? s.t('bankWillSync', {'x': s.money(m.balance!)}) : null,
            ),
          ]),
        ],
      ],
    );
  }
}
