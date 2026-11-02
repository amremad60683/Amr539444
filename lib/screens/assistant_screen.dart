import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/assistant.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'home_screen.dart' show insightColor;

class _Msg {
  _Msg(this.text, {required this.fromUser});
  final String text;
  final bool fromUser;
}

/// Chat-style smart assistant with quick questions and live insights.
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
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
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
    final a = Assistant(app);
    final insights = a.insights();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(s.t('assistantTitle')),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                _Bubble(text: s.t('assistantIntro'), fromUser: false),
                const SizedBox(height: 8),
                // Live insights as a bot message.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 340),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.t('insights'), style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        for (final i in insights)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(i.icon, size: 18, color: insightColor(context, i.level)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(i.text)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                for (final m in _msgs) ...[
                  const SizedBox(height: 8),
                  _Bubble(text: m.text, fromUser: m.fromUser),
                ],
              ],
            ),
          ),
          // Quick questions.
          SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (final q in AssistantQuestion.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        label: Text(a.questionLabel(q)),
                        onPressed: () => _ask(a, q),
                      ),
                    ),
                ],
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
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: fromUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromUser ? scheme.primary : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(text, style: TextStyle(color: fromUser ? scheme.onPrimary : scheme.onSurface)),
      ),
    );
  }
}
