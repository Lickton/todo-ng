import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/task_entity.dart';
import '../services/config_service.dart';

class NotificationService {
  static const String channelKey = 'task_reminders';
  static const String _prefsKeyNotifications = 'notifications_enabled';


  static Future<bool> areNotificationsEnabledByUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyNotifications) ?? false;
  }

  /// Schedule a notification for a task
  static Future<void> scheduleTaskNotification(TaskEntity task) async {
    // Check if user has enabled notifications
    final userEnabled = await areNotificationsEnabledByUser();
    if (!userEnabled) {
      print('Notification not scheduled: user has disabled notifications');
      return;
    }

    if (!task.hasNotification) {
      print('Notification not scheduled: hasNotification=false');
      return;
    }

    try {
      DateTime? scheduledDateTime;

      // 优先使用 reminderTime
      if (task.reminderTime != null && task.reminderTime!.isNotEmpty) {
        final rt = task.reminderTime!;
        if (rt.startsWith('offset:')) {
          // 相对任务时间：需要 task.date + task.time
          if (task.time == null || task.date == null) return;
          final dateFormat = DateFormat('dd/MM/yy');
          final timeFormat = DateFormat('h:mm a');
          final date = dateFormat.parse(task.date!);
          final time = timeFormat.parse(task.time!);
          final taskDt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          final min = int.tryParse(rt.substring(7)) ?? 5;
          scheduledDateTime = taskDt.subtract(Duration(minutes: min));
        } else if (rt.startsWith('custom:')) {
          scheduledDateTime = DateFormat('dd/MM/yy h:mm a').parse(rt.substring(7));
        } else {
          // 绝对时间（无任务时间时）
          scheduledDateTime = DateFormat('dd/MM/yy h:mm a').parse(rt);
        }
      } else {
        // 兼容旧数据：使用任务时间
        if (task.time == null || task.date == null) return;
        final dateFormat = DateFormat('dd/MM/yy');
        final timeFormat = DateFormat('h:mm a');
        final date = dateFormat.parse(task.date!);
        final time = timeFormat.parse(task.time!);
        scheduledDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      }

      print('Scheduling notification for ${task.title} at $scheduledDateTime');

      // Don't schedule if the time has already passed
      if (scheduledDateTime.isBefore(DateTime.now())) {
        print('Notification not scheduled: time has already passed');
        return;
      }

      final locale = ConfigService.instance.effectiveLocale ??
          PlatformDispatcher.instance.locale;
      final l10n = lookupAppLocalizations(locale);
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: task.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000, // Use timestamp if ID is null
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
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  /// Cancel a specific task notification
  static Future<void> cancelTaskNotification(int? taskId) async {
    if (taskId != null) {
      await AwesomeNotifications().cancel(taskId);
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }

  /// Reschedule all pending task notifications
  static Future<void> rescheduleAllNotifications(List<TaskEntity> tasks) async {
    // Check if user has enabled notifications
    final userEnabled = await areNotificationsEnabledByUser();
    if (!userEnabled) {
      print('Not rescheduling notifications: user has disabled notifications');
      await cancelAllNotifications();
      return;
    }

    // Cancel all existing notifications first
    await cancelAllNotifications();

    // Schedule notifications for all pending tasks
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
      null, // Use default icon
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

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      final result = await AwesomeNotifications().requestPermissionToSendNotifications();
      return result;
    }
    return true;
  }

  /// Check if notifications are allowed
  static Future<bool> isNotificationAllowed() async {
    return await AwesomeNotifications().isNotificationAllowed();
  }
}