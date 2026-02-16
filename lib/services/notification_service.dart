import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/task_entity.dart';
import '../services/config_service.dart';
import '../utils/recurrence_utils.dart';

class NotificationService {
  static const String channelKey = 'task_reminders';
  static const String _prefsKeyNotifications = 'notifications_enabled';

  /// 重复任务最多提前调度的天数
  static const int _recurringScheduleDaysAhead = 60;

  static Future<bool> areNotificationsEnabledByUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyNotifications) ?? false;
  }

  /// 从 reminderTime 解析出单次提醒的调度时间
  /// 返回 null 表示无法解析
  static DateTime? _parseReminderScheduledTime(
    TaskEntity task,
    DateTime occurrenceDateTime,
    String rt,
  ) {
    if (rt.startsWith('offset:')) {
      // 发生当天：提前 m 分钟
      final min = int.tryParse(rt.substring(7)) ?? 5;
      return occurrenceDateTime.subtract(Duration(minutes: min));
    }
    if (rt.startsWith('days_before:')) {
      // 发生前 n 天在 h:mm 提醒
      final rest = rt.substring(12);
      final comma = rest.indexOf(',');
      if (comma <= 0) return null;
      final n = int.tryParse(rest.substring(0, comma).trim());
      final timeStr = rest.substring(comma + 1).trim();
      if (n == null || n < 1) return null;
      try {
        final t = DateFormat('h:mm a').parseStrict(timeStr);
        final reminderDate = occurrenceDateTime.subtract(Duration(days: n));
        return DateTime(
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          t.hour,
          t.minute,
        );
      } catch (_) {
        return null;
      }
    }
    if (rt.startsWith('custom:')) {
      try {
        return DateFormat('dd/MM/yy h:mm a').parse(rt.substring(7));
      } catch (_) {
        return null;
      }
    }
    // 绝对时间
    try {
      return DateFormat('dd/MM/yy h:mm a').parse(rt);
    } catch (_) {
      return null;
    }
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

      final rt = task.reminderTime?.trim() ?? '';
      final hasReminderConfig = rt.isNotEmpty;

      // 无 reminderTime 时使用任务时间作为提醒
      final effectiveRt = hasReminderConfig ? rt : 'offset:0';

      final rule = (task.repeatRule ?? '').trim().toLowerCase();
      final isRecurring = rule.isNotEmpty && rule != 'no repeat';

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

          final scheduled = _parseReminderScheduledTime(task, occDt, effectiveRt);
          if (scheduled == null || scheduled.isBefore(now)) continue;

          final notifId = taskId * 1000 + i;
          await _scheduleSingle(task, notifId, scheduled);
        }
      } else {
        // 单次任务
        final occDt = RecurrenceUtils.getBaseOccurrenceDateTime(task);
        if (occDt == null) return;

        DateTime? scheduled;
        if (hasReminderConfig) {
          scheduled = _parseReminderScheduledTime(task, occDt, effectiveRt);
        } else {
          scheduled = occDt;
        }
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
  static Future<void> _cancelTaskNotifications(int taskId, [String? repeatRule]) async {
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
      return await AwesomeNotifications().requestPermissionToSendNotifications();
    }
    return true;
  }

  static Future<bool> isNotificationAllowed() async {
    return await AwesomeNotifications().isNotificationAllowed();
  }
}
