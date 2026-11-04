import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/txn.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// One transaction: coloured category tile, title, time, signed amount.
/// Swipe or long-press to delete.
class TxnRow extends StatelessWidget {
  const TxnRow(this.t, {super.key, this.showDate = false});
  final Txn t;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final s = app.s;
    final tk = context.tk;
    final cat = app.categoryById(t.category);
    final when = showDate ? '${s.shortDate(t.date)} · ${s.time(t.date)}' : s.time(t.date);
    final (IconData icon, Color color, String title, String subtitle) = switch (t.type) {
      TxnType.expense => (
          cat.icon,
          cat.color,
          t.note.isEmpty ? cat.label(app.isAr) : t.note,
          t.note.isEmpty ? when : '${cat.label(app.isAr)} · $when',
        ),
      TxnType.installment => (CupertinoIcons.calendar, tk.accent, app.installmentName(t), s.t('type_installment')),
      TxnType.deposit => (
          CupertinoIcons.arrow_down_circle,
          tk.good,
          t.note.isEmpty ? s.t('type_deposit') : t.note,
          when,
        ),
      TxnType.salary => (CupertinoIcons.money_pound_circle, tk.good, s.t('type_salary'), when),
    };
    final income = t.isIncome;

    Future<bool> ask() => confirm(context, s, s.t('deleteTxn'), ok: s.t('delete'), danger: true);

    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: tk.danger,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(CupertinoIcons.trash, color: Colors.white),
      ),
      confirmDismiss: (_) => ask(),
      onDismissed: (_) => app.deleteTxn(t),
      child: Line(
        leading: IconTile(icon: icon, color: color),
        title: title,
        subtitle: subtitle,
        trailing: Text(
          '${income ? '+' : '-'}${s.money(t.amount)}',
          style: AppType.bodyStrong.copyWith(color: income ? tk.good : tk.ink),
        ),
        onLongPress: () async {
          if (await ask()) await app.deleteTxn(t);
        },
      ),
    );
  }
}
