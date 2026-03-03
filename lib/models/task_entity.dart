import 'dart:convert';

import 'package:intl/intl.dart';

import 'action_item.dart';

/// 优先级：红 > 黄 > 蓝 > 白
enum TaskPriority {
  red,
  yellow,
  blue,
  white,
}

/// 时间类型：仅开始、仅结束、两者都有
/// - start_only: 有计划的任务（组会、学习计划等），可重复
/// - end_only / both: 无重复，做一段时间就结束
enum TimeKind {
  startOnly, // 仅有开始时间
  endOnly, // 仅有结束时间
  both, // 开始+结束都有
}

class TaskEntity {
  TaskEntity({
    this.id,
    required this.title,
    this.description,
    this.time,
    this.date,
    this.timeKind = TimeKind.startOnly,
    this.endTime,
    this.endDate,
    this.hasNotification = false,
    this.reminderTime,
    this.useSystemAlarm = false,
    this.repeatRule,
    this.completed = false,
    this.priority = TaskPriority.white,
    this.createdAt,
    this.updatedAt,
    this.actions,
  });

  int? id;
  String title;
  String? description;
  String? time; // "11:30 AM"
  String? date; // "26/11/24"
  /// 时间类型，null 或缺失时按 startOnly 处理（兼容旧数据）
  TimeKind timeKind;
  String? endTime; // "18:00"
  String? endDate; // "26/11/24"
  bool hasNotification;

  /// 提醒时间：
  /// - offset:m 发生当天提前 m 分钟
  /// - days_before:n,h:mm 发生前 n 天在 h:mm 提醒
  /// - custom:dd/MM/yy h:mm a 自定义绝对时间
  /// - dd/MM/yy h:mm a 无任务时间时的绝对时间
  String? reminderTime;

  /// 是否同时在系统闹钟中添加提醒（仅 Android）
  bool useSystemAlarm;
  String? repeatRule; // e.g., "Weekly"
  bool completed;
  TaskPriority priority;
  String? createdAt;
  String? updatedAt;

  /// 动作列表，支持多个动作（如同时打电话+导航）。空或 null 表示无动作。
  List<ActionItem>? actions;

  static final DateFormat _dateFmt = DateFormat('dd/MM/yy');
  static final DateFormat _timeFmt = DateFormat('h:mm a');

  /// 兼容旧版单动作：返回第一个动作的 type，无动作时 null。
  String? get actionType =>
      actions?.isNotEmpty == true ? actions!.first.type : null;
  String? get actionData =>
      actions?.isNotEmpty == true ? actions!.first.data : null;
  String? get actionTarget =>
      actions?.isNotEmpty == true ? actions!.first.target : null;

  /// 统一后的开始时间（Todoist/Things 风格）：一个开始时间点 + 可选结束时间点。
  DateTime? get startAt => _combineDateTime(date, time);

  /// 可选结束时间，null 表示无区间，仅有一个时间点。
  DateTime? get endAt => _combineDateTime(endDate, endTime);

  bool get hasTimeRange => endAt != null;

