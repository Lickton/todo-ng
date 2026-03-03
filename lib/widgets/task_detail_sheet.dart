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
import 'package:doable_todo_list_app/widgets/reminder_setting_field.dart';

import 'package:doable_todo_list_app/screens/home_page.dart' show Task;

class TaskDetailSheet extends StatefulWidget {
  const TaskDetailSheet({super.key, required this.task});

  final Task task;

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  // 标题与描述的编辑状态，保存时统一从 controller 读取。
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  late Task _task;

  bool _reminder = false;
  String? _reminderTime;
  bool _useSystemAlarm = false;
  late DateTimeSectionState _scheduleState;

  List<ActionItem> _actions = [];
  bool _hasIncompleteAction = false;

  static const Color _blueColor = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _task = widget.task;

    _titleCtrl.text = _task.title;
    final desc = _task.description ?? '';
    _descCtrl.text = desc;
    _reminder = _task.hasNotification;
    _useSystemAlarm = _task.useSystemAlarm;
    final selectedDate = _parseDateOrNull(_task.date) ?? DateTime.now();
    final selectedTime =
        _parseTimeOrNull(_task.time) ?? const TimeOfDay(hour: 0, minute: 0);
    _scheduleState = DateTimeSectionState(
      dateEnabled: (_task.date ?? '').trim().isNotEmpty,
      timeEnabled: (_task.time ?? '').trim().isNotEmpty,
      repeatEnabled: (_task.repeatRule ?? '').trim().isNotEmpty,
      date: selectedDate,
      time: selectedTime,
      repeat: _repeatUiFromStorage(_task.repeatRule),
    ).normalized();
    _reminderTime = ReminderRule.toLegacyUi(
      _task.reminderTime,
      occurrenceDateTime: DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      ),
    );

    _actions = _task.actions ?? [];
  }

  @override
  void dispose() {
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

  RepeatUiConfig _repeatUiFromStorage(String? rule) {
    final parsed = RepeatSelection.fromStorage(rule);
    switch (parsed.frequency) {
      case RepeatFrequency.weekly:
        return RepeatUiConfig(
          type: RepeatUiType.weekly,
          weekdays: parsed.weekdays,
        );
      case RepeatFrequency.monthly:
        return RepeatUiConfig(
          type: RepeatUiType.monthly,
          monthDays: parsed.monthDays,
        );
      case RepeatFrequency.daily:
        return const RepeatUiConfig(type: RepeatUiType.daily);
      default:
        return const RepeatUiConfig(type: RepeatUiType.daily);
    }
  }

  RepeatSelection _repeatSelectionFromState(RepeatUiConfig repeat) {
    switch (repeat.type) {
      case RepeatUiType.daily:
        return const RepeatSelection(frequency: RepeatFrequency.daily);
      case RepeatUiType.weekly:
        return RepeatSelection(
          frequency: RepeatFrequency.weekly,
          weekdays: Set<int>.from(repeat.weekdays),
        );
      case RepeatUiType.monthly:
        return RepeatSelection(
          frequency: RepeatFrequency.monthly,
          monthDays: Set<int>.from(repeat.monthDays),
        );
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterTitle)),
      );
      return;
    }

    if (_hasIncompleteAction) {
      // 行动项未填完整时阻止保存；会议类型使用更严格的结构校验。
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

    final dateStr =
        _scheduleState.dateEnabled ? _formatDate(_scheduleState.date) : null;
    final timeStr =
        _scheduleState.timeEnabled ? _formatTime(_scheduleState.time) : null;

    final occurrenceDateTime = DateTime(
      _scheduleState.date.year,
      _scheduleState.date.month,
      _scheduleState.date.day,
      _scheduleState.time.hour,
      _scheduleState.time.minute,
    );
    final repeatSelection = _scheduleState.repeatEnabled
        ? _repeatSelectionFromState(_scheduleState.repeat)
        : const RepeatSelection(frequency: RepeatFrequency.none);
    final normalizedRepeat = repeatSelection.toStorage();
    final reminderEnabled = _reminder && _scheduleState.timeEnabled;
    final reminderStorage = reminderEnabled
        ? ReminderRule.fromUi(
            _reminderTime,
            occurrenceDateTime: occurrenceDateTime,
          )?.toStorage()
        : null;

    // 过滤掉未完成输入的 action，避免写入空 type/data。
    final validActions = _actions
        .where((a) => a.type.isNotEmpty && (a.data?.trim().isNotEmpty == true))
        .toList();
    final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text;
    if (kDebugMode && desc != null) {
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
      timeKind: TimeKind.startOnly,
      endTime: null,
      endDate: null,
      hasNotification: reminderEnabled,
      reminderTime: reminderStorage,
      useSystemAlarm: reminderEnabled ? _useSystemAlarm : false,
      repeatRule: normalizedRepeat,
      completed: _task.completed,
      actions: validActions.isEmpty ? null : validActions,
    );

    final rowsUpdated = await TaskRepository().update(entity);
    if (kDebugMode) {
      debugPrint('[TaskDetailSheet] update 返回 rowsUpdated=$rowsUpdated');
    }

    if (mounted &&
        reminderEnabled &&
        _useSystemAlarm &&
        SystemAlarmService.instance.isSupported) {
      // 仅在用户开启系统闹钟且平台支持时创建系统级闹钟。
      final hm = ReminderSettingField.getReminderHourMinute(
        reminderTime: _reminderTime,
        taskDate: _scheduleState.date,
        taskTime: _scheduleState.time,
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
              _buildSaveButton(),
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
          const SizedBox(height: bigSpacing),
          _FieldLabel(text: AppLocalizations.of(context)!.description),
          const SizedBox(height: spacing),
          // 描述区为纯文本多行输入，不做 Markdown 解析/预览。
          _InputField(
            controller: _descCtrl,
            hint: AppLocalizations.of(context)!.description,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: bigSpacing),
          _FieldLabel(text: AppLocalizations.of(context)!.dateAndTime),
          const SizedBox(height: spacing),
          DateTimePickerSection(
            state: _scheduleState,
            onChanged: (next) => setState(() {
              _scheduleState = next;
              if (!_scheduleState.timeEnabled) {
                _reminder = false;
                _reminderTime = null;
                _useSystemAlarm = false;
              }
            }),
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
          if (_scheduleState.timeEnabled)
            ReminderSettingField(
              reminderEnabled: _reminder,
              reminderTime: _reminderTime,
              taskDate: _scheduleState.date,
              taskTime: _scheduleState.time,
              onReminderChanged: (enabled, time) => setState(() {
                _reminder = enabled;
                _reminderTime = time;
              }),
              useSystemAlarm: _useSystemAlarm,
              onSystemAlarmChanged: Platform.isAndroid
                  ? (v) => setState(() => _useSystemAlarm = v)
                  : null,
            ),
          if (!_scheduleState.timeEnabled)
            Text(
              '未启用时间，提醒不可用',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
