import 'package:flutter/material.dart';

/// Kind of money movement.
/// - [expense]: daily spending, counted against the daily limit.
/// - [installment]: an installment payment, NOT counted against the daily limit.
/// - [deposit]: money added to the balance (salary, etc.).
enum TxnType { expense, installment, deposit }

/// Spending categories with an icon each.
enum ExpenseCategory {
  food(Icons.restaurant_rounded),
  transport(Icons.directions_bus_rounded),
  shopping(Icons.shopping_bag_rounded),
  bills(Icons.receipt_long_rounded),
  fun(Icons.celebration_rounded),
  health(Icons.local_hospital_rounded),
  other(Icons.more_horiz_rounded);

  const ExpenseCategory(this.icon);
  final IconData icon;

  static ExpenseCategory fromName(String? name) =>
      ExpenseCategory.values.firstWhere((c) => c.name == name, orElse: () => ExpenseCategory.other);
}

class Txn {
  Txn({
    required this.id,
    required this.amount,
    required this.date,
    this.note = '',
    this.category = ExpenseCategory.other,
    this.type = TxnType.expense,
  });

  final String id;
  final double amount;
  final DateTime date;
  final String note;
  final ExpenseCategory category;
  final TxnType type;

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'category': category.name,
        'type': type.name,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        note: (j['note'] as String?) ?? '',
        category: ExpenseCategory.fromName(j['category'] as String?),
        type: TxnType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => TxnType.expense,
        ),
      );
}
