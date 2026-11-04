import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/assistant.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class _Msg {
  _Msg(this.text, {required this.fromUser});
  final String text;
  final bool fromUser;
}

/// Chat-style assistant: live reminders on top, quick questions at the bottom.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _msgs = <_Msg>[];
  final _scroll = ScrollController();

  void _ask(Assistant a, AssistantQuestion q) {
    setState(() {
      _msgs.add(_Msg(a.questionLabel(q), fromUser: true));
      _msgs.add(_Msg(a.answer(q), fromUser: false));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: easeOutExpo);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final tk = context.tk;
    final a = Assistant(app);
    final insights = a.insights();

    Color levelColor(InsightLevel l) => switch (l) {
          InsightLevel.danger => tk.danger,
          InsightLevel.warning => tk.warn,
          InsightLevel.good => tk.good,
          InsightLevel.info => tk.dark ? tk.ink2 : tk.primaryEnd,
        };

    return Scaffold(
      appBar: AppBar(title: Text(s.t('assistantTitle'))),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                HeroCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(CupertinoIcons.chat_bubble_2_fill, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(s.t('assistantIntro'), style: AppType.body.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Group(indent: 68, children: [
                  for (final i in insights) Line(icon: i.icon, iconColor: levelColor(i.level), title: i.text),
                ]),
                for (final m in _msgs) ...[
                  const SizedBox(height: 12),
                  _Bubble(text: m.text, fromUser: m.fromUser),
                ],
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: tk.surface, border: Border(top: BorderSide(color: tk.line))),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  children: [
                    for (final q in AssistantQuestion.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ActionChip(
                          backgroundColor: tk.raised,
                          side: BorderSide.none,
                          label: Text(a.questionLabel(q),
                              style: AppType.label.copyWith(color: tk.ink, fontWeight: FontWeight.w700)),
                          onPressed: () => _ask(a, q),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.fromUser});
  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final r = const Radius.circular(20);
    return Align(
      alignment: fromUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: fromUser ? (tk.dark ? tk.primaryEnd : tk.primary) : tk.surface,
          boxShadow: fromUser ? null : tk.cardShadow,
          borderRadius: BorderRadiusDirectional.only(
            topStart: r,
            topEnd: r,
            bottomStart: fromUser ? r : const Radius.circular(6),
            bottomEnd: fromUser ? const Radius.circular(6) : r,
          ),
        ),
        child: Text(text, style: AppType.body.copyWith(color: fromUser ? Colors.white : tk.ink)),
      ),
    );
  }
}
