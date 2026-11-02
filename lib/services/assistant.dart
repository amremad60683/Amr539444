import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'budget_engine.dart';
import 'date_utils.dart';

enum InsightLevel { info, good, warning, danger }

class Insight {
  Insight(this.text, this.level, this.icon);
  final String text;
  final InsightLevel level;
  final IconData icon;
}

/// Questions the user can ask the assistant.
enum AssistantQuestion { today, balance, installments, week, tip }

/// Local "smart assistant": reads your data and produces reminders,
/// warnings and answers. Runs fully on the phone, no internet needed.
class Assistant {
  Assistant(this.app);
  final AppState app;

  /// Proactive insights shown on the home screen and the assistant tab.
  List<Insight> insights() {
    final s = app.s;
    final out = <Insight>[];
    final t = app.today;
    final now = DateTime.now();

    if (t.status == BudgetStatus.over) {
      out.add(Insight(s.t('i_over_today', {'x': s.money(t.overBy)}),
          InsightLevel.danger, Icons.block_rounded));
    }
    if (t.deducted > 0) {
      out.add(Insight(s.t('deductedToday', {'x': s.money(t.deducted)}),
          InsightLevel.warning, Icons.trending_down_rounded));
    } else if (t.debtIn > 0) {
      out.add(Insight(s.t('i_debt', {'x': s.money(t.debtIn)}),
          InsightLevel.warning, Icons.trending_down_rounded));
    }

    for (final i in app.installments.where((i) => !i.isFinished)) {
      final days = dateOnly(i.nextDue).difference(dateOnly(now)).inDays;
      if (days == 0) {
        out.add(Insight(s.t('i_inst_today', {'name': i.name, 'x': s.money(i.amount)}),
            InsightLevel.warning, Icons.event_rounded));
      } else if (days > 0 && days <= 5) {
        out.add(Insight(
            s.t('i_inst_soon', {'name': i.name, 'x': s.money(i.amount), 'd': days}),
            InsightLevel.info,
            Icons.event_rounded));
      }
    }

    final inst30 = app.installmentsDueWithin(30);
    if (inst30 > 0 && app.settings.balance < inst30) {
      out.add(Insight(
          s.t('i_low_balance', {'bal': s.money(app.settings.balance), 'inst': s.money(inst30)}),
          InsightLevel.danger,
          Icons.account_balance_wallet_rounded));
    }

    final tomorrowKey = dayKey(DateTime(now.year, now.month, now.day + 1));
    if (app.outings.containsKey(tomorrowKey)) {
      out.add(Insight(s.t('i_outing_tomorrow', {'x': s.money(app.outings[tomorrowKey]!)}),
          InsightLevel.info, Icons.celebration_rounded));
    }

    if (t.spent == 0 && now.hour >= 18) {
      out.add(Insight(s.t('i_no_log'), InsightLevel.info, Icons.edit_note_rounded));
    }

    final streak = _streak();
    if (streak >= 3) {
      out.add(Insight(s.t('i_streak', {'d': streak}), InsightLevel.good,
          Icons.local_fire_department_rounded));
    }

    if (out.isEmpty) {
      out.add(Insight(s.t('i_all_good'), InsightLevel.good, Icons.check_circle_rounded));
    }
    return out;
  }

  /// Consecutive past days (before today) within the allowance.
  int _streak() {
    final start = dateOnly(app.settings.startDate);
    final days = app.lastDays(60).reversed.skip(1);
    var n = 0;
    for (final d in days) {
      if (d.day.isBefore(start)) break;
      if (d.status == BudgetStatus.over) break;
      n++;
    }
    return n;
  }

  String answer(AssistantQuestion q) {
    final s = app.s;
    switch (q) {
      case AssistantQuestion.today:
        final t = app.today;
        if (t.status == BudgetStatus.over) {
          return s.t('a_today_over', {
            'allow': s.money(t.allowance),
            'over': s.money(t.overBy),
            'carry': s.money(t.debtOut),
          });
        }
        return s.t('a_today', {
          'allow': s.money(t.allowance),
          'spent': s.money(t.spent),
          'left': s.money(t.remaining),
          'target': s.money(t.target),
        });

      case AssistantQuestion.balance:
        final avg = app.averageDaily();
        final days = app.balanceDays();
        if (avg == null || days == null) {
          return s.t('a_balance_nodata', {'bal': s.money(app.settings.balance)});
        }
        return s.t('a_balance', {
          'bal': s.money(app.settings.balance),
          'inst': s.money(app.installmentsDueWithin(30)),
          'avg': s.money(avg),
          'd': days,
        });

      case AssistantQuestion.installments:
        final next = app.nextInstallment;
        if (next == null) return s.t('a_inst_none');
        return s.t('a_inst', {
          'n': app.installments.where((i) => !i.isFinished).length,
          'x': s.money(app.monthlyInstallments),
          'name': next.name,
          'amount': s.money(next.amount),
          'date': s.date(next.nextDue),
        });

      case AssistantQuestion.week:
        final days = app.lastDays(14);
        final thisWeek = days.sublist(7);
        final lastWeek = days.sublist(0, 7);
        final a = thisWeek.fold(0.0, (x, d) => x + d.spent);
        final b = lastWeek.fold(0.0, (x, d) => x + d.spent);
        final overDays = thisWeek.where((d) => d.status == BudgetStatus.over).length;
        String cmp;
        if (b == 0) {
          cmp = '';
        } else {
          final p = ((a - b) / b * 100).round();
          if (p <= -5) {
            cmp = s.t('a_week_better', {'p': -p});
          } else if (p >= 5) {
            cmp = s.t('a_week_worse', {'p': p});
          } else {
            cmp = s.t('a_week_same');
          }
        }
        return s.t('a_week', {
          'x': s.money(a),
          'avg': s.money(a / 7),
          'over': overDays,
          'cmp': cmp,
        }).trim();

      case AssistantQuestion.tip:
        final i = DateTime.now().millisecondsSinceEpoch % 5 + 1;
        return s.t('tip$i');
    }
  }

  String questionLabel(AssistantQuestion q) => app.s.t('q_${q.name}');
}
