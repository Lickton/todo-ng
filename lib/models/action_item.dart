/// 单个动作项：类型、数据、目标（如地图偏好、会议平台等）。
class ActionItem {
  const ActionItem({
    required this.type,
    this.data,
    this.target,
  });

  final String type;
  final String? data;
  final String? target;

  Map<String, dynamic> toJson() => {
        'type': type,
        'data': data,
        'target': target,
      };

  factory ActionItem.fromJson(Map<String, dynamic> j) => ActionItem(
        type: j['type'] as String? ?? '',
        data: j['data'] as String?,
        target: j['target'] as String?,
      );

  ActionItem copyWith({String? type, String? data, String? target}) =>
      ActionItem(
        type: type ?? this.type,
        data: data ?? this.data,
        target: target ?? this.target,
      );
}
