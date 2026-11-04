/// Kind of money movement.
/// - [expense]: daily spending, counted against the daily limit.
/// - [installment]: an installment payment, NOT counted against the daily limit.
/// - [deposit]: money added to the balance by hand.
/// - [salary]: the monthly salary, added automatically on payday.
enum TxnType { expense, installment, deposit, salary }

class Txn {
  Txn({
    required this.id,
    required this.amount,
    required this.date,
    this.note = '',
    this.category = 'other',
    this.type = TxnType.expense,
  });

  final String id;
  final double amount;
  final DateTime date;
  final String note;

  /// Category id (see `builtInCategories` and custom categories).
  final String category;
  final TxnType type;

  bool get isIncome => type == TxnType.deposit || type == TxnType.salary;

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'category': category,
        'type': type.name,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        note: (j['note'] as String?) ?? '',
        category: (j['category'] as String?) ?? 'other',
        type: TxnType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => TxnType.expense,
        ),
      );
}
