import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../services/biometric_service.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/add_expense_sheet.dart' show showCategoryEditor;
import '../widgets/bank_sheet.dart';
import '../widgets/common.dart';
import 'bank_guide_screen.dart';
import 'lock_screen.dart' show PinDots, PinPad;
import 'month_screen.dart' show showSalarySheet;

/// Account: who you are, bank messages, budget, security and app settings.
/// Every choice opens a sheet, so rows never squeeze in either language.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final st = app.settings;
    final tk = context.tk;
    final top = MediaQuery.of(context).padding.top;

    Widget value(String v) => Text(v, style: AppType.label.copyWith(color: tk.ink3, fontWeight: FontWeight.w700));
    final themeNames = {'light': s.t('themeLight'), 'dark': s.t('themeDark'), 'system': s.t('themeSystem')};
    final langNames = {'ar': s.t('arabic'), 'en': s.t('english')};
    final genderNames = {'m': s.t('male'), 'f': s.t('female')};
    final sync = st.lastBankSync;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---------------------------------------------------- header
          Container(
            decoration: BoxDecoration(
              gradient: tk.hero,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            padding: EdgeInsets.fromLTRB(20, top + 16, 20, 24),
            child: Column(
              children: [
                Text(s.t('profile'), style: AppType.title.copyWith(color: Colors.white)),
                const SizedBox(height: 18),
                Avatar(name: st.name, size: 76),
                const SizedBox(height: 12),
                Text(st.name, style: AppType.page.copyWith(color: Colors.white)),
                Text(s.t('memberSince', {'d': s.dayMonth(st.startDate)}),
                    style: AppType.label.copyWith(color: tk.onPrimary2)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.creditcard, color: tk.onPrimary2, size: 18),
                      const SizedBox(width: 10),
                      Text('${s.t('balance')}  ', style: AppType.label.copyWith(color: tk.onPrimary2)),
                      Text(s.money(st.balance), style: AppType.figure.copyWith(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------------------------------------------------- bank
                SectionHeader(s.t('bankTitle')),
                Group(indent: 68, children: [
                  Line(
                    leading: const IconTile(icon: CupertinoIcons.building_2_fill, color: Color(0xFF3B82F6), size: 38),
                    title: s.t('bankConnect'),
                    subtitle: sync == null
                        ? s.t('bankNever')
                        : s.t('bankLast', {'t': sameDay(sync, DateTime.now()) ? s.time(sync) : s.shortDate(sync)}),
                    chevron: true,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BankGuideScreen())),
                  ),
                  Line(
                    leading: const IconTile(icon: CupertinoIcons.doc_on_clipboard, color: Color(0xFF06B6D4), size: 38),
                    title: s.t('bankPaste'),
                    chevron: true,
                    onTap: () => showBankPaste(context),
                  ),
                  Line(
                    leading: IconTile(icon: CupertinoIcons.arrow_2_circlepath, color: tk.good, size: 38),
                    title: s.t('bankSync'),
                    subtitle: s.t('bankSyncHelp'),
                    trailing: Switch.adaptive(
                      value: st.bankSyncBalance,
                      onChanged: (v) => app.setBankOptions(syncBalance: v),
                    ),
                  ),
                  Line(
                    leading: IconTile(icon: CupertinoIcons.bolt, color: tk.accent, size: 38),
                    title: s.t('bankAuto'),
                    trailing: Switch.adaptive(value: st.bankAutoAdd, onChanged: (v) => app.setBankOptions(autoAdd: v)),
                  ),
                ]),

                // ---------------------------------------------------- account
                SectionHeader(s.t('account')),
                Group(indent: 68, children: [
                  Line(
                    icon: CupertinoIcons.person,
                    iconColor: tk.primaryEnd,
                    title: s.t('yourName'),
                    trailing: value(st.name),
                    chevron: true,
                    onTap: () => _editName(context, app),
                  ),
                  Line(
                    icon: CupertinoIcons.money_pound_circle,
                    iconColor: tk.good,
                    title: s.t('salaryTitle'),
                    trailing: value(st.hasSalary ? s.money(st.salary) : s.t('safetyNone')),
                    chevron: true,
                    onTap: () => showSalarySheet(context),
                  ),
                  Line(
                    icon: CupertinoIcons.slider_horizontal_3,
                    iconColor: tk.accent,
                    title: s.t('limits'),
                    trailing: value('${s.num0(st.minDaily)} / ${s.num0(st.maxDaily)}'),
                    chevron: true,
                    onTap: () => _editLimits(context, app),
                  ),
                  Line(
                    icon: CupertinoIcons.lock_shield,
                    iconColor: const Color(0xFF10B981),
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
                    iconColor: const Color(0xFF8B5CF6),
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

                // ---------------------------------------------------- categories
                SectionHeader(s.t('categories'), action: s.t('addCategory'), onAction: () async {
                  final r = await showCategoryEditor(context);
                  if (r != null) await app.addCategory(r.$1, r.$2);
                }),
                Panel(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in app.allCategories)
                        Chip(
                          avatar: Icon(c.icon, size: 16, color: c.color),
                          label: Text(c.label(app.isAr), style: AppType.label.copyWith(color: tk.ink)),
                          backgroundColor: tk.raised,
                          side: BorderSide.none,
                          onDeleted: c.custom
                              ? () async {
                                  if (await confirm(context, s, s.t('deleteCategory'), ok: s.t('delete'), danger: true)) {
                                    await app.deleteCategory(c);
                                  }
                                }
                              : null,
                        ),
                    ],
                  ),
                ),

                // ---------------------------------------------------- security
                SectionHeader(s.t('security')),
                Group(indent: 68, children: [
                  Line(
                    icon: CupertinoIcons.lock,
                    iconColor: tk.primaryEnd,
                    title: st.pinHash == null ? s.t('setPin') : s.t('changePin'),
                    trailing: value(st.pinHash == null ? s.t('pinOff') : s.t('pinSet')),
                    chevron: true,
                    onTap: () => _setPin(context, app),
                  ),
                  if (st.pinHash != null) ...[
                    Line(
                      icon: CupertinoIcons.viewfinder,
                      iconColor: tk.accent,
                      title: s.t('faceId'),
                      trailing: Switch.adaptive(
                        value: st.biometrics,
                        onChanged: (v) async {
                          if (v && !await BiometricService().available()) return;
                          await app.setBiometrics(v);
                        },
                      ),
                    ),
                    Line(
                      icon: CupertinoIcons.lock_fill,
                      iconColor: tk.ink2,
                      title: s.t('lockNow'),
                      onTap: app.lock,
                    ),
                    Line(
                      icon: CupertinoIcons.lock_open,
                      iconColor: tk.danger,
                      title: s.t('removePin'),
                      titleColor: tk.danger,
                      onTap: () async {
                        await app.setPin(null);
                        await app.setBiometrics(false);
                      },
                    ),
                  ],
                ]),

                // ---------------------------------------------------- app
                SectionHeader(s.t('appSection')),
                Group(indent: 68, children: [
                  Line(
                    icon: CupertinoIcons.globe,
                    iconColor: const Color(0xFF3B82F6),
                    title: s.t('language'),
                    trailing: value(langNames[st.lang]!),
                    chevron: true,
                    onTap: () async {
                      final v = await pickOption(context, title: s.t('language'), options: langNames, current: st.lang);
                      if (v != null) await app.setLanguage(v);
                    },
                  ),
                  Line(
                    icon: CupertinoIcons.moon,
                    iconColor: const Color(0xFF6366F1),
                    title: s.t('appearance'),
                    trailing: value(themeNames[st.themeMode]!),
                    chevron: true,
                    onTap: () async {
                      final v = await pickOption(context,
                          title: s.t('appearance'), options: themeNames, current: st.themeMode);
                      if (v != null) await app.setThemeMode(v);
                    },
                  ),
                  if (app.isAr)
                    Line(
                      icon: CupertinoIcons.person_2,
                      iconColor: const Color(0xFFEC4899),
                      title: s.t('addressAs'),
                      trailing: value(genderNames[st.gender]!),
                      chevron: true,
                      onTap: () async {
                        final v = await pickOption(context,
                            title: s.t('addressAs'), options: genderNames, current: st.gender);
                        if (v != null) await app.setGender(v);
                      },
                    ),
                  Line(
                    icon: CupertinoIcons.bell,
                    iconColor: tk.warn,
                    title: s.t('notifications'),
                    trailing: Switch.adaptive(value: st.notifications, onChanged: app.setNotifications),
                  ),
                  Line(
                    icon: CupertinoIcons.clock,
                    iconColor: const Color(0xFF0EA5E9),
                    title: s.t('reminderTime'),
                    trailing: value(
                      MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: st.reminderHour, minute: 0)),
                    ),
                    chevron: true,
                    onTap: st.notifications
                        ? () async {
                            final t = await showTimePicker(
                                context: context, initialTime: TimeOfDay(hour: st.reminderHour, minute: 0));
                            if (t != null) await app.setReminderHour(t.hour);
                          }
                        : null,
                  ),
                ]),

                const SizedBox(height: 26),
                Group(indent: 68, children: [
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
          ),
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
      isScrollControlled: true,
      builder: (_) => _PinSetupSheet(title: s.t('setPin')),
    );
    if (first == null || first.length != 4 || !context.mounted) return;
    final second = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
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
