class AppSettings {
  AppSettings({
    this.name = '',
    this.balance = 0,
    this.minDaily = 150,
    this.maxDaily = 250,
    this.lang = 'ar',
    this.pinHash,
    this.notifications = true,
    this.reminderHour = 21,
    DateTime? startDate,
    this.onboarded = false,
  }) : startDate = startDate ?? DateTime.now();

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

  /// SHA-256 of the optional 4-digit PIN.
  String? pinHash;

  bool notifications;

  /// Hour of the daily "did you log your spending?" reminder.
  int reminderHour;

  /// First day of tracking. Carry-over of overspending is computed from here.
  DateTime startDate;

  bool onboarded;

  Map<String, dynamic> toJson() => {
        'name': name,
        'balance': balance,
        'minDaily': minDaily,
        'maxDaily': maxDaily,
        'lang': lang,
        'pinHash': pinHash,
        'notifications': notifications,
        'reminderHour': reminderHour,
        'startDate': startDate.toIso8601String(),
        'onboarded': onboarded,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        name: (j['name'] as String?) ?? '',
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        minDaily: (j['minDaily'] as num?)?.toDouble() ?? 150,
        maxDaily: (j['maxDaily'] as num?)?.toDouble() ?? 250,
        lang: (j['lang'] as String?) ?? 'ar',
        pinHash: j['pinHash'] as String?,
        notifications: (j['notifications'] as bool?) ?? true,
        reminderHour: (j['reminderHour'] as int?) ?? 21,
        startDate: j['startDate'] != null ? DateTime.parse(j['startDate'] as String) : null,
        onboarded: (j['onboarded'] as bool?) ?? false,
      );
}
