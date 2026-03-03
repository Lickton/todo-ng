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
import 'package:doable_todo_list_app/utils/task_schedule_codec.dart';
import 'package:doable_todo_list_app/widgets/action_selector.dart';
import 'package:doable_todo_list_app/widgets/date_time_picker_section.dart';
import 'package:doable_todo_list_app/widgets/description_markdown_field.dart';
import 'package:doable_todo_list_app/widgets/priority_picker_field.dart';
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

  TaskPriority _priority = TaskPriority.white;
  bool _reminder = false;
  String? _reminderTime;
  bool _useSystemAlarm = false;
  TimeKind _timeKind = TimeKind.startOnly;
  String? _repeatRule;
  final Set<int> _repeatWeekdays = {};
  final Set<int> _repeatMonthDays = {};
  final Map<int, Set<int>> _repeatYearMonthDays = {};
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedEndTime;

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

    _priority = _task.priority;
    _reminder = _task.hasNotification;
    _useSystemAlarm = _task.useSystemAlarm;
    _timeKind = _task.timeKind;

    _selectedDate = _parseDateOrNull(_task.date) ?? DateTime.now();
    _selectedTime =
        _parseTimeOrNull(_task.time) ?? const TimeOfDay(hour: 0, minute: 0);
    _selectedEndDate = _parseDateOrNull(_task.endDate);
    _selectedEndTime = _parseTimeOrNull(_task.endTime);
    _reminderTime = ReminderRule.toLegacyUi(
      _task.reminderTime,
      occurrenceDateTime: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      ),
    );
    _hydrateAllFromRule(_task.repeatRule);

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
    final baseDate = _parseDateOrNull(_task.date);
    final parsed = RepeatSelection.fromStorage(rule, baseDate: baseDate);
    _repeatRule = parsed.toUiRule();
    _repeatWeekdays.clear();
    _repeatWeekdays.addAll(parsed.weekdays);
    _repeatMonthDays.clear();
    _repeatMonthDays.addAll(parsed.monthDays);
    _repeatYearMonthDays.clear();
    _repeatYearMonthDays.addAll(parsed.yearMonthDays);
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

    final dateStr = _formatDate(_selectedDate);
    final timeStr = _formatTime(_selectedTime);
    final endDateStr =
        _selectedEndDate != null ? _formatDate(_selectedEndDate!) : null;
    final endTimeStr =
        _selectedEndTime != null ? _formatTime(_selectedEndTime!) : null;

    final occurrenceDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final repeatSelection = _timeKind == TimeKind.startOnly
        ? RepeatSelection.fromUi(
            rule: _repeatRule,
            weekdays: _repeatWeekdays,
            monthDays: _repeatMonthDays,
            yearMonthDays: _repeatYearMonthDays,
          )
        : const RepeatSelection(frequency: RepeatFrequency.none);
    final normalizedRepeat = repeatSelection.toStorage();
    final reminderStorage = _reminder
        ? ReminderRule.fromUi(
            _reminderTime,
            occurrenceDateTime: occurrenceDateTime,
          )?.toStorage()
        : null;

    final validActions = _actions
        .where((a) => a.type.isNotEmpty && (a.data?.trim().isNotEmpty == true))
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
      priority: _priority,
      time: timeStr,
      date: dateStr,
      timeKind: _timeKind,
      endTime: endTimeStr,
      endDate: endDateStr,
      hasNotification: _reminder,
      reminderTime: reminderStorage,
      useSystemAlarm: _useSystemAlarm,
      repeatRule: normalizedRepeat,
      completed: _task.completed,
      actions: validActions.isEmpty ? null : validActions,
    );

    final rowsUpdated = await TaskRepository().update(entity);
    if (kDebugMode) {
      debugPrint('[TaskDetailSheet] update 返回 rowsUpdated=$rowsUpdated');
    }

    if (mounted &&
        _reminder &&
        _useSystemAlarm &&
        SystemAlarmService.instance.isSupported) {
      final hm = ReminderSettingField.getReminderHourMinute(
        reminderTime: _reminderTime,
        taskDate: _selectedDate,
        taskTime: _selectedTime,
      );
      if (hm != null && mounted) {
        await SystemAlarmService.instance.createAlarm(
          hour: hm.$1,
          minute: hm.$2,
          title: title,
          context: context,
          getPermissionTitle: () =>
              AppLocalizations.of(context)!.systemAlarmPermissionTitle,
          getPermissionMessage: () =>
              AppLocalizations.of(context)!.systemAlarmPermissionMessage,
          getGoToSettingsLabel: () =>
              AppLocalizations.of(context)!.goToSettings,
          getCancelLabel: () =>
              AppLocalizations.of(context)!.useSystemAlarmFallback,
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
          _FieldLabel(text: AppLocalizations.of(context)!.priority),
          const SizedBox(height: spacing),
          PriorityPickerField(
            value: _priority,
            onChanged: (p) => setState(() => _priority = p),
          ),
          const SizedBox(height: bigSpacing),
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
          _FieldLabel(text: AppLocalizations.of(context)!.dateAndTime),
          const SizedBox(height: spacing),
          DateTimePickerSection(
            timeKind: _timeKind,
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            onDateChanged: (d) => setState(() => _selectedDate = d),
            onTimeChanged: (t) => setState(() => _selectedTime = t),
            onTimeKindChanged: (k) => setState(() {
              _timeKind = k;
              if (k == TimeKind.both) {
                _selectedEndDate ??= _selectedDate.add(const Duration(days: 1));
                _selectedEndTime ??= _selectedTime;
              } else {
                _selectedEndDate = null;
                _selectedEndTime = null;
              }
            }),
            selectedEndDate: _selectedEndDate,
            selectedEndTime: _selectedEndTime,
            onEndDateChanged: (d) => setState(() => _selectedEndDate = d),
            onEndTimeChanged: (t) => setState(() => _selectedEndTime = t),
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
          _FieldLabel(text: AppLocalizations.of(context)!.reminder),
          const SizedBox(height: spacing),
          if (_timeKind == TimeKind.startOnly)
            RepeatPickerField(
              repeatRule: _repeatRule,
              repeatWeekdays: _repeatWeekdays,
              repeatMonthDays: _repeatMonthDays,
              repeatYearMonthDays: _repeatYearMonthDays,
              selectedTime: _selectedTime,
              onTimeChanged: (t) => setState(() =>
                  _selectedTime = t ?? const TimeOfDay(hour: 0, minute: 0)),
              showTimePicker: false,
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
          if (_timeKind == TimeKind.startOnly) const SizedBox(height: 12),
          ReminderSettingField(
            reminderEnabled: _reminder,
            reminderTime: _reminderTime,
            taskDate: _selectedDate,
            taskTime: _selectedTime,
            onReminderChanged: (enabled, time) => setState(() {
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
