
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'notification_service.dart';

class NotificationScheduler {
  NotificationScheduler._internal();

  // Singleton instance.
  static final NotificationScheduler _instance =
      NotificationScheduler._internal();

  factory NotificationScheduler() => _instance;

  final NotificationService _notificationService =
      NotificationService();

  static const int maxReminders = 56;
  static const int futureWeeks = 7;

  // Prevent overlapping synchronization operations.
  Future<void> _queue = Future<void>.value();

  // Prevent outdated synchronization after logout.
  bool _suspended = false;
  int _generation = 0;

  int get generation => _generation;

  // Track the last applied reminder time.
  String? _lastAppliedTime;

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _queue.then((_) => action());

    // Keep the queue usable even if an operation fails.
    _queue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          'Notification queue operation failed: $error',
        );
      },
    );

    return operation;
  }

  // Generate a consistent notification ID for each date.
  int notificationIdForDate(DateTime date) {
    final utcDate = DateTime.utc(
      date.year,
      date.month,
      date.day,
    );

    final daysSinceEpoch =
        utcDate.millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;

    return 100000 + daysSinceEpoch;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
    );
  }

  // Synchronize reminders using the selected time and status.
  Future<void> syncWeeklyPlans({
    required Map<String, dynamic>? currentPlan,
    required Map<String, dynamic>? nextPlan,
    int reminderHour = 11,
    int reminderMinute = 50,
    bool remindersEnabled = true,
  }) {
    if (reminderHour < 0 ||
        reminderHour > 23 ||
        reminderMinute < 0 ||
        reminderMinute > 59) {
      throw ArgumentError('Invalid reminder time');
    }

    final generation = _generation;

    return _enqueue(() async {
      // Skip suspended or outdated synchronization.
      if (_suspended || generation != _generation) {
        return;
      }

      // Cancel reminders when disabled.
      if (!remindersEnabled) {
        await _notificationService
            .cancelAllTrainingReminders();

        _lastAppliedTime = null;
        return;
      }

      await _sync(
        currentPlan,
        nextPlan,
        generation,
        reminderHour,
        reminderMinute,
      );
    });
  }

  Future<void> _sync(
    Map<String, dynamic>? currentPlan,
    Map<String, dynamic>? nextPlan,
    int generation,
    int reminderHour,
    int reminderMinute,
  ) async {
    final desiredDates = <DateTime>{};

    // Collect incomplete sessions from the current week.
    if (currentPlan != null) {
      final sessions =
          (currentPlan['sessions'] as List<dynamic>?) ?? [];

      for (final session in sessions) {
        if (session['is_completed'] == true) continue;

        final date = _dateOnly(
          DateTime.parse(
            session['practice_date'] as String,
          ),
        );

        desiredDates.add(date);
      }
    }

    // Collect sessions from the next week.
    if (nextPlan != null) {
      final nextWeekStart = _dateOnly(
        DateTime.parse(
          nextPlan['week_start'] as String,
        ),
      );

      final sessions =
          (nextPlan['sessions'] as List<dynamic>?) ?? [];

      final dayOffsets = <int>{};

      for (final session in sessions) {
        final date = _dateOnly(
          DateTime.parse(
            session['practice_date'] as String,
          ),
        );

        final offset =
            date.difference(nextWeekStart).inDays;

        if (offset < 0 || offset > 6) continue;

        if (session['is_completed'] != true) {
          desiredDates.add(date);
        }

        dayOffsets.add(offset);
      }

      // Repeat training days for future weeks.
      for (var week = 1; week <= futureWeeks; week++) {
        for (final offset in dayOffsets) {
          desiredDates.add(
            nextWeekStart.add(
              Duration(days: week * 7 + offset),
            ),
          );
        }
      }
    }

    // Keep only future reminders.
    final now = DateTime.now();

    final futureDates = desiredDates.where((date) {
      final reminderTime = DateTime(
        date.year,
        date.month,
        date.day,
        reminderHour,
        reminderMinute,
      );

      return reminderTime.isAfter(now);
    }).toList()
      ..sort();

    final selectedDates =
        futureDates.take(maxReminders).toList();

    final desiredIds = <int, DateTime>{
      for (final date in selectedDates)
        notificationIdForDate(date): date,
    };

    // Get currently scheduled reminders.
    final pendingIds = await _notificationService
        .pendingTrainingReminderIds();

    if (_suspended || generation != _generation) {
      return;
    }

    // Detect a change in the reminder time.
    final selectedTime =
        '$reminderHour:$reminderMinute';

    final forceRefresh =
        _lastAppliedTime != selectedTime;

    // Cancel outdated reminders.
    final idsToCancel = forceRefresh
        ? pendingIds
        : pendingIds.difference(
            desiredIds.keys.toSet(),
          );

    for (final id in idsToCancel) {
      if (_suspended || generation != _generation) {
        return;
      }

      await _notificationService
          .cancelPracticeReminder(id);
    }

    // Schedule missing reminders.
    for (final entry in desiredIds.entries) {
      if (_suspended || generation != _generation) {
        return;
      }

      if (!forceRefresh &&
          pendingIds.contains(entry.key)) {
        continue;
      }

      await _notificationService
          .schedulePracticeReminder(
        notificationId: entry.key,
        practiceDate: entry.value,
        reminderHour: reminderHour,
        reminderMinute: reminderMinute,
      );
    }

    if (_suspended || generation != _generation) {
      return;
    }

    _lastAppliedTime = selectedTime;
  }

  // Suspend synchronization and cancel reminders on logout.
  Future<void> suspendAndCancelTrainingReminders() {
    _suspended = true;
    _generation++;

    _lastAppliedTime = null;

    return _enqueue(() async {
      await _notificationService
          .cancelAllTrainingReminders();
    });
  }

  // Allow synchronization after login.
  void resume() {
    _suspended = false;
    _generation++;

    _lastAppliedTime = null;
  }
}
