import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/services/notification_service.dart';

/// 提醒设置项：置于时间区块末尾，从按钮变为设置项
/// - 有任务时间：显示提前 X 分钟 / 准时 / 自定义
/// - 无任务时间：显示快捷选项（今天 9:00 等）或自定义
/// - Android 专用：设定系统闹钟开关
class ReminderSettingField extends StatelessWidget {
  const ReminderSettingField({
    super.key,
    required this.reminderEnabled,
    required this.reminderTime,
    required this.taskDate,
    this.taskTime,
    required this.onReminderChanged,
    this.useSystemAlarm = false,
    this.onSystemAlarmChanged,
  });

  final bool reminderEnabled;
  /// offset:5, offset:10, offset:0(准时), custom:dd/MM/yy h:mm a, 或 dd/MM/yy h:mm a(绝对)
  final String? reminderTime;
  final DateTime? taskDate;
  final TimeOfDay? taskTime;
  final void Function(bool enabled, String? reminderTime) onReminderChanged;
  /// 是否同时在系统闹钟中添加（仅 Android 显示）
  final bool useSystemAlarm;
  final void Function(bool)? onSystemAlarmChanged;

  static const _blueColor = Color(0xFF2563EB);

  bool get _hasTaskTime => taskTime != null && taskDate != null;

  /// 从 reminderTime 解析出提醒时刻的 (hour, minute)，用于系统闹钟
  static (int hour, int minute)? getReminderHourMinute({
    required String? reminderTime,
    required DateTime? taskDate,
    required TimeOfDay? taskTime,
  }) {
    if (reminderTime == null || reminderTime.isEmpty) return null;
    DateTime? dt;
    if (taskDate != null && taskTime != null) {
      final taskDt = DateTime(
        taskDate.year,
        taskDate.month,
        taskDate.day,
        taskTime.hour,
        taskTime.minute,
      );
      if (reminderTime.startsWith('offset:')) {
        final min = int.tryParse(reminderTime.substring(7)) ?? 5;
        dt = taskDt.subtract(Duration(minutes: min));
      } else if (reminderTime.startsWith('custom:')) {
        try {
          dt = DateFormat('dd/MM/yy h:mm a').parse(reminderTime.substring(7));
        } catch (_) {}
      }
    }
    if (dt == null && !reminderTime.startsWith('offset:') && !reminderTime.startsWith('custom:')) {
      try {
        dt = DateFormat('dd/MM/yy h:mm a').parse(reminderTime);
      } catch (_) {}
    }
    if (dt == null) return null;
    return (dt.hour, dt.minute);
  }

  String _formatTime(TimeOfDay t) {
    return DateFormat('h:mm a').format(DateTime(0, 1, 1, t.hour, t.minute));
  }

  String _formatDateShort(BuildContext context, DateTime d) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.Md(locale).format(d);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时间摘要
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _hasTaskTime
                ? '${l10n.time}: ${_formatDateShort(context, taskDate!)} ${_formatTime(taskTime!)}'
                : '${l10n.time}: ${l10n.timeNotSet}',
            style: TextStyle(
              fontSize: 14,
              color: _hasTaskTime ? Colors.black87 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // 提醒区块
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              // 开启提醒开关
              _ReminderRow(
                icon: Icons.notifications,
                label: l10n.reminderEnabled,
                trailing: Switch(
                  value: reminderEnabled,
                  onChanged: (v) => _onToggle(context, v),
                  activeTrackColor: _blueColor,
                ),
                onTap: () => _onToggle(context, !reminderEnabled),
              ),
              if (reminderEnabled) ...[
                Divider(height: 1, color: Colors.grey.shade300),
                _ReminderRow(
                  icon: Icons.calendar_today,
                  label: _buildReminderLabel(context),
                  trailing: TextButton(
                    onPressed: () => _openReminderPicker(context),
                    child: Text(
                      _hasTaskTime ? l10n.modify : l10n.set,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _blueColor,
                      ),
                    ),
                  ),
                  onTap: () => _openReminderPicker(context),
                ),
                if (Platform.isAndroid && onSystemAlarmChanged != null) ...[
                  Divider(height: 1, color: Colors.grey.shade300),
                  _ReminderRow(
                    icon: Icons.alarm,
                    label: l10n.systemAlarmTitle,
                    subtitle: l10n.systemAlarmSubtitle,
                    trailing: Switch(
                      value: useSystemAlarm,
                      onChanged: onSystemAlarmChanged,
                      activeTrackColor: _blueColor,
                    ),
                    onTap: () => onSystemAlarmChanged!(!useSystemAlarm),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _buildReminderLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!reminderEnabled) return '';
    if (_hasTaskTime) {
      if (reminderTime == null || reminderTime!.isEmpty) {
        return l10n.minutesBefore(5); // 默认提前 5 分钟
      }
      if (reminderTime!.startsWith('offset:')) {
        final min = int.tryParse(reminderTime!.substring(7)) ?? 5;
        if (min == 0) return '${l10n.onTime} (${_formatReminderTimeFromOffset(0)})';
        return '${l10n.minutesBefore(min)} (${_formatReminderTimeFromOffset(min)})';
      }
      if (reminderTime!.startsWith('custom:')) {
        try {
          final s = reminderTime!.substring(7);
          final dt = DateFormat('dd/MM/yy h:mm a').parse(s);
          return DateFormat('h:mm a').format(dt);
        } catch (_) {}
      }
      return l10n.tapToSetReminderTime;
    } else {
      if (reminderTime != null && reminderTime!.isNotEmpty && !reminderTime!.startsWith('offset:')) {
        try {
          final dt = DateFormat('dd/MM/yy h:mm a').parse(reminderTime!);
          final now = DateTime.now();
          if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
            return l10n.todayAt(DateFormat('h:mm a').format(dt));
          }
          if (dt.year == now.year && dt.month == now.month && dt.day == now.day + 1) {
            return l10n.tomorrowAt(DateFormat('h:mm a').format(dt));
          }
          return DateFormat('M/d h:mm a').format(dt);
        } catch (_) {}
      }
      return l10n.tapToSetReminderTime;
    }
  }

