import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/task_entity.dart';
import '../services/config_service.dart';
import '../utils/recurrence_utils.dart';
import '../utils/task_schedule_codec.dart';

class NotificationService {
  static const String channelKey = 'task_reminders';
  static const String _prefsKeyNotifications = 'notifications_enabled';

  /// 重复任务最多提前调度的天数
  static const int _recurringScheduleDaysAhead = 60;

  static Future<bool> areNotificationsEnabledByUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyNotifications) ?? false;
  }

  /// 获取任务的发生时刻（用于提醒计算）
  static DateTime? _getOccurrenceDateTime(TaskEntity task, DateTime onDate) {
    return RecurrenceUtils.getOccurrenceDateTime(task, onDate);
  }

  /// Schedule a notification for a task
  static Future<void> scheduleTaskNotification(TaskEntity task) async {
    final userEnabled = await areNotificationsEnabledByUser();
    if (!userEnabled) return;
    if (!task.hasNotification) return;

    try {
      final taskId = task.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _cancelTaskNotifications(taskId, task.repeatRule);

      final baseOccurrence = RecurrenceUtils.getBaseOccurrenceDateTime(task);
      final reminderRule = ReminderRule.fromStorage(
        task.reminderTime,
        occurrenceDateTime: baseOccurrence,
      );
      final repeat = RepeatSelection.fromStorage(
        task.repeatRule,
        baseDate: baseOccurrence,
      );
      final isRecurring = repeat.isRepeating;

      if (isRecurring) {
        // 重复任务：为每次发生调度提醒
        final now = DateTime.now();
        final from = DateTime(now.year, now.month, now.day);
        final occurrences = RecurrenceUtils.getOccurrenceDatesInRange(
          task,
          from,
          _recurringScheduleDaysAhead,
        );

        for (var i = 0; i < occurrences.length; i++) {
          final occDate = occurrences[i];
          final occDt = _getOccurrenceDateTime(task, occDate);
          if (occDt == null) continue;

          final scheduled = (reminderRule ?? const ReminderRule.relative(0))
              .scheduleAt(occDt);
          if (scheduled == null || scheduled.isBefore(now)) continue;

          final notifId = taskId * 1000 + i;
          await _scheduleSingle(task, notifId, scheduled);
        }
      } else {
        // 单次任务
        final occDt = RecurrenceUtils.getBaseOccurrenceDateTime(task);
        if (occDt == null) return;

        final scheduled =
            (reminderRule ?? const ReminderRule.relative(0)).scheduleAt(occDt);
        if (scheduled == null || scheduled.isBefore(DateTime.now())) return;

        await _scheduleSingle(task, taskId, scheduled);
      }
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  static Future<void> _scheduleSingle(
    TaskEntity task,
    int notifId,
    DateTime scheduledDateTime,
  ) async {
    final locale = ConfigService.instance.effectiveLocale ??
        PlatformDispatcher.instance.locale;
    final l10n = lookupAppLocalizations(locale);

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: notifId,
        channelKey: channelKey,
        title: l10n.taskReminder,
        body: task.title,
        category: NotificationCategory.Reminder,
        wakeUpScreen: true,
        payload: {
          'task_id': task.id?.toString() ?? '',
          'task_title': task.title,
        },
      ),
      schedule: NotificationCalendar.fromDate(
        date: scheduledDateTime,
        allowWhileIdle: true,
      ),
    );
  }

  /// 取消某任务的所有通知（含重复任务的多次调度）
  static Future<void> _cancelTaskNotifications(int taskId,
      [String? repeatRule]) async {
    await AwesomeNotifications().cancel(taskId);
    for (var i = 0; i < _recurringScheduleDaysAhead; i++) {
      await AwesomeNotifications().cancel(taskId * 1000 + i);
    }
  }

  /// Cancel a specific task notification
  static Future<void> cancelTaskNotification(int? taskId) async {
    if (taskId != null) {
      await _cancelTaskNotifications(taskId);
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }

  /// Reschedule all pending task notifications
  static Future<void> rescheduleAllNotifications(List<TaskEntity> tasks) async {
    final userEnabled = await areNotificationsEnabledByUser();
    if (!userEnabled) {
      await cancelAllNotifications();
      return;
    }

    await cancelAllNotifications();

    for (final task in tasks) {
      if (!task.completed && task.hasNotification) {
        await scheduleTaskNotification(task);
      }
    }
  }

  /// Initialize notifications
  static Future<void> initializeNotifications() async {
    final locale = ConfigService.instance.effectiveLocale ??
        PlatformDispatcher.instance.locale;
    final l10n = lookupAppLocalizations(locale);
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: channelKey,
          channelName: l10n.notificationChannelName,
          channelDescription: l10n.notificationChannelDescription,
          defaultColor: const Color(0xFF9D50DD),
          ledColor: const Color(0xFF9D50DD),
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
      ],
    );
  }

  static Future<bool> requestPermissions() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      return await AwesomeNotifications()
          .requestPermissionToSendNotifications();
    }
    return true;
  }

  static Future<bool> isNotificationAllowed() async {
    return await AwesomeNotifications().isNotificationAllowed();
  }
}