  static DateTime? _combineDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null ||
        dateStr.isEmpty ||
        timeStr == null ||
        timeStr.isEmpty) {
      return null;
    }
    try {
      final d = _dateFmt.parseStrict(dateStr);
      final t = _timeFmt.parseStrict(timeStr);
      return DateTime(d.year, d.month, d.day, t.hour, t.minute);
    } catch (_) {
      return null;
    }
  }

  static List<ActionItem> _parseActions(Map<String, dynamic> m) {
    final raw = m['actions'] as String?;
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>?;
        if (list != null) {
          return list
              .map((e) => ActionItem.fromJson(e as Map<String, dynamic>))
              .where((a) => a.type.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    // 兼容旧版单动作列
    final t = m['action_type'] as String?;
    if (t != null && t.isNotEmpty) {
      return [
        ActionItem(
          type: t,
          data: m['action_data'] as String?,
          target: m['action_target'] as String?,
        ),
      ];
    }
    return [];
  }

  static TimeKind _parseTimeKind(String? v) {
    if (v == null || v.isEmpty) return TimeKind.startOnly;
    switch (v) {
      case 'end_only':
        return TimeKind.endOnly;
      case 'both':
        return TimeKind.both;
      default:
        return TimeKind.startOnly;
    }
  }

  static String _timeKindToStr(TimeKind k) {
    switch (k) {
      case TimeKind.endOnly:
        return 'end_only';
      case TimeKind.both:
        return 'both';
      default:
        return 'start_only';
    }
  }

  static TaskPriority _parsePriority(String? v) {
    if (v == null || v.isEmpty) return TaskPriority.white;
    switch (v) {
      case 'red':
        return TaskPriority.red;
      case 'yellow':
        return TaskPriority.yellow;
      case 'blue':
        return TaskPriority.blue;
      default:
        return TaskPriority.white;
    }
  }

  static String _priorityToStr(TaskPriority p) {
    switch (p) {
      case TaskPriority.red:
        return 'red';
      case TaskPriority.yellow:
        return 'yellow';
      case TaskPriority.blue:
        return 'blue';
      default:
        return 'white';
    }
  }

  factory TaskEntity.fromMap(Map<String, dynamic> m) {
    final acts = _parseActions(m);
    return TaskEntity(
      id: m['id'] as int?,
      title: m['title'] as String,
      description: m['description'] as String?,
      time: m['time'] as String?,
      date: m['date'] as String?,
      timeKind: _parseTimeKind(m['time_kind'] as String?),
      endTime: m['end_time'] as String?,
      endDate: m['end_date'] as String?,
      hasNotification: (m['has_notification'] as int? ?? 0) == 1,
      reminderTime: m['reminder_time'] as String?,
      useSystemAlarm: (m['use_system_alarm'] as int? ?? 0) == 1,
      repeatRule: m['repeat_rule'] as String?,
      completed: (m['completed'] as int? ?? 0) == 1,
      priority: _parsePriority(m['priority'] as String?),
      createdAt: m['created_at'] as String?,
      updatedAt: m['updated_at'] as String?,
      actions: acts.isEmpty ? null : acts,
    );
  }

  Map<String, dynamic> toMap() {
    final acts = actions ?? [];
    final actionsJson =
        acts.isEmpty ? null : jsonEncode(acts.map((a) => a.toJson()).toList());
    return {
      'id': id,
      'title': title,
      'description': description,
      'time': time,
      'date': date,
      'time_kind': _timeKindToStr(timeKind),
      'end_time': endTime,
      'end_date': endDate,
      'has_notification': hasNotification ? 1 : 0,
      'reminder_time': reminderTime,
      'use_system_alarm': useSystemAlarm ? 1 : 0,
      'repeat_rule': repeatRule,
      'completed': completed ? 1 : 0,
      'priority': _priorityToStr(priority),
      'created_at': createdAt,
      'updated_at': updatedAt,
      'actions': actionsJson,
    };
  }

  TaskEntity copyWith({
    int? id,
    String? title,
    String? description,
    String? time,
    String? date,
    TimeKind? timeKind,
    String? endTime,
    String? endDate,
    bool? hasNotification,
    String? reminderTime,
    bool? useSystemAlarm,
    String? repeatRule,
    bool? completed,
    TaskPriority? priority,
    String? createdAt,
    String? updatedAt,
    List<ActionItem>? actions,
  }) {
    return TaskEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      time: time ?? this.time,
      date: date ?? this.date,
      timeKind: timeKind ?? this.timeKind,
      endTime: endTime ?? this.endTime,
      endDate: endDate ?? this.endDate,
      hasNotification: hasNotification ?? this.hasNotification,
      reminderTime: reminderTime ?? this.reminderTime,
      useSystemAlarm: useSystemAlarm ?? this.useSystemAlarm,
      repeatRule: repeatRule ?? this.repeatRule,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      actions: actions ?? this.actions,
    );
  }
}
