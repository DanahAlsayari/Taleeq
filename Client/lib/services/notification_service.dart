import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Load timezone data.
    tz_data.initializeTimeZones();
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
    }
    //icon for the notification
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings: settings);
  }

  Future<bool> requestPermission() async {
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    return false;
  }

  Future<void> schedulePracticeReminder({
    required int notificationId,
    required DateTime practiceDate,
    required int reminderHour, //for editable training reminder time
    required int reminderMinute,
  }) async {
    final scheduledTime = tz.TZDateTime(
      tz.local,
      practiceDate.year,
      practiceDate.month,
      practiceDate.day,
      reminderHour,
      reminderMinute,
    );

    if (!scheduledTime.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'training_reminders',
      'Training Reminders',
      channelDescription: 'Reminders for scheduled speech training',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id: notificationId,
      title: 'طليق | تذكير بالتدريب',
      body: 'حان وقت تدريبك على الطلاقة! 🌿',
      scheduledDate: scheduledTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelPracticeReminder(int notificationId) async {
    await _notifications.cancel(id: notificationId);
  }

  Future<Set<int>> pendingTrainingReminderIds() async {
    final pending = await _notifications.pendingNotificationRequests();

    return pending
        .map((notification) => notification.id)
        .where((id) => id >= 100000 && id < 200000)
        .toSet();
  }

  Future<void> cancelAllTrainingReminders() async {
    final ids = await pendingTrainingReminderIds();

    for (final id in ids) {
      await _notifications.cancel(id: id);
    }
  }
} //end of NotificationService class
