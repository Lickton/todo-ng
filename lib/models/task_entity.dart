import 'dart:convert';

import 'action_item.dart';

class TaskEntity {
  TaskEntity({
    this.id,
    required this.title,
    this.description,
    this.time,
    this.date,
    this.hasNotification = false,
    this.repeatRule,
    this.completed = false,
    this.createdAt,
    this.updatedAt,
    this.actions,
  });

  int? id;
  String title;
  String? description;
  String? time; // "11:30 AM"
  String? date; // "26/11/24"
  bool hasNotification;
  String? repeatRule; // e.g., "Weekly"
  bool completed;
  String? createdAt;
  String? updatedAt;

  /// 动作列表，支持多个动作（如同时打电话+导航）。空或 null 表示无动作。
  List<ActionItem>? actions;

  /// 兼容旧版单动作：返回第一个动作的 type，无动作时 null。
  String? get actionType => actions?.isNotEmpty == true ? actions!.first.type : null;
  String? get actionData => actions?.isNotEmpty == true ? actions!.first.data : null;
  String? get actionTarget => actions?.isNotEmpty == true ? actions!.first.target : null;

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

  factory TaskEntity.fromMap(Map<String, dynamic> m) {
    final acts = _parseActions(m);
    return TaskEntity(
      id: m['id'] as int?,
      title: m['title'] as String,
      description: m['description'] as String?,
      time: m['time'] as String?,
      date: m['date'] as String?,
      hasNotification: (m['has_notification'] as int? ?? 0) == 1,
      repeatRule: m['repeat_rule'] as String?,
      completed: (m['completed'] as int? ?? 0) == 1,
      createdAt: m['created_at'] as String?,
      updatedAt: m['updated_at'] as String?,
      actions: acts.isEmpty ? null : acts,
    );
  }

  Map<String, dynamic> toMap() {
    final acts = actions ?? [];
    final actionsJson = acts.isEmpty
        ? null
        : jsonEncode(acts.map((a) => a.toJson()).toList());
    return {
      'id': id,
      'title': title,
      'description': description,
      'time': time,
      'date': date,
      'has_notification': hasNotification ? 1 : 0,
      'repeat_rule': repeatRule,
      'completed': completed ? 1 : 0,
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
    bool? hasNotification,
    String? repeatRule,
    bool? completed,
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
      hasNotification: hasNotification ?? this.hasNotification,
      repeatRule: repeatRule ?? this.repeatRule,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      actions: actions ?? this.actions,
    );
  }
}
