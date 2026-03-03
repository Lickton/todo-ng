import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/task_entity.dart';
import '../services/config_service.dart';
import '../utils/recurrence_utils.dart';
import '../utils/task_schedule_codec.dart';

/// 本地通知服务：
/// 负责通知开关读取、权限请求、单任务提醒调度、批量重排与取消。
class NotificationService {
  /// 与 `main.dart` 中通知渠道保持一致，用于把任务提醒归到同一个 channel。
  static const String channelKey = 'task_reminders';

  /// SharedPreferences 中记录“用户是否在应用内启用通知”的键。
  static const String _prefsKeyNotifications = 'notifications_enabled';

  /// 重复任务最多提前调度的天数
  static const int _recurringScheduleDaysAhead = 60;

  /// 读取应用内通知总开关（不是系统权限）。
  /// 若未设置，默认按关闭处理，避免未经用户确认就大量创建通知。
  static Future<bool> areNotificationsEnabledByUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyNotifications) ?? false;
  }

  /// 计算任务在某一天的“发生时刻”（日期 + 时间）。
  /// 提醒时间会基于这个发生时刻做偏移。
  static DateTime? _getOccurrenceDateTime(TaskEntity task, DateTime onDate) {
    return RecurrenceUtils.getOccurrenceDateTime(task, onDate);
  }

  /// 为单个任务调度提醒（会先清掉旧提醒，再按最新规则创建）。
  static Future<void> scheduleTaskNotification(TaskEntity task) async {
    // 先看应用内开关和任务级开关，任一关闭都不调度。
    final userEnabled = await areNotificationsEnabledByUser();
    if (!userEnabled) return;
    if (!task.hasNotification) return;

    try {
      // 新建任务可能还没有持久化 id，这里兜底生成一个临时 id。
      final taskId = task.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 先取消同任务既有通知，避免重复提醒。
      await _cancelTaskNotifications(taskId, task.repeatRule);

      // 解析任务基准发生时间、提醒规则（提前/准时）和重复规则。
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
        // 重复任务：在 [今天, 今天+60天] 窗口内，逐次发生逐次调度。
        // 这样可避免一次性创建无限未来通知，同时保证短期提醒可用。
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

          // 重复任务的通知 id 规则：
          // 基础 taskId 乘 1000，再加 occurrence 序号，确保每次提醒唯一且可批量取消。
          final notifId = taskId * 1000 + i;
          await _scheduleSingle(task, notifId, scheduled);
        }
      } else {
        // 单次任务：只算一次发生时刻，生成一条通知。
        final occDt = RecurrenceUtils.getBaseOccurrenceDateTime(task);
        if (occDt == null) return;

        final scheduled =
            (reminderRule ?? const ReminderRule.relative(0)).scheduleAt(occDt);
        if (scheduled == null || scheduled.isBefore(DateTime.now())) return;

        await _scheduleSingle(task, taskId, scheduled);
      }
    } catch (e) {
      // 调度失败不抛到 UI，避免影响主流程；仅记录日志便于排查。
      print('Error scheduling notification: $e');
    }
  }

  /// 创建一条具体通知（content + schedule）。
  /// 这里会根据当前语言生成本地化标题。
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
        // 同一个 id 的通知会被覆盖，因此 id 生成策略非常关键。
        id: notifId,
        channelKey: channelKey,
        title: l10n.taskReminder,
        body: task.title,
        category: NotificationCategory.Reminder,
        wakeUpScreen: true,
        payload: {
          // payload 用于点击通知后恢复业务上下文（如定位到任务）。
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
    // 取消单次任务通知 id。
    await AwesomeNotifications().cancel(taskId);

    // 同时取消重复任务可能占用的 id 段（taskId*1000 + i）。
    // 即使当前不是重复任务，执行这段也安全。
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
      // 用户关闭应用内通知时，确保系统侧所有通知被清空。
      await cancelAllNotifications();
      return;
    }

    // 全量重排策略：先清空，再按当前任务状态重建。
    await cancelAllNotifications();

    for (final task in tasks) {
      // 仅为“未完成 + 开启提醒”的任务创建通知。
      if (!task.completed && task.hasNotification) {
        await scheduleTaskNotification(task);
      }
    }
  }

  /// Initialize notifications
  static Future<void> initializeNotifications() async {
    // 该方法提供可本地化的 channel 名称/描述（与 main 中固定文案版本不同）。
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

  /// 请求系统通知权限（仅在系统尚未授权时发起申请）。
  static Future<bool> requestPermissions() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      return await AwesomeNotifications()
          .requestPermissionToSendNotifications();
    }
    return true;
  }

  /// 查询系统层面的通知权限状态。
  static Future<bool> isNotificationAllowed() async {
    return await AwesomeNotifications().isNotificationAllowed();
  }
}
