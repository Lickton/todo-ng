import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/services/system_alarm_service.dart';
import 'package:doable_todo_list_app/models/action_item.dart';
import 'package:doable_todo_list_app/models/task_entity.dart';
import 'package:doable_todo_list_app/repositories/task_repository.dart';
import 'package:doable_todo_list_app/utils/meeting_utils.dart';
import 'package:doable_todo_list_app/widgets/action_selector.dart';
import 'package:doable_todo_list_app/widgets/description_markdown_field.dart';
import 'package:doable_todo_list_app/widgets/reminder_setting_field.dart';
import 'package:doable_todo_list_app/widgets/repeat_picker_field.dart';

import 'package:doable_todo_list_app/screens/home_page.dart' show Task;

class TaskDetailSheet extends StatefulWidget {
  const TaskDetailSheet({super.key, required this.task});

  final Task task;

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  late Task _task;

  bool _reminder = false;
  String? _reminderTime;
  bool _useSystemAlarm = false;
  String? _repeatRule;
  final Set<int> _repeatWeekdays = {};
  final Set<int> _repeatMonthDays = {};
  final Map<int, Set<int>> _repeatYearMonthDays = {};
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  List<ActionItem> _actions = [];
  bool _hasIncompleteAction = false;

  /// 全屏 Markdown 编辑打开时隐藏主保存按钮
  bool _isFullscreenMarkdown = false;

  /// 保存前触发，将描述区内联未暂存内容同步到 controller
  final _descFlushRequested = ValueNotifier<int>(0);

  static const Color _blueColor = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _task = widget.task;

    _titleCtrl.text = _task.title;
    final desc = _task.description ?? '';
    _descCtrl.text = desc;
    if (kDebugMode && desc.isNotEmpty) {
      final hasTrailingSpaces = desc.contains('  \n') || desc.endsWith('  ');
      debugPrint('[TaskDetailSheet] 加载 description 长度=${desc.length}, '
          '含行尾双空格=$hasTrailingSpaces, '
          'repr=${desc.replaceAll('\n', '\\n').replaceAll(' ', '·')}');
    }

    _reminder = _task.hasNotification;
    _reminderTime = _task.reminderTime;
    _useSystemAlarm = _task.useSystemAlarm;
    _repeatRule = _task.repeatRule;
    _hydrateAllFromRule(_repeatRule);

    _selectedDate = _parseDateOrNull(_task.date);
    _selectedTime = _parseTimeOrNull(_task.time);

