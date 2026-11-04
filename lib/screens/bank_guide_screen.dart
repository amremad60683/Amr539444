import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/bank_sheet.dart';
import '../widgets/common.dart';

/// How to have bank messages read automatically with an iPhone Shortcut.
class BankGuideScreen extends StatelessWidget {
  const BankGuideScreen({super.key});

  static const link = 'masrofy://bank?text=';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final steps = ['g1', 'g2', 'g3', 'g4', 'g5', 'g6'];

    return Scaffold(
      appBar: AppBar(title: Text(s.t('bankTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          HeroCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(CupertinoIcons.lock_shield, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('guideTitle'), style: AppType.title.copyWith(color: Colors.white)),
                      const SizedBox(height: 6),
                      Text(s.t('bankSub'), style: AppType.label.copyWith(color: tk.onPrimary2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Panel(child: Text(s.t('guideWhy'), style: AppType.body.copyWith(color: tk.ink2))),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++) ...[
            const SizedBox(height: 10),
            Panel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == steps.length - 1 ? tk.good : tk.accent,
                      shape: BoxShape.circle,
                    ),
                    child: i == steps.length - 1
                        ? const Icon(CupertinoIcons.checkmark_alt, color: Colors.white, size: 18)
                        : Text('${i + 1}',
                            style: AppType.label.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.t(steps[i]), style: AppType.body.copyWith(color: tk.ink)),
                        if (steps[i] == 'g5') ...[
                          const SizedBox(height: 10),
                          _CopyLink(text: link),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => showBankPaste(context),
            icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 20),
            label: Text(s.t('guideTry')),
          ),
          const SizedBox(height: 10),
          Text(s.t('guideNote'), textAlign: TextAlign.center, style: AppType.meta.copyWith(color: tk.ink3)),
        ],
      ),
    );
  }
}

class _CopyLink extends StatelessWidget {
  const _CopyLink({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Material(
      color: tk.raised,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('masrofy://bank?text=')));
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                Expanded(
                  child: Text(text,
                      style: AppType.label.copyWith(color: tk.ink, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                ),
                Icon(CupertinoIcons.doc_on_doc, size: 18, color: tk.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
