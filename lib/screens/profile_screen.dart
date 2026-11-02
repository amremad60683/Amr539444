import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'lock_screen.dart' show PinPad;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final st = app.settings;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(s.t('profile'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.seed,
                  child: Text(
                    st.name.isEmpty ? '?' : st.name.characters.first.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(st.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Text('${s.t('balance')}: ${s.money(st.balance)}'),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () => _editName(context, app),
                ),
              ],
            ),
          ),
          SectionTitle(s.t('settings')),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(s.t('language')),
                  trailing: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 'ar', label: Text(s.t('arabic'))),
                      ButtonSegment(value: 'en', label: Text(s.t('english'))),
                    ],
                    selected: {st.lang},
                    onSelectionChanged: (v) => app.setLanguage(v.first),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: Text(s.t('limits')),
                  subtitle: Text('${s.t('dailyMin')}: ${s.money(st.minDaily)}\n'
                      '${s.t('dailyMax')}: ${s.money(st.maxDaily)}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editLimits(context, app),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_rounded),
                  title: Text(s.t('editBalance')),
                  subtitle: Text(s.money(st.balance)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final v = await askAmount(context, s, title: s.t('setBalance'), initial: st.balance, allowZero: true);
                    if (v != null) await app.setBalance(v);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.savings_rounded),
                  title: Text(s.t('addMoney')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final v = await askAmount(context, s, title: s.t('addMoney'));
                    if (v != null) await app.addMoney(v, '');
                  },
                ),
              ],
            ),
          ),
          SectionTitle(s.t('notifications')),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_rounded),
                  title: Text(s.t('notifications')),
                  value: st.notifications,
                  onChanged: app.setNotifications,
                ),
                const Divider(height: 1),
                ListTile(
                  enabled: st.notifications,
                  leading: const Icon(Icons.alarm_rounded),
                  title: Text(s.t('reminderTime')),
                  trailing: Text(
                    MaterialLocalizations.of(context)
                        .formatTimeOfDay(TimeOfDay(hour: st.reminderHour, minute: 0)),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: st.reminderHour, minute: 0),
                    );
                    if (t != null) await app.setReminderHour(t.hour);
                  },
                ),
              ],
            ),
          ),
          SectionTitle(s.t('pinLock')),
          AppCard(
            padding: EdgeInsets.zero,
            child: st.pinHash == null
                ? ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: Text(s.t('setPin')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _setPin(context, app),
                  )
                : ListTile(
                    leading: const Icon(Icons.lock_rounded, color: AppColors.safe),
                    title: Text(s.t('pinSet')),
                    trailing: TextButton(onPressed: () => app.setPin(null), child: Text(s.t('removePin'))),
                  ),
          ),
          const SizedBox(height: 24),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: Theme.of(context).colorScheme.error),
              title: Text(s.t('resetData'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                if (await confirm(context, s, s.t('resetConfirm'), ok: s.t('delete'), danger: true)) {
                  await app.resetAll();
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone_android_rounded, size: 16),
              const SizedBox(width: 6),
              Text(s.t('about'), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, AppState app) async {
    final s = app.s;
    final c = TextEditingController(text: app.settings.name);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('yourName')),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(s.t('save'))),
        ],
      ),
    );
    if (r != null && r.isNotEmpty) await app.setName(r);
  }

  Future<void> _editLimits(BuildContext context, AppState app) async {
    final s = app.s;
    final mn = TextEditingController(text: s.num0(app.settings.minDaily).replaceAll(',', ''));
    final mx = TextEditingController(text: s.num0(app.settings.maxDaily).replaceAll(',', ''));
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('limits')),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('cancel'))),
          TextButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text(s.t('save')),
          ),
        ],
      ),
    );
    if (ok == true) await app.setLimits(parseAmount(mn.text)!, parseAmount(mx.text)!);
  }

  Future<void> _setPin(BuildContext context, AppState app) async {
    final s = app.s;
    final pin = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => _PinSetupSheet(title: s.t('setPin')),
    );
    if (pin != null && pin.length == 4) await app.setPin(pin);
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
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (i) => Container(
                margin: const EdgeInsets.all(8),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? scheme.primary : scheme.outlineVariant,
                ),
              ),
            ),
          ),
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
