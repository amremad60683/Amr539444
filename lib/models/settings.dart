import 'category.dart';

class AppSettings {
  AppSettings({
    this.name = '',
    this.balance = 0,
    this.minDaily = 150,
    this.maxDaily = 250,
    this.lang = 'ar',
    this.gender = 'm',
    this.themeMode = 'dark',
    this.pinHash,
    this.notifications = true,
    this.reminderHour = 21,
    DateTime? startDate,
    this.onboarded = false,
    this.salary = 0,
    this.salaryDay = 1,
    this.nextSalary,
    this.safetyBalance = 0,
    List<CategoryDef>? customCategories,
  })  : startDate = startDate ?? DateTime.now(),
        customCategories = customCategories ?? [];

  String name;

  /// Current balance, entered manually by the user (no bank connection).
  double balance;

  /// Daily target (soft limit): crossing it shows a gentle warning.
  double minDaily;

  /// Daily maximum (hard limit): crossing it warns and the excess is
  /// deducted from the following day(s).
  double maxDaily;

  /// 'ar' or 'en'.
  String lang;

  /// 'm' or 'f'. Only changes how the Arabic text addresses the user.
  String gender;

  /// 'dark', 'light' or 'system'.
  String themeMode;

  /// SHA-256 of the optional 4-digit PIN.
  String? pinHash;

  bool notifications;

  /// Hour of the daily "did you log your spending?" reminder.
  int reminderHour;

  /// First day of tracking. Carry-over of overspending is computed from here.
  DateTime startDate;

  bool onboarded;

  /// Monthly salary (0 = not set). Added to the balance on [salaryDay].
  double salary;
  int salaryDay;

  /// Date the next salary will be added automatically.
  DateTime? nextSalary;

  /// Money the user never wants to go below by the end of the month.
  double safetyBalance;

  List<CategoryDef> customCategories;

  bool get hasSalary => salary > 0;

  Map<String, dynamic> toJson() => {
        'name': name,
        'balance': balance,
        'minDaily': minDaily,
        'maxDaily': maxDaily,
        'lang': lang,
        'gender': gender,
        'themeMode': themeMode,
        'pinHash': pinHash,
        'notifications': notifications,
        'reminderHour': reminderHour,
        'startDate': startDate.toIso8601String(),
        'onboarded': onboarded,
        'salary': salary,
        'salaryDay': salaryDay,
        'nextSalary': nextSalary?.toIso8601String(),
        'safetyBalance': safetyBalance,
        'customCategories': customCategories.map((c) => c.toJson()).toList(),
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        name: (j['name'] as String?) ?? '',
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        minDaily: (j['minDaily'] as num?)?.toDouble() ?? 150,
        maxDaily: (j['maxDaily'] as num?)?.toDouble() ?? 250,
        lang: (j['lang'] as String?) ?? 'ar',
        gender: (j['gender'] as String?) ?? 'm',
        themeMode: (j['themeMode'] as String?) ?? 'dark',
        pinHash: j['pinHash'] as String?,
        notifications: (j['notifications'] as bool?) ?? true,
        reminderHour: (j['reminderHour'] as int?) ?? 21,
        startDate: j['startDate'] != null ? DateTime.parse(j['startDate'] as String) : null,
        onboarded: (j['onboarded'] as bool?) ?? false,
        salary: (j['salary'] as num?)?.toDouble() ?? 0,
        salaryDay: (j['salaryDay'] as int?) ?? 1,
        nextSalary: j['nextSalary'] != null ? DateTime.parse(j['nextSalary'] as String) : null,
        safetyBalance: (j['safetyBalance'] as num?)?.toDouble() ?? 0,
        customCategories: ((j['customCategories'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(CategoryDef.fromJson)
            .toList(),
      );
}
