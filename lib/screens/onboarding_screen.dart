import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../services/biometric_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'lock_screen.dart' show PinDots, PinPad;
import 'month_screen.dart' show DayPicker;

/// Sign-up: welcome, then three steps (you, your budget, your PIN).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.biometrics});
  final BiometricService? biometrics;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final _bio = widget.biometrics ?? BiometricService();
  final _form1 = GlobalKey<FormState>();
  final _form2 = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _balance = TextEditingController();
  final _min = TextEditingController(text: '150');
  final _max = TextEditingController(text: '250');
  final _salary = TextEditingController();
  String _lang = 'ar';
  String _gender = 'm';
  int _payday = 1;
  int _step = 0;
  String _pin = '';
  String? _firstPin;
  bool _pinMismatch = false;
  bool _faceId = false;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _bio.available().then((v) {
      if (mounted) setState(() => _bioAvailable = v);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _balance, _min, _max, _salary]) {
      c.dispose();
    }
    super.dispose();
  }

  S get s => S(_lang, _gender);

  void _finish({String? pin}) {
    context.read<AppState>().completeOnboarding(
          name: _name.text.trim(),
          balance: parseAmount(_balance.text)!,
          minDaily: parseAmount(_min.text)!,
          maxDaily: parseAmount(_max.text)!,
          lang: _lang,
          gender: _gender,
          salary: parseAmount(_salary.text) ?? 0,
          salaryDay: _payday,
          pin: pin,
          biometrics: _faceId,
        );
  }

  void _pinDigit(String d) {
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _pinMismatch = false;
    });
    if (_pin.length < 4) return;
    if (_firstPin == null) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
      });
    } else if (_pin == _firstPin) {
      _finish(pin: _pin);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _firstPin = null;
        _pinMismatch = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: reduceMotion(context) ? 0 : 280),
        child: KeyedSubtree(key: ValueKey(_step), child: _page()),
      ),
    );
  }

  Widget _page() => switch (_step) {
        0 => _welcome(),
        1 => _stepScaffold(1, s.t('step1Title'), _aboutYou(), () {
            if (_form1.currentState!.validate()) setState(() => _step = 2);
          }),
        2 => _stepScaffold(2, s.t('step2Title'), _budget(), () {
            if (_form2.currentState!.validate()) setState(() => _step = 3);
          }),
        _ => _security(),
      };

  // ---------------------------------------------------------------- welcome

  Widget _welcome() {
    final tk = context.tk;
    final top = MediaQuery.of(context).padding.top;
    Widget feature(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: AppType.bodyStrong.copyWith(color: Colors.white))),
            ],
          ),
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: tk.bg,
        body: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: tk.hero,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
                ),
                padding: EdgeInsets.fromLTRB(24, top + 12, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BrandMark(size: 44, isAr: _lang == 'ar', onHero: true),
                        const Spacer(),
                        _LangToggle(value: _lang, onChanged: (v) => setState(() => _lang = v)),
                      ],
                    ),
                    const Spacer(),
                    Text(s.t('welcomeTitle'), style: AppType.page.copyWith(color: Colors.white, fontSize: 32)),
                    const SizedBox(height: 10),
                    Text(s.t('welcomeBody'), style: AppType.body.copyWith(color: tk.onPrimary2)),
                    const SizedBox(height: 26),
                    feature(CupertinoIcons.scope, s.t('feat1')),
                    feature(CupertinoIcons.money_pound_circle, s.t('feat2')),
                    feature(CupertinoIcons.chat_bubble_text, s.t('feat3')),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 24, MediaQuery.of(context).padding.bottom + 20),
              child: Column(
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: tk.accent, foregroundColor: tk.onAccent),
                    onPressed: () => setState(() => _step = 1),
                    child: Text(s.t('getStarted')),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.lock, size: 14, color: tk.ink3),
                      const SizedBox(width: 6),
                      Text(s.t('haveAccount'), style: AppType.meta.copyWith(color: tk.ink3)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- steps

  Widget _stepScaffold(int n, String title, Widget body, VoidCallback onNext) {
    final tk = context.tk;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _StepBar(
              step: n,
              label: s.t('stepOf', {'n': n, 't': 3}),
              backLabel: s.t('back'),
              onBack: () => setState(() => _step = n - 1),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  Text(title, style: AppType.page.copyWith(color: tk.ink)),
                  const SizedBox(height: 20),
                  body,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton(onPressed: onNext, child: Text(s.t('next'))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutYou() {
    final tk = context.tk;
    return Form(
      key: _form1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
            decoration: InputDecoration(labelText: s.t('yourName'), prefixIcon: const Icon(CupertinoIcons.person)),
            validator: (v) => (v == null || v.trim().isEmpty) ? s.t('required') : null,
          ),
          if (_lang == 'ar') ...[
            const SizedBox(height: 18),
            Text(s.t('addressAs'), style: AppType.label.copyWith(color: tk.ink3)),
            const SizedBox(height: 8),
            PillTabs(
              labels: [s.t('male'), s.t('female')],
              index: _gender == 'f' ? 1 : 0,
              onChanged: (i) => setState(() => _gender = i == 1 ? 'f' : 'm'),
            ),
          ],
          const SizedBox(height: 18),
          AmountField(
            controller: _balance,
            label: s.t('currentBalance'),
            suffix: s.currency,
            validator: positiveValidator(s, allowZero: true),
          ),
        ],
      ),
    );
  }

  Widget _budget() {
    final tk = context.tk;
    return Form(
      key: _form2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AmountField(controller: _min, label: s.t('dailyMin'), helper: s.t('minHelp'), suffix: s.currency, validator: positiveValidator(s)),
          const SizedBox(height: 14),
          AmountField(
            controller: _max,
            label: s.t('dailyMax'),
            helper: s.t('maxHelp'),
            suffix: s.currency,
            validator: (v) {
              final base = positiveValidator(s)(v);
              if (base != null) return base;
              final mn = parseAmount(_min.text);
              if (mn != null && parseAmount(v!)! < mn) return s.t('minMaxError');
              return null;
            },
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: AmountField(controller: _salary, label: s.t('salaryOptional'), suffix: s.currency)),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DayPicker(label: s.t('salaryDay'), value: _payday, onChanged: (d) => setState(() => _payday = d)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(s.t('salaryHelp'), style: AppType.meta.copyWith(color: tk.ink3)),
          ),
        ],
      ),
    );
  }

  Widget _security() {
    final tk = context.tk;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _StepBar(
              step: 3,
              label: s.t('stepOf', {'n': 3, 't': 3}),
              backLabel: s.t('back'),
              onBack: () => setState(() {
                _step = 2;
                _pin = '';
                _firstPin = null;
              }),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                children: [
                  Text(s.t('step3Title'), style: AppType.page.copyWith(color: tk.ink)),
                  const SizedBox(height: 6),
                  Text(s.t('step3Body'), style: AppType.body.copyWith(color: tk.ink2)),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(_firstPin == null ? s.t('setPin') : s.t('confirmPin'),
                        style: AppType.bodyStrong.copyWith(color: tk.ink)),
                  ),
                  PinDots(length: _pin.length),
                  SizedBox(
                    height: 22,
                    child: Center(
                      child: _pinMismatch
                          ? Text(s.t('pinMismatch'), style: AppType.label.copyWith(color: tk.danger))
                          : null,
                    ),
                  ),
                  if (_bioAvailable)
                    Group(children: [
                      Line(
                        icon: CupertinoIcons.viewfinder,
                        iconColor: tk.accent,
                        title: s.t('useFaceId'),
                        trailing: Switch.adaptive(value: _faceId, onChanged: (v) => setState(() => _faceId = v)),
                      ),
                    ]),
                  PinPad(onDigit: _pinDigit, onBackspace: () {
                    if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
                  }),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _finish(),
              style: TextButton.styleFrom(foregroundColor: tk.ink2),
              child: Text(s.t('skip')),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.label, required this.backLabel, required this.onBack});
  final int step;
  final String label;
  final String backLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 24, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: backLabel,
            onPressed: onBack,
            icon: Icon(
              Directionality.of(context) == TextDirection.rtl ? CupertinoIcons.chevron_right : CupertinoIcons.chevron_left,
              color: tk.ink,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                for (var i = 1; i <= 3; i++)
                  Expanded(
                    child: Container(
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= step ? tk.accent : tk.raised,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: AppType.meta.copyWith(color: tk.ink3)),
        ],
      ),
    );
  }
}

/// AR / EN switch for the navy welcome screen.
class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget opt(String v, String label) => GestureDetector(
          onTap: () => onChanged(v),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36, minWidth: 64),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: value == v ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label,
                style: AppType.label.copyWith(color: value == v ? tk.primary : Colors.white, fontWeight: FontWeight.w800)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [opt('ar', 'العربية'), opt('en', 'English')]),
    );
  }
}
