import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../l10n/strings.dart';
import '../models/installment.dart';
import '../models/settings.dart';
import '../models/txn.dart';
import '../services/budget_engine.dart';
import '../services/date_utils.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

/// What happened when an expense was added, so the UI can react.
class ExpenseOutcome {
  ExpenseOutcome(this.before, this.after);
  final DayBudget before;
  final DayBudget after;

  bool get crossedTarget =>
      before.status == BudgetStatus.safe && after.status == BudgetStatus.warning;
  bool get crossedLimit =>
      before.status != BudgetStatus.over && after.status == BudgetStatus.over;
}

class AppState extends ChangeNotifier {
  AppState(this._storage, this._notifications);

  final StorageService _storage;
  final NotificationService _notifications;

  late AppSettings settings;
  List<Txn> txns = [];
  List<Installment> installments = [];

  /// dayKey -> outing budget.
  Map<String, double> outings = {};

  /// Installments auto-paid during the last [processDueInstallments] call.
  List<Installment> lastAutoPaid = [];

  bool unlocked = false;

  S get s => S(settings.lang);
  bool get isAr => settings.lang == 'ar';

  // ---------------------------------------------------------------- loading

  Future<void> load() async {
    settings = _storage.loadSettings();
    txns = _storage.loadTxns()..sort((a, b) => b.date.compareTo(a.date));
    installments = _storage.loadInstallments();
    outings = _storage.loadOutings();
    unlocked = settings.pinHash == null;
    if (settings.onboarded) {
      await processDueInstallments();
      await _reschedule();
    }
  }

  /// Called when the app is resumed: pay due installments, refresh reminders.
  Future<void> refresh() async {
    if (!settings.onboarded) return;
    final paid = await processDueInstallments();
    if (paid) await _reschedule();
    notifyListeners();
  }

  // ---------------------------------------------------------------- budget

  BudgetEngine get engine => BudgetEngine(
        minDaily: settings.minDaily,
        maxDaily: settings.maxDaily,
        startDate: settings.startDate,
        spentByDay: spentByDay,
        outingBudgets: outings,
      );

  Map<String, double> get spentByDay {
    final m = <String, double>{};
    for (final t in txns.where((t) => t.type == TxnType.expense)) {
      final k = dayKey(t.date);
      m[k] = (m[k] ?? 0) + t.amount;
    }
    return m;
  }

  DayBudget get today => engine.forDay(DateTime.now());

  DayBudget budgetFor(DateTime day) => engine.forDay(day);

  /// What tomorrow's allowance will be given today's spending so far.
  DayBudget get tomorrow {
    final n = DateTime.now();
    return engine.forDay(DateTime(n.year, n.month, n.day + 1));
  }

  List<DayBudget> lastDays(int n) => engine.range(DateTime.now(), n);

  double spentBetween(DateTime from, DateTime to) => txns
      .where((t) =>
          t.type == TxnType.expense &&
          !t.date.isBefore(dateOnly(from)) &&
          t.date.isBefore(DateTime(to.year, to.month, to.day + 1)))
      .fold(0.0, (a, t) => a + t.amount);

  /// Average daily spending over the last [days] tracked days.
  double? averageDaily([int days = 14]) {
    final now = DateTime.now();
    final start = dateOnly(settings.startDate);
    final from = DateTime(now.year, now.month, now.day - (days - 1));
    final effectiveFrom = from.isBefore(start) ? start : from;
    final count = DateTime(now.year, now.month, now.day).difference(effectiveFrom).inDays + 1;
    if (count < 2 && spentByDay.isEmpty) return null;
    final total = spentBetween(effectiveFrom, now);
    if (total == 0) return null;
    return total / max(1, count);
  }

  /// Installments due within the next [days] days.
  double installmentsDueWithin(int days) {
    final now = dateOnly(DateTime.now());
    final until = DateTime(now.year, now.month, now.day + days);
    double sum = 0;
    for (final i in installments) {
      var due = i.nextDue;
      var left = i.remaining;
      while (left > 0 && !due.isAfter(until)) {
        sum += i.amount;
        left--;
        due = dueDateIn(due.year, due.month + 1, i.dueDay);
      }
    }
    return sum;
  }

  /// Estimated number of days the balance lasts after upcoming installments.
  int? balanceDays() {
    final avg = averageDaily();
    final perDay = avg ?? 0;
    if (perDay <= 0) return null;
    final free = settings.balance - installmentsDueWithin(30);
    return max(0, (free / perDay).floor());
  }

  Installment? get nextInstallment {
    final active = installments.where((i) => !i.isFinished).toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    return active.isEmpty ? null : active.first;
  }

  double get monthlyInstallments =>
      installments.where((i) => !i.isFinished).fold(0.0, (a, i) => a + i.amount);

