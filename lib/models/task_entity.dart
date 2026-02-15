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
    this.actionType,
    this.actionData,
    this.actionTarget,
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

  /// 动作类型。可选: 'navigation'|'phone'|'web'|'meeting'|'message'，null 表示无动作。
  String? actionType;
  /// 动作数据: navigation=地址, phone=号码, web=URL, meeting=会议链接/会议号, message=预设消息文本。
  String? actionData;
  /// 动作目标: navigation=地图偏好('gaode'|'baidu'|'google'), meeting=会议平台('tencent'|'zoom'|'dingtalk'), message=联系人标识，其他可为 null。
  String? actionTarget;

  factory TaskEntity.fromMap(Map<String, dynamic> m) => TaskEntity(
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
        actionType: m['action_type'] as String?,
        actionData: m['action_data'] as String?,
        actionTarget: m['action_target'] as String?,
      );

  Map<String, dynamic> toMap() => {
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
        'action_type': actionType,
        'action_data': actionData,
        'action_target': actionTarget,
      };

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
    String? actionType,
    String? actionData,
    String? actionTarget,
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
      actionType: actionType ?? this.actionType,
      actionData: actionData ?? this.actionData,
      actionTarget: actionTarget ?? this.actionTarget,
    );
  }
}
