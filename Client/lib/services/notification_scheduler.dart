import 'dart:async';

import 'notification_service.dart';

import 'package:flutter/foundation.dart'; // Import foundation.dart for debugPrint

class NotificationScheduler {
  NotificationScheduler._internal();

  static final NotificationScheduler _instance =
      NotificationScheduler._internal();

  factory NotificationScheduler() => _instance;

  final NotificationService _notificationService = NotificationService();

  // Maximum number of training reminders to keep pending.
  static const int maxReminders = 56;

  // Number of weeks to project after next week.
  static const int futureWeeks = 7;

  // Prevent overlapping synchronization operations.
  Future<void> _queue = Future<void>.value();

  // Prevent outdated synchronization after logout.
  bool _suspended = false;
  int _generation = 0;
  // Expose the current generation to detect outdated API responses.
  int get generation => _generation;

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _queue.then((_) => action());

    // Keep the queue usable even if an operation fails.
    _queue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Notification queue operation failed: $error');
      },
    );

    return operation;
  }

  // Generate a stable notification ID for each date.
  int notificationIdForDate(DateTime date) {
    final utcDate = DateTime.utc(date.year, date.month, date.day);

    final daysSinceEpoch =
        utcDate.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

    return 100000 + daysSinceEpoch;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  Future<void> syncWeeklyPlans({
    required Map<String, dynamic>? currentPlan,
    required Map<String, dynamic>? nextPlan,
  }) {
    // Capture the current generation to identify outdated sync requests.
    final generation = _generation;

    // Queue the synchronization task to prevent overlapping operations.
    return _enqueue(() async {
      /* Skip synchronization if notifications are suspended
     or if the request belongs to an outdated generation.*/
      if (_suspended || generation != _generation) return;

      // Synchronize reminders with the weekly plans.
      await _sync(currentPlan, nextPlan, generation);
    });
  }

  Future<void> _sync(
    Map<String, dynamic>? currentPlan,
    Map<String, dynamic>? nextPlan,
    int generation,
  ) async {
    final desiredDates = <DateTime>{};

    // 1. Current week: exclude completed sessions.
    if (currentPlan != null) {
      final sessions = (currentPlan['sessions'] as List<dynamic>?) ?? [];

      for (final session in sessions) {
        if (session['is_completed'] == true) continue;

        final date = _dateOnly(
          DateTime.parse(session['practice_date'] as String),
        );

        desiredDates.add(date);
      }
    }

    // 2. Next week and its repeating pattern.
    if (nextPlan != null) {
      final nextWeekStart = _dateOnly(
        DateTime.parse(nextPlan['week_start'] as String),
      );

      final sessions = (nextPlan['sessions'] as List<dynamic>?) ?? [];

      final dayOffsets = <int>{};

      for (final session in sessions) {
        final date = _dateOnly(
          DateTime.parse(session['practice_date'] as String),
        );

        final offset = date.difference(nextWeekStart).inDays;

        if (offset < 0 || offset > 6) continue;

        // Schedule next week's session.
        if (session['is_completed'] != true) {
          desiredDates.add(date);
        }

        dayOffsets.add(offset);
      }

      // Project the selected weekdays into future weeks.
      for (var week = 1; week <= futureWeeks; week++) {
        for (final offset in dayOffsets) {
          desiredDates.add(
            nextWeekStart.add(Duration(days: week * 7 + offset)),
          );
        }
      }
    }

    // 3. Remove past dates and sort future dates.
    final now = DateTime.now();

    final futureDates = desiredDates.where((date) {
      final reminderTime = DateTime(date.year, date.month, date.day, 11 , 50);

      return reminderTime.isAfter(now);
    }).toList()..sort();

    // 4. Respect the pending reminder limit.
    final selectedDates = futureDates.take(maxReminders).toList();

    final desiredIds = <int, DateTime>{
      for (final date in selectedDates) notificationIdForDate(date): date,
    };

    // 5. Read currently pending training reminders.
    final pendingIds = await _notificationService.pendingTrainingReminderIds();

    // Stop if logout occurred while reading pending reminders.
    if (_suspended || generation != _generation) return;

    // 6. Cancel reminders that are no longer needed.
    for (final id in pendingIds.difference(desiredIds.keys.toSet())) {
      // Prevent outdated synchronization from continuing after logout.
      if (_suspended || generation != _generation) return;

      await _notificationService.cancelPracticeReminder(id);
    }

    // 7. Schedule reminders that are missing.
    for (final entry in desiredIds.entries) {
      // Stop scheduling if this request is no longer valid.
      if (_suspended || generation != _generation) return;

      if (pendingIds.contains(entry.key)) continue;

      await _notificationService.schedulePracticeReminder(
        notificationId: entry.key,
        practiceDate: entry.value,
      );
    }
  }

  // Stop outdated synchronization and cancel training reminders on logout.
  Future<void> suspendAndCancelTrainingReminders() {
    // Immediately prevent old synchronization requests from continuing.
    _suspended = true;

    // Invalidate synchronization requests from the previous session.
    _generation++;

    // Wait for ongoing operations, then cancel training reminders.
    return _enqueue(() async {
      await _notificationService.cancelAllTrainingReminders();
    });
  }

  // Allow notification synchronization for a new login session.
  void resume() {
    // Enable notification scheduling again.
    _suspended = false;

    // Invalidate any synchronization requests from previous sessions.
    _generation++;
  }
}