    _actions = _task.actions ?? [];
  }

  @override
  void dispose() {
    _descFlushRequested.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) => DateFormat('dd/MM/yy').format(d);

  String _formatTime(TimeOfDay t) {
    final dt = DateTime(0, 1, 1, t.hour, t.minute);
    return DateFormat('h:mm a').format(dt);
  }

  DateTime? _parseDateOrNull(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      return DateFormat('dd/MM/yy').parseStrict(s);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseTimeOrNull(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      final dt = DateFormat('h:mm a').parseStrict(s);
      return TimeOfDay.fromDateTime(dt);
    } catch (_) {
      return null;
    }
  }

  void _hydrateAllFromRule(String? rule) {
    _repeatWeekdays.clear();
    _repeatMonthDays.clear();
    _repeatYearMonthDays.clear();
    if (rule == null) return;
    final colon = rule.indexOf(':');
    if (colon < 0 || colon + 1 >= rule.length) return;
    final suffix = rule.substring(colon + 1).trim();
    if (rule.startsWith('Weekly')) {
      for (final s in suffix.split(RegExp(r'[,\s\[\]]+'))) {
        final v = int.tryParse(s.trim());
        if (v != null && v >= 1 && v <= 7) _repeatWeekdays.add(v);
      }
    } else if (rule.startsWith('Monthly')) {
      for (final s in suffix.split(RegExp(r'[,\s\[\]]+'))) {
        final v = int.tryParse(s.trim());
        if (v != null && v >= 1 && v <= 31) _repeatMonthDays.add(v);
      }
    } else if (rule.startsWith('Yearly')) {
      for (final part in suffix.split(',')) {
        final dash = part.indexOf('-');
        if (dash > 0 && dash < part.length - 1) {
          final m = int.tryParse(part.substring(0, dash).trim());
          final d = int.tryParse(part.substring(dash + 1).trim());
          if (m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
            _repeatYearMonthDays.putIfAbsent(m, () => {}).add(d);
          }
        }
      }
    }
  }

  Future<void> _save() async {
    _descFlushRequested.value++;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterTitle)),
      );
      return;
    }

    if (_hasIncompleteAction) {
      final hasMeetingIncomplete = _actions.any((a) =>
          a.type == 'meeting' &&
          (a.data == null ||
              a.data!.trim().isEmpty ||
              !MeetingUtils.hasValidMeetingData(a.data!)));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasMeetingIncomplete
                ? AppLocalizations.of(context)!.meetingInvitationEmpty
                : AppLocalizations.of(context)!.pleaseFillActionOrSelectNone,
          ),
        ),
      );
      return;
    }

    final dateStr = _formatDate(_selectedDate ?? DateTime.now());
    final timeStr = _selectedTime != null ? _formatTime(_selectedTime!) : null;

    String? normalizedRepeat;
    if (_repeatRule == null || _repeatRule == 'No repeat') {
      normalizedRepeat = null;
    } else if (_repeatRule == 'Weekly' && _repeatWeekdays.isNotEmpty) {
      normalizedRepeat = 'Weekly:${_repeatWeekdays.toList()..sort()}';
    } else if (_repeatRule == 'Monthly' && _repeatMonthDays.isNotEmpty) {
      normalizedRepeat = 'Monthly:${_repeatMonthDays.toList()..sort()}';
    } else if (_repeatRule == 'Yearly' && _repeatYearMonthDays.isNotEmpty) {
      final parts = <String>[];
      for (final e in _repeatYearMonthDays.entries) {
        for (final d in e.value) {
          parts.add('${e.key}-$d');
        }
      }
      parts.sort();
      normalizedRepeat = 'Yearly:${parts.join(',')}';
    } else {
      normalizedRepeat = _repeatRule;
    }

    final validActions = _actions
        .where((a) =>
            a.type.isNotEmpty && (a.data?.trim().isNotEmpty == true))
        .toList();
    final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text;
    if (kDebugMode && desc != null) {
      // 调试：验证行尾两个空格是否被保留（Markdown 换行）
      final hasTrailingSpaces = desc.contains('  \n') || desc.endsWith('  ');
      debugPrint('[TaskDetailSheet] 保存 description 长度=${desc.length}, '
          '含行尾双空格=$hasTrailingSpaces, '
          'repr=${desc.replaceAll('\n', '\\n').replaceAll(' ', '·')}');
    }
    final entity = TaskEntity(
      id: _task.id,
      title: title,
      description: desc,
      time: timeStr,
      date: dateStr,
      hasNotification: _reminder,
      reminderTime: _reminder ? _reminderTime : null,
      useSystemAlarm: _useSystemAlarm,
      repeatRule: normalizedRepeat,
      completed: _task.completed,
      actions: validActions.isEmpty ? null : validActions,
    );

    final rowsUpdated = await TaskRepository().update(entity);
    if (kDebugMode) {
      debugPrint('[TaskDetailSheet] update 返回 rowsUpdated=$rowsUpdated');
    }

    if (mounted && _reminder && _useSystemAlarm && SystemAlarmService.instance.isSupported) {
      final hm = ReminderSettingField.getReminderHourMinute(
        reminderTime: _reminderTime,
        taskDate: _selectedDate ?? DateTime.now(),
        taskTime: _selectedTime,
      );
      if (hm != null && mounted) {
        await SystemAlarmService.instance.createAlarm(
          hour: hm.$1,
          minute: hm.$2,
          title: title,
          context: context,
          getPermissionTitle: () => AppLocalizations.of(context)!.systemAlarmPermissionTitle,
          getPermissionMessage: () => AppLocalizations.of(context)!.systemAlarmPermissionMessage,
          getGoToSettingsLabel: () => AppLocalizations.of(context)!.goToSettings,
          getCancelLabel: () => AppLocalizations.of(context)!.useSystemAlarmFallback,
        );
      }
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final initialSize = viewInsets > 0 ? 0.95 : 0.7;

    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: _buildContent(),
                ),
              ),
              if (!_isFullscreenMarkdown) _buildSaveButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + viewInsets),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _blueColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppLocalizations.of(context)!.save,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    const spacing = 16.0;
    const bigSpacing = 24.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(text: AppLocalizations.of(context)!.taskLabel),
          const SizedBox(height: spacing),
          _InputField(
            controller: _titleCtrl,
            hint: AppLocalizations.of(context)!.title,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: spacing),
          _FieldLabel(text: AppLocalizations.of(context)!.description),
          const SizedBox(height: spacing),
          DescriptionMarkdownField(
            controller: _descCtrl,
            hintText: AppLocalizations.of(context)!.description,
            onChanged: () => setState(() {}),
            onFullscreenChanged: (v) =>
                setState(() => _isFullscreenMarkdown = v),
            flushRequested: _descFlushRequested,
          ),
          const SizedBox(height: bigSpacing),

          ActionSelector(
            showTitle: true,
            initialActions: _actions,
            onActionsChanged: (list) => setState(() => _actions = list),
            onHasIncompleteChanged: (v) =>
                setState(() => _hasIncompleteAction = v),
          ),
          const SizedBox(height: bigSpacing),

          _FieldLabel(text: AppLocalizations.of(context)!.time),
          const SizedBox(height: spacing),
          RepeatPickerField(
            repeatRule: _repeatRule,
            repeatWeekdays: _repeatWeekdays,
            repeatMonthDays: _repeatMonthDays,
            repeatYearMonthDays: _repeatYearMonthDays,
            selectedTime: _selectedTime,
            onTimeChanged: (t) => setState(() => _selectedTime = t),
            onChanged: (rule, {weekdays, monthDays, yearMonthDays}) {
              setState(() {
                _repeatRule = rule;
                _repeatWeekdays.clear();
                _repeatWeekdays.addAll(weekdays ?? {});
                _repeatMonthDays.clear();
                _repeatMonthDays.addAll(monthDays ?? {});
                _repeatYearMonthDays.clear();
                _repeatYearMonthDays.addAll(yearMonthDays ?? {});
              });
            },
          ),
          const SizedBox(height: 12),
          ReminderSettingField(
            reminderEnabled: _reminder,
            reminderTime: _reminderTime,
            taskDate: _selectedDate ?? DateTime.now(),
            taskTime: _selectedTime,
            onReminderChanged: (enabled, time) =>
                setState(() {
                  _reminder = enabled;
                  _reminderTime = time;
                }),
            useSystemAlarm: _useSystemAlarm,
            onSystemAlarmChanged: Platform.isAndroid
                ? (v) => setState(() => _useSystemAlarm = v)
                : null,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
      ),
      style: const TextStyle(fontSize: 14, height: 1.4),
    );
  }
}
