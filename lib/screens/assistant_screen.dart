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
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: easeOutExpo);
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
          InsightLevel.good => tk.accent,
          InsightLevel.info => tk.ink2,
        };

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                PageTitle(s.t('assistantTitle')),
                const SizedBox(height: 12),
                _Bubble(text: s.t('assistantIntro'), fromUser: false),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Group(children: [
                      for (final i in insights)
                        Line(icon: i.icon, iconColor: levelColor(i.level), title: i.text),
                    ]),
                  ),
                ),
                for (final m in _msgs) ...[
                  const SizedBox(height: 10),
                  _Bubble(text: m.text, fromUser: m.fromUser),
                ],
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: tk.line))),
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                for (final q in AssistantQuestion.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text(a.questionLabel(q), style: AppType.label.copyWith(color: tk.ink)),
                      onPressed: () => _ask(a, q),
                    ),
                  ),
              ],
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
    return Align(
      alignment: fromUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromUser ? tk.ink : tk.surface,
          border: fromUser ? null : Border.all(color: tk.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(text, style: AppType.body.copyWith(color: fromUser ? tk.bg : tk.ink)),
      ),
    );
  }
}
