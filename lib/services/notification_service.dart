// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Day;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/workout_models.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // FIX: "settings:" is now a required named parameter
    await _notificationsPlugin.initialize(settings: initSettings);
  }

  Future<void> scheduleWorkoutNotifications(List<Session> sessions) async {
    await _notificationsPlugin.cancelAll(); // Reset existing notifications

    for (var session in sessions) {
      final int weekday = _dayToWeekday(session.day);

      // Build a quick summary (e.g., "4 exercises scheduled")
      String resume =
          "${session.exercises.length} exercises scheduled today. Ready to give it your all?";

      // FIX: All zonedSchedule parameters are now named
      await _notificationsPlugin.zonedSchedule(
        id: session.id.hashCode, // Unique ID based on the session
        title: "It's time for your session: ${session.title}!",
        body: resume,
        scheduledDate: _nextInstanceOfTime(
          weekday,
          6,
          0,
        ), // At 06:00 AM on the corresponding day
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'workout_channel',
            'Workout Notifications',
            channelDescription: 'Daily reminders for sessions',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // FIX: uiLocalNotificationDateInterpretation was removed from the package
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  int _dayToWeekday(Day day) {
    switch (day) {
      case Day.monday:
        return DateTime.monday;
      case Day.tuesday:
        return DateTime.tuesday;
      case Day.wednesday:
        return DateTime.wednesday;
      case Day.thursday:
        return DateTime.thursday;
      case Day.friday:
        return DateTime.friday;
      case Day.saturday:
        return DateTime.saturday;
      case Day.sunday:
        return DateTime.sunday;
    }
    // FIX: Added a default return to satisfy the compiler
  }

  tz.TZDateTime _nextInstanceOfTime(int weekday, int hour, int minute) {
    tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}

final notificationService = NotificationService();
