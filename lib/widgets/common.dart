import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../theme.dart';

/// Exponential ease-out used for confident arrivals.
const easeOutExpo = Cubic(0.16, 1, 0.3, 1);

bool reduceMotion(BuildContext context) => MediaQuery.of(context).disableAnimations;

// ------------------------------------------------------------------ reveal

/// Tells widgets below it whether the first-load reveal has happened.
/// Before it, values render as flat "bones" at their real size; after it,
/// they fade in without any layout shift.
class RevealScope extends InheritedNotifier<ValueNotifier<bool>> {
  const RevealScope({super.key, required ValueNotifier<bool> revealed, required super.child})
      : super(notifier: revealed);

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RevealScope>()?.notifier?.value ?? true;
}

/// A flat placeholder bar (no shimmer) with the size of the value it stands for.
class Bone extends StatelessWidget {
  const Bone({super.key, required this.width, required this.height, this.radius = 6});
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: context.tk.raised, borderRadius: BorderRadius.circular(radius)),
      );
}

/// Shows [bone] until the reveal, then crossfades to [child] in place.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, required this.bone});
  final Widget child;
  final Widget bone;

  @override
  Widget build(BuildContext context) {
    final shown = RevealScope.of(context);
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduceMotion(context) ? 0 : 320),
      switchInCurve: easeOutExpo,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      child: shown ? KeyedSubtree(key: const ValueKey(true), child: child) : KeyedSubtree(key: const ValueKey(false), child: bone),
    );
  }
}

// ------------------------------------------------------------------ brand

/// The product mark: the first letter of the name in the accent.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36, required this.isAr});
  final double size;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tk.accent, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Text(
        isAr ? 'م' : 'M',
        style: TextStyle(
          fontFamily: AppType.family,
          color: tk.onAccent,
          fontSize: size * 0.55,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ surfaces

/// Bordered surface. A border or a shadow, never both: this uses the border.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Material(
      color: tk.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: tk.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        highlightColor: tk.raised,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A panel holding rows separated by inset hairlines (iOS grouped list).
class Group extends StatelessWidget {
  const Group({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(indent: 16, endIndent: 16));
      rows.add(children[i]);
    }
    return Panel(padding: EdgeInsets.zero, child: Column(children: rows));
  }
}

/// One row of a [Group]: optional grey icon, title, subtitle, trailing.
class Line extends StatelessWidget {
  const Line({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.chevron = false,
    this.titleColor,
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool chevron;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      highlightColor: tk.raised,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: iconColor ?? tk.ink2),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppType.body.copyWith(color: titleColor ?? tk.ink)),
                    if (subtitle != null)
                      Text(subtitle!, style: AppType.label.copyWith(color: tk.ink3)),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              if (chevron) ...[
                const SizedBox(width: 6),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? CupertinoIcons.chevron_left
                      : CupertinoIcons.chevron_right,
                  size: 16,
                  color: tk.ink3,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppType.title.copyWith(color: tk.ink))),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: tk.ink2, padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text(action!, style: AppType.label.copyWith(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// Label above a value; values are bones until the reveal.
class Figure extends StatelessWidget {
  const Figure({super.key, required this.label, required this.value, this.color, this.boneWidth = 72});
  final String label;
  final String value;
  final Color? color;
  final double boneWidth;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.label.copyWith(color: tk.ink3), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        SizedBox(
          height: 28,
          child: Reveal(
          bone: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Bone(width: boneWidth, height: 18)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: AppType.figure.copyWith(color: color ?? tk.ink)),
          ),
        ),
        ),
      ],
    );
  }
}

/// One container split by hairlines into equal columns of [Figure]s.
class FigureStrip extends StatelessWidget {
  const FigureStrip({super.key, required this.figures});
  final List<Figure> figures;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    // Fixed-height cells (no intrinsic measuring) so bones and values take
    // exactly the same space: nothing shifts when the values land.
    final cells = <Widget>[];
    for (var i = 0; i < figures.length; i++) {
      cells.add(Expanded(
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: i == 0
              ? null
              : BoxDecoration(border: BorderDirectional(start: BorderSide(color: tk.line))),
          child: figures[i],
        ),
      ));
    }
    return Panel(padding: EdgeInsets.zero, child: Row(children: cells));
  }
}

/// A short note with a small icon, coloured by meaning.
class Note extends StatelessWidget {
  const Note({super.key, required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppType.label.copyWith(color: color, fontWeight: FontWeight.w600))),
        ],
      );
}

/// Empty state that keeps its frame: one sentence and, optionally, an action.
class EmptyBlock extends StatelessWidget {
  const EmptyBlock({super.key, required this.text, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AppType.body.copyWith(color: tk.ink2)),
          if (action != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

/// Page title row used at the top of each tab.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.page.copyWith(color: tk.ink)),
                if (subtitle != null) Text(subtitle!, style: AppType.label.copyWith(color: tk.ink3)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ inputs

/// Number input that accepts digits and a decimal point (also Arabic digits).
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.hint,
    this.autofocus = false,
    this.validator,
    this.big = false,
    this.suffix,
    this.integer = false,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? hint;
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
      style: big
          ? AppType.lead.copyWith(fontSize: 34, color: context.tk.ink)
          : AppType.body.copyWith(fontSize: 17, color: context.tk.ink),
      decoration: InputDecoration(labelText: label, helperText: helper, hintText: hint, suffixText: suffix),
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

/// Bottom sheet asking for one amount.
Future<double?> askAmount(BuildContext context, S s,
    {required String title, double? initial, String? helper, bool allowZero = false}) {
  final c = TextEditingController(text: initial == null ? '' : s.num0(initial).replaceAll(',', ''));
  final key = GlobalKey<FormState>();
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppType.title.copyWith(color: ctx.tk.ink)),
            const SizedBox(height: 16),
            AmountField(
              controller: c,
              label: s.t('amount'),
              helper: helper,
              autofocus: true,
              big: true,
              suffix: s.currency,
              validator: positiveValidator(s, allowZero: allowZero),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, parseAmount(c.text));
              },
              child: Text(s.t('save')),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirm(BuildContext context, S s, String message,
    {String? title, String? ok, bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final tk = ctx.tk;
      return AlertDialog(
        title: title == null ? null : Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: tk.ink2),
            child: Text(s.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: danger ? tk.danger : tk.ink),
            child: Text(ok ?? s.t('confirm')),
          ),
        ],
      );
    },
  );
  return r ?? false;
}
