import 'dart:async';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_alarm_clock/flutter_alarm_clock.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_entity.dart';
import '../repositories/task_repository.dart';
import '../utils/recurrence_utils.dart';
import '../utils/task_schedule_codec.dart';

/// 系统闹钟服务：在 Android 系统闹钟应用中创建闹钟
/// - Android 11 及以下：可直接使用 skipUi: true 静默创建
/// - Android 12 及以上：需 SCHEDULE_EXACT_ALARM 权限
class SystemAlarmService {
  SystemAlarmService._();
  static final SystemAlarmService instance = SystemAlarmService._();
  static const Duration _checkInterval = Duration(hours: 6);
  static const Duration _windowDuration = Duration(days: 1);
  static const String _prefsAlarmKeys = 'system_alarm_created_keys_v1';

  Timer? _periodicCheckTimer;
  bool _autoSyncStarted = false;

  /// 是否支持系统闹钟（仅 Android）
  bool get isSupported => Platform.isAndroid;

  /// 检查 Android 12+ 的精确闹钟权限
  /// 返回 true 表示可使用 skipUi: true，false 表示需降级为 skipUi: false
  Future<bool> _hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final status = await ph.Permission.scheduleExactAlarm.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// 打开「闹钟与提醒」权限设置页（设置 -> 隐私/安全 -> 特殊应用权限 -> 闹钟和提醒）
  /// 使用 ACTION_REQUEST_SCHEDULE_EXACT_ALARM 跳转到正确位置，而非通用应用设置页
  Future<bool> openAlarmPermissionSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        data: 'package:${packageInfo.packageName}',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('SystemAlarmService.openAlarmPermissionSettings error: $e');
      // 降级：打开通用应用设置页
      return ph.openAppSettings();
    }
  }

  /// 创建系统闹钟
  /// [hour] 小时 0-23
  /// [minute] 分钟 0-59
  /// [title] 闹钟标题（可选）
  /// [context] 用于弹窗，若需降级且用户拒绝去设置时使用 skipUi: false
  ///
  /// 返回：true 表示成功创建，false 表示未创建（如非 Android 或用户去设置页）
  Future<bool> createAlarm({
    required int hour,
    required int minute,
    String title = '',
    BuildContext? context,
    required String Function() getPermissionTitle,
    required String Function() getPermissionMessage,
    required String Function() getGoToSettingsLabel,
    required String Function() getCancelLabel,
    bool suppressUiIfNoPermission = false,
  }) async {
    if (!Platform.isAndroid) return false;

    try {
      final hasPermission = await _hasExactAlarmPermission();
      if (!hasPermission && suppressUiIfNoPermission) {
        return false;
      }
      bool useSkipUi = hasPermission;

      if (!hasPermission && context != null && context.mounted) {
        final shouldRequest = await _showPermissionDialog(
          context: context,
          getPermissionTitle: getPermissionTitle,
          getPermissionMessage: getPermissionMessage,
          getGoToSettingsLabel: getGoToSettingsLabel,
          getCancelLabel: getCancelLabel,
        );
        if (!context.mounted) return false;
        if (shouldRequest == true) {
          await openAlarmPermissionSettings();
          return false; // 用户去设置，不在此处创建，返回后用户可再次保存
        }
        if (shouldRequest == false) {
          useSkipUi = false; // 用户选择取消，降级为跳转系统闹钟界面
        }
      } else if (!hasPermission) {
        useSkipUi = false;
      }

      FlutterAlarmClock.createAlarm(
        hour: hour,
        minutes: minute,
        title: title,
        skipUi: useSkipUi,
      );
      return true;
    } catch (e) {
      debugPrint('SystemAlarmService.createAlarm error: $e');
      return false;
    }
  }

  /// 启动自动检查：
  /// - 立即执行一次
  /// - 此后每 6 小时执行一次
  Future<void> startAutoSync({
    required String Function() getPermissionTitle,
    required String Function() getPermissionMessage,
    required String Function() getGoToSettingsLabel,
    required String Function() getCancelLabel,
  }) async {
    if (!Platform.isAndroid) return;
    if (_autoSyncStarted) return;
    _autoSyncStarted = true;

    await syncUpcomingTaskAlarms(
      getPermissionTitle: getPermissionTitle,
      getPermissionMessage: getPermissionMessage,
      getGoToSettingsLabel: getGoToSettingsLabel,
      getCancelLabel: getCancelLabel,
      suppressUiIfNoPermission: true,
    );

    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(_checkInterval, (_) {
      syncUpcomingTaskAlarms(
        getPermissionTitle: getPermissionTitle,
        getPermissionMessage: getPermissionMessage,
        getGoToSettingsLabel: getGoToSettingsLabel,
        getCancelLabel: getCancelLabel,
        suppressUiIfNoPermission: true,
      );
    });
  }

  /// 停止自动检查（测试或手动控制时可用）。
  void stopAutoSync() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
    _autoSyncStarted = false;
  }

  /// 检查 [当前时间, 明日同一时刻-1秒] 内需提醒任务并创建系统闹钟。
  ///
  /// 条件：
  /// - task.useSystemAlarm == true
  /// - task.hasNotification == true
  /// - task.completed == false
  /// - 且提醒时刻命中检查窗口
  Future<void> syncUpcomingTaskAlarms({
    required String Function() getPermissionTitle,
    required String Function() getPermissionMessage,
    required String Function() getGoToSettingsLabel,
    required String Function() getCancelLabel,
    bool suppressUiIfNoPermission = true,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      final tasks = await TaskRepository().fetchAll();
      final now = DateTime.now();
      final windowStart = now;
      final windowEnd = now.add(_windowDuration).subtract(
            const Duration(seconds: 1),
          );
      final prefs = await SharedPreferences.getInstance();
      final createdKeys = _loadAndPruneAlarmKeys(prefs, now);
      var changed = false;

      for (final task in tasks) {
        if (!_shouldCreateForTask(task)) continue;

        final reminderTimes =
            _getReminderDateTimesInWindow(task, windowStart, windowEnd);
        for (final reminderAt in reminderTimes) {
          final key = _alarmKey(task, reminderAt);
          if (createdKeys.contains(key)) continue;

          final created = await createAlarm(
            hour: reminderAt.hour,
            minute: reminderAt.minute,
            title: task.title,
            context: null,
            getPermissionTitle: getPermissionTitle,
            getPermissionMessage: getPermissionMessage,
            getGoToSettingsLabel: getGoToSettingsLabel,
            getCancelLabel: getCancelLabel,
            suppressUiIfNoPermission: suppressUiIfNoPermission,
          );
          if (created) {
            createdKeys.add(key);
            changed = true;
          }
        }
      }

      if (changed) {
        await prefs.setStringList(_prefsAlarmKeys, createdKeys.toList());
      }
    } catch (e) {
      debugPrint('SystemAlarmService.syncUpcomingTaskAlarms error: $e');
    }
  }

  bool _shouldCreateForTask(TaskEntity task) {
    return task.useSystemAlarm && task.hasNotification && !task.completed;
  }

  Set<String> _loadAndPruneAlarmKeys(SharedPreferences prefs, DateTime now) {
    final raw = prefs.getStringList(_prefsAlarmKeys) ?? const <String>[];
    final keepAfter = now.subtract(const Duration(days: 2)).millisecondsSinceEpoch;
    final next = <String>{};
    for (final k in raw) {
      final at = _alarmAtFromKey(k);
      if (at == null || at < keepAfter) continue;
      next.add(k);
    }
    return next;
  }

  int? _alarmAtFromKey(String key) {
    final idx = key.indexOf('@');
    if (idx <= 0 || idx >= key.length - 1) return null;
    return int.tryParse(key.substring(idx + 1));
  }

  String _alarmKey(TaskEntity task, DateTime reminderAt) {
    final id = task.id ?? 0;
    return '$id@${reminderAt.millisecondsSinceEpoch}';
  }

  List<DateTime> _getReminderDateTimesInWindow(
    TaskEntity task,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    final result = <DateTime>[];
    final baseOccurrence = RecurrenceUtils.getBaseOccurrenceDateTime(task);
    final reminderRule = ReminderRule.fromStorage(
          task.reminderTime,
          occurrenceDateTime: baseOccurrence,
        ) ??
        const ReminderRule.relative(0);
    final repeat = RepeatSelection.fromStorage(
      task.repeatRule,
      baseDate: baseOccurrence,
    );

    if (!repeat.isRepeating) {
      if (baseOccurrence == null) return result;
      final scheduled = reminderRule.scheduleAt(baseOccurrence);
      if (_isWithinWindow(scheduled, windowStart, windowEnd)) {
        result.add(scheduled!);
      }
      return result;
    }

    if (reminderRule.type == ReminderType.absolute) {
      final abs = reminderRule.absoluteAt;
      if (_isWithinWindow(abs, windowStart, windowEnd)) {
        result.add(abs!);
      }
      return result;
    }

    final leadMinutes = reminderRule.minutesBefore ?? 0;
    final occurrenceStart = windowStart.add(Duration(minutes: leadMinutes));
    final occurrenceEnd = windowEnd.add(Duration(minutes: leadMinutes));
    var d = DateTime(
      occurrenceStart.year,
      occurrenceStart.month,
      occurrenceStart.day,
    );
    final endDate = DateTime(
      occurrenceEnd.year,
      occurrenceEnd.month,
      occurrenceEnd.day,
    );

    while (!d.isAfter(endDate)) {
      if (RecurrenceUtils.taskMatchesDate(task, d)) {
        final occDt = RecurrenceUtils.getOccurrenceDateTime(task, d);
        if (occDt != null) {
          final scheduled = occDt.subtract(Duration(minutes: leadMinutes));
          if (_isWithinWindow(scheduled, windowStart, windowEnd)) {
            result.add(scheduled);
          }
        }
      }
      d = d.add(const Duration(days: 1));
    }

    final unique = <int, DateTime>{};
    for (final dt in result) {
      unique[dt.millisecondsSinceEpoch] = dt;
    }
    return unique.values.toList()..sort();
  }

  bool _isWithinWindow(
    DateTime? dateTime,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    if (dateTime == null) return false;
    return !dateTime.isBefore(windowStart) && !dateTime.isAfter(windowEnd);
  }

  /// 显示权限引导弹窗
  /// 返回：true=用户点击去设置，false=用户选择取消（降级），null=用户关闭弹窗
  Future<bool?> _showPermissionDialog({
    required BuildContext context,
    required String Function() getPermissionTitle,
    required String Function() getPermissionMessage,
    required String Function() getGoToSettingsLabel,
    required String Function() getCancelLabel,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(getPermissionTitle()),
        content: Text(getPermissionMessage()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(getCancelLabel()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(getGoToSettingsLabel()),
          ),
        ],
      ),
    );
  }
}