  double get remainingInstallments =>
      installments.fold(0.0, (a, i) => a + i.remainingAmount);

  // ---------------------------------------------------------------- onboarding & settings

  Future<void> completeOnboarding({
    required String name,
    required double balance,
    required double minDaily,
    required double maxDaily,
    required String lang,
  }) async {
    settings
      ..name = name
      ..balance = balance
      ..minDaily = minDaily
      ..maxDaily = maxDaily
      ..lang = lang
      ..startDate = dateOnly(DateTime.now())
      ..onboarded = true;
    unlocked = true;
    await _storage.saveSettings(settings);
    await _notifications.requestPermission();
    await _reschedule();
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    settings.lang = lang;
    await _saveSettings();
  }

  Future<void> setLimits(double min, double max) async {
    settings
      ..minDaily = min
      ..maxDaily = max;
    await _saveSettings();
  }

  Future<void> setName(String name) async {
    settings.name = name;
    await _saveSettings();
  }

  Future<void> setBalance(double v) async {
    settings.balance = v;
    await _saveSettings();
  }

  Future<void> addMoney(double amount, String note) async {
    settings.balance += amount;
    txns.insert(
      0,
      Txn(
        id: _id(),
        amount: amount,
        date: DateTime.now(),
        note: note,
        type: TxnType.deposit,
      ),
    );
    await _storage.saveTxns(txns);
    await _saveSettings();
  }

  Future<void> setNotifications(bool v) async {
    settings.notifications = v;
    if (v) await _notifications.requestPermission();
    await _saveSettings();
  }

  Future<void> setReminderHour(int h) async {
    settings.reminderHour = h;
    await _saveSettings();
  }

  static String hashPin(String pin) => sha256.convert(utf8.encode('masrofy:$pin')).toString();

  Future<void> setPin(String? pin) async {
    settings.pinHash = pin == null ? null : hashPin(pin);
    await _saveSettings();
  }

