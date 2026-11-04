import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'month_screen.dart' show DayPicker;

/// First-run setup: name, how to be addressed, balance, limits, salary.
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
  final _salary = TextEditingController();
  String _lang = 'ar';
  String _gender = 'm';
  int _payday = 1;

  @override
  void dispose() {
    for (final c in [_name, _balance, _min, _max, _salary]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    context.read<AppState>().completeOnboarding(
          name: _name.text.trim(),
          balance: parseAmount(_balance.text)!,
          minDaily: parseAmount(_min.text)!,
          maxDaily: parseAmount(_max.text)!,
          lang: _lang,
          gender: _gender,
          salary: parseAmount(_salary.text) ?? 0,
          salaryDay: _payday,
        );
  }

  @override
  Widget build(BuildContext context) {
    final s = S(_lang, _gender);
    final tk = context.tk;
    Widget gap([double h = 14]) => SizedBox(height: h);

    return Directionality(
      textDirection: _lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Row(
                  children: [
                    BrandMark(size: 40, isAr: _lang == 'ar'),
                    const Spacer(),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: 'ar', label: Text(s.t('arabic'))),
                        ButtonSegment(value: 'en', label: Text(s.t('english'))),
                      ],
                      selected: {_lang},
                      onSelectionChanged: (v) => setState(() => _lang = v.first),
                    ),
                  ],
                ),
                gap(32),
                Text(s.t('welcome'), style: AppType.page.copyWith(color: tk.ink)),
                gap(6),
                Text(s.t('onbIntro'), style: AppType.body.copyWith(color: tk.ink2)),
                gap(28),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  decoration: InputDecoration(labelText: s.t('yourName')),
                  validator: (v) => (v == null || v.trim().isEmpty) ? s.t('required') : null,
                ),
                if (_lang == 'ar') ...[
                  gap(),
                  Row(
                    children: [
                      Expanded(child: Text(s.t('addressAs'), style: AppType.body.copyWith(color: tk.ink2))),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: 'm', label: Text(s.t('male'))),
                          ButtonSegment(value: 'f', label: Text(s.t('female'))),
                        ],
                        selected: {_gender},
                        onSelectionChanged: (v) => setState(() => _gender = v.first),
                      ),
                    ],
                  ),
                ],
                gap(),
                AmountField(
                  controller: _balance,
                  label: s.t('currentBalance'),
                  suffix: s.currency,
                  validator: positiveValidator(s, allowZero: true),
                ),
                gap(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AmountField(
                        controller: _min,
                        label: s.t('dailyMin'),
                        suffix: s.currency,
                        validator: positiveValidator(s),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AmountField(
                        controller: _max,
                        label: s.t('dailyMax'),
                        suffix: s.currency,
                        validator: (v) {
                          final base = positiveValidator(s)(v);
                          if (base != null) return base;
                          final mn = parseAmount(_min.text);
                          if (mn != null && parseAmount(v!)! < mn) return s.t('minMaxError');
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text('${s.t('minHelp')}. ${s.t('maxHelp')}.', style: AppType.meta.copyWith(color: tk.ink3)),
                ),
                gap(20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: AmountField(controller: _salary, label: s.t('salaryOptional'), suffix: s.currency),
                    ),
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
                gap(32),
                FilledButton(onPressed: _submit, child: Text(s.t('start'))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
