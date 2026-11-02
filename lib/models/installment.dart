import '../services/date_utils.dart';

/// A monthly installment (قسط).
class Installment {
  Installment({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDay,
    required this.total,
    required this.remaining,
    required this.nextDue,
  });

  final String id;
  final String name;

  /// Amount paid every month.
  final double amount;

  /// Day of month the payment is due (1..31, clamped to month length).
  final int dueDay;

  /// Total number of installments.
  final int total;

  /// How many installments are still unpaid.
  int remaining;

  /// Date of the next unpaid installment.
  DateTime nextDue;

  bool get isFinished => remaining <= 0;
  int get paid => total - remaining;
  double get remainingAmount => amount * remaining;

  /// First due date on or after [from] for a given [dueDay].
  static DateTime firstDueFrom(DateTime from, int dueDay) {
    final today = dateOnly(from);
    final thisMonth = dueDateIn(today.year, today.month, dueDay);
    if (!thisMonth.isBefore(today)) return thisMonth;
    return dueDateIn(today.year, today.month + 1, dueDay);
  }

  /// Advance [nextDue] by one month.
  void advance() {
    nextDue = dueDateIn(nextDue.year, nextDue.month + 1, dueDay);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'dueDay': dueDay,
        'total': total,
        'remaining': remaining,
        'nextDue': nextDue.toIso8601String(),
      };

  factory Installment.fromJson(Map<String, dynamic> j) => Installment(
        id: j['id'] as String,
        name: j['name'] as String,
        amount: (j['amount'] as num).toDouble(),
        dueDay: j['dueDay'] as int,
        total: j['total'] as int,
        remaining: j['remaining'] as int,
        nextDue: DateTime.parse(j['nextDue'] as String),
      );
}
