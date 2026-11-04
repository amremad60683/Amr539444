import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/biometric_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Login: navy top with the greeting, PIN pad below. Face ID when enabled.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, this.biometrics});
  final BiometricService? biometrics;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late final _bio = widget.biometrics ?? BiometricService();
  String _pin = '';
  bool _error = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    if (app.settings.biometrics) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _faceId());
    }
  }

  Future<void> _faceId() async {
    final app = context.read<AppState>();
    if (await _bio.authenticate(app.s.t('faceIdReason'))) {
      app.unlocked = true;
      app.refresh();
    }
  }

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
    final top = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: tk.primary,
        body: Container(
          decoration: BoxDecoration(gradient: tk.hero),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, top + 24, 24, 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BrandMark(size: 64, isAr: app.isAr, onHero: true),
                      const SizedBox(height: 20),
                      Text(s.t('loginTitle', {'name': app.settings.name}),
                          textAlign: TextAlign.center, style: AppType.page.copyWith(color: Colors.white)),
                      const SizedBox(height: 6),
                      Text(s.t('loginBody'), style: AppType.body.copyWith(color: tk.onPrimary2)),
                      const SizedBox(height: 24),
                      PinDots(length: _pin.length, onHero: true),
                      SizedBox(
                        height: 30,
                        child: Center(
                          child: _error
                              ? Text(s.t('wrongPin'), style: AppType.label.copyWith(color: Tokens.heroDanger))
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: tk.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: EdgeInsets.fromLTRB(16, 24, 16, MediaQuery.of(context).padding.bottom + 20),
                child: PinPad(
                  onDigit: _tap,
                  onBackspace: () {
                    if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
                  },
                  onFaceId: app.settings.biometrics ? _faceId : null,
                  faceIdLabel: s.t('useFaceId'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, this.onHero = false});
  final int length;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final on = onHero ? Colors.white : (tk.dark ? tk.ink : tk.primary);
    final off = onHero ? Colors.white.withValues(alpha: 0.35) : tk.lineStrong;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        4,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.all(10),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < length ? (onHero ? tk.accent : on) : Colors.transparent,
            border: Border.all(color: i < length ? (onHero ? tk.accent : on) : off, width: 2),
          ),
        ),
      ),
    );
  }
}

class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onBackspace, this.onFaceId, this.faceIdLabel});
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onFaceId;
  final String? faceIdLabel;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget key(Widget child, VoidCallback? onTap, {String? label, bool filled = true}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Semantics(
            button: onTap != null,
            label: label,
            child: Material(
              color: onTap == null || !filled ? Colors.transparent : tk.raised,
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
        key(Text(d, style: AppType.page.copyWith(color: tk.ink, fontWeight: FontWeight.w700)), () => onDigit(d));
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              onFaceId == null
                  ? key(const SizedBox(), null)
                  : key(Icon(CupertinoIcons.viewfinder, color: tk.accent, size: 30), onFaceId,
                      label: faceIdLabel, filled: false),
              digit('0'),
              key(Icon(CupertinoIcons.delete_left, color: tk.ink2), onBackspace, label: 'Backspace', filled: false),
            ],
          ),
        ],
      ),
    );
  }
}
