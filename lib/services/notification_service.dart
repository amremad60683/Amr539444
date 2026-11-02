import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One scheduled reminder.
class Reminder {
  Reminder({required this.id, required this.when, required this.title, required this.body});
  final int id;
  final DateTime when;
  final String title;
  final String body;
}

/// Local notifications: instant warnings + scheduled reminders.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _dailyId = 1;
  static const _instantBase = 100;
  int _instantCounter = 0;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'masrofy_main',
      'Masrofy',
      channelDescription: 'Spending warnings and installment reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to UTC if the zone can't be resolved.
    }
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  Future<void> requestPermission() async {
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Show a notification right now (e.g. "you crossed the limit").
  Future<void> showNow(String title, String body) async {
    if (!_ready) return;
    final id = _instantBase + (_instantCounter++ % 50);
    await _plugin.show(id: id, title: title, body: body, notificationDetails: _details);
  }

  /// Replace all scheduled reminders.
  ///
  /// [dailyHour] schedules a repeating "log your spending" reminder.
  /// [reminders] are one-off reminders (installments, outings...).
  Future<void> reschedule({
    required bool enabled,
    required int dailyHour,
    required String dailyTitle,
    required String dailyBody,
    required List<Reminder> reminders,
  }) async {
    if (!_ready) return;
    await _plugin.cancelAllPendingNotifications();
    if (!enabled) return;

    final now = tz.TZDateTime.now(tz.local);
    var daily = tz.TZDateTime(tz.local, now.year, now.month, now.day, dailyHour);
    if (!daily.isAfter(now)) daily = daily.add(const Duration(days: 1));
    await _schedule(_dailyId, daily, dailyTitle, dailyBody, repeatDaily: true);

    for (final r in reminders) {
      final when = tz.TZDateTime.from(r.when, tz.local);
      if (when.isAfter(now)) await _schedule(r.id, when, r.title, r.body);
    }
  }

  Future<void> _schedule(int id, tz.TZDateTime when, String title, String body,
      {bool repeatDaily = false}) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
      );
    } catch (e) {
      debugPrint('Failed to schedule $id: $e');
    }
  }
}
