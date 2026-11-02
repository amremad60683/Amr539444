import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// First-run setup: name, balance, daily limits, language.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _balance = TextEditingController();
  final _min = TextEditingController(text: '150');
  final _max = TextEditingController(text: '250');
  String _lang = 'ar';

  @override
  void dispose() {
    for (final c in [_name, _balance, _min, _max]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S(_lang);
    return Directionality(
      textDirection: _lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'ar', label: Text(s.t('arabic'))),
                      ButtonSegment(value: 'en', label: Text(s.t('english'))),
                    ],
                    selected: {_lang},
                    onSelectionChanged: (v) => setState(() => _lang = v.first),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.savings_rounded, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 20),
                Text(s.t('welcome'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(s.t('onbIntro'), style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: s.t('yourName'), prefixIcon: const Icon(Icons.person_rounded)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? s.t('required') : null,
                ),
                const SizedBox(height: 14),
                AmountField(
                  controller: _balance,
                  label: s.t('currentBalance'),
                  suffix: s.currency,
                  validator: positiveValidator(s, allowZero: true),
                ),
                const SizedBox(height: 14),
                AmountField(
                  controller: _min,
                  label: s.t('dailyMin'),
                  helper: s.t('minHelp'),
                  suffix: s.currency,
                  validator: positiveValidator(s),
                ),
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
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () {
                    if (!_form.currentState!.validate()) return;
                    context.read<AppState>().completeOnboarding(
                          name: _name.text.trim(),
                          balance: parseAmount(_balance.text)!,
                          minDaily: parseAmount(_min.text)!,
                          maxDaily: parseAmount(_max.text)!,
                          lang: _lang,
                        );
                  },
                  child: Text(s.t('start')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