  String _formatReminderTimeFromOffset(int minutesBefore) {
    if (taskTime == null || taskDate == null) return '';
    final dt = DateTime(
      taskDate!.year,
      taskDate!.month,
      taskDate!.day,
      taskTime!.hour,
      taskTime!.minute,
    );
    final reminder = dt.subtract(Duration(minutes: minutesBefore));
    return DateFormat('h:mm a').format(reminder);
  }

  Future<void> _onToggle(BuildContext context, bool enabled) async {
    if (enabled) {
      final userEnabled = await _checkNotificationPermission(context);
      if (!userEnabled) return;
    }
    onReminderChanged(enabled, enabled ? (reminderTime ?? 'offset:5') : null);
  }

  Future<bool> _checkNotificationPermission(BuildContext context) async {
    final userEnabled = await NotificationService.areNotificationsEnabledByUser();
    if (!userEnabled && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.notificationsDisabledInSettings),
          action: SnackBarAction(
            label: AppLocalizations.of(context)!.settings,
            onPressed: () => Navigator.pushNamed(context, 'settings'),
          ),
        ),
      );
    }
    return userEnabled;
  }

  Future<void> _openReminderPicker(BuildContext context) async {
    if (_hasTaskTime) {
      await _showReminderPickerWithTaskTime(context);
    } else {
      await _showReminderPickerNoTaskTime(context);
    }
  }

  Future<void> _showReminderPickerWithTaskTime(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final offsets = [5, 10, 15, 30, 60];
    final now = DateTime.now();
    final taskDt = DateTime(
      taskDate!.year,
      taskDate!.month,
      taskDate!.day,
      taskTime!.hour,
      taskTime!.minute,
    );

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.6;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        l10n.reminderTime,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...offsets.map((m) {
                      final reminderDt = taskDt.subtract(Duration(minutes: m));
                      final timeStr = DateFormat('h:mm a').format(reminderDt);
                      final isSelected = reminderTime == 'offset:$m';
                      return ListTile(
                        leading: isSelected ? const Icon(Icons.star, color: _blueColor, size: 22) : null,
                        title: Text('${l10n.minutesBefore(m)} ($timeStr)'),
                        onTap: () => Navigator.pop(ctx, 'offset:$m'),
                      );
                    }),
                    const Divider(),
                    ListTile(
                      leading: reminderTime == 'offset:0' ? const Icon(Icons.star, color: _blueColor, size: 22) : null,
                      title: Text('${l10n.onTime} (${DateFormat('h:mm a').format(taskDt)})'),
                      onTap: () => Navigator.pop(ctx, 'offset:0'),
                    ),
                    const Divider(),
                    ListTile(
                      title: Text(l10n.customTime),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: taskDt.isBefore(now) ? now : taskDt,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (picked == null || !context.mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(taskDt),
                        );
                        if (time != null && context.mounted) {
                          final customDt = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                          final str = DateFormat('dd/MM/yy h:mm a').format(customDt);
                          onReminderChanged(true, 'custom:$str');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) {
      onReminderChanged(true, selected);
    }
  }

  Future<void> _showReminderPickerNoTaskTime(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today9 = DateTime(now.year, now.month, now.day, 9, 0);
    final today12 = DateTime(now.year, now.month, now.day, 12, 0);
    final today18 = DateTime(now.year, now.month, now.day, 18, 0);
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrow9 = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
    final timeFmt = DateFormat('h:mm a');
    final options = [
      (l10n.todayAt(timeFmt.format(today9)), today9),
      (l10n.todayAt(timeFmt.format(today12)), today12),
      (l10n.todayAt(timeFmt.format(today18)), today18),
      (l10n.tomorrowAt(timeFmt.format(tomorrow9)), tomorrow9),
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.6;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        l10n.reminderTime,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        l10n.quickOptions,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...options.map((opt) {
                      return ListTile(
                        leading: const Icon(Icons.calendar_today, size: 20, color: Colors.black54),
                        title: Text(opt.$1),
                        onTap: () {
                          final str = DateFormat('dd/MM/yy h:mm a').format(opt.$2);
                          Navigator.pop(ctx, str);
                        },
                      );
                    }),
                    const Divider(),
                    ListTile(
                      title: Text(l10n.customTime),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (picked == null || !context.mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null && context.mounted) {
                          final customDt = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                          final str = DateFormat('dd/MM/yy h:mm a').format(customDt);
                          onReminderChanged(true, str);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) {
      onReminderChanged(true, selected);
    }
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}