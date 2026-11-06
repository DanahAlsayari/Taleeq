import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  // Use a single notification service instance across the application.
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  // Initialize the notification service
  Future<void> initialize() async {
    // Load timezone data.
    tz_data.initializeTimeZones();

    // Get the device's current timezone.
    final deviceTimezone = await FlutterTimezone.getLocalTimezone();

    // Set the timezone used for scheduling notifications.
    tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));

    //icon for the notification
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    /* ios settings to not request notification permissions immediately when opening the app */
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

  // Request permission to display notifications.
  Future<bool> requestPermission() async {
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          //allows you to access platform-specific implementations of the FlutterLocalNotificationsPlugin.
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

  // Display a test notification immediately.
  Future<void> showTestNotification() async {
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

    await _notifications.show(
      id: 1,
      title: 'طليق | تذكير بالتدريب',
      body: 'حان وقت تدريبك! 🌿',
      notificationDetails: details,
    );
  }

  // Schedule a test notification one minute from now.
  Future<void> scheduleTestNotification() async {
    final scheduledTime = tz.TZDateTime.now(tz.local)
        .add(const Duration(minutes: 1));

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
      id: 2,
      title: 'طليق | تذكير مجدول',
      body: 'حان وقت تدريبك على الطلاقة! 🌿',
      scheduledDate: scheduledTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> schedulePracticeReminder({
    required int notificationId,
    required DateTime practiceDate,
  }) async {
    const int reminderHour = 21;
    const int reminderMinute = 30;

    final scheduledTime = tz.TZDateTime(
      //translate the practiceDate to the local timezone and set the time to 7 PM
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

  // Get the IDs of pending training reminders only the one it date didnt come yet.
  Future<Set<int>> pendingTrainingReminderIds() async {
    final pending = await _notifications.pendingNotificationRequests();

    return pending
        .map((notification) => notification.id)
        .where((id) => id >= 100000 && id < 200000)
        .toSet();
  }

  // Cancel pending training reminders without affecting other notifications.
  Future<void> cancelAllTrainingReminders() async {
    final ids = await pendingTrainingReminderIds();

    for (final id in ids) {
      await _notifications.cancel(id: id);
    }
  }
} //end of NotificationService class
