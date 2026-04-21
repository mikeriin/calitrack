// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Day;
import 'package:flutter_timezone/flutter_timezone.dart';
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

    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = tzInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // Fallback par défaut si introuvable
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('ic_notif');
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

    await _notificationsPlugin.initialize(settings: initSettings);
  }

  Future<void> scheduleWorkoutNotifications(List<Session> sessions) async {
    await _notificationsPlugin.cancelAll(); // Reset existing notifications

    for (int i = 0; i < sessions.length; i++) {
      var session = sessions[i];
      final int weekday = _dayToWeekday(session.day);

      String resume =
          "${session.exercises.length} exercises scheduled today. Ready to give it your all?";

      await _notificationsPlugin.zonedSchedule(
        id: i,
        title: "It's time for your session: ${session.title}!",
        body: resume,
        scheduledDate: _nextInstanceOfTime(weekday, 10, 12),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'workout_channel', // <-- LE CHANGEMENT MAGIQUE EST ICI
            'Workout Notifications',
            channelDescription: 'Daily reminders for sessions',
            importance: Importance.max, // On force au max
            priority: Priority.max, // On force au max
            playSound: true, // On force le son
            enableVibration: true, // On force le vibreur
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
