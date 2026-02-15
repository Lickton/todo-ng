import 'package:flutter/material.dart';

import 'package:doable_todo_list_app/models/task_entity.dart';
import 'package:doable_todo_list_app/utils/action_executor.dart';

/// 动作类型对应的显示文案。
String _actionTypeLabel(String? type) {
  switch (type) {
    case 'navigation':
      return '导航';
    case 'phone':
      return '拨打';
    case 'web':
      return '打开';
    case 'meeting':
      return '会议';
    case 'message':
      return '消息';
    default:
      return '动作';
  }
}

/// 动作类型对应的图标。
IconData _actionTypeIcon(String? type) {
  switch (type) {
    case 'navigation':
      return Icons.navigation;
    case 'phone':
      return Icons.phone;
    case 'web':
      return Icons.web;
    case 'meeting':
      return Icons.video_call;
    case 'message':
      return Icons.message;
    default:
      return Icons.touch_app;
  }
}

/// 任务动作按钮：根据 [task] 的 actionType 显示对应图标与文案，点击执行动作并反馈结果。
class TaskActionButton extends StatefulWidget {
  const TaskActionButton({
    super.key,
    required this.task,
    this.onActionExecuted,
  });

  final TaskEntity task;
  final VoidCallback? onActionExecuted;

  @override
  State<TaskActionButton> createState() => _TaskActionButtonState();
}

class _TaskActionButtonState extends State<TaskActionButton> {
  static const Color _themeColor = Color(0xFF2563EB);
  bool _loading = false;

  Future<void> _onPressed() async {
    if (_loading) return;
    setState(() => _loading = true);
    final ok = await ActionExecutor.executeAction(widget.task);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已打开 ${_actionTypeLabel(widget.task.actionType)}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('打开失败，请检查是否安装对应应用'),
        ),
      );
    }
    widget.onActionExecuted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.task.actionType;
    if (type == null || type.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _loading ? null : _onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _themeColor, width: 1.5),
            color: _themeColor.withOpacity(0.08),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_actionTypeIcon(type), size: 18, color: _themeColor),
                    const SizedBox(width: 6),
                    Text(
                      _actionTypeLabel(type),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
