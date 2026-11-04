import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/add_expense_sheet.dart' show showCategoryEditor;
import '../widgets/common.dart';
import 'lock_screen.dart' show PinDots, PinPad;
import 'month_screen.dart' show showSalarySheet;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final st = app.settings;
    final tk = context.tk;

    Widget value(String v) => Text(v, style: AppType.body.copyWith(color: tk.ink2));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          PageTitle(s.t('profile')),
          const SizedBox(height: 12),
          Group(children: [
            Line(
              title: st.name,
              subtitle: '${s.t('balance')}: ${s.money(st.balance)}',
              chevron: true,
              onTap: () => _editName(context, app),
            ),
          ]),

          SectionHeader(s.t('settings')),
          Group(children: [
            Line(
              icon: CupertinoIcons.moon,
              title: s.t('appearance'),
              trailing: _Segmented(
                value: st.themeMode,
                options: {'dark': s.t('themeDark'), 'light': s.t('themeLight'), 'system': s.t('themeSystem')},
                onChanged: app.setThemeMode,
              ),
            ),
            Line(
              icon: CupertinoIcons.globe,
              title: s.t('language'),
              trailing: _Segmented(
                value: st.lang,
                options: {'ar': s.t('arabic'), 'en': s.t('english')},
                onChanged: app.setLanguage,
              ),
            ),
            if (app.isAr)
              Line(
                icon: CupertinoIcons.person,
                title: s.t('addressAs'),
                trailing: _Segmented(
                  value: st.gender,
                  options: {'m': s.t('male'), 'f': s.t('female')},
                  onChanged: app.setGender,
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Group(children: [
            Line(
              icon: CupertinoIcons.slider_horizontal_3,
              title: s.t('limits'),
              trailing: value('${s.num0(st.minDaily)} / ${s.num0(st.maxDaily)}'),
              chevron: true,
              onTap: () => _editLimits(context, app),
            ),
            Line(
              icon: CupertinoIcons.money_pound_circle,
              title: s.t('salaryTitle'),
              trailing: value(st.hasSalary ? s.money(st.salary) : s.t('safetyNone')),
              chevron: true,
              onTap: () => showSalarySheet(context),
            ),
            Line(
              icon: CupertinoIcons.lock,
              title: s.t('safety'),
              trailing: value(st.safetyBalance > 0 ? s.money(st.safetyBalance) : s.t('safetyNone')),
              chevron: true,
              onTap: () async {
                final v = await askAmount(context, s,
                    title: s.t('safety'), helper: s.t('safetyHelp'), initial: st.safetyBalance, allowZero: true);
                if (v != null) await app.setSafetyBalance(v);
              },
            ),
            Line(
              icon: CupertinoIcons.pencil,
              title: s.t('editBalance'),
              trailing: value(s.money(st.balance)),
              chevron: true,
              onTap: () async {
                final v = await askAmount(context, s,
                    title: s.t('setBalance'), helper: s.t('setBalanceHelp'), initial: st.balance, allowZero: true);
                if (v != null) await app.setBalance(v);
              },
            ),
          ]),

          SectionHeader(s.t('categories'), action: s.t('addCategory'), onAction: () async {
            final r = await showCategoryEditor(context);
            if (r != null) await app.addCategory(r.$1, r.$2);
          }),
          if (st.customCategories.isEmpty)
            Text(
              app.allCategories.map((c) => c.label(app.isAr)).join(' · '),
              style: AppType.label.copyWith(color: tk.ink3),
            )
          else
            Group(children: [
              for (final c in st.customCategories)
                Line(
                  icon: c.icon,
                  title: c.label(app.isAr),
                  trailing: IconButton(
                    tooltip: s.t('delete'),
                    icon: Icon(CupertinoIcons.trash, size: 18, color: tk.ink3),
                    onPressed: () async {
                      if (await confirm(context, s, s.t('deleteCategory'), ok: s.t('delete'), danger: true)) {
                        await app.deleteCategory(c);
                      }
                    },
                  ),
                ),
            ]),

          SectionHeader(s.t('notifications')),
          Group(children: [
            Line(
              icon: CupertinoIcons.bell,
              title: s.t('notifications'),
              trailing: Switch.adaptive(value: st.notifications, onChanged: app.setNotifications),
            ),
            Line(
              icon: CupertinoIcons.clock,
              title: s.t('reminderTime'),
              trailing: value(
                MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: st.reminderHour, minute: 0)),
              ),
              chevron: true,
              onTap: st.notifications
                  ? () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: st.reminderHour, minute: 0),
                      );
                      if (t != null) await app.setReminderHour(t.hour);
                    }
                  : null,
            ),
          ]),

          SectionHeader(s.t('pinLock')),
          Group(children: [
            if (st.pinHash == null)
              Line(
                icon: CupertinoIcons.lock,
                title: s.t('setPin'),
                chevron: true,
                onTap: () => _setPin(context, app),
              )
            else
              Line(
                icon: CupertinoIcons.lock_fill,
                iconColor: tk.accent,
                title: s.t('pinSet'),
                trailing: TextButton(onPressed: () => app.setPin(null), child: Text(s.t('removePin'))),
              ),
          ]),

          const SizedBox(height: 28),
          Group(children: [
            Line(
              icon: CupertinoIcons.trash,
              iconColor: tk.danger,
              title: s.t('resetData'),
              titleColor: tk.danger,
              onTap: () async {
                if (await confirm(context, s, s.t('resetConfirm'), ok: s.t('delete'), danger: true)) {
                  await app.resetAll();
                }
              },
            ),
          ]),
          const SizedBox(height: 16),
          Center(child: Text(s.t('about'), style: AppType.meta.copyWith(color: tk.ink3))),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, AppState app) async {
    final s = app.s;
    final c = TextEditingController(text: app.settings.name);
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: s.t('yourName'))),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(s.t('save'))),
          ],
        ),
      ),
    );
    if (r != null && r.isNotEmpty) await app.setName(r);
  }

  Future<void> _editLimits(BuildContext context, AppState app) async {
    final s = app.s;
    final mn = TextEditingController(text: s.num0(app.settings.minDaily).replaceAll(',', ''));
    final mx = TextEditingController(text: s.num0(app.settings.maxDaily).replaceAll(',', ''));
    final key = GlobalKey<FormState>();
    final ok = await showModalBottomSheet<bool>(
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
              Text(s.t('limits'), style: AppType.title.copyWith(color: ctx.tk.ink)),
              const SizedBox(height: 16),
              AmountField(
                  controller: mn,
                  label: s.t('dailyMin'),
                  helper: s.t('minHelp'),
                  suffix: s.currency,
                  validator: positiveValidator(s)),
              const SizedBox(height: 12),
              AmountField(
                controller: mx,
                label: s.t('dailyMax'),
                helper: s.t('maxHelp'),
                suffix: s.currency,
                validator: (v) {
                  final base = positiveValidator(s)(v);
                  if (base != null) return base;
                  final a = parseAmount(mn.text);
                  if (a != null && parseAmount(v!)! < a) return s.t('minMaxError');
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (key.currentState!.validate()) Navigator.pop(ctx, true);
                },
                child: Text(s.t('save')),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) await app.setLimits(parseAmount(mn.text)!, parseAmount(mx.text)!);
  }

  Future<void> _setPin(BuildContext context, AppState app) async {
    final s = app.s;
    final first = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _PinSetupSheet(title: s.t('setPin')),
    );
    if (first == null || first.length != 4 || !context.mounted) return;
    final second = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _PinSetupSheet(title: s.t('confirmPin')),
    );
    if (!context.mounted) return;
    if (second == first) {
      await app.setPin(first);
    } else if (second != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('pinMismatch'))));
    }
  }
}

/// Compact segmented control for a settings row.
class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.options, required this.onChanged});
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      segments: [for (final e in options.entries) ButtonSegment(value: e.key, label: Text(e.value))],
      selected: {value},
      onSelectionChanged: (v) => onChanged(v.first),
    );
  }
}

class _PinSetupSheet extends StatefulWidget {
  const _PinSetupSheet({required this.title});
  final String title;

  @override
  State<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<_PinSetupSheet> {
  String _pin = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: AppType.title.copyWith(color: context.tk.ink)),
          const SizedBox(height: 8),
          PinDots(length: _pin.length),
          PinPad(
            onDigit: (d) {
              if (_pin.length >= 4) return;
              setState(() => _pin += d);
              if (_pin.length == 4) Navigator.pop(context, _pin);
            },
            onBackspace: () {
              if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