  bool unlock(String pin) {
    if (settings.pinHash == null || hashPin(pin) == settings.pinHash) {
      unlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> resetAll() async {
    await _storage.clear();
    settings = AppSettings();
    txns = [];
    installments = [];
    outings = {};
    unlocked = true;
    await _notifications.reschedule(
        enabled: false, dailyHour: 21, dailyTitle: '', dailyBody: '', reminders: []);
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    await _storage.saveSettings(settings);
    await _reschedule();
    notifyListeners();
  }

  // ---------------------------------------------------------------- expenses

  /// Preview what the day would look like after spending [amount] on [date].
  ExpenseOutcome preview(double amount, DateTime date) {
    final before = engine.forDay(date);
    final m = spentByDay;
    final k = dayKey(date);
    m[k] = (m[k] ?? 0) + amount;
    final after = BudgetEngine(
      minDaily: settings.minDaily,
      maxDaily: settings.maxDaily,
      startDate: settings.startDate,
      spentByDay: m,
      outingBudgets: outings,
    ).forDay(date);
    return ExpenseOutcome(before, after);
  }

  Future<ExpenseOutcome> addExpense({
    required double amount,
    required DateTime date,
    String note = '',
    ExpenseCategory category = ExpenseCategory.other,
  }) async {
    final outcome = preview(amount, date);
    txns.add(Txn(id: _id(), amount: amount, date: date, note: note, category: category));
    txns.sort((a, b) => b.date.compareTo(a.date));
    settings.balance -= amount;
    await _storage.saveTxns(txns);
    await _storage.saveSettings(settings);

    if (sameDay(date, DateTime.now())) {
      final a = outcome.after;
      if (outcome.crossedLimit) {
        await _notifications.showNow(
          s.t('limitCrossedTitle'),
          s.t('limitCrossedBody', {'over': s.money(a.overBy), 'tomorrow': s.money(tomorrow.allowance)}),
        );
      } else if (outcome.crossedTarget) {
        await _notifications.showNow(
          s.t('targetReachedTitle'),
          s.t('targetReachedBody', {'spent': s.money(a.spent), 'left': s.money(a.remaining)}),
        );
      }
    }
    await _reschedule();
    notifyListeners();
    return outcome;
  }

  Future<void> deleteTxn(Txn t) async {
    txns.removeWhere((e) => e.id == t.id);
    if (t.type == TxnType.deposit) {
      settings.balance -= t.amount;
    } else {
      settings.balance += t.amount;
    }
    if (t.type == TxnType.installment) {
      // Restore the installment count if it still exists.
      final inst = installments.where((i) => t.note == i.id).firstOrNull;
      if (inst != null) {
        inst.remaining = min(inst.total, inst.remaining + 1);
        inst.nextDue = dueDateIn(inst.nextDue.year, inst.nextDue.month - 1, inst.dueDay);
        await _storage.saveInstallments(installments);
      }
    }
    await _storage.saveTxns(txns);
    await _saveSettings();
  }

  // ---------------------------------------------------------------- installments

  Future<void> addInstallment({
    required String name,
    required double amount,
    required int dueDay,
    required int total,
    required int remaining,
  }) async {
    installments.add(Installment(
      id: _id(),
      name: name,
      amount: amount,
      dueDay: dueDay,
      total: max(total, remaining),
      remaining: remaining,
      nextDue: Installment.firstDueFrom(DateTime.now(), dueDay),
    ));
    await _storage.saveInstallments(installments);
    await processDueInstallments();
    await _reschedule();
    notifyListeners();
  }

  Future<void> deleteInstallment(Installment i) async {
    installments.removeWhere((e) => e.id == i.id);
    await _storage.saveInstallments(installments);
    await _reschedule();
    notifyListeners();
  }

  Future<void> payInstallment(Installment i, {bool auto = false}) async {
    if (i.isFinished) return;
    settings.balance -= i.amount;
    // `note` keeps the installment id so deleting the entry can undo it;
    // the name is shown via [installmentName].
    txns.add(Txn(
      id: _id(),
      amount: i.amount,
      date: auto ? i.nextDue.add(const Duration(hours: 9)) : DateTime.now(),
      note: i.id,
      category: ExpenseCategory.bills,
      type: TxnType.installment,
    ));
    txns.sort((a, b) => b.date.compareTo(a.date));
    i.remaining--;
    i.advance();
    await _storage.saveInstallments(installments);
    await _storage.saveTxns(txns);
    await _storage.saveSettings(settings);
    await _notifications.showNow(
      s.t('instPaidNotif', {'name': i.name}),
      s.t('instPaidBody', {'x': s.money(i.amount), 'n': i.remaining}),
    );
    if (!auto) {
      await _reschedule();
      notifyListeners();
    }
  }

  String installmentName(Txn t) =>
      installments.where((i) => i.id == t.note).firstOrNull?.name ?? s.t('type_installment');

  /// Automatically pay every installment whose due date has arrived.
  /// Returns true if anything was paid.
  Future<bool> processDueInstallments() async {
    final today = dateOnly(DateTime.now());
    lastAutoPaid = [];
    for (final i in installments) {
      while (!i.isFinished && !i.nextDue.isAfter(today)) {
        await payInstallment(i, auto: true);
        lastAutoPaid.add(i);
      }
    }
    return lastAutoPaid.isNotEmpty;
  }

  // ---------------------------------------------------------------- outings

  Future<void> setOuting(DateTime day, double budget) async {
    outings[dayKey(day)] = budget;
    await _storage.saveOutings(outings);
    await _reschedule();
    notifyListeners();
  }

  Future<void> removeOuting(String key) async {
    outings.remove(key);
    await _storage.saveOutings(outings);
    await _reschedule();
    notifyListeners();
  }

  List<MapEntry<DateTime, double>> get upcomingOutings {
    final today = dateOnly(DateTime.now());
    final list = outings.entries
        .map((e) => MapEntry(parseDayKey(e.key), e.value))
        .where((e) => !e.key.isBefore(today))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return list;
  }

  // ---------------------------------------------------------------- reminders

  Future<void> _reschedule() async {
    final reminders = <Reminder>[];
    var id = 1000;
    for (final i in installments.where((i) => !i.isFinished)) {
      final due = i.nextDue;
      final args = {'name': i.name};
      final body = s.t('instSoonBody', {'x': s.money(i.amount), 'date': s.shortDate(due)});
      reminders.add(Reminder(
        id: id++,
        when: DateTime(due.year, due.month, due.day - 2, 10),
        title: s.t('instSoonTitle', args),
        body: body,
      ));
      reminders.add(Reminder(
        id: id++,
        when: DateTime(due.year, due.month, due.day, 9),
        title: s.t('instTodayTitle', args),
        body: body,
      ));
    }
    for (final o in upcomingOutings) {
      reminders.add(Reminder(
        id: id++,
        when: DateTime(o.key.year, o.key.month, o.key.day - 1, 12),
        title: s.t('outingDay'),
        body: s.t('i_outing_tomorrow', {'x': s.money(o.value)}),
      ));
    }
    await _notifications.reschedule(
      enabled: settings.notifications,
      dailyHour: settings.reminderHour,
      dailyTitle: s.t('dailyReminderTitle'),
      dailyBody: s.t('dailyReminderBody'),
      reminders: reminders,
    );
  }

  static int _seq = 0;
  static String _id() => '${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
}
