import 'package:flutter/material.dart';

import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/models/action_item.dart';
import 'package:doable_todo_list_app/models/task_entity.dart';
import 'package:doable_todo_list_app/utils/action_executor.dart';

/// 动作类型对应的显示文案（根据当前语言）。
String _actionTypeLabel(BuildContext context, String? type) {
  final l10n = AppLocalizations.of(context)!;
  switch (type) {
    case 'navigation':
      return l10n.actionTypeLabelNavigation;
    case 'phone':
      return l10n.actionTypeLabelPhone;
    case 'web':
      return l10n.actionTypeLabelWeb;
    case 'meeting':
      return l10n.actionTypeLabelMeeting;
    case 'message':
      return l10n.actionTypeLabelMessage;
    default:
      return l10n.actionTypeLabelDefault;
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
        SnackBar(content: Text(AppLocalizations.of(context)!.actionOpened(_actionTypeLabel(context, widget.task.actionType)))),
      );
    } else {
      final msg = (widget.task.actionType == 'meeting' && ActionExecutor.lastTencentNotInstalled)
          ? AppLocalizations.of(context)!.tencentMeetingNotInstalled
          : AppLocalizations.of(context)!.actionOpenFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_actionTypeIcon(type), size: 18, color: _themeColor),
              const SizedBox(width: 6),
              Text(
                _actionTypeLabel(context, type),
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

/// 多个动作按钮：为每个动作显示一个按钮，点击执行对应动作。
class TaskActionButtons extends StatelessWidget {
  const TaskActionButtons({
    super.key,
    required this.task,
    this.onActionExecuted,
  });

  final TaskEntity task;
  final VoidCallback? onActionExecuted;

  @override
  Widget build(BuildContext context) {
    final actions = task.actions;
    if (actions == null || actions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions
          .where((a) => a.type.isNotEmpty && (a.data?.trim().isNotEmpty == true))
          .map((item) => _SingleActionButton(
                item: item,
                onActionExecuted: onActionExecuted,
              ))
          .toList(),
    );
  }
}

class _SingleActionButton extends StatefulWidget {
  const _SingleActionButton({
    required this.item,
    this.onActionExecuted,
  });

  final ActionItem item;
  final VoidCallback? onActionExecuted;

  @override
  State<_SingleActionButton> createState() => _SingleActionButtonState();
}

class _SingleActionButtonState extends State<_SingleActionButton> {
  static const Color _themeColor = Color(0xFF2563EB);
  bool _loading = false;

  Future<void> _onPressed() async {
    if (_loading) return;
    setState(() => _loading = true);
    final ok = await ActionExecutor.executeActionItem(
      widget.item.type,
      widget.item.data,
      widget.item.target,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.actionOpened(_actionTypeLabel(context, widget.item.type)))),
      );
    } else {
      final msg = (widget.item.type == 'meeting' && ActionExecutor.lastTencentNotInstalled)
          ? AppLocalizations.of(context)!.tencentMeetingNotInstalled
          : AppLocalizations.of(context)!.actionOpenFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
    widget.onActionExecuted?.call();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_actionTypeIcon(widget.item.type), size: 18, color: _themeColor),
              const SizedBox(width: 6),
              Text(
                _actionTypeLabel(context, widget.item.type),
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
