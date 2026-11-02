import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/txn.dart';

/// Rounded card with padding.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Number input that accepts digits and a decimal point (also Arabic digits).
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.autofocus = false,
    this.validator,
    this.big = false,
    this.suffix,
    this.integer = false,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool autofocus;
  final String? Function(String?)? validator;
  final bool big;
  final String? suffix;
  final bool integer;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: [
        ArabicDigitsFormatter(),
        FilteringTextInputFormatter.allow(RegExp(integer ? r'[0-9]' : r'[0-9.]')),
      ],
      style: big ? Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800) : null,
      decoration: InputDecoration(labelText: label, helperText: helper, suffixText: suffix),
      validator: validator,
    );
  }
}

/// Converts Arabic-Indic digits (٠-٩) to Latin digits while typing.
class ArabicDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    var t = newValue.text;
    for (var i = 0; i < 10; i++) {
      t = t.replaceAll(ar[i], '$i');
    }
    t = t.replaceAll('٫', '.');
    return newValue.copyWith(text: t);
  }
}

double? parseAmount(String v) => double.tryParse(v.trim());

String? Function(String?) positiveValidator(S s, {bool allowZero = false}) => (v) {
      final x = parseAmount(v ?? '');
      if (x == null || x < 0 || (!allowZero && x == 0)) return s.t('required');
      return null;
    };

/// Simple dialog asking for one amount.
Future<double?> askAmount(BuildContext context, S s,
    {required String title, double? initial, String? helper, bool allowZero = false}) {
  final c = TextEditingController(text: initial == null ? '' : s.num0(initial).replaceAll(',', ''));
  final key = GlobalKey<FormState>();
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: key,
        child: AmountField(
          controller: c,
          label: s.t('amount'),
          helper: helper,
          autofocus: true,
          suffix: s.currency,
          validator: positiveValidator(s, allowZero: allowZero),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () {
            if (key.currentState!.validate()) Navigator.pop(ctx, parseAmount(c.text));
          },
          child: Text(s.t('save')),
        ),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, S s, String message, {String? title, String? ok, bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: title == null ? null : Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(88, 44),
            backgroundColor: danger ? Theme.of(ctx).colorScheme.error : null,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok ?? s.t('confirm')),
        ),
      ],
    ),
  );
  return r ?? false;
}

String categoryLabel(S s, ExpenseCategory c) => s.t('cat_${c.name}');

/// Small colored pill.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(text,
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
