import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

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
    final s = context.read<AppState>().s;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(Icons.lock_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(s.t('enterPin'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => Container(
                  margin: const EdgeInsets.all(8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 28,
              child: _error ? Text(s.t('wrongPin'), style: TextStyle(color: scheme.error)) : null,
            ),
            const Spacer(),
            PinPad(onDigit: _tap, onBackspace: () {
              if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
            }),
            const SizedBox(height: 32),
          ],
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
    Widget key(Widget child, VoidCallback? onTap) => SizedBox(
          width: 80,
          height: 72,
          child: InkWell(borderRadius: BorderRadius.circular(40), onTap: onTap, child: Center(child: child)),
        );
    Widget digit(String d) => key(Text(d, style: Theme.of(context).textTheme.headlineSmall), () => onDigit(d));
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
              key(const Icon(Icons.backspace_outlined), onBackspace),
            ],
          ),
        ],
      ),
    );
  }
}
