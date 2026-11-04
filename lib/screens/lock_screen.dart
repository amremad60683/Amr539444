import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// PIN entry screen (only shown when a PIN is set).
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _error = false;

  void _tap(String d) {
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = false;
    });
    if (_pin.length == 4) {
      final ok = context.read<AppState>().unlock(_pin);
      if (!ok) {
        HapticFeedback.heavyImpact();
        setState(() {
          _pin = '';
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final s = app.s;
    final tk = context.tk;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            BrandMark(size: 56, isAr: app.isAr),
            const SizedBox(height: 20),
            Text(s.t('enterPin'), style: AppType.title.copyWith(color: tk.ink)),
            const SizedBox(height: 20),
            PinDots(length: _pin.length),
            SizedBox(
              height: 32,
              child: Center(
                child: _error ? Text(s.t('wrongPin'), style: AppType.label.copyWith(color: tk.danger)) : null,
              ),
            ),
            const Spacer(),
            PinPad(
              onDigit: _tap,
              onBackspace: () {
                if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length});
  final int length;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        4,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.all(9),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < length ? tk.ink : Colors.transparent,
            border: Border.all(color: i < length ? tk.ink : tk.lineStrong, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onBackspace});
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget key(Widget child, VoidCallback? onTap, {String? label}) => Padding(
          padding: const EdgeInsets.all(8),
          child: Semantics(
            button: onTap != null,
            label: label,
            child: Material(
              color: onTap == null ? Colors.transparent : tk.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(width: 72, height: 72, child: Center(child: child)),
              ),
            ),
          ),
        );
    Widget digit(String d) =>
        key(Text(d, style: AppType.page.copyWith(color: tk.ink, fontWeight: FontWeight.w500)), () => onDigit(d));
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(mainAxisAlignment: MainAxisAlignment.center, children: row.map(digit).toList()),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              key(const SizedBox(), null),
              digit('0'),
              key(Icon(CupertinoIcons.delete_left, color: tk.ink2), onBackspace, label: 'Backspace'),
            ],
          ),
        ],
      ),
    );
  }
}
