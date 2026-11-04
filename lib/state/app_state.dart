import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../l10n/strings.dart';
import '../models/category.dart';
import '../models/installment.dart';
import '../models/settings.dart';
import '../models/txn.dart';
import '../services/bank_sms.dart';
import '../services/budget_engine.dart';
import '../services/date_utils.dart';
import '../services/month_plan.dart';
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

  StorageService get storage => _storage;
  NotificationService get notifications => _notifications;

  AppSettings settings = AppSettings();

  /// True once data is loaded from storage.
  bool ready = false;
  List<Txn> txns = [];
  List<Installment> installments = [];

  /// dayKey -> outing budget.
  Map<String, double> outings = {};

  bool unlocked = false;

  /// A bank message waiting for the user to confirm (from a Shortcut link
  /// or pasted). Shown as a sheet by the home shell.
  BankMessage? pendingBank;

  /// Set when a bank message was added automatically, for a short notice.
  BankMessage? lastAutoBank;

  S get s => S(settings.lang, settings.gender);
  bool get isAr => settings.lang == 'ar';

  // ---------------------------------------------------------------- loading

  Future<void> load() async {
    settings = _storage.loadSettings();
    txns = _storage.loadTxns()..sort((a, b) => b.date.compareTo(a.date));
    installments = _storage.loadInstallments();
    outings = _storage.loadOutings();
    unlocked = settings.pinHash == null;
    if (settings.onboarded) {
      await processAutomatic();
      await _reschedule();
    }
    ready = true;
    notifyListeners();
  }

  /// Called when the app is resumed: pay due installments, add salary,
  /// refresh reminders.
  Future<void> refresh() async {
    if (!settings.onboarded) return;
    if (await processAutomatic()) await _reschedule();
    notifyListeners();
  }

  /// Runs everything that happens by itself on a date. Returns true if
  /// anything changed.
  Future<bool> processAutomatic() async {
    final a = await processDueInstallments();
    final b = await processSalary();
    return a || b;
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

  Iterable<Txn> _between(TxnType type, DateTime from, DateTime to) => txns.where((t) =>
      t.type == type &&
      !t.date.isBefore(dateOnly(from)) &&
      t.date.isBefore(DateTime(to.year, to.month, to.day + 1)));

  double spentBetween(DateTime from, DateTime to) =>
      _between(TxnType.expense, from, to).fold(0.0, (a, t) => a + t.amount);

  double installmentsPaidBetween(DateTime from, DateTime to) =>
      _between(TxnType.installment, from, to).fold(0.0, (a, t) => a + t.amount);

  /// Category id -> amount spent between [from] and [to], largest first.
  List<MapEntry<CategoryDef, double>> spentByCategory(DateTime from, DateTime to) {
    final m = <String, double>{};
    for (final t in _between(TxnType.expense, from, to)) {
      final id = categoryById(t.category).id;
      m[id] = (m[id] ?? 0) + t.amount;
    }
    return (m.entries.map((e) => MapEntry(categoryById(e.key), e.value)).toList()
      ..sort((a, b) => b.value.compareTo(a.value)));
  }

  /// Average daily spending over the last [days] tracked days.
  double? averageDaily([int days = 14]) {
    final now = DateTime.now();
    final start = dateOnly(settings.startDate);
    final from = DateTime(now.year, now.month, now.day - (days - 1));
    final effectiveFrom = from.isBefore(start) ? start : from;
    final count = DateTime(now.year, now.month, now.day).difference(effectiveFrom).inDays + 1;
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
    final perDay = averageDaily() ?? 0;
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

  MonthPlan get monthPlan => MonthPlan.build(
        now: DateTime.now(),
        balance: settings.balance,
        salary: settings.salary,
        salaryDay: settings.salaryDay,
        nextSalary: settings.nextSalary,
        safetyBalance: settings.safetyBalance,
        spentByDay: spentByDay,
        installmentsPaidBetween: installmentsPaidBetween,
        installments: installments,
        trackingStart: settings.startDate,
      );

  // ---------------------------------------------------------------- categories

  List<CategoryDef> get allCategories => [...builtInCategories, ...settings.customCategories];

  CategoryDef categoryById(String id) =>
      allCategories.where((c) => c.id == id).firstOrNull ?? builtInCategories.last;

  Future<void> addCategory(String name, String iconKey) async {
    settings.customCategories.add(
      CategoryDef(id: 'c_${_id()}', ar: name, en: name, iconKey: iconKey, custom: true),
    );
    await _saveSettings();
  }

  Future<void> deleteCategory(CategoryDef c) async {
    settings.customCategories.removeWhere((e) => e.id == c.id);
    txns = [
      for (final t in txns)
        t.category == c.id
            ? Txn(id: t.id, amount: t.amount, date: t.date, note: t.note, category: 'other', type: t.type)
            : t,
    ];
    await _storage.saveTxns(txns);
    await _saveSettings();
  }

  // ---------------------------------------------------------------- onboarding & settings

  Future<void> completeOnboarding({
    required String name,
    required double balance,
    required double minDaily,
    required double maxDaily,
    required String lang,
    String gender = 'm',
    double salary = 0,
    int salaryDay = 1,
    String? pin,
    bool biometrics = false,
  }) async {
    settings
      ..pinHash = pin == null ? null : hashPin(pin)
      ..biometrics = pin != null && biometrics
      ..name = name
      ..balance = balance
      ..minDaily = minDaily
      ..maxDaily = maxDaily
      ..lang = lang
      ..gender = gender
      ..startDate = dateOnly(DateTime.now())
      ..onboarded = true;
    _applySalary(salary, salaryDay);
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

  Future<void> setGender(String g) async {
    settings.gender = g;
    await _saveSettings();
  }

  Future<void> setThemeMode(String m) async {
    settings.themeMode = m;
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

  Future<void> setSafetyBalance(double v) async {
    settings.safetyBalance = v;
    await _saveSettings();
  }

  Future<void> addMoney(double amount, String note) async {
    settings.balance += amount;
    txns.insert(0, Txn(id: _id(), amount: amount, date: DateTime.now(), note: note, type: TxnType.deposit));
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

  // ---------------------------------------------------------------- salary

  /// The first automatic salary comes on the next payday after today:
  /// the balance entered today already contains this month's salary.
  void _applySalary(double amount, int day) {
    settings
      ..salary = amount
      ..salaryDay = day;
    if (amount <= 0) {
      settings.nextSalary = null;
      return;
    }
    final now = DateTime.now();
    settings.nextSalary = Installment.firstDueFrom(DateTime(now.year, now.month, now.day + 1), day);
  }

  Future<void> setSalary(double amount, int day) async {
    _applySalary(amount, day);
    await _saveSettings();
  }

  /// Add the salary for every payday that has arrived. Returns true if added.
  Future<bool> processSalary() async {
    final next = settings.nextSalary;
    if (!settings.hasSalary || next == null) return false;
    final today = dateOnly(DateTime.now());
    var added = false;
    var due = next;
    while (!due.isAfter(today)) {
      settings.balance += settings.salary;
      txns.add(Txn(
        id: _id(),
        amount: settings.salary,
        date: due.add(const Duration(hours: 8)),
        type: TxnType.salary,
      ));
      due = dueDateIn(due.year, due.month + 1, settings.salaryDay);
      added = true;
    }
    if (added) {
      settings.nextSalary = due;
      txns.sort((a, b) => b.date.compareTo(a.date));
      await _storage.saveTxns(txns);
      await _storage.saveSettings(settings);
      await _notifications.showNow(
        s.t('salaryAddedTitle'),
        s.t('salaryAddedBody', {'x': s.money(settings.salary)}),
      );
    }
    return added;
  }

  // ---------------------------------------------------------------- bank messages

  bool bankSeenBefore(BankMessage m) => settings.bankSeen.contains(m.fingerprint);

  /// Takes the text of a bank message (from the iPhone Shortcut link or the
  /// clipboard). Adds it right away when auto-add is on, otherwise keeps it
  /// for the confirmation sheet.
  Future<void> receiveBankText(String text) async {
    final m = parseBankSms(text);
    if (settings.bankAutoAdd && m.isUseful && !bankSeenBefore(m)) {
      await applyBank(m);
      lastAutoBank = m;
    } else {
      pendingBank = m;
    }
    notifyListeners();
  }

  void dismissBank() {
    pendingBank = null;
    lastAutoBank = null;
    notifyListeners();
  }

  /// Records a bank message: adds the expense or income, then (if the bank
  /// sent it and sync is on) sets the balance to what the bank says. The
  /// app never contacts the bank; it only reads the message text.
  Future<void> applyBank(BankMessage m, {String? category, bool addTxn = true}) async {
    if (addTxn && m.hasTransaction && !bankSeenBefore(m)) {
      final note = m.merchant ?? s.t('fromBank');
      if (m.kind == BankKind.debit) {
        await addExpense(amount: m.amount!, date: DateTime.now(), note: note, category: category ?? m.category);
      } else if (m.kind == BankKind.credit) {
        await addMoney(m.amount!, note);
      }
    }
    if (m.balance != null && settings.bankSyncBalance) {
      settings.balance = m.balance!;
    }
    settings.lastBankSync = DateTime.now();
    settings.bankSeen = [...settings.bankSeen, m.fingerprint].reversed.take(300).toList().reversed.toList();
    pendingBank = null;
    await _saveSettings();
  }

  Future<void> setBankOptions({bool? syncBalance, bool? autoAdd}) async {
    if (syncBalance != null) settings.bankSyncBalance = syncBalance;
    if (autoAdd != null) settings.bankAutoAdd = autoAdd;
    await _saveSettings();
  }

  Future<void> setBiometrics(bool v) async {
    settings.biometrics = v;
    await _saveSettings();
  }

  /// Lock the app now (shows the login screen when a PIN is set).
  void lock() {
    if (settings.pinHash == null) return;
    unlocked = false;
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
    String category = 'other',
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
    if (t.isIncome) {
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
      category: 'bills',
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
    var paid = false;
    for (final i in installments) {
      while (!i.isFinished && !i.nextDue.isAfter(today)) {
        await payInstallment(i, auto: true);
        paid = true;
      }
    }
    return paid;
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
    return outings.entries
        .map((e) => MapEntry(parseDayKey(e.key), e.value))
        .where((e) => !e.key.isBefore(today))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
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
    final pay = settings.nextSalary;
    if (settings.hasSalary && pay != null) {
      reminders.add(Reminder(
        id: id++,
        when: DateTime(pay.year, pay.month, pay.day - 1, 19),
        title: s.t('salarySoonTitle'),
        body: s.t('salarySoonBody', {'x': s.money(settings.salary)}),
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
